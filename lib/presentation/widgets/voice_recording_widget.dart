import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/services/voice_recording_service.dart';

/// Voice recording button and UI for journal entries
class VoiceRecordingWidget extends StatefulWidget {
  final Function(String? filePath)? onRecordingComplete;
  final VoidCallback? onTranscribing;

  const VoiceRecordingWidget({
    super.key,
    this.onRecordingComplete,
    this.onTranscribing,
  });

  @override
  State<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends State<VoiceRecordingWidget>
    with SingleTickerProviderStateMixin {
  final VoiceRecordingService _service = VoiceRecordingService();
  VoiceRecordingState _state = VoiceRecordingState.idle;
  Duration _duration = Duration.zero;
  Timer? _timer;
  late AnimationController _pulseController;

  static const _primaryColor = Color(0xFF6366F1);
  static const _recordColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_state == VoiceRecordingState.recording) {
      await _stopRecording();
    } else if (_state == VoiceRecordingState.idle) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _service.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    final started = await _service.startRecording();
    if (started) {
      setState(() {
        _state = VoiceRecordingState.recording;
        _duration = Duration.zero;
      });
      _startTimer();
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final filePath = await _service.stopRecording();

    setState(() => _state = VoiceRecordingState.idle);

    if (filePath != null) {
      widget.onRecordingComplete?.call(filePath);
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _service.cancelRecording();
    setState(() {
      _state = VoiceRecordingState.idle;
      _duration = Duration.zero;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _duration = _duration + const Duration(seconds: 1));
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_state == VoiceRecordingState.recording) {
      return _buildRecordingUI();
    }
    return _buildIdleButton();
  }

  Widget _buildIdleButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_rounded, size: 20, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Voice Note',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _recordColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _recordColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Pulse animation
          AnimatedBuilder(
            animation: _pulseController,
            builder:
                (_, __) => Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _recordColor.withOpacity(
                      0.5 + _pulseController.value * 0.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
          ),
          const SizedBox(width: 12),

          // Duration
          Text(
            _formatDuration(_duration),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _recordColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          const Spacer(),

          // Cancel button
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Stop button
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, const Color(0xFF8B5CF6)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
