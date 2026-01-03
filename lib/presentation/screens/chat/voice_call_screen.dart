import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/services/voice_call_service.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../domain/services/cloud_functions_service.dart';
import '../../../domain/entities/chat_session.dart';

/// Voice Call State Machine
/// Controls the flow of conversation to prevent mic toggling
enum VoiceCallState {
  /// Initial connecting state
  connecting,
  /// Ready but idle - waiting for user to speak
  idle,
  /// User is currently speaking
  userSpeaking,
  /// Processing user input, getting AI response
  processingAI,
  /// AI is speaking response
  aiSpeaking,
  /// Error state
  error,
}

/// Full-screen voice call with AI
/// Uses speech-to-text and text-to-speech for natural conversation
class VoiceCallScreen extends ConsumerStatefulWidget {
  final String? sessionId;

  const VoiceCallScreen({super.key, this.sessionId});

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen>
    with TickerProviderStateMixin {
  final VoiceCallService _voiceService = VoiceCallService();
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final ChatRepository _chatRepository = ChatRepository();

  // Conversation history for context
  final List<ChatMessage> _conversationHistory = [];

  // Display messages for the UI (includes both user and AI messages)
  final List<_VoiceMessage> _displayMessages = [];
  final ScrollController _scrollController = ScrollController();

  // === STATE MACHINE ===
  VoiceCallState _callState = VoiceCallState.connecting;
  
  // Legacy state flags (kept for compatibility, derived from _callState)
  bool get _isConnecting => _callState == VoiceCallState.connecting;
  bool get _isListening => _callState == VoiceCallState.userSpeaking || _callState == VoiceCallState.idle;
  bool get _isSpeaking => _callState == VoiceCallState.aiSpeaking;
  bool get _isProcessing => _callState == VoiceCallState.processingAI;
  
  bool _sttAvailable = false;
  bool _showTextInput = false;
  String _userTranscript = '';
  String _aiResponse = '';
  String _callDuration = '00:00';
  int _seconds = 0;
  Timer? _durationTimer;
  String _errorMessage = '';
  String _connectingStatus = 'Initializing...';
  final TextEditingController _textController = TextEditingController();

  // Voice session ID - persists throughout the call
  late String _voiceSessionId;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _breatheController;
  late AnimationController _userWaveController;
  
  // Audio level simulation for visual feedback
  double _audioLevel = 0.0;
  Timer? _audioLevelTimer;
  
  // Timer for delayed listening start - can be cancelled
  Timer? _delayedListeningTimer;

  // Design colors
  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF8B5CF6);
  static const _backgroundColor = Color(0xFF1A1A2E);
  static const _accentColor = Color(0xFF00D9FF);
  static const _userSpeakingColor = Color(0xFF10B981);
  static const _aiSpeakingColor = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();

    // Create a persistent session ID for this voice call
    _voiceSessionId =
        widget.sessionId ?? 'voice_${DateTime.now().millisecondsSinceEpoch}';

