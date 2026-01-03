import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/services/voice_call_service.dart';
import '../../../domain/services/cloud_functions_service.dart';
import '../../../domain/entities/chat_session.dart';

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

  // Conversation history for context
  final List<ChatMessage> _conversationHistory = [];

  // Call state
  bool _isConnecting = true;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String _userTranscript = '';
  String _aiResponse = '';
  String _callDuration = '00:00';
  int _seconds = 0;
  Timer? _durationTimer;
  String _errorMessage = '';

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Design colors
  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF8B5CF6);
  static const _backgroundColor = Color(0xFF1A1A2E);
  static const _accentColor = Color(0xFF00D9FF);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _setupVoiceService();
    _initializeCall();
  }

  void _setupVoiceService() {
    _voiceService.onSpeechResult = (text) {
      if (mounted) setState(() => _userTranscript = text);
    };

    _voiceService.onListeningStateChanged = (listening) {
      if (mounted) setState(() => _isListening = listening);
      // Process speech when we get final result and listening stops
      if (!listening && _userTranscript.isNotEmpty && !_isProcessing && !_isSpeaking) {
        _processUserSpeech();
      }
    };

    _voiceService.onSpeakingStateChanged = (speaking) {
      if (mounted) setState(() => _isSpeaking = speaking);
      // When AI finishes speaking, resume continuous listening
      if (!speaking && !_isProcessing && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _voiceService.isSttAvailable && !_voiceService.isListening) {
            _startListening();
          }
        });
      }
    };

    _voiceService.onError = (error) {
      debugPrint('Voice service error: $error');
      if (mounted) setState(() => _errorMessage = error);
    };
  }

  Future<void> _initializeCall() async {
    debugPrint('Initializing voice call...');

    // Request microphone permission at runtime
    debugPrint('Requesting microphone permission...');
    final micStatus = await Permission.microphone.request();
    debugPrint('Microphone permission status: $micStatus');

    if (!micStatus.isGranted) {
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Microphone permission denied';
      });
      if (mounted) {
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

    // Request speech permission (needed on some devices)
    debugPrint('Requesting speech permission...');
    final speechStatus = await Permission.speech.request();
    debugPrint('Speech permission status: $speechStatus');

    // Initialize TTS FIRST and wait for it to be ready
    debugPrint('Initializing text-to-speech...');
    final ttsReady = await _voiceService.initTts();
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

    // Initialize STT
    debugPrint('Initializing speech-to-text...');
    final sttReady = await _voiceService.initStt();
    debugPrint('STT initialized: $sttReady');

    if (!sttReady && mounted) {
      setState(() => _errorMessage = 'Speech recognition unavailable');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Speech recognition not available. On emulator, install "Google Speech Services" from Play Store and download English language pack.',
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

    if (mounted) setState(() => _isConnecting = false);
    _startDurationTimer();

    // AI greets the user - give extra time for TTS to be fully ready
    await Future.delayed(const Duration(milliseconds: 1000));

    final greeting = "Hi, I'm here to listen. How are you feeling today?";
    setState(() => _aiResponse = greeting);
    await _voiceService.speak(greeting);
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
    await _voiceService.stopListening();
  }

  Future<void> _processUserSpeech() async {
    if (_userTranscript.isEmpty) {
      return; // Don't restart here, continuous mode handles it
    }

    // Pause listening while processing (but keep continuous mode enabled)
    await _voiceService.pauseListening();
    
    setState(() {
      _isProcessing = true;
      _aiResponse = '';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Add user message to history
    _conversationHistory.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: _userTranscript,
        role: 'user',
        timestamp: DateTime.now(),
      ),
    );

    try {
      // Use existing cloud function
      final response = await _cloudFunctions.sendChatMessage(
        userId: user.uid,
        sessionId:
            widget.sessionId ??
            'voice_${DateTime.now().millisecondsSinceEpoch}',
        message: _userTranscript,
        conversationHistory: _conversationHistory,
      );

      final aiText = response.response;
      setState(() => _aiResponse = aiText);

      // Add AI response to history
      _conversationHistory.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: aiText,
          role: 'assistant',
          timestamp: DateTime.now(),
        ),
      );

      // Speak the response
      await _voiceService.speak(aiText);
    } catch (e) {
      debugPrint('Error processing speech: $e');
      await _voiceService.speak(
        "I'm sorry, I couldn't process that. Could you try again?",
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _endCall() async {
    _durationTimer?.cancel();
    await _voiceService.dispose();
    if (mounted) context.pop();
  }

  void _toggleMute() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Spacer(),
            _buildCenterOrb(),
            const SizedBox(height: 32),
            _buildStatusText(),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
              ),
            ],
            const Spacer(),
            _buildTranscriptArea(),
            const SizedBox(height: 24),
            _buildControls(),
            const SizedBox(height: 40),
          ],
        ),
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
      status = 'Connecting...';
    } else if (_isProcessing) {
      status = 'Thinking...';
    } else if (_isSpeaking) {
      status = 'AI is speaking';
    } else if (_isListening) {
      status = 'Listening...';
    } else {
      status = 'Tap mic to speak';
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
        // Mute/Unmute button
        GestureDetector(
          onTap: _toggleMute,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
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
