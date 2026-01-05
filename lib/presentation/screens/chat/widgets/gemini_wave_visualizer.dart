import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../voice_call_screen.dart';

class GeminiWaveVisualizer extends StatefulWidget {
  final VoiceCallState callState;
  final double audioLevel; // 0.0 to 1.0

  const GeminiWaveVisualizer({
    super.key,
    required this.callState,
    required this.audioLevel,
  });

  @override
  State<GeminiWaveVisualizer> createState() => _GeminiWaveVisualizerState();
}

class _GeminiWaveVisualizerState extends State<GeminiWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine active volume based on state
    double activeVolume = widget.audioLevel;
    
    // Override volume for specific states to ensure animation
    if (widget.callState == VoiceCallState.processingAI || widget.callState == VoiceCallState.connecting) {
      activeVolume = 0.1; // Gentle idle ripple
    } else if (widget.callState == VoiceCallState.aiSpeaking) {
      // If AI is speaking, use a simulated rhythmic volume if actual volume isn't provided
      // or boost the provided volume
      activeVolume = 0.6; 
    } else if (widget.callState == VoiceCallState.idle) {
      activeVolume = 0.05; // Very subtle movement
    }

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          painter: GeminiWavePainter(
            animationValue: _waveController.value,
            volume: activeVolume,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class GeminiWavePainter extends CustomPainter {
  final double animationValue;
  final double volume;

  GeminiWavePainter({required this.animationValue, required this.volume});

  @override
  void paint(Canvas canvas, Size size) {
    // We draw 3 overlapping waves to create the "Aurora" effect
    
    // Layer 1: Deep Blue (Background) - Slow moving
    _drawWave(
      canvas,
      size,
      color: const Color(0xFF1A237E).withOpacity(0.6),
      amplitude: 30 + (volume * 20),
      frequency: 1.5,
      phase: animationValue * 2 * math.pi,
      yOffset: 120, // Raised up
    );

    // Layer 2: Cyan/Purple (Mid) - Medium speed
    _drawWave(
      canvas,
      size,
      color: const Color(0xFF6C63FF).withOpacity(0.5),
      amplitude: 40 + (volume * 40),
      frequency: 2.2,
      phase: (animationValue * 2 * math.pi) + 2,
      yOffset: 90, // Raised up
    );

    // Layer 3: Bright Cyan/White (Foreground) - Fast & Reactive
    _drawWave(
      canvas,
      size,
      color: const Color(0xFF4FACFE).withOpacity(0.4),
      amplitude: 20 + (volume * 80), // Highly reactive to volume
      frequency: 3.0,
      phase: (animationValue * 2 * math.pi) + 4,
      yOffset: 60, // Raised up
      isGlow: true, // Add glow to this layer
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required Color color,
    required double amplitude,
    required double frequency,
    required double phase,
    required double yOffset,
    bool isGlow = false,
  }) {
    final path = Path();
    final baseHeight = size.height;

    path.moveTo(0, baseHeight);
    
    // Draw sine wave
    for (double x = 0; x <= size.width; x++) {
      // Calculate y using sine wave formula
      // We add some noise/complexity by combining two sine waves
      final normalizedX = x / size.width;
      final sine1 = math.sin((normalizedX * frequency * 2 * math.pi) + phase);
      final sine2 = math.sin((normalizedX * frequency * 1.5 * 2 * math.pi) + (phase * 1.5));
      
      final y = baseHeight - yOffset - (sine1 + sine2 * 0.5) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, baseHeight);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (isGlow) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(GeminiWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.volume != volume;
  }
}