    // Main pulse animation for orb
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Wave animation for listening state
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    
    // Breathing animation for AI speaking (slower, calmer)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    
    // User speaking waveform animation
    _userWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    _setupVoiceService();
    _initializeCall();
  }

  /// Transition to a new state with proper cleanup
  void _transitionToState(VoiceCallState newState) {
    if (_callState == newState) return;
    
    final oldState = _callState;
    debugPrint('[VoiceCall] State: $oldState → $newState');
    
    setState(() {
      _callState = newState;
    });
    
    // Handle state-specific actions
    switch (newState) {
      case VoiceCallState.idle:
        _stopAudioLevelSimulation();
        // Unblock mic restarts when idle
        _voiceService.unblockMicRestarts();
        // Cancel any existing delayed listening timer
        _delayedListeningTimer?.cancel();
        // Start listening after a longer delay (avoids mic sound and gives time for audio to settle)
        _delayedListeningTimer = Timer(const Duration(milliseconds: 1000), () {
          if (_sttAvailable && !_voiceService.isListening && _callState == VoiceCallState.idle && mounted) {
            debugPrint('[VoiceCall] Starting listening (delayed)');
            _voiceService.startListening(continuous: true);
          }
        });
        break;
      case VoiceCallState.userSpeaking:
        _startAudioLevelSimulation();
        break;
      case VoiceCallState.processingAI:
        _stopAudioLevelSimulation();
        // CRITICAL: Cancel delayed listening timer to prevent mic from starting during AI processing
        _delayedListeningTimer?.cancel();
        _delayedListeningTimer = null;
        // CRITICAL: Block mic restarts while getting AI response
        _voiceService.blockMicRestarts();
        // Stop listening completely during processing
        _voiceService.stopListening();
        break;
      case VoiceCallState.aiSpeaking:
        _stopAudioLevelSimulation();
        // CRITICAL: Cancel delayed listening timer to prevent mic from starting during AI speech
        _delayedListeningTimer?.cancel();
        _delayedListeningTimer = null;
        // Keep mic blocked while AI speaks
        _voiceService.blockMicRestarts();
        break;
      case VoiceCallState.connecting:
      case VoiceCallState.error:
        _stopAudioLevelSimulation();
        break;
    }
  }
  
  /// Simulate audio level for visual feedback
  void _startAudioLevelSimulation() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _callState == VoiceCallState.userSpeaking) {
        setState(() {
          // Simulate varying audio levels
          _audioLevel = 0.3 + (math.Random().nextDouble() * 0.7);
        });
      }
    });
  }
  
  void _stopAudioLevelSimulation() {
    _audioLevelTimer?.cancel();
    if (mounted) {
      setState(() => _audioLevel = 0.0);
    }
  }

  void _setupVoiceService() {
    _voiceService.onSpeechResult = (text) {
      if (mounted && text.isNotEmpty) {
        // User started speaking - transition to userSpeaking
        if (_callState == VoiceCallState.idle) {
          _transitionToState(VoiceCallState.userSpeaking);
        }
        setState(() => _userTranscript = text);
      }
    };

    // Process speech when we get a final result
    _voiceService.onFinalResult = (finalText) {
      if (mounted && finalText.isNotEmpty && _callState != VoiceCallState.processingAI && _callState != VoiceCallState.aiSpeaking) {
        debugPrint('[VoiceCall] Final result - processing: "$finalText"');
        // CRITICAL: Block mic immediately to prevent restart during processing
        _voiceService.blockMicRestarts();
        setState(() => _userTranscript = finalText);
        _processUserSpeech();
      }
    };

    _voiceService.onListeningStateChanged = (listening) {
      // Only update UI, don't change state machine here
      debugPrint('[VoiceCall] Listening state changed: $listening');
    };

    _voiceService.onSpeakingStateChanged = (speaking) {
      debugPrint('[VoiceCall] Speaking state changed: $speaking');
      if (speaking) {
        // AI started speaking - ensure we're in aiSpeaking state
        if (_callState != VoiceCallState.aiSpeaking) {
          _transitionToState(VoiceCallState.aiSpeaking);
        }
      } else if (_callState == VoiceCallState.aiSpeaking) {
        // AI finished speaking - go back to idle
        // This will unblock mic and start listening
        debugPrint('[VoiceCall] AI finished speaking - transitioning to idle');
        _transitionToState(VoiceCallState.idle);
      }
    };

    _voiceService.onError = (error) {
      debugPrint('[VoiceCall] Voice service error: $error');
      // Don't show transient errors, just log them
      if (error.contains('permission') || error.contains('unavailable')) {
        if (mounted) setState(() => _errorMessage = error);
      }
    };
  }

  /// Interrupt AI speaking when user taps
  Future<void> _interruptAI() async {
    if (_callState == VoiceCallState.aiSpeaking) {
      debugPrint('[VoiceCall] User interrupting AI');
      await _voiceService.stopSpeaking();
      _transitionToState(VoiceCallState.idle);
    }
  }

  /// Scroll conversation to bottom
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initializeCall() async {
    debugPrint('Initializing voice call...');

    try {
      // Request microphone permission at runtime with timeout
      if (mounted)
        setState(() => _connectingStatus = 'Requesting mic permission...');
      debugPrint('Requesting microphone permission...');
      final micStatus = await Permission.microphone.request().timeout(
        const Duration(seconds: 10),
        onTimeout: () => PermissionStatus.denied,
      );
      debugPrint('Microphone permission status: $micStatus');

      if (!micStatus.isGranted) {
        if (mounted) {
          setState(() {
            _callState = VoiceCallState.idle;
            _errorMessage =
                'Microphone permission denied. Please grant permission in Settings.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Microphone permission is required for voice calls',
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Request speech permission (needed on some devices) with timeout
      if (mounted) setState(() => _connectingStatus = 'Setting up speech...');
      debugPrint('Requesting speech permission...');
      try {
        await Permission.speech.request().timeout(
          const Duration(seconds: 5),
          onTimeout: () => PermissionStatus.denied,
        );
      } catch (e) {
        debugPrint('Speech permission request failed: $e');
        // Continue anyway - not all devices need this
      }

      // Initialize TTS with timeout
      if (mounted)
        setState(() => _connectingStatus = 'Initializing voice output...');
      debugPrint('Initializing text-to-speech...');
      bool ttsReady = false;
      try {
        // Use Google Cloud Wavenet TTS for natural human-like voice
        ttsReady = await _voiceService.initTts(
          googleCloudApiKey: 'AIzaSyBq3pkFHajhAiYMa-zXFkNzEdh5v_x7tVc',
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('TTS initialization timed out');
            return false;
          },
        );
      } catch (e) {
        debugPrint('TTS init error: $e');
      }
      debugPrint('TTS initialized: $ttsReady');

      if (!ttsReady && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice output unavailable. AI responses will be shown as text.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Initialize STT with timeout
      if (mounted)
        setState(
          () => _connectingStatus = 'Initializing speech recognition...',
        );
      debugPrint('Initializing speech-to-text...');
      bool sttReady = false;
      try {
        sttReady = await _voiceService.initStt().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('STT initialization timed out');
            return false;
          },
        );
      } catch (e) {
        debugPrint('STT init error: $e');
      }
      debugPrint('STT initialized: $sttReady');

      if (mounted) {
        setState(() => _sttAvailable = sttReady);
      }

      if (!sttReady && mounted) {
        setState(() {
          _errorMessage =
              'Speech recognition unavailable - use keyboard to type';
          _showTextInput = true; // Show text input as fallback
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Speech recognition not available. Please install "Google Speech Services" from Play Store.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }

      // Create voice session document in Firestore BEFORE starting call
      debugPrint('About to create voice session with ID: $_voiceSessionId');
      try {
        await _createVoiceSession();
        debugPrint('Voice session creation completed');
      } catch (e) {
        debugPrint('Voice session creation error: $e');
      }

      // Mark as connected - but if TTS is ready, go to processingAI to prevent mic
      // from starting before the greeting finishes
      if (ttsReady) {
        // Go directly to processingAI to block mic and cancel any delayed listening timers
        if (mounted) _transitionToState(VoiceCallState.processingAI);
      } else {
        // No TTS - go to idle which will start listening after delay
        if (mounted) _transitionToState(VoiceCallState.idle);
      }
      _startDurationTimer();

      // AI greets the user - give extra time for TTS to be fully ready
      await Future.delayed(const Duration(milliseconds: 500));

      final greeting = "Hi, I'm here to listen. How are you feeling today?";
      if (mounted) setState(() => _aiResponse = greeting);

      if (ttsReady) {
        // Speak greeting - state machine handles transitions via onSpeakingStateChanged
        // DO NOT transition here - let the callback handle it when audio actually starts
        await _voiceService.speak(greeting);
        
        // speak() returns immediately after starting audio - don't do anything here
        // The onSpeakingStateChanged callback will:
        // 1. Transition to aiSpeaking when audio starts playing
        // 2. Transition to idle when audio finishes
      } else if (sttReady) {
        // No TTS - just start listening directly (we're already in idle state)
        // The idle transition above already started the delayed listening timer
      }
    } catch (e) {
      debugPrint('Voice call initialization error: $e');
      if (mounted) {
        setState(() {
          _callState = VoiceCallState.idle;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  /// Create voice session document in Firestore so Cloud Function can update it
  Future<void> _createVoiceSession() async {
    debugPrint('[VoiceSession] _createVoiceSession called');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[VoiceSession] No user logged in!');
      return;
    }

    debugPrint('[VoiceSession] User ID: ${user.uid}');
    debugPrint('[VoiceSession] Session ID: $_voiceSessionId');

    try {
      debugPrint('[VoiceSession] Creating Firestore document...');
      await FirebaseFirestore.instance
          .collection('chat_sessions')
          .doc(_voiceSessionId)
          .set({
            'userId': user.uid,
            'title': 'Voice Call',
            'startedAt': FieldValue.serverTimestamp(),
            'lastMessageAt': FieldValue.serverTimestamp(),
            'messageCount': 0,
            'messages': [],
            'isVoiceCall': true,
          });
      debugPrint(
        '[VoiceSession] ✅ Voice session document created successfully!',
      );
    } catch (e) {
      debugPrint('[VoiceSession] ❌ Error creating voice session: $e');
      // Continue anyway - the cloud function might still work
      rethrow; // Rethrow so we can see the error in logs
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _seconds++;
      setState(() {
        final mins = (_seconds ~/ 60).toString().padLeft(2, '0');
        final secs = (_seconds % 60).toString().padLeft(2, '0');
        _callDuration = '$mins:$secs';
      });
    });
  }

  void _startListening() async {
    if (_isSpeaking || _isProcessing) return;
    setState(() {
      _userTranscript = '';
      _errorMessage = '';
    });
    // Use continuous listening mode - stays active until call ends
    await _voiceService.startListening(continuous: true);
  }

  void _stopListening() async {
    await _voiceService.stopListeningAndNotify();
  }

  Future<void> _processUserSpeech() async {
    if (_userTranscript.isEmpty) {
      return;
    }

    // Transition to processing state
    _transitionToState(VoiceCallState.processingAI);

    // Store the user's message before clearing
    final userMessage = _userTranscript;
    final messageTimestamp = DateTime.now();

    setState(() {
      _aiResponse = '';
      // Add user message to display list
      _displayMessages.add(
        _VoiceMessage(
          text: userMessage,
          isUser: true,
          timestamp: messageTimestamp,
        ),
      );
    });

    // Scroll to bottom after adding user message
    _scrollToBottom();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Create user message object
    final userChatMessage = ChatMessage(
      id: messageTimestamp.millisecondsSinceEpoch.toString(),
      content: userMessage,
      role: 'user',
      timestamp: messageTimestamp,
    );

    // Add user message to local history
    _conversationHistory.add(userChatMessage);

    // Save user message to Firestore immediately
    try {
      await _chatRepository.addMessageToSession(
        sessionId: _voiceSessionId,
        message: userChatMessage,
      );
      debugPrint('[VoiceCall] User message saved to Firestore');
    } catch (e) {
      debugPrint('[VoiceCall] Error saving user message: $e');
      // Continue anyway - don't block the conversation
    }

    try {
      // Use existing cloud function with the persistent voice session ID
      final response = await _cloudFunctions.sendChatMessage(
        userId: user.uid,
        sessionId: _voiceSessionId,
        message: userMessage,
        conversationHistory: _conversationHistory,
      );

      final aiText = response.response;
      setState(() {
        _aiResponse = aiText;
        // Add AI response to display list
        _displayMessages.add(
          _VoiceMessage(text: aiText, isUser: false, timestamp: DateTime.now()),
        );
      });

      // Scroll to bottom after adding AI message
      _scrollToBottom();

      // Add AI response to history (AI message is saved by cloud function)
      _conversationHistory.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: aiText,
          role: 'assistant',
          timestamp: DateTime.now(),
        ),
      );

      // Speak the response - let onSpeakingStateChanged handle state transitions
      setState(() => _userTranscript = '');
      // DON'T transition here - speak() calls blockMicRestarts() and 
      // onSpeakingStateChanged will handle the transition when audio starts
      await _voiceService.speak(aiText);
    } catch (e) {
      debugPrint('[VoiceCall] Error processing speech: $e');
      setState(() => _userTranscript = '');
      // On error, speak error message
      await _voiceService.speak(
        "I'm sorry, I couldn't process that. Could you try again?",
      );
    }
  }

  /// Send text message (fallback when STT is unavailable)
  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() {
      _userTranscript = text;
      _textController.clear();
      _showTextInput = false;
    });

    await _processUserSpeech();
  }

  void _endCall() async {
    _durationTimer?.cancel();
    await _voiceService.dispose();
    if (mounted) context.pop();
  }

  void _toggleMute() {
    if (!_sttAvailable) {
      // If STT not available, toggle text input instead
      setState(() => _showTextInput = !_showTextInput);
      return;
    }
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _audioLevelTimer?.cancel();
    _delayedListeningTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _breatheController.dispose();
    _userWaveController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Conversation area takes most space
            Expanded(child: _buildConversationArea()),
            // Compact orb with status - tap to interrupt
            _buildCompactOrbAndStatus(),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            // Current transcript (what user is saying now)
            if (_userTranscript.isNotEmpty && !_isProcessing)
              _buildCurrentTranscript(),
            if (_showTextInput) _buildTextInput(),
            const SizedBox(height: 16),
            _buildControls(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Conversation area showing all messages
  Widget _buildConversationArea() {
    if (_displayMessages.isEmpty && !_isProcessing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _sttAvailable
                    ? 'Start speaking to begin the conversation'
                    : 'Type a message to begin',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _displayMessages.length + (_isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayMessages.length && _isProcessing) {
          // Show typing indicator
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_displayMessages[index]);
      },
    );
  }

  /// Individual message bubble
  Widget _buildMessageBubble(_VoiceMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: 12,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                isUser
                    ? _primaryColor.withOpacity(0.8)
                    : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomRight: isUser ? const Radius.circular(4) : null,
              bottomLeft: !isUser ? const Radius.circular(4) : null,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'MindMate AI',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                message.text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Typing indicator when AI is thinking
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 48, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              20,
            ).copyWith(bottomLeft: const Radius.circular(4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MindMate AI ',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 24,
                height: 16,
                child: _ThinkingDots(color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact orb with tap-to-interrupt and state-specific animations
  Widget _buildCompactOrbAndStatus() {
    return GestureDetector(
      onTap: _callState == VoiceCallState.aiSpeaking ? _interruptAI : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated orb based on state
            _buildStateOrb(),
            const SizedBox(height: 12),
            // Status text
            _buildStateStatusText(),
          ],
        ),
      ),
    );
  }
  
  /// State-specific animated orb
  Widget _buildStateOrb() {
    switch (_callState) {
      case VoiceCallState.userSpeaking:
        return _buildUserSpeakingOrb();
      case VoiceCallState.aiSpeaking:
        return _buildAISpeakingOrb();
      case VoiceCallState.processingAI:
        return _buildProcessingOrb();
      case VoiceCallState.idle:
        return _buildIdleOrb();
      case VoiceCallState.connecting:
        return _buildConnectingOrb();
      case VoiceCallState.error:
        return _buildErrorOrb();
    }
  }
  
  /// User speaking - green pulsing orb with waveform
  Widget _buildUserSpeakingOrb() {
    return AnimatedBuilder(
      animation: _userWaveController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer wave rings
              ...List.generate(3, (index) {
                final delay = index * 0.2;
                final scale = 1.0 + (_audioLevel * 0.5 * (index + 1) * 0.3);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 60 * scale,
                  height: 60 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _userSpeakingColor.withOpacity(0.3 - (index * 0.1)),
                      width: 2,
                    ),
                  ),
                );
              }),
              // Core orb
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 50 + (_audioLevel * 10),
                height: 50 + (_audioLevel * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _userSpeakingColor,
                      _userSpeakingColor.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _userSpeakingColor.withOpacity(0.5),
                      blurRadius: 20 + (_audioLevel * 15),
                      spreadRadius: 5 + (_audioLevel * 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// AI speaking - purple breathing orb
  Widget _buildAISpeakingOrb() {
    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, child) {
        final breathe = 1.0 + (_breatheController.value * 0.15);
        return Container(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Breathing glow
              Transform.scale(
                scale: breathe,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _aiSpeakingColor.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              // Core orb
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _aiSpeakingColor,
                      _aiSpeakingColor.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _aiSpeakingColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Processing - spinning indicator
  Widget _buildProcessingOrb() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spinning ring
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                _primaryColor.withOpacity(0.7),
              ),
            ),
          ),
          // Core orb
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryColor.withOpacity(0.3),
            ),
            child: Icon(
              Icons.psychology_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Idle - subtle pulsing ready state
  Widget _buildIdleOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 1.0 + (_pulseController.value * 0.08);
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _accentColor.withOpacity(0.8),
                  _primaryColor.withOpacity(0.5),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              Icons.mic_none_rounded,
              color: Colors.white.withOpacity(0.9),
              size: 22,
            ),
          ),
        );
      },
    );
  }
  
  /// Connecting orb
  Widget _buildConnectingOrb() {
    return SizedBox(
      width: 50,
      height: 50,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
      ),
    );
  }
  
  /// Error orb
  Widget _buildErrorOrb() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.withOpacity(0.3),
      ),
      child: const Icon(
        Icons.error_outline_rounded,
        color: Colors.red,
        size: 24,
      ),
    );
  }
  
  /// State-specific status text
  Widget _buildStateStatusText() {
    String statusText;
    String? subText;
    Color statusColor;
    
    switch (_callState) {
      case VoiceCallState.connecting:
        statusText = _connectingStatus;
        statusColor = Colors.white.withOpacity(0.7);
        break;
      case VoiceCallState.idle:
        statusText = 'Listening...';
        subText = 'Start speaking whenever you\'re ready';
        statusColor = _accentColor;
        break;
      case VoiceCallState.userSpeaking:
        statusText = 'Hearing you...';
        statusColor = _userSpeakingColor;
        break;
      case VoiceCallState.processingAI:
        statusText = 'Thinking...';
        statusColor = _primaryColor;
        break;
      case VoiceCallState.aiSpeaking:
        statusText = 'MindMate is speaking';
        subText = 'Tap to interrupt';
        statusColor = _aiSpeakingColor;
        break;
      case VoiceCallState.error:
        statusText = 'Error';
        subText = _errorMessage;
        statusColor = Colors.red;
        break;
    }
    
    return Column(
      children: [
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  String _buildStatusString() {
    switch (_callState) {
      case VoiceCallState.connecting:
        return _connectingStatus;
      case VoiceCallState.idle:
        return 'Ready';
      case VoiceCallState.userSpeaking:
        return 'Listening...';
      case VoiceCallState.processingAI:
        return 'Thinking...';
      case VoiceCallState.aiSpeaking:
        return 'Speaking...';
      case VoiceCallState.error:
        return 'Error';
    }
  }

  /// Shows what the user is currently saying
  Widget _buildCurrentTranscript() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_rounded, color: _accentColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _userTranscript,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendTextMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MindMate AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isConnecting ? 'Connecting...' : _callDuration,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterOrb() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _waveController]),
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.15);
        final shouldAnimate = _isSpeaking || _isListening;

        return Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (shouldAnimate ? _accentColor : _primaryColor)
                    .withOpacity(0.3),
                blurRadius: shouldAnimate ? 60 : 40,
                spreadRadius: shouldAnimate ? 20 : 10,
              ),
            ],
          ),
          child: Transform.scale(
            scale: shouldAnimate ? scale : 1.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (shouldAnimate ? _accentColor : _primaryColor).withOpacity(
                      0.8,
                    ),
                    _secondaryColor.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
              ),
              child: Center(
                child: Icon(
                  _isSpeaking
                      ? Icons.record_voice_over_rounded
                      : _isListening
                      ? Icons.mic_rounded
                      : Icons.headset_mic_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText() {
    String status;
    if (_isConnecting) {
      status = _connectingStatus;
    } else if (_isProcessing) {
      status = 'Thinking...';
    } else if (_isSpeaking) {
      status = 'Speaking...';
    } else if (_isListening) {
      status = 'Listening...';
    } else if (_sttAvailable) {
      status = 'Ready - just speak';
    } else {
      status = 'Type your message';
    }

    return Text(
      status,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTranscriptArea() {
    final displayText =
        _aiResponse.isNotEmpty
            ? _aiResponse
            : _userTranscript.isNotEmpty
            ? '"$_userTranscript"'
            : '';

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
        child: Text(
          displayText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 18,
            fontStyle:
                _aiResponse.isEmpty ? FontStyle.italic : FontStyle.normal,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mute/Unmute button or Keyboard button if STT unavailable
        GestureDetector(
          onTap: _toggleMute,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color:
                  _showTextInput
                      ? _primaryColor
                      : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              !_sttAvailable
                  ? (_showTextInput
                      ? Icons.keyboard_hide_rounded
                      : Icons.keyboard_rounded)
                  : (_isListening ? Icons.mic_rounded : Icons.mic_off_rounded),
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 40),
        // End call button
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 40),
        // Speaker toggle (placeholder)
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

/// Message model for voice conversation display
class _VoiceMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _VoiceMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Animated thinking dots
class _ThinkingDots extends StatefulWidget {
  final Color color;

  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value + delay) % 1.0);
            final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(opacity.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
