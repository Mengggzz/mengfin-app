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
    for (int i = 0; i < 50; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 6 + _random.nextDouble() * 8, // 6-14px
        speed: (0.1 + _random.nextDouble() * 0.25) * 2, // kecepatan 2x
        swaySpeed: 0.5 + _random.nextDouble() * 1.5,
        swayAmplitude: 0.03 + _random.nextDouble() * 0.05,
        rotation: _random.nextDouble() * 2 * math.pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 2,
        opacity: 0.35 + _random.nextDouble() * 0.35, // 0.35-0.70
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
    final bgColor = AppColors.bg;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Log debug sementara (Task 5 Bug D)
    debugPrint('[SeasonBackground] build: season=${season.name}, isAnimEnabled=$isAnimEnabled, systemDisableAnimations=$disableAnimations');

    // Catatan Bug D & Task 5 (Keputusan Nanda): Mengabaikan preferensi MediaQuery.disableAnimations sistem
    // sehingga hanya toggle "Animasi Background" di aplikasi yang menentukan kemunculan partikel.
    if (!isAnimEnabled) {
      return Container(
        color: bgColor,
        child: widget.child,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: bgColor),
        ),
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

      final s = p.size;

      switch (season) {
        case Season.semi:
          // Semi — bunga 5 kelopak
          paint.color = (isDark ? const Color(0xFFF472B6) : const Color(0xFFEC4899))
              .withValues(alpha: p.opacity);
          for (int i = 0; i < 5; i++) {
            canvas.save();
            canvas.rotate(i * 2 * math.pi / 5);
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(0, -0.55 * s),
                width: 0.64 * s,
                height: 1.1 * s,
              ),
              paint,
            );
            canvas.restore();
          }
          final centerPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFFDE68A);
          canvas.drawCircle(Offset.zero, 0.22 * s, centerPaint);

        case Season.panas:
          // Panas — kilau bintang 4-sisi
          paint.color = (isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B))
              .withValues(alpha: p.opacity * 0.8);
          final s1 = 1.2 * s;
          final starPath = Path()
            ..moveTo(0, -s1)
            ..quadraticBezierTo(0.12 * s1, -0.12 * s1, s1, 0)
            ..quadraticBezierTo(0.12 * s1, 0.12 * s1, 0, s1)
            ..quadraticBezierTo(-0.12 * s1, 0.12 * s1, -s1, 0)
            ..quadraticBezierTo(-0.12 * s1, -0.12 * s1, 0, -s1)
            ..close();
          canvas.drawPath(starPath, paint);

        case Season.gugur:
          // Gugur — daun maple
          paint.color = (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
              .withValues(alpha: p.opacity);
          final maplePath = Path()
            ..moveTo(0, -0.8 * s)
            ..lineTo(0.16 * s, -0.24 * s)
            ..lineTo(0.72 * s, -0.36 * s)
            ..lineTo(0.28 * s, 0)
            ..lineTo(0.72 * s, 0.36 * s)
            ..lineTo(0.16 * s, 0.24 * s)
            ..lineTo(0, 0.8 * s)
            ..lineTo(-0.16 * s, 0.24 * s)
            ..lineTo(-0.72 * s, 0.36 * s)
            ..lineTo(-0.28 * s, 0)
            ..lineTo(-0.72 * s, -0.36 * s)
            ..lineTo(-0.16 * s, -0.24 * s)
            ..close();
          canvas.drawPath(maplePath, paint);
          final stemPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.12 * s
            ..strokeCap = StrokeCap.round
            ..color = paint.color;
          canvas.drawLine(Offset(0, 0.8 * s), Offset(0, 1.1 * s), stemPaint);

        case Season.dingin:
          // Dingin — kristal salju 6-sisi
          final snowColor = (isDark ? const Color(0xFFE0F2FE) : const Color(0xFF38BDF8))
              .withValues(alpha: p.opacity * 0.9);
          final snowPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.16 * s
            ..strokeCap = StrokeCap.round
            ..color = snowColor;
          for (int i = 0; i < 3; i++) {
            final angle = i * math.pi / 3;
            final dx = 0.9 * s * math.cos(angle);
            final dy = 0.9 * s * math.sin(angle);
            canvas.drawLine(Offset(-dx, -dy), Offset(dx, dy), snowPaint);
          }
          final snowDot = Paint()
            ..style = PaintingStyle.fill
            ..color = snowColor;
          canvas.drawCircle(Offset.zero, 0.15 * s, snowDot);

        case Season.defaut:
          // Default — bokeh 2-lapis
          final baseColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0E7490);
          final outerPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = baseColor.withValues(alpha: (p.opacity * 0.18).clamp(0.0, 1.0));
          canvas.drawCircle(Offset.zero, 1.0 * s, outerPaint);
          final innerPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = baseColor.withValues(alpha: (p.opacity * 0.45).clamp(0.0, 1.0));
          canvas.drawCircle(Offset.zero, 0.55 * s, innerPaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonParticlePainter oldDelegate) => true;
}
