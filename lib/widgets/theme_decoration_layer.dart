import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../theme/theme_config.dart';

// Stable for the app session — same launch = same moon phase throughout.
final bool _moonIsFull = Random().nextBool();

// ── Element data ──────────────────────────────────────────────────────────────

class _Flake {
  const _Flake({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.alpha,
    required this.rot,
  });
  final double x;      // 0-1 horizontal fraction
  final double phase;  // 0-1 y-position starting offset
  final double speed;  // cycles per 130s (= 130 / period_seconds, period ∈ [6.5, 13])
  final double size;   // icon size in px
  final double alpha;  // opacity
  final double rot;    // signed total rotation over one descent (radians)
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.base,
    required this.amp,
    required this.twinkleSpeed,
    required this.phase,
    required this.sparkle,
  });
  final double x, y;          // 0-1 fractions
  final double size;
  final double base;           // base opacity
  final double amp;            // opacity oscillation amplitude
  final double twinkleSpeed;  // twinkle cycles per 130s
  final double phase;          // initial phase 0-2π
  final bool sparkle;          // true → auto_awesome, false → star
}

class _HeatElem {
  const _HeatElem({
    required this.x,
    required this.y,
    required this.size,
    required this.alpha,
    required this.type,
  });
  final double x, y;  // 0-1 fractions (y ≥ 0.08 to clear top)
  final double size;
  final double alpha;
  final int type;     // 0=sun, 1=wave, 2=palm
}

// ── Generators ────────────────────────────────────────────────────────────────

List<_Flake> _genFlakes(int seed) {
  final rng = Random(seed);
  return List.generate(18, (_) => _Flake(
    x:     rng.nextDouble(),
    phase: rng.nextDouble(),
    speed: 130.0 / (6.5 + rng.nextDouble() * 6.5),
    size:  8.0 + rng.nextDouble() * 8.0,
    alpha: 0.15 + rng.nextDouble() * 0.15,
    rot:   rng.nextDouble() * (160.0 * pi / 180.0) * (rng.nextBool() ? 1.0 : -1.0),
  ));
}

List<_Star> _genStars(int seed) {
  final rng = Random(seed);
  return List.generate(40, (i) {
    final sparkle = (i % 5 == 0);
    return _Star(
      x:            rng.nextDouble(),
      y:            rng.nextDouble(),
      sparkle:      sparkle,
      size:         sparkle ? (10.0 + rng.nextDouble() * 6.0) : (5.0 + rng.nextDouble() * 7.0),
      base:         0.20 + rng.nextDouble() * 0.12,
      amp:          0.10 + rng.nextDouble() * 0.12,
      phase:        rng.nextDouble() * 6.2832,
      twinkleSpeed: sparkle
          ? 130.0 / (3.0 + rng.nextDouble() * 4.0)
          : 130.0 / (2.5 + rng.nextDouble() * 4.5),
    );
  });
}

List<_HeatElem> _genHeat(int seed) {
  final rng = Random(seed);
  final elems = <_HeatElem>[];
  for (int i = 0; i < 4; i++) {
    elems.add(_HeatElem(
      x: rng.nextDouble(), y: 0.08 + rng.nextDouble() * 0.92,
      size: 14.0 + rng.nextDouble() * 8.0,
      alpha: 0.12 + rng.nextDouble() * 0.10, type: 0,
    ));
  }
  for (int i = 0; i < 3; i++) {
    elems.add(_HeatElem(
      x: rng.nextDouble(), y: 0.08 + rng.nextDouble() * 0.92,
      size: 10.0 + rng.nextDouble() * 8.0,
      alpha: 0.12 + rng.nextDouble() * 0.10, type: 1,
    ));
  }
  for (int i = 0; i < 4; i++) {
    elems.add(_HeatElem(
      x: 0.02 + rng.nextDouble() * 0.96, y: 0.08 + rng.nextDouble() * 0.92,
      size: 16.0 + rng.nextDouble() * 10.0,
      alpha: 0.12 + rng.nextDouble() * 0.10, type: 2,
    ));
  }
  return elems;
}

// ── Widget ────────────────────────────────────────────────────────────────────

class ThemeDecorationLayer extends ConsumerStatefulWidget {
  final int seed;
  const ThemeDecorationLayer({super.key, required this.seed});

  @override
  ConsumerState<ThemeDecorationLayer> createState() => _ThemeDecorationLayerState();
}

