// CashEW "Boho Glass" visual style: an earthy bohemian palette and line-art
// backdrop, with frosted glass surfaces layered on top.
// Toggle with the "bohoGlass" setting (on by default).
import 'dart:math' as math;
import 'dart:ui';

import 'package:budget/struct/settings.dart';
import 'package:flutter/material.dart';

bool bohoGlassEnabled() => appStateSettings["bohoGlass"] != false;

// Battery saver keeps the palette but skips blur and the decorated backdrop
bool bohoGlassLite() => appStateSettings["batterySaver"] == true;

class BohoPalette {
  static const Color terracotta = Color(0xFFC0643F);
  static const Color rust = Color(0xFF9E4B2E);
  static const Color mustard = Color(0xFFD9A441);
  static const Color sage = Color(0xFF8E9F6C);
  static const Color olive = Color(0xFF5F6D3D);
  static const Color dustyRose = Color(0xFFD69C8E);
  static const Color clay = Color(0xFFE6B89C);
  static const Color teal = Color(0xFF3E6F70);
  static const Color plum = Color(0xFF7E4F72);
  static const Color cream = Color(0xFFF7EEE3);
  static const Color sand = Color(0xFFEEDFCC);
  static const Color umber = Color(0xFF4A3426);
  static const Color cocoa = Color(0xFF211915);
  static const Color night = Color(0xFF140F0D);
}

Color bohoBackgroundColor(Brightness brightness) =>
    brightness == Brightness.light ? BohoPalette.cream : BohoPalette.cocoa;

// Translucent fill for cards and other surfaces resting on the backdrop
Color bohoGlassFill(Brightness brightness) => brightness == Brightness.light
    ? Colors.white.withOpacity(0.46)
    : Colors.white.withOpacity(0.075);

// Stronger fill for bars that content scrolls underneath
Color bohoGlassBarFill(Brightness brightness) => brightness == Brightness.light
    ? BohoPalette.cream.withOpacity(0.62)
    : BohoPalette.cocoa.withOpacity(0.62);

Color bohoGlassBorder(Brightness brightness) => brightness == Brightness.light
    ? Colors.white.withOpacity(0.75)
    : Colors.white.withOpacity(0.12);

ColorScheme bohoColorScheme(Brightness brightness) {
  if (brightness == Brightness.light) {
    return ColorScheme.fromSeed(
      seedColor: BohoPalette.terracotta,
      brightness: Brightness.light,
    ).copyWith(
      primary: BohoPalette.terracotta,
      onPrimary: Colors.white,
      primaryContainer: BohoPalette.clay,
      onPrimaryContainer: BohoPalette.umber,
      secondary: BohoPalette.olive,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF0DCC6),
      onSecondaryContainer: BohoPalette.umber,
      tertiary: BohoPalette.teal,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD5E3D6),
      onTertiaryContainer: Color(0xFF1F3A3A),
      background: BohoPalette.cream,
      onBackground: BohoPalette.umber,
      surface: BohoPalette.cream,
      onSurface: BohoPalette.umber,
      surfaceVariant: BohoPalette.sand,
      onSurfaceVariant: Color(0xFF6B5444),
      outline: Color(0xFFB59A84),
      outlineVariant: Color(0xFFDCC8B4),
    );
  }
  return ColorScheme.fromSeed(
    seedColor: BohoPalette.terracotta,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Color(0xFFE79B78),
    onPrimary: Color(0xFF3B1A0E),
    primaryContainer: Color(0xFF7A3B24),
    onPrimaryContainer: Color(0xFFFFDBCC),
    secondary: Color(0xFFC2CF9C),
    onSecondary: Color(0xFF2A3214),
    secondaryContainer: Color(0xFF3A2C24),
    onSecondaryContainer: Color(0xFFF3E2D3),
    tertiary: Color(0xFF8FC2C2),
    onTertiary: Color(0xFF0E3333),
    tertiaryContainer: Color(0xFF2A4A4A),
    onTertiaryContainer: Color(0xFFCDEAEA),
    background: BohoPalette.cocoa,
    onBackground: Color(0xFFF3E2D3),
    surface: BohoPalette.cocoa,
    onSurface: Color(0xFFF3E2D3),
    surfaceVariant: Color(0xFF3A2C24),
    onSurfaceVariant: Color(0xFFD8C2B0),
    outline: Color(0xFF8E7768),
    outlineVariant: Color(0xFF52423A),
  );
}

// Paints the backdrop behind [child]. With no child it fills its parent.
class BohoBackground extends StatelessWidget {
  const BohoBackground({this.child, super.key});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (bohoGlassEnabled() == false) return child ?? SizedBox.shrink();
    Widget backdrop = RepaintBoundary(
      child: CustomPaint(
        painter: _BohoBackdropPainter(
          dark: Theme.of(context).brightness == Brightness.dark,
          decorated: bohoGlassLite() == false,
        ),
        child: SizedBox.expand(),
      ),
    );
    if (child == null) return backdrop;
    return Stack(
      fit: StackFit.passthrough,
      children: [Positioned.fill(child: backdrop), child!],
    );
  }
}

// Frosted glass: blurs whatever is behind it and tints it
class BohoGlass extends StatelessWidget {
  const BohoGlass({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.blur = 18,
    this.fill,
    this.border = true,
    super.key,
  });
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color? fill;
  final bool border;

