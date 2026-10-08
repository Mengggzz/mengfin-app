import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../services/theme_service.dart';

class SeasonBackground extends StatefulWidget {
  final Widget child;
  const SeasonBackground({super.key, required this.child});

  @override
  State<SeasonBackground> createState() => _SeasonBackgroundState();
}

class _SeasonBackgroundState extends State<SeasonBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initParticles();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 3 + _random.nextDouble() * 6,
        speed: 0.1 + _random.nextDouble() * 0.25,
        swaySpeed: 0.5 + _random.nextDouble() * 1.5,
        swayAmplitude: 0.02 + _random.nextDouble() * 0.04,
        rotation: _random.nextDouble() * 2 * math.pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 2,
        opacity: 0.15 + _random.nextDouble() * 0.25,
      ));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (state == AppLifecycleState.paused) {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final season = themeService.season;
    final isAnimEnabled = themeService.animasiBackground;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (!isAnimEnabled || disableAnimations) {
      return widget.child;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SeasonParticlePainter(
                    particles: _particles,
                    progress: _controller.value,
                    season: season,
                    isDark: themeService.isDark,
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double swaySpeed;
  final double swayAmplitude;
  double rotation;
  final double rotationSpeed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.swaySpeed,
    required this.swayAmplitude,
    required this.rotation,
    required this.rotationSpeed,
    required this.opacity,
  });
}

class _SeasonParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Season season;
  final bool isDark;

  _SeasonParticlePainter({
    required this.particles,
    required this.progress,
    required this.season,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      double currentY;
      double currentX;

      if (season == Season.panas) {
        // Melayang ke atas
        currentY = (p.y - progress * p.speed) % 1.0;
        if (currentY < 0) currentY += 1.0;
        currentX = (p.x + math.sin(progress * 2 * math.pi * p.swaySpeed) * p.swayAmplitude) % 1.0;
      } else {
        // Jatuh ke bawah
        currentY = (p.y + progress * p.speed) % 1.0;
        currentX = (p.x + math.sin(progress * 2 * math.pi * p.swaySpeed) * p.swayAmplitude) % 1.0;
      }

      final drawX = currentX * size.width;
      final drawY = currentY * size.height;
      final currentRotation = p.rotation + progress * p.rotationSpeed * math.pi;

      canvas.save();
      canvas.translate(drawX, drawY);
      canvas.rotate(currentRotation);

      final paint = Paint()..style = PaintingStyle.fill;

      switch (season) {
        case Season.semi:
          // Kelopak bunga pink
          paint.color = (isDark ? const Color(0xFFF472B6) : const Color(0xFFEC4899))
              .withValues(alpha: p.opacity);
          final rect = Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size);
          canvas.drawOval(rect, paint);

        case Season.panas:
          // Bokeh cahaya hangat melayang naik
          paint.color = (isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B))
              .withValues(alpha: p.opacity * 0.8);
          canvas.drawCircle(Offset.zero, p.size * 1.2, paint);

        case Season.gugur:
          // Daun jatuh amber / coklat
          paint.color = (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
              .withValues(alpha: p.opacity);
          final path = Path();
          path.moveTo(0, -p.size);
          path.quadraticBezierTo(p.size, 0, 0, p.size);
          path.quadraticBezierTo(-p.size, 0, 0, -p.size);
          canvas.drawPath(path, paint);

        case Season.dingin:
          // Salju putih kebiruan
          paint.color = (isDark ? const Color(0xFFE0F2FE) : const Color(0xFF38BDF8))
              .withValues(alpha: p.opacity * 0.9);
          canvas.drawCircle(Offset.zero, p.size * 0.8, paint);

        case Season.defaut:
          // Partikel halus cyan
          paint.color = (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0E7490))
              .withValues(alpha: p.opacity * 0.6);
          canvas.drawCircle(Offset.zero, p.size * 0.7, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonParticlePainter oldDelegate) => true;
}
