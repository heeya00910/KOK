import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import 'home_shell.dart';
import 'legal_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  late AnimationController _fadeController;
  late AnimationController _lightController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _lightController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _lightController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await AuthService().signInWithGoogle();
      if (mounted) _goHome();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await AuthService().signInWithApple();
      if (mounted) _goHome();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.4),
                radius: 1.3,
                colors: [
                  Color(0xFF0D1B3E),
                  Color(0xFF080E1F),
                  Color(0xFF050810),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _lightController,
            builder: (context, _) => CustomPaint(
              painter: _LoginLightPainter(progress: _lightController.value),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: _lightController,
                      builder: (context, child) {
                        final pulse = (sin(_lightController.value * pi * 2) * 0.3 + 0.7);
                        return Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withAlpha((25 * pulse).toInt()),
                                blurRadius: 70,
                                spreadRadius: 25,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFF2D78).withAlpha((15 * pulse).toInt()),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: Colors.white.withAlpha((10 * pulse).toInt()),
                                blurRadius: 35,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/images/kok_logo.png',
                        height: 140,
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
                    const SizedBox(height: 8),
                    Text(
                      'What Koreans actually think.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withAlpha(60),
                        letterSpacing: 0.8,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Spacer(flex: 2),
                    if (_error != null) _buildError(),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: KokColors.primary,
                          ),
                        ),
                      ),
                    _buildAppleButton(),
                    const SizedBox(height: 12),
                    _buildGoogleButton(),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'By continuing, you agree to our ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withAlpha(50),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LegalPage(type: LegalType.terms))),
                          child: Text(
                            'Terms of Service',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(100),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withAlpha(80),
                            ),
                          ),
                        ),
                        Text(
                          ' and ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withAlpha(50),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LegalPage(type: LegalType.privacy))),
                          child: Text(
                            'Privacy Policy',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(100),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withAlpha(80),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KokColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KokColors.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: KokColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: KokColors.error, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signInWithApple,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white.withAlpha(100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apple_rounded, size: 24, color: Colors.black),
            const SizedBox(width: 10),
            Text('Continue with Apple',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withAlpha(40)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 10),
            Text('Continue with Google',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(220))),
          ],
        ),
      ),
    );
  }
}

class _LoginLightPainter extends CustomPainter {
  final double progress;
  _LoginLightPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final beams = [
      (0.10, 310.0, 0.05, 0.7),
      (0.30, 260.0, 0.04, 1.1),
      (0.55, 220.0, 0.04, 0.6),
      (0.75, 330.0, 0.05, 1.3),
      (0.90, 280.0, 0.03, 0.9),
    ];

    for (final (bx, hue, bw, spd) in beams) {
      final phase = (progress * spd) % 1.0;
      final sway = sin(phase * pi * 2) * 0.05;
      final pulse = (sin(phase * pi * 2) * 0.5 + 0.5) * 0.07;

      final cx = (bx + sway) * size.width;
      final w = bw * size.width;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HSLColor.fromAHSL(pulse, hue, 0.7, 0.55).toColor(),
            HSLColor.fromAHSL(pulse * 0.2, hue, 0.5, 0.35).toColor(),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.8],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      final path = Path()
        ..moveTo(cx - w * 0.2, 0)
        ..lineTo(cx + w * 0.2, 0)
        ..lineTo(cx + w * 2.5, size.height)
        ..lineTo(cx - w * 2.5, size.height)
        ..close();

      canvas.drawPath(path, paint);
    }

    final glow1 = Paint()
      ..color = const Color(0xFFFF2D78).withAlpha((sin(progress * pi * 2) * 4 + 5).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.2), 140, glow1);

    final glow2 = Paint()
      ..color = const Color(0xFF7C3AED).withAlpha((cos(progress * pi * 2) * 3 + 4).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.1), 100, glow2);
  }

  @override
  bool shouldRepaint(_LoginLightPainter old) => old.progress != progress;
}
