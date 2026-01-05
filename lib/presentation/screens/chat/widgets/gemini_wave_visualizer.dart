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
    // Draw a subtle gradient background at the bottom for depth
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        const Color(0xFF1A1F3C).withValues(alpha: 0.3),
        const Color(0xFF1A237E).withValues(alpha: 0.4),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    
    final bgPaint = Paint()
      ..shader = bgGradient.createShader(
        Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6),
      bgPaint,
    );
    
    // We draw 3 overlapping waves to create the "Aurora" effect
    // Waves are positioned at the bottom of the canvas and rise upward
    
    // Layer 1: Deep Blue (Background) - Slow moving, tallest wave
    _drawWave(
      canvas,
      size,
      color: const Color(0xFF1A237E).withValues(alpha: 0.7),
      amplitude: 35 + (volume * 25),
      frequency: 1.5,
      phase: animationValue * 2 * math.pi,
      baseOffset: 0,
      waveHeight: 160 + (volume * 50),
    );

    // Layer 2: Purple/Indigo (Mid) - Medium speed
    _drawWave(
      canvas,
      size,
      color: const Color(0xFF5C6BC0).withValues(alpha: 0.6),
      amplitude: 45 + (volume * 45),
      frequency: 2.0,
      phase: (animationValue * 2 * math.pi) + 1.5,
      baseOffset: 0,
      waveHeight: 120 + (volume * 70),
    );

    // Layer 3: Bright Cyan (Foreground) - Fast & Reactive
    _drawWave(
      canvas,
      size,
      color: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
      amplitude: 25 + (volume * 80),
      frequency: 2.8,
      phase: (animationValue * 2 * math.pi) + 3,
      baseOffset: 0,
      waveHeight: 80 + (volume * 90),
      isGlow: true,
    );
    
    // Add a bright highlight layer for extra pop
    _drawWave(
      canvas,
      size,
      color: const Color(0xFFE0F7FA).withValues(alpha: 0.25),
      amplitude: 15 + (volume * 50),
      frequency: 3.5,
      phase: (animationValue * 2 * math.pi) + 5,
      baseOffset: 0,
      waveHeight: 50 + (volume * 60),
      isGlow: true,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required Color color,
    required double amplitude,
    required double frequency,
    required double phase,
    required double baseOffset,
    required double waveHeight,
    bool isGlow = false,
  }) {
    final path = Path();
    final baseY = size.height - baseOffset; // Bottom of canvas

    path.moveTo(0, size.height); // Start at bottom-left corner
    
    // Draw sine wave from left to right
    for (double x = 0; x <= size.width; x++) {
      final normalizedX = x / size.width;
      // Combine two sine waves for organic movement
      final sine1 = math.sin((normalizedX * frequency * 2 * math.pi) + phase);
      final sine2 = math.sin((normalizedX * frequency * 1.5 * 2 * math.pi) + (phase * 1.5));
      
      // Wave rises from the bottom
      final waveY = baseY - waveHeight - (sine1 + sine2 * 0.5) * amplitude;
      path.lineTo(x, waveY);
    }

    path.lineTo(size.width, size.height); // Go to bottom-right corner
    path.close(); // Close the path back to start

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (isGlow) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(GeminiWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.volume != volume;
  }
}
