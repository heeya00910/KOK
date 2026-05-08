import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_shell.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _lightController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _lightController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    bool isLoggedIn = false;
    try {
      isLoggedIn = AuthService().isLoggedIn;
    } catch (_) {}
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isLoggedIn ? const HomeShell() : const LoginPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _lightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildStageBackground(),
          AnimatedBuilder(
            animation: _lightController,
            builder: (context, _) => CustomPaint(
              painter: _StageLightPainter(
                progress: _lightController.value,
              ),
              size: Size.infinite,
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _lightController,
                      builder: (context, child) {
                        final pulse = (sin(_lightController.value * pi * 2) * 0.3 + 0.7);
                        return Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withAlpha((30 * pulse).toInt()),
                                blurRadius: 80,
                                spreadRadius: 30,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFF2D78).withAlpha((18 * pulse).toInt()),
                                blurRadius: 60,
                                spreadRadius: 15,
                              ),
                              BoxShadow(
                                color: Colors.white.withAlpha((12 * pulse).toInt()),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/images/kok_logo.png',
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      "KOREAN'S REAL VIEW ON K-POP",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(120),
                        letterSpacing: 4.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 1.2,
          colors: [
            Color(0xFF0D1B3E),
            Color(0xFF080E1F),
            Color(0xFF050810),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class _StageLightPainter extends CustomPainter {
  final double progress;
  _StageLightPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);

    final beams = [
      _LightBeam(x: 0.15, hue: 320, width: 0.08, speed: 1.0),
      _LightBeam(x: 0.4, hue: 270, width: 0.06, speed: 1.4),
      _LightBeam(x: 0.6, hue: 210, width: 0.07, speed: 0.8),
      _LightBeam(x: 0.85, hue: 340, width: 0.05, speed: 1.2),
      _LightBeam(x: 0.25, hue: 250, width: 0.04, speed: 1.6),
      _LightBeam(x: 0.75, hue: 290, width: 0.06, speed: 0.9),
    ];

    for (final beam in beams) {
      final phase = (progress * beam.speed + rng.nextDouble() * 0.5) % 1.0;
      final sway = sin(phase * pi * 2) * 0.08;
      final intensity = (sin(phase * pi * 2) * 0.5 + 0.5) * 0.12;

      final centerX = (beam.x + sway) * size.width;
      final beamWidth = beam.width * size.width;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HSLColor.fromAHSL(intensity, beam.hue.toDouble(), 0.8, 0.6).toColor(),
            HSLColor.fromAHSL(intensity * 0.3, beam.hue.toDouble(), 0.6, 0.4).toColor(),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      final path = Path()
        ..moveTo(centerX - beamWidth * 0.3, 0)
        ..lineTo(centerX + beamWidth * 0.3, 0)
        ..lineTo(centerX + beamWidth * 2, size.height)
        ..lineTo(centerX - beamWidth * 2, size.height)
        ..close();

      canvas.drawPath(path, paint);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF7C3AED).withAlpha((sin(progress * pi * 2) * 8 + 10).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.35),
      120,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_StageLightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LightBeam {
  final double x;
  final int hue;
  final double width;
  final double speed;
  const _LightBeam({
    required this.x,
    required this.hue,
    required this.width,
    required this.speed,
  });
}
