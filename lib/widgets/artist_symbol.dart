import 'dart:math';
import 'package:flutter/material.dart';

class ArtistSymbolStyle {
  final String label;
  final List<Color> gradient;
  final Color foreground;
  final String motif;

  const ArtistSymbolStyle({
    required this.label,
    required this.gradient,
    required this.foreground,
    required this.motif,
  });
}

class ArtistSymbol extends StatelessWidget {
  final String artistName;
  final double size;

  const ArtistSymbol({super.key, required this.artistName, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final style = artistSymbols[artistName];
    if (style == null) return _buildGenericAvatar();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.gradient.length >= 2
              ? [style.gradient[0], style.gradient[1]]
              : [style.gradient[0], style.gradient[0]],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: style.gradient[0].withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.32),
        child: CustomPaint(
          painter: _MotifPainter(
            motif: style.motif,
            color: style.foreground.withAlpha(35),
            size: size,
          ),
          child: Center(
            child: Text(
              style.label,
              style: TextStyle(
                color: style.foreground,
                fontSize: _labelFontSize(style.label),
                fontWeight: FontWeight.w900,
                letterSpacing: style.label.length <= 2 ? 1.0 : -0.3,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _labelFontSize(String label) {
    if (label.length == 1) return size * 0.48;
    if (label.length == 2) return size * 0.40;
    if (label.length == 3) return size * 0.32;
    return size * 0.26;
  }

  Widget _buildGenericAvatar() {
    final initial = artistName.isNotEmpty ? artistName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Text(initial,
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  static const Map<String, ArtistSymbolStyle> artistSymbols = {
    'BTS': ArtistSymbolStyle(
      label: 'BTS',
      gradient: [Color(0xFF1A0533), Color(0xFF7B3FF2)],
      foreground: Colors.white,
      motif: 'orbit',
    ),
    'BLACKPINK': ArtistSymbolStyle(
      label: 'BP',
      gradient: [Color(0xFF111111), Color(0xFF2A0A1A)],
      foreground: Color(0xFFFF4FA3),
      motif: 'thinFrame',
    ),
    'Stray Kids': ArtistSymbolStyle(
      label: 'SKZ',
      gradient: [Color(0xFF111111), Color(0xFF3A0A0A)],
      foreground: Color(0xFFE50914),
      motif: 'slash',
    ),
    'SEVENTEEN': ArtistSymbolStyle(
      label: 'SVT',
      gradient: [Color(0xFF8EC5E8), Color(0xFFF7CAC9)],
      foreground: Color(0xFF111827),
      motif: 'diamondDot',
    ),
    'KATSEYE': ArtistSymbolStyle(
      label: 'KYE',
      gradient: [Color(0xFF2563EB), Color(0xFFC7D2FE)],
      foreground: Color(0xFF111827),
      motif: 'catEye',
    ),
    'Jung Kook': ArtistSymbolStyle(
      label: 'JK',
      gradient: [Color(0xFF111111), Color(0xFF2D1065)],
      foreground: Color(0xFFE5E7EB),
      motif: 'shine',
    ),
    'Lisa': ArtistSymbolStyle(
      label: 'LS',
      gradient: [Color(0xFF111111), Color(0xFF2A1A00)],
      foreground: Color(0xFFD4AF37),
      motif: 'slash',
    ),
    'Jennie': ArtistSymbolStyle(
      label: 'JN',
      gradient: [Color(0xFFF8F1E7), Color(0xFFF0E6D6)],
      foreground: Color(0xFF111111),
      motif: 'glowDot',
    ),
    'Rosé': ArtistSymbolStyle(
      label: 'RS',
      gradient: [Color(0xFF7F1D1D), Color(0xFFB76E79)],
      foreground: Color(0xFFFFF7ED),
      motif: 'wave',
    ),
    'NewJeans': ArtistSymbolStyle(
      label: 'NJ',
      gradient: [Color(0xFF6EE7F9), Color(0xFFA7F3D0)],
      foreground: Color(0xFF111827),
      motif: 'bubbleDot',
    ),
    'aespa': ArtistSymbolStyle(
      label: 'AE',
      gradient: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
      foreground: Colors.white,
      motif: 'grid',
    ),
    'ENHYPEN': ArtistSymbolStyle(
      label: 'EN',
      gradient: [Color(0xFF0F172A), Color(0xFF1E293B)],
      foreground: Color(0xFFF59E0B),
      motif: 'eclipse',
    ),
    'TWICE': ArtistSymbolStyle(
      label: 'TW',
      gradient: [Color(0xFFFFB86C), Color(0xFFFF5FA2)],
      foreground: Color(0xFF111827),
      motif: 'glowDot',
    ),
    'IVE': ArtistSymbolStyle(
      label: 'IV',
      gradient: [Color(0xFF1D4ED8), Color(0xFF3B6CF5)],
      foreground: Colors.white,
      motif: 'shine',
    ),
    'LE SSERAFIM': ArtistSymbolStyle(
      label: 'LSF',
      gradient: [Color(0xFF111111), Color(0xFF1A1A1A)],
      foreground: Colors.white,
      motif: 'upwardCurve',
    ),
    'TXT': ArtistSymbolStyle(
      label: 'TXT',
      gradient: [Color(0xFFA3E635), Color(0xFF22D3EE)],
      foreground: Color(0xFF111827),
      motif: 'sparkle',
    ),
    'ATEEZ': ArtistSymbolStyle(
      label: 'ATZ',
      gradient: [Color(0xFF0F172A), Color(0xFF92400E)],
      foreground: Color(0xFF0EA5E9),
      motif: 'ring',
    ),
    'NCT': ArtistSymbolStyle(
      label: 'NCT',
      gradient: [Color(0xFF111111), Color(0xFF0A1A0A)],
      foreground: Color(0xFF39FF14),
      motif: 'grid',
    ),
    'RIIZE': ArtistSymbolStyle(
      label: 'RZ',
      gradient: [Color(0xFFFF7A1A), Color(0xFF2563EB)],
      foreground: Colors.white,
      motif: 'upwardCurve',
    ),
    'BABYMONSTER': ArtistSymbolStyle(
      label: 'BM',
      gradient: [Color(0xFF111111), Color(0xFF2A0808)],
      foreground: Color(0xFFEF4444),
      motif: 'claw',
    ),
    'EXO': ArtistSymbolStyle(
      label: 'XO',
      gradient: [Color(0xFF111827), Color(0xFF1E293B)],
      foreground: Color(0xFF94A3B8),
      motif: 'orbit',
    ),
    'ITZY': ArtistSymbolStyle(
      label: 'ITZ',
      gradient: [Color(0xFFFF2D95), Color(0xFFFACC15)],
      foreground: Color(0xFF111111),
      motif: 'sparkle',
    ),
    'NMIXX': ArtistSymbolStyle(
      label: 'NMX',
      gradient: [Color(0xFF14B8A6), Color(0xFF8B5CF6)],
      foreground: Colors.white,
      motif: 'wave',
    ),
    'ILLIT': ArtistSymbolStyle(
      label: 'ILT',
      gradient: [Color(0xFFC4B5FD), Color(0xFFFEF3C7)],
      foreground: Color(0xFF111827),
      motif: 'glowDot',
    ),
    'TWS': ArtistSymbolStyle(
      label: 'TWS',
      gradient: [Color(0xFF60A5FA), Color(0xFFEFF6FF)],
      foreground: Color(0xFF1E3A8A),
      motif: 'pageCorner',
    ),
    'KISS OF LIFE': ArtistSymbolStyle(
      label: 'KOL',
      gradient: [Color(0xFF7F1D1D), Color(0xFF4A0E0E)],
      foreground: Color(0xFFF5E6CC),
      motif: 'wave',
    ),
    'ZEROBASEONE': ArtistSymbolStyle(
      label: 'ZB1',
      gradient: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
      foreground: Colors.white,
      motif: 'zeroRing',
    ),
    'BOYNEXTDOOR': ArtistSymbolStyle(
      label: 'BND',
      gradient: [Color(0xFF22C55E), Color(0xFFA7F3D0)],
      foreground: Color(0xFF1E293B),
      motif: 'door',
    ),
    'MONSTA X': ArtistSymbolStyle(
      label: 'MX',
      gradient: [Color(0xFF111111), Color(0xFF1A0808)],
      foreground: Color(0xFFE5E7EB),
      motif: 'slash',
    ),
    'TREASURE': ArtistSymbolStyle(
      label: 'TR',
      gradient: [Color(0xFF2563EB), Color(0xFFDBEAFE)],
      foreground: Colors.white,
      motif: 'diamondDot',
    ),
    '(G)I-DLE': ArtistSymbolStyle(
      label: 'GID',
      gradient: [Color(0xFF7C3AED), Color(0xFFDC2626)],
      foreground: Color(0xFF111111),
      motif: 'stageCurve',
    ),
    'Red Velvet': ArtistSymbolStyle(
      label: 'RV',
      gradient: [Color(0xFFDC2626), Color(0xFFFF6B6B)],
      foreground: Color(0xFFFFF1F2),
      motif: 'cakeLayer',
    ),
    'Kep1er': ArtistSymbolStyle(
      label: 'KP1',
      gradient: [Color(0xFF1E3A8A), Color(0xFFA78BFA)],
      foreground: Colors.white,
      motif: 'ring',
    ),
    'Jimin': ArtistSymbolStyle(
      label: 'JM',
      gradient: [Color(0xFFF5D06F), Color(0xFFC4B5FD)],
      foreground: Color(0xFF111111),
      motif: 'wave',
    ),
    'V': ArtistSymbolStyle(
      label: 'V',
      gradient: [Color(0xFF047857), Color(0xFF92400E)],
      foreground: Color(0xFFE5E7EB),
      motif: 'cameraCorner',
    ),
    'SUGA': ArtistSymbolStyle(
      label: 'SG',
      gradient: [Color(0xFF111111), Color(0xFF374151)],
      foreground: Color(0xFF38BDF8),
      motif: 'waveform',
    ),
    'Jisoo': ArtistSymbolStyle(
      label: 'JS',
      gradient: [Color(0xFF991B1B), Color(0xFF5C1010)],
      foreground: Color(0xFFFFF7ED),
      motif: 'glowDot',
    ),
    'IU': ArtistSymbolStyle(
      label: 'IU',
      gradient: [Color(0xFFC084FC), Color(0xFFEFF6FF)],
      foreground: Color(0xFF111827),
      motif: 'waveform',
    ),
    'izna': ArtistSymbolStyle(
      label: 'IZN',
      gradient: [Color(0xFFBAE6FD), Color(0xFF94A3B8)],
      foreground: Color(0xFF111827),
      motif: 'icySparkle',
    ),
    'Hearts2Hearts': ArtistSymbolStyle(
      label: 'H2H',
      gradient: [Color(0xFFFB7185), Color(0xFFFDBA74)],
      foreground: Colors.white,
      motif: 'connector',
    ),
    'MEOVV': ArtistSymbolStyle(
      label: 'MVV',
      gradient: [Color(0xFF111111), Color(0xFF1A1A2E)],
      foreground: Color(0xFFD1D5DB),
      motif: 'catEye',
    ),
  };
}

class _MotifPainter extends CustomPainter {
  final String motif;
  final Color color;
  final double size;

  _MotifPainter({required this.motif, required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = canvasSize.width;
    final h = canvasSize.height;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size * 0.025
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (motif) {
      case 'orbit':
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.7, height: h * 0.7),
          -pi * 0.3, pi * 1.2, false, paint..strokeWidth = size * 0.02,
        );
        canvas.drawCircle(Offset(w * 0.82, h * 0.22), size * 0.04, fillPaint);

      case 'thinFrame':
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.76, h * 0.76),
          Radius.circular(size * 0.08),
        );
        canvas.drawRRect(r, paint..strokeWidth = size * 0.015);

      case 'slash':
        canvas.drawLine(
          Offset(w * 0.72, h * 0.15),
          Offset(w * 0.85, h * 0.85),
          paint..strokeWidth = size * 0.035,
        );

      case 'sparkle':
        _drawCross(canvas, Offset(w * 0.82, h * 0.18), size * 0.06, fillPaint);
        _drawCross(canvas, Offset(w * 0.15, h * 0.80), size * 0.04, fillPaint);

      case 'catEye':
        final path = Path()
          ..moveTo(w * 0.10, h * 0.78)
          ..quadraticBezierTo(w * 0.50, h * 0.58, w * 0.90, h * 0.78);
        canvas.drawPath(path, paint..strokeWidth = size * 0.025);
        canvas.drawCircle(Offset(w * 0.50, h * 0.72), size * 0.03, fillPaint);

      case 'wave':
        final path = Path()
          ..moveTo(w * 0.08, h * 0.82)
          ..cubicTo(w * 0.30, h * 0.68, w * 0.50, h * 0.92, w * 0.92, h * 0.72);
        canvas.drawPath(path, paint..strokeWidth = size * 0.025);

      case 'connector':
        canvas.drawCircle(Offset(w * 0.20, h * 0.80), size * 0.04, fillPaint);
        canvas.drawCircle(Offset(w * 0.80, h * 0.80), size * 0.04, fillPaint);
        canvas.drawLine(
          Offset(w * 0.24, h * 0.80),
          Offset(w * 0.76, h * 0.80),
          paint..strokeWidth = size * 0.02,
        );

      case 'grid':
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 3; j++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  w * (0.62 + i * 0.10), h * (0.62 + j * 0.10),
                  size * 0.06, size * 0.06,
                ),
                Radius.circular(size * 0.01),
              ),
              fillPaint,
            );
          }
        }

      case 'upwardCurve':
        final path = Path()
          ..moveTo(w * 0.15, h * 0.88)
          ..quadraticBezierTo(w * 0.50, h * 0.60, w * 0.85, h * 0.15);
        canvas.drawPath(path, paint..strokeWidth = size * 0.025);

      case 'claw':
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(w * (0.65 + i * 0.08), h * 0.15),
            Offset(w * (0.58 + i * 0.08), h * 0.40),
            paint..strokeWidth = size * 0.028,
          );
        }

      case 'ring':
        canvas.drawCircle(
          Offset(w * 0.78, h * 0.22),
          size * 0.10,
          paint..strokeWidth = size * 0.02,
        );

      case 'door':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.72, h * 0.55, w * 0.18, h * 0.35),
            Radius.circular(size * 0.03),
          ),
          paint..strokeWidth = size * 0.018,
        );

      case 'waveform':
        final heights = [0.35, 0.55, 0.25, 0.45, 0.30];
        for (var i = 0; i < heights.length; i++) {
          final x = w * (0.15 + i * 0.08);
          final barH = h * heights[i] * 0.35;
          canvas.drawLine(
            Offset(x, h * 0.88),
            Offset(x, h * 0.88 - barH),
            paint..strokeWidth = size * 0.03,
          );
        }

      case 'glowDot':
        canvas.drawCircle(Offset(w * 0.82, h * 0.18), size * 0.07, fillPaint);
        canvas.drawCircle(
          Offset(w * 0.82, h * 0.18), size * 0.12,
          Paint()..color = color.withAlpha(15)..style = PaintingStyle.fill,
        );

      case 'diamondDot':
        final path = Path()
          ..moveTo(w * 0.82, h * 0.12)
          ..lineTo(w * 0.90, h * 0.22)
          ..lineTo(w * 0.82, h * 0.32)
          ..lineTo(w * 0.74, h * 0.22)
          ..close();
        canvas.drawPath(path, fillPaint);

      case 'pageCorner':
        final path = Path()
          ..moveTo(w * 0.75, h * 0.0)
          ..lineTo(w, h * 0.0)
          ..lineTo(w, h * 0.25)
          ..close();
        canvas.drawPath(path, Paint()..color = color.withAlpha(25)..style = PaintingStyle.fill);

      case 'stageCurve':
        final path = Path()
          ..moveTo(0, h * 0.0)
          ..quadraticBezierTo(w * 0.15, h * 0.50, 0, h)
          ..moveTo(w, h * 0.0)
          ..quadraticBezierTo(w * 0.85, h * 0.50, w, h);
        canvas.drawPath(path, paint..strokeWidth = size * 0.02);

      case 'cakeLayer':
        for (var i = 0; i < 3; i++) {
          final y = h * (0.72 + i * 0.08);
          final path = Path()
            ..moveTo(w * 0.10, y)
            ..cubicTo(w * 0.30, y - h * 0.03, w * 0.70, y + h * 0.03, w * 0.90, y);
          canvas.drawPath(path, paint..strokeWidth = size * 0.015);
        }

      case 'cameraCorner':
        final s = size * 0.08;
        // top-left
        canvas.drawLine(Offset(w * 0.10, h * 0.10), Offset(w * 0.10 + s, h * 0.10), paint..strokeWidth = size * 0.02);
        canvas.drawLine(Offset(w * 0.10, h * 0.10), Offset(w * 0.10, h * 0.10 + s), paint);
        // top-right
        canvas.drawLine(Offset(w * 0.90, h * 0.10), Offset(w * 0.90 - s, h * 0.10), paint);
        canvas.drawLine(Offset(w * 0.90, h * 0.10), Offset(w * 0.90, h * 0.10 + s), paint);
        // bottom-left
        canvas.drawLine(Offset(w * 0.10, h * 0.90), Offset(w * 0.10 + s, h * 0.90), paint);
        canvas.drawLine(Offset(w * 0.10, h * 0.90), Offset(w * 0.10, h * 0.90 - s), paint);
        // bottom-right
        canvas.drawLine(Offset(w * 0.90, h * 0.90), Offset(w * 0.90 - s, h * 0.90), paint);
        canvas.drawLine(Offset(w * 0.90, h * 0.90), Offset(w * 0.90, h * 0.90 - s), paint);

      case 'bubbleDot':
        canvas.drawCircle(Offset(w * 0.78, h * 0.20), size * 0.06, fillPaint);
        canvas.drawCircle(Offset(w * 0.88, h * 0.35), size * 0.035, fillPaint);
        canvas.drawCircle(Offset(w * 0.18, h * 0.82), size * 0.045, fillPaint);

      case 'eclipse':
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.78, h * 0.22), width: size * 0.22, height: size * 0.22),
          0, pi * 1.5, false, paint..strokeWidth = size * 0.022,
        );
        canvas.drawCircle(Offset(w * 0.78, h * 0.22), size * 0.04, fillPaint);

      case 'shine':
        _drawCross(canvas, Offset(w * 0.80, h * 0.20), size * 0.09, fillPaint);
        _drawCross(canvas, Offset(w * 0.18, h * 0.82), size * 0.05, fillPaint);

      case 'zeroRing':
        canvas.drawOval(
          Rect.fromCenter(center: Offset(w * 0.80, h * 0.22), width: size * 0.15, height: size * 0.20),
          paint..strokeWidth = size * 0.02,
        );

      case 'icySparkle':
        _drawCross(canvas, Offset(w * 0.80, h * 0.18), size * 0.07, fillPaint);
        canvas.drawLine(
          Offset(w * 0.15, h * 0.85), Offset(w * 0.25, h * 0.75),
          paint..strokeWidth = size * 0.015,
        );
        canvas.drawLine(
          Offset(w * 0.25, h * 0.85), Offset(w * 0.20, h * 0.78),
          paint..strokeWidth = size * 0.015,
        );
    }
  }

  void _drawCross(Canvas canvas, Offset center, double armLen, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - armLen * 0.5, center.dy),
      Offset(center.dx + armLen * 0.5, center.dy),
      Paint()..color = paint.color..strokeWidth = size * 0.025..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - armLen * 0.5),
      Offset(center.dx, center.dy + armLen * 0.5),
      Paint()..color = paint.color..strokeWidth = size * 0.025..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MotifPainter old) =>
      motif != old.motif || color != old.color || size != old.size;
}
