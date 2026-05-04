import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

class KokLogo extends StatelessWidget {
  final double fontSize;
  final bool showSubtitle;
  final bool useImage;

  const KokLogo({
    super.key,
    this.fontSize = 28,
    this.showSubtitle = false,
    this.useImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useImage)
          Image.asset(
            'assets/images/kok_logo.png',
            height: fontSize * 1.2,
            fit: BoxFit.contain,
          )
        else
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [KokColors.gradientStart, KokColors.gradientEnd],
            ).createShader(bounds),
            child: Text(
              'KOK',
              style: GoogleFonts.spaceGrotesk(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
        if (showSubtitle)
          Text(
            "Korean's real view On K-pop",
            style: GoogleFonts.inter(
              fontSize: fontSize * 0.35,
              fontWeight: FontWeight.w400,
              color: KokColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
      ],
    );
  }
}