class _ThemeDecorationLayerState extends ConsumerState<ThemeDecorationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  List<_Flake> _flakes = const [];
  List<_Star> _stars = const [];
  List<_HeatElem> _heat = const [];
  String _cachedTheme = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 130),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _regen(String themeId) {
    if (themeId == _cachedTheme) return;
    _cachedTheme = themeId;
    switch (themeId) {
      case 'frost_blue':
        _flakes = _genFlakes(widget.seed);
        _stars = const [];
        _heat = const [];
      case 'starry_night':
        _flakes = const [];
        _stars = _genStars(widget.seed);
        _heat = const [];
      case 'heat_wave':
        _flakes = const [];
        _stars = const [];
        _heat = _genHeat(widget.seed);
      default:
        _flakes = const [];
        _stars = const [];
        _heat = const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(activeThemeIdProvider);
    final animEnabled = ref.watch(animationsEnabledProvider);

    if (themeId == 'warm_clay') return const SizedBox.expand();

    _regen(themeId);

    // Only frost_blue and starry_night have animated elements.
    final wantsAnim = animEnabled &&
        (themeId == 'frost_blue' || themeId == 'starry_night');

    if (wantsAnim && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!wantsAnim && _ctrl.isAnimating) {
      _ctrl.stop();
    }

    final config = resolveTheme(themeId, null);

    return IgnorePointer(
      child: CustomPaint(
        painter: _Painter(
          animation: _ctrl,
          themeId: themeId,
          decorColor: config.decorationColor,
          gradient: config.pageBackgroundGradient,
          flakes: _flakes,
          stars: _stars,
          heat: _heat,
          moonIsFull: _moonIsFull,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _Painter extends CustomPainter {
  final Animation<double> animation;
  final String themeId;
  final Color decorColor;
  final LinearGradient? gradient;
  final List<_Flake> flakes;
  final List<_Star> stars;
  final List<_HeatElem> heat;
  final bool moonIsFull;

  _Painter({
    required this.animation,
    required this.themeId,
    required this.decorColor,
    required this.gradient,
    required this.flakes,
    required this.stars,
    required this.heat,
    required this.moonIsFull,
  }) : super(repaint: animation);

  @override
  bool shouldRepaint(_Painter old) =>
      old.themeId != themeId ||
      old.decorColor != decorColor ||
      old.gradient != gradient ||
      old.moonIsFull != moonIsFull;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Gradient page background (replaces flat scaffoldBackgroundColor for frost_blue / starry_night)
    if (gradient != null) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawRect(rect, Paint()..shader = gradient!.createShader(rect));
    }

    // 2. Decorations
    final t = animation.value;
    switch (themeId) {
      case 'frost_blue':   _drawSnow(canvas, size, t);
      case 'heat_wave':    _drawHeat(canvas, size);
      case 'starry_night': _drawNight(canvas, size, t);
    }
  }

  // ── 霜蓝 — animated snowflakes ────────────────────────────────────────────────

  void _drawSnow(Canvas canvas, Size size, double t) {
    for (final f in flakes) {
      // y progresses from 0 to 1 over period, wrapping seamlessly (modulo)
      final yFrac = (t * f.speed + f.phase) % 1.0;
      final angle = f.rot * yFrac;

      canvas.save();
      canvas.translate(f.x * size.width, yFrac * size.height);
      if (angle != 0) canvas.rotate(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.ac_unit.codePoint),
          style: TextStyle(
            fontFamily: Icons.ac_unit.fontFamily,
            fontSize: f.size,
            color: decorColor.withValues(alpha: f.alpha),
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  // ── 热浪 — static beach elements ─────────────────────────────────────────────

  void _drawHeat(Canvas canvas, Size size) {
    for (final e in heat) {
      final p = Offset(e.x * size.width, e.y * size.height);
      final c = decorColor.withValues(alpha: e.alpha);
      switch (e.type) {
        case 0: _glyph(canvas, p, Icons.wb_sunny, e.size, c);
        case 1: _glyph(canvas, p, Icons.waves, e.size, c);
        case 2: _palm(canvas, p, e.size, c);
      }
    }
  }

  // ── 星夜 — animated stars + static moon ──────────────────────────────────────

  void _drawNight(Canvas canvas, Size size, double t) {
    for (final s in stars) {
      // Opacity oscillates via sin — each star has independent speed and phase
      final alpha = (s.base + s.amp * sin(t * s.twinkleSpeed * 6.2832 + s.phase))
          .clamp(0.05, 0.60);
      _glyph(
        canvas,
        Offset(s.x * size.width, s.y * size.height),
        s.sparkle ? Icons.auto_awesome : Icons.star,
        s.size,
        decorColor.withValues(alpha: alpha),
      );
    }

    // Moon — static regardless of animation
    final moonCenter = Offset(size.width * 0.82, size.height * 0.10 + 80);
    if (moonIsFull) {
      canvas.drawCircle(moonCenter, 18.0,
          Paint()..color = const Color(0xFFEDE8DC).withValues(alpha: 0.38));
    } else {
      _glyph(canvas, moonCenter, Icons.nightlight_round, 38.0,
          decorColor.withValues(alpha: 0.38));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _glyph(Canvas canvas, Offset center, IconData icon, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _palm(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = center.dx, cy = center.dy;
    final tw = size * 0.07;
    final topX = cx + size * 0.06;
    final topY = cy - size * 0.14;

    canvas.drawPath(
      Path()
        ..moveTo(cx - tw, cy + size * 0.46)
        ..quadraticBezierTo(cx - tw * 0.4, cy + size * 0.08, topX - tw * 0.5, topY)
        ..lineTo(topX + tw * 0.5, topY)
        ..quadraticBezierTo(cx + tw * 1.6, cy + size * 0.08, cx + tw, cy + size * 0.46)
        ..close(),
      paint,
    );

    void frond(double angle, double len) {
      final dx = sin(angle) * len;
      final dy = -cos(angle) * len;
      final nx = (-dy / len) * len * 0.056;
      final ny = (dx / len) * len * 0.056;
      canvas.drawPath(
        Path()
          ..moveTo(topX + nx, topY + ny)
          ..quadraticBezierTo(
              topX + dx * 0.48 + nx * 0.25, topY + dy * 0.48 + ny * 0.25,
              topX + dx, topY + dy)
          ..quadraticBezierTo(
              topX + dx * 0.48 - nx * 0.25, topY + dy * 0.48 - ny * 0.25,
              topX - nx, topY - ny)
          ..close(),
        paint,
      );
    }

    frond(-1.05, size * 0.43);
    frond(-0.32, size * 0.42);
    frond(0.42,  size * 0.41);
    frond(1.08,  size * 0.39);
  }
}