  @override
  Widget build(BuildContext context) {
    Brightness brightness = Theme.of(context).brightness;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill ??
            (bohoGlassLite()
                ? bohoBackgroundColor(brightness).withOpacity(0.94)
                : bohoGlassBarFill(brightness)),
        borderRadius: borderRadius,
        border: border
            ? Border.all(color: bohoGlassBorder(brightness), width: 0.8)
            : null,
      ),
      child: child,
    );
    if (bohoGlassLite()) return surface;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      ),
    );
  }
}

// Large bold text is set in Fraunces with its soft, hand-made axes
TextStyle bohoHeadingStyle(TextStyle style) {
  return style.copyWith(
    fontFamily: "Fraunces",
    fontWeight: FontWeight.w600,
    fontVariations: const [
      FontVariation('wght', 620),
      FontVariation('opsz', 72),
      FontVariation('SOFT', 100),
      FontVariation('WONK', 1),
    ],
    letterSpacing: (style.letterSpacing ?? 0) - 0.2,
  );
}

bool useBohoHeading(double fontSize, FontWeight fontWeight) =>
    bohoGlassEnabled() &&
    fontSize >= 19 &&
    fontWeight.index >= FontWeight.w600.index;

class _BohoBackdropPainter extends CustomPainter {
  _BohoBackdropPainter({required this.dark, required this.decorated});
  final bool dark;
  final bool decorated;

  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width;
    double h = size.height;
    if (w <= 0 || h <= 0) return;
    Rect rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [Color(0xFF2A1E18), BohoPalette.cocoa, BohoPalette.night]
              : [Color(0xFFFAF2E8), BohoPalette.cream, Color(0xFFF1E2D1)],
        ).createShader(rect),
    );

    if (decorated == false) return;

    // Soft colour blobs give the glass something to frost
    double blobScale = math.min(w, 520);
    void blob(Offset c, double r, Color color, double opacity) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(opacity * 0.45),
              color.withOpacity(0),
            ],
            stops: [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    double k = dark ? 0.55 : 1;
    blob(Offset(w * 0.92, h * 0.05), blobScale * 0.85, BohoPalette.terracotta,
        0.5 * k);
    blob(Offset(w * 0.02, h * 0.24), blobScale * 0.7, BohoPalette.mustard,
        0.42 * k);
    blob(Offset(w * 0.95, h * 0.55), blobScale * 0.75, BohoPalette.sage,
        0.42 * k);
    blob(Offset(w * 0.08, h * 0.82), blobScale * 0.8, BohoPalette.dustyRose,
        0.45 * k);
    blob(Offset(w * 0.7, h * 1.02), blobScale * 0.7, BohoPalette.teal,
        0.22 * k);

    Color ink = dark
        ? BohoPalette.clay.withOpacity(0.14)
        : BohoPalette.umber.withOpacity(0.11);
    Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = ink;
    double unit = math.min(w, 480) / 10;

    // Rainbow arches, top right
    Offset rainbow = Offset(w - unit * 1.6, unit * 3.4);
    List<Color> bands = [
      BohoPalette.terracotta,
      BohoPalette.mustard,
      BohoPalette.sage,
      BohoPalette.dustyRose,
    ];
    for (int i = 0; i < bands.length; i++) {
      double r = unit * (2.6 - i * 0.55);
      canvas.drawArc(
        Rect.fromCircle(center: rainbow, radius: r),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.42
          ..strokeCap = StrokeCap.round
          ..color = bands[i].withOpacity(dark ? 0.16 : 0.2),
      );
    }

    // Sun with rays, top left
    Offset sun = Offset(unit * 1.5, unit * 1.9);
    canvas.drawCircle(sun, unit * 0.55, line);
    for (int i = 0; i < 12; i++) {
      double a = i * math.pi / 6;
      Offset dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(sun + dir * unit * 0.8, sun + dir * unit * 1.15, line);
    }

    // Leafy sprig, lower right
    Offset stemStart = Offset(w - unit * 0.6, h * 0.78);
    Path stem = Path()
      ..moveTo(stemStart.dx, stemStart.dy)
      ..quadraticBezierTo(w - unit * 2.2, h * 0.74, w - unit * 3.4, h * 0.66);
    canvas.drawPath(stem, line);
    for (PathMetric metric in stem.computeMetrics()) {
      for (int i = 1; i <= 6; i++) {
        Tangent? t = metric.getTangentForOffset(metric.length * i / 7);
        if (t == null) continue;
        for (int side in [-1, 1]) {
          canvas.save();
          canvas.translate(t.position.dx, t.position.dy);
          canvas.rotate(-t.angle + side * 0.9);
          canvas.drawOval(
            Rect.fromLTWH(0, -unit * 0.16, unit * 0.75, unit * 0.32),
            line,
          );
          canvas.restore();
        }
      }
    }

    // Scalloped half-mandala, lower left
    Offset mandala = Offset(unit * 0.2, h * 0.6);
    for (int ring = 1; ring <= 3; ring++) {
      double r = unit * 0.9 * ring;
      int petals = 6 + ring * 4;
      for (int i = 0; i <= petals; i++) {
        double a = -math.pi / 2 + math.pi * i / petals;
        Offset p = mandala + Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawCircle(p, unit * 0.12 * (4 - ring) * 0.6 + 1, line);
      }
    }

    // Scattered dots
    Paint dot = Paint()..color = ink;
    math.Random random = math.Random(7);
    for (int i = 0; i < 46; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * w, random.nextDouble() * h),
        random.nextDouble() * 1.6 + 0.8,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_BohoBackdropPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.decorated != decorated;
}
