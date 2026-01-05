import 'dart:async';
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
import 'widgets/gemini_wave_visualizer.dart';

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
  bool get _isListening => _callState == VoiceCallState.userSpeaking || _callState == VoiceCallState.idle;
  
  bool _sttAvailable = false;
  bool _showTextInput = false;
  String _userTranscript = '';
  String _aiResponse = '';
  String _callDuration = '00:00';
  int _seconds = 0;
  Timer? _durationTimer;
  String _errorMessage = '';
  final TextEditingController _textController = TextEditingController();

  // Voice session ID - persists throughout the call
  late String _voiceSessionId;

  // Audio level for visual feedback
  double _audioLevel = 0.0;
  
  // Timer for delayed listening start - can be cancelled
  Timer? _delayedListeningTimer;
  
  // Pending AI response - shown when voice starts playing
  String? _pendingAiResponse;
  _VoiceMessage? _pendingAiMessage;

  // Design colors
  static const _backgroundColor = Color(0xFF0F111A); // Deep midnight blue

  @override
  void initState() {
    super.initState();

    // Create a persistent session ID for this voice call
    _voiceSessionId =
        widget.sessionId ?? 'voice_${DateTime.now().millisecondsSinceEpoch}';

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
        // Audio level is now handled by real callback
        break;
      case VoiceCallState.processingAI:
        // CRITICAL: Cancel delayed listening timer to prevent mic from starting during AI processing
        _delayedListeningTimer?.cancel();
        _delayedListeningTimer = null;
        // CRITICAL: Block mic restarts while getting AI response
        _voiceService.blockMicRestarts();
        // Stop listening completely during processing
        _voiceService.stopListening();
        break;
      case VoiceCallState.aiSpeaking:
        // CRITICAL: Cancel delayed listening timer to prevent mic from starting during AI speech
        _delayedListeningTimer?.cancel();
        _delayedListeningTimer = null;
        // Keep mic blocked while AI speaks
        _voiceService.blockMicRestarts();
        break;
      case VoiceCallState.connecting:
      case VoiceCallState.error:
        break;
    }
  }
  
  void _setupVoiceService() {
    _voiceService.onSoundLevelChanged = (level) {
      if (mounted && _callState == VoiceCallState.userSpeaking) {
        setState(() => _audioLevel = level);
      }
    };

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
        // Show the pending AI response text now that voice is playing
        if (_pendingAiResponse != null && mounted) {
          setState(() {
            _aiResponse = _pendingAiResponse!;
            if (_pendingAiMessage != null) {
              _displayMessages.add(_pendingAiMessage!);
            }
            _pendingAiResponse = null;
            _pendingAiMessage = null;
          });
          _scrollToBottom();
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
      
      if (ttsReady) {
        // Store greeting as pending - will show when voice starts
        _pendingAiResponse = greeting;
        _pendingAiMessage = null; // Greeting doesn't go in message list
        
        // Speak greeting - state machine handles transitions via onSpeakingStateChanged
        // Text will be shown when onSpeakingStateChanged fires with speaking=true
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
    if (_callState == VoiceCallState.aiSpeaking || _callState == VoiceCallState.processingAI) return;
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
      
      // Store AI response as pending - will show when voice starts
      _pendingAiResponse = aiText;
      _pendingAiMessage = _VoiceMessage(text: aiText, isUser: false, timestamp: DateTime.now());

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
      await _voiceService.speakStream(aiText);
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
    if (text.isEmpty || _callState == VoiceCallState.processingAI) return;

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
    _delayedListeningTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Column(
              children: [
                _buildHeader(),
                
                // Spacer to push visualizer down
                const Spacer(),
                
                // The Wave Visualizer
                GestureDetector(
                  onTap: _interruptAI,
                  child: SizedBox(
                    height: 500, // Taller container for the waves
                    width: double.infinity,
                    child: GeminiWaveVisualizer(
                      callState: _callState,
                      audioLevel: _audioLevel,
                    ),
                  ),
                ),
                
                // Status Text & Transcript
                _buildStatusArea(),
                
                const Spacer(),
                
                // Controls
                _buildControls(),
                const SizedBox(height: 40),
              ],
            ),
            
            // Text Input Overlay (if needed)
            if (_showTextInput)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildTextInput(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _endCall,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D9FF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _callDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Placeholder for balance
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStatusArea() {
    String statusText = '';
    Color statusColor = Colors.white.withValues(alpha: 0.7);
    
    switch (_callState) {
      case VoiceCallState.connecting:
        statusText = 'Connecting...';
        break;
      case VoiceCallState.idle:
        statusText = 'Listening...';
        break;
      case VoiceCallState.userSpeaking:
        statusText = 'Listening...';
        statusColor = const Color(0xFF64B5F6); // Light Blue
        break;
      case VoiceCallState.processingAI:
        statusText = 'Thinking...';
        statusColor = const Color(0xFFBA68C8); // Purple
        break;
      case VoiceCallState.aiSpeaking:
        statusText = 'MindMate is speaking...';
        statusColor = const Color(0xFF4DD0E1); // Cyan
        break;
      case VoiceCallState.error:
        statusText = _errorMessage.isNotEmpty ? _errorMessage : 'Error';
        statusColor = Colors.redAccent;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Status Label
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Transcript / Response
          if (_userTranscript.isNotEmpty || _aiResponse.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: SingleChildScrollView(
                child: Text(
                  _callState == VoiceCallState.aiSpeaking 
                      ? _aiResponse 
                      : _userTranscript,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Keyboard Toggle
        _buildControlButton(
          icon: _showTextInput ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
          onTap: () => setState(() => _showTextInput = !_showTextInput),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        
        const SizedBox(width: 24),
        
        // End Call (Large)
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Mic Toggle
        _buildControlButton(
          icon: _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
          onTap: _toggleMute,
          color: _isListening 
              ? Colors.white.withValues(alpha: 0.1) 
              : Colors.white.withValues(alpha: 0.3),
          isActive: _isListening,
        ),
      ],
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    bool isActive = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
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
              decoration: const BoxDecoration(
                color: Color(0xFF64B5F6), // Light Blue accent
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
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

