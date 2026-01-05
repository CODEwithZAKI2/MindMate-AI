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
    with TickerProviderStateMixin {
  late AnimationController _primaryWaveController;
  late AnimationController _secondaryWaveController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  
  // Smooth volume transition
  double _smoothVolume = 0.0;
  double _targetVolume = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Primary wave - slower, smoother movement
    _primaryWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    
    // Secondary wave - different speed for organic feel
    _secondaryWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    // Glow pulsation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    // Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    
    // Smooth volume interpolation
    _primaryWaveController.addListener(_updateSmoothVolume);
  }
  
  void _updateSmoothVolume() {
    setState(() {
      // Smooth lerp towards target volume
      _smoothVolume = _smoothVolume + (_targetVolume - _smoothVolume) * 0.08;
    });
  }

  @override
  void dispose() {
    _primaryWaveController.dispose();
    _secondaryWaveController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine active volume based on state
    double activeVolume = widget.audioLevel;
    
    // Override volume for specific states to ensure animation
    if (widget.callState == VoiceCallState.processingAI || widget.callState == VoiceCallState.connecting) {
      activeVolume = 0.15; // Gentle idle ripple
    } else if (widget.callState == VoiceCallState.aiSpeaking) {
      activeVolume = 0.65; 
    } else if (widget.callState == VoiceCallState.userSpeaking) {
      activeVolume = math.max(0.4, widget.audioLevel);
    } else if (widget.callState == VoiceCallState.idle) {
      activeVolume = 0.08; // Very subtle movement
    }
    
    _targetVolume = activeVolume;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _primaryWaveController,
        _secondaryWaveController,
        _glowController,
        _particleController,
      ]),
      builder: (context, child) {
        return CustomPaint(
          painter: GeminiWavePainter(
            primaryAnimation: _primaryWaveController.value,
            secondaryAnimation: _secondaryWaveController.value,
            glowAnimation: _glowController.value,
            particleAnimation: _particleController.value,
            volume: _smoothVolume,
            callState: widget.callState,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class GeminiWavePainter extends CustomPainter {
  final double primaryAnimation;
  final double secondaryAnimation;
  final double glowAnimation;
  final double particleAnimation;
  final double volume;
  final VoiceCallState callState;
  
  // Pre-computed random values for particles
  static final List<_Particle> _particles = List.generate(
    25,
    (i) => _Particle(
      x: (i * 0.04) + (math.sin(i * 1.5) * 0.1),
      speed: 0.3 + (i % 5) * 0.15,
      size: 2.0 + (i % 4) * 1.5,
      opacity: 0.3 + (i % 3) * 0.2,
    ),
  );

  GeminiWavePainter({
    required this.primaryAnimation,
    required this.secondaryAnimation,
    required this.glowAnimation,
    required this.particleAnimation,
    required this.volume,
    required this.callState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw ambient background glow
    _drawAmbientGlow(canvas, size);
    
    // Draw floating particles
    _drawParticles(canvas, size);
    
    // Draw multiple wave layers with gradients
    _drawGradientWave(
      canvas, size,
      colors: [
        const Color(0xFF0D47A1).withValues(alpha: 0.8),
        const Color(0xFF1565C0).withValues(alpha: 0.6),
        const Color(0xFF1976D2).withValues(alpha: 0.4),
      ],
      animation: primaryAnimation,
      amplitude: 30 + (volume * 35),
      frequency: 1.2,
      phaseOffset: 0,
      waveHeight: 180 + (volume * 60),
    );
    
    // Purple mid-layer
    _drawGradientWave(
      canvas, size,
      colors: [
        const Color(0xFF4527A0).withValues(alpha: 0.7),
        const Color(0xFF5E35B1).withValues(alpha: 0.5),
        const Color(0xFF7E57C2).withValues(alpha: 0.3),
      ],
      animation: secondaryAnimation,
      amplitude: 40 + (volume * 50),
      frequency: 1.6,
      phaseOffset: math.pi / 3,
      waveHeight: 140 + (volume * 80),
    );
    
    // Cyan foreground layer with glow
    _drawGlowingWave(
      canvas, size,
      baseColor: const Color(0xFF00BCD4),
      animation: primaryAnimation,
      secondaryAnimation: secondaryAnimation,
      amplitude: 25 + (volume * 70),
      frequency: 2.0,
      phaseOffset: math.pi / 2,
      waveHeight: 100 + (volume * 100),
      glowIntensity: glowAnimation,
    );
    
    // Bright accent layer
    _drawGlowingWave(
      canvas, size,
      baseColor: const Color(0xFF4DD0E1),
      animation: secondaryAnimation,
      secondaryAnimation: primaryAnimation,
      amplitude: 18 + (volume * 55),
      frequency: 2.5,
      phaseOffset: math.pi,
      waveHeight: 60 + (volume * 70),
      glowIntensity: 1 - glowAnimation,
    );
    
    // Top shimmer layer
    _drawShimmerWave(canvas, size);
  }
  
  void _drawAmbientGlow(Canvas canvas, Size size) {
    final glowPulse = 0.3 + (glowAnimation * 0.2) + (volume * 0.3);
    
    // Bottom center glow
    final centerGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.2),
        radius: 1.0 + (volume * 0.3),
        colors: [
          Color.lerp(
            const Color(0xFF1A237E),
            const Color(0xFF00BCD4),
            volume,
          )!.withValues(alpha: glowPulse),
          const Color(0xFF1A237E).withValues(alpha: glowPulse * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), centerGlow);
  }
  
  void _drawParticles(Canvas canvas, Size size) {
    for (var particle in _particles) {
      final animatedY = (particleAnimation + particle.speed) % 1.0;
      final y = size.height - (animatedY * size.height * 0.7);
      final x = particle.x * size.width + 
                math.sin(animatedY * math.pi * 4 + particle.x * 10) * 20;
      
      // Fade in/out based on position
      final fadeProgress = animatedY;
      final opacity = particle.opacity * 
          math.sin(fadeProgress * math.pi) * 
          (0.5 + volume * 0.5);
      
      if (opacity > 0.05) {
        final particlePaint = Paint()
          ..color = Color.lerp(
            const Color(0xFF4FC3F7),
            const Color(0xFFE0F7FA),
            fadeProgress,
          )!.withValues(alpha: opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size);
        
        canvas.drawCircle(
          Offset(x, y),
          particle.size * (1 + volume * 0.5),
          particlePaint,
        );
      }
    }
  }

  void _drawGradientWave(
    Canvas canvas,
    Size size, {
    required List<Color> colors,
    required double animation,
    required double amplitude,
    required double frequency,
    required double phaseOffset,
    required double waveHeight,
  }) {
    final path = Path();
    final baseY = size.height;
    final phase = animation * 2 * math.pi + phaseOffset;

    path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      
      // Smoother wave with cubic easing
      final easedX = _smoothStep(normalizedX);
      
      // Multiple harmonics for organic movement
      final wave1 = math.sin((easedX * frequency * 2 * math.pi) + phase);
      final wave2 = math.sin((easedX * frequency * 1.3 * 2 * math.pi) + phase * 1.4) * 0.4;
      final wave3 = math.sin((easedX * frequency * 0.7 * 2 * math.pi) + phase * 0.6) * 0.2;
      
      final combinedWave = wave1 + wave2 + wave3;
      final waveY = baseY - waveHeight - combinedWave * amplitude;
      
      path.lineTo(x, waveY);
    }

    path.lineTo(size.width, size.height);
    path.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, size.height - waveHeight - amplitude * 2, size.width, waveHeight + amplitude * 2),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }
  
  void _drawGlowingWave(
    Canvas canvas,
    Size size, {
    required Color baseColor,
    required double animation,
    required double secondaryAnimation,
    required double amplitude,
    required double frequency,
    required double phaseOffset,
    required double waveHeight,
    required double glowIntensity,
  }) {
    final path = Path();
    final baseY = size.height;
    final phase = animation * 2 * math.pi + phaseOffset;
    final phase2 = secondaryAnimation * 2 * math.pi;

    path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      
      // Complex wave with multiple frequencies
      final wave1 = math.sin((normalizedX * frequency * 2 * math.pi) + phase);
      final wave2 = math.sin((normalizedX * frequency * 1.5 * 2 * math.pi) + phase2) * 0.35;
      final wave3 = math.cos((normalizedX * frequency * 0.8 * 2 * math.pi) + phase * 0.7) * 0.25;
      
      final combinedWave = wave1 + wave2 + wave3;
      final waveY = baseY - waveHeight - combinedWave * amplitude;
      
      path.lineTo(x, waveY);
    }

    path.lineTo(size.width, size.height);
    path.close();

    // Draw glow layer first
    final glowPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.3 + glowIntensity * 0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawPath(path, glowPaint);
    
    // Draw main wave with gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        baseColor.withValues(alpha: 0.6 + glowIntensity * 0.2),
        baseColor.withValues(alpha: 0.3),
        baseColor.withValues(alpha: 0.1),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, size.height - waveHeight - amplitude * 2, size.width, waveHeight + amplitude * 2),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }
  
  void _drawShimmerWave(Canvas canvas, Size size) {
    final shimmerPhase = primaryAnimation * 4 * math.pi;
    final waveHeight = 40 + (volume * 50);
    
    final path = Path();
    path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x += 3) {
      final normalizedX = x / size.width;
      
      final wave = math.sin((normalizedX * 3.5 * 2 * math.pi) + shimmerPhase) *
                   math.sin((normalizedX * math.pi)); // Envelope
      
      final waveY = size.height - waveHeight - wave * (15 + volume * 40);
      path.lineTo(x, waveY);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    // Shimmer effect
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + primaryAnimation * 2, 0),
        end: Alignment(primaryAnimation * 2, 0),
        colors: [
          Colors.transparent,
          const Color(0xFFE0F7FA).withValues(alpha: 0.15 + volume * 0.15),
          const Color(0xFFFFFFFF).withValues(alpha: 0.2 + volume * 0.1),
          const Color(0xFFE0F7FA).withValues(alpha: 0.15 + volume * 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, shimmerPaint);
  }
  
  // Smooth step function for easing
  double _smoothStep(double x) {
    return x * x * (3 - 2 * x);
  }

  @override
  bool shouldRepaint(GeminiWavePainter oldDelegate) {
    return oldDelegate.primaryAnimation != primaryAnimation ||
        oldDelegate.secondaryAnimation != secondaryAnimation ||
        oldDelegate.glowAnimation != glowAnimation ||
        oldDelegate.particleAnimation != particleAnimation ||
        oldDelegate.volume != volume;
  }
}

// Helper class for particles
class _Particle {
  final double x;
  final double speed;
  final double size;
  final double opacity;
  
  const _Particle({
    required this.x,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}
