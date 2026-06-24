import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../theme/theme_config.dart';

// ── Particle data classes ──────────────────────────────────────────────────────

class _SnowFlake {
  final double x;
  final double y0;
  final double radius;
  final double fallSpeed;  // screen-heights per 30-second cycle
  final double swayAmp;
  final double swayFreq;
  final double baseOpacity; // 0.35–0.65
  final double opacityAmp;
  final double phase;

  const _SnowFlake({
    required this.x,
    required this.y0,
    required this.radius,
    required this.fallSpeed,
    required this.swayAmp,
    required this.swayFreq,
    required this.baseOpacity,
    required this.opacityAmp,
    required this.phase,
  });

  factory _SnowFlake.random(math.Random rng) => _SnowFlake(
        x: rng.nextDouble(),
        y0: rng.nextDouble(),
        radius: 5.0 + rng.nextDouble() * 8.0,
        fallSpeed: 2.5 + rng.nextDouble() * 1.5,
        swayAmp: 0.02 + rng.nextDouble() * 0.03,
        swayFreq: 0.5 + rng.nextDouble() * 1.0,
        baseOpacity: 0.35 + rng.nextDouble() * 0.30,
        opacityAmp: 0.05 + rng.nextDouble() * 0.08,
        phase: rng.nextDouble(),
      );
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double baseOpacity;
  final double twinkleAmp;
  final double twinkleFreq;
  final double phase;
  final bool isSparkle; // gold 4-pointed star vs white dot

  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.baseOpacity,
    required this.twinkleAmp,
    required this.twinkleFreq,
    required this.phase,
    required this.isSparkle,
  });

  factory _Star.random(math.Random rng, {required bool sparkle}) => _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: sparkle
            ? (3.5 + rng.nextDouble() * 3.5)
            : (0.8 + rng.nextDouble() * 1.4),
        baseOpacity: sparkle
            ? (0.55 + rng.nextDouble() * 0.35)
            : (0.35 + rng.nextDouble() * 0.35),
        twinkleAmp: sparkle
            ? (0.15 + rng.nextDouble() * 0.25)
            : (0.10 + rng.nextDouble() * 0.18),
        twinkleFreq: sparkle
            ? (4.0 + rng.nextDouble() * 4.0)
            : (3.0 + rng.nextDouble() * 5.0),
        phase: rng.nextDouble(),
        isSparkle: sparkle,
      );
}

class _Ember {
  final double x;
  final double y0;       // starting y (0..1), bottom region
  final double radius;
  final double riseSpeed; // screen-heights per 30s cycle
  final double swayAmp;
  final double swayFreq;
  final double baseOpacity;
  final double opacityAmp;
  final double phase;
  final Color color;

  const _Ember({
    required this.x,
    required this.y0,
    required this.radius,
    required this.riseSpeed,
    required this.swayAmp,
    required this.swayFreq,
    required this.baseOpacity,
    required this.opacityAmp,
    required this.phase,
    required this.color,
  });

  static const _colors = [
    Color(0xFFFF8C00),
    Color(0xFFFF4500),
    Color(0xFFFFD700),
    Color(0xFFFF6347),
  ];

  factory _Ember.random(math.Random rng) => _Ember(
        x: rng.nextDouble(),
        y0: 0.5 + rng.nextDouble() * 0.5,
        radius: 2.0 + rng.nextDouble() * 4.0,
        riseSpeed: 1.5 + rng.nextDouble() * 1.5,
        swayAmp: 0.02 + rng.nextDouble() * 0.04,
        swayFreq: 0.5 + rng.nextDouble() * 1.5,
        baseOpacity: 0.3 + rng.nextDouble() * 0.3,
        opacityAmp: 0.1 + rng.nextDouble() * 0.15,
        phase: rng.nextDouble(),
        color: _colors[rng.nextInt(_colors.length)],
      );
}

// ── CustomPainters ─────────────────────────────────────────────────────────────

class _SnowPainter extends CustomPainter {
  final List<_SnowFlake> flakes;
  final double t;
  final double speedMult;

  const _SnowPainter({
    required this.flakes,
    required this.t,
    required this.speedMult,
  });

  // Precomputed cos/sin for 6 arm angles (multiples of π/3).
  // Branch of arm i with dir ±1 has angle (i±1)·π/3 → index (i±1+6)%6 in same table.
  static final _cos6 = List<double>.unmodifiable(
      List.generate(6, (i) => math.cos(i * math.pi / 3.0)));
  static final _sin6 = List<double>.unmodifiable(
      List.generate(6, (i) => math.sin(i * math.pi / 3.0)));

  @override
  void paint(Canvas canvas, Size size) {
    final et = t * speedMult; // same for every flake — computed once
    for (final f in flakes) {
      final y = (f.y0 + f.fallSpeed * et) % 1.0;
      final x =
          f.x + f.swayAmp * math.sin(2 * math.pi * (f.swayFreq * et + f.phase));
      final opacity = (f.baseOpacity +
              f.opacityAmp * math.sin(2 * math.pi * (1.5 * et + f.phase)))
          .clamp(0.0, 1.0);
      _drawFlake(canvas, x * size.width, y * size.height, f.radius, opacity);
    }
  }

  void _drawFlake(Canvas canvas, double cx, double cy, double r, double opacity) {
    // Blue-tinted glow for visibility on bright gradient top area
    final glowPaint = Paint()
      ..color = const Color(0xFF8FB8E8).withValues(alpha: opacity * 0.28)
      ..strokeWidth = r * 0.45
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final mainPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final armLen = r;
    final branchFraction = r * 0.58;
    final branchLen = r * 0.33;

    for (var i = 0; i < 6; i++) {
      final ac = _cos6[i];
      final as = _sin6[i];
      final ex = cx + ac * armLen;
      final ey = cy + as * armLen;

      canvas.drawLine(Offset(cx, cy), Offset(ex, ey), glowPaint);
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey), mainPaint);

      // Two branches at 58%: dir -1 → index (i+5)%6, dir +1 → index (i+1)%6
      final bx = cx + ac * branchFraction;
      final by = cy + as * branchFraction;
      final biMinus = (i + 5) % 6;
      final biPlus = (i + 1) % 6;
      canvas.drawLine(
        Offset(bx, by),
        Offset(bx + _cos6[biMinus] * branchLen, by + _sin6[biMinus] * branchLen),
        mainPaint,
      );
      canvas.drawLine(
        Offset(bx, by),
        Offset(bx + _cos6[biPlus] * branchLen, by + _sin6[biPlus] * branchLen),
        mainPaint,
      );
    }
    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.13,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_SnowPainter old) =>
      old.t != t || old.speedMult != speedMult;
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  final double speedMult;

  const _StarPainter({
    required this.stars,
    required this.t,
    required this.speedMult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final et = t * speedMult;
      final opacity = (s.baseOpacity +
              s.twinkleAmp *
                  math.sin(2 * math.pi * (s.twinkleFreq * et + s.phase)))
          .clamp(0.0, 1.0);

      final px = s.x * size.width;
      final py = s.y * size.height;

      if (s.isSparkle) {
        _drawSparkle(canvas, px, py, s.radius, opacity);
      } else {
        // White off-white distant star dot
        canvas.drawCircle(
          Offset(px, py),
          s.radius,
          Paint()
            ..color = const Color(0xFFF5F5F0).withValues(alpha: opacity)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawSparkle(Canvas canvas, double cx, double cy, double r, double opacity) {
    final fillPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // 4-pointed star path
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final rad = i.isEven ? r : r * 0.38;
      final x = cx + math.cos(angle) * rad;
      final y = cy + math.sin(angle) * rad;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fillPaint);

    // Glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.55,
      Paint()
        ..color = const Color(0xFFFFE88A).withValues(alpha: opacity * 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.t != t || old.speedMult != speedMult;
}

class _EmberPainter extends CustomPainter {
  final List<_Ember> embers;
  final double t;
  final double speedMult;

  const _EmberPainter({
    required this.embers,
    required this.t,
    required this.speedMult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in embers) {
      final et = t * speedMult;
      // Rise from bottom: y decreases as time increases
      final riseProgress = (e.riseSpeed * et + (1.0 - e.y0)) % 1.0;
      final y = 1.0 - riseProgress;
      final x = e.x +
          e.swayAmp * math.sin(2 * math.pi * (e.swayFreq * et + e.phase));
      final opacity = (e.baseOpacity +
              e.opacityAmp *
                  math.sin(2 * math.pi * (2.0 * et + e.phase)))
          .clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        e.radius,
        Paint()
          ..color = e.color.withValues(alpha: opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.radius * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) =>
      old.t != t || old.speedMult != speedMult;
}

// ── ThemeBackground ────────────────────────────────────────────────────────────

class ThemeBackground extends ConsumerStatefulWidget {
  final Widget child;
  const ThemeBackground({super.key, required this.child});

  @override
  ConsumerState<ThemeBackground> createState() => _ThemeBackgroundState();
}

class _ThemeBackgroundState extends ConsumerState<ThemeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  List<_SnowFlake>? _flakes;
  List<_Star>? _stars;
  List<_Ember>? _embers;
  String? _cachedThemeId;
  double? _cachedDensity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _rebuildParticles(String themeId, double density) {
    _cachedThemeId = themeId;
    _cachedDensity = density;
    _flakes = null;
    _stars = null;
    _embers = null;

    final config = resolveTheme(themeId);
    final effectiveDensity = density * config.densityBaseMultiplier;
    final rng = math.Random(themeId.hashCode ^ 0xABCD);

    if (config.decorations.contains('snowflake')) {
      final count = (17 * effectiveDensity).round().clamp(0, 200);
      _flakes = List.generate(count, (_) => _SnowFlake.random(rng));
    } else if (config.decorations.contains('star')) {
      final total = (40 * effectiveDensity).round().clamp(0, 400);
      final sparkleCount = (total * 0.15).round();
      final dotCount = total - sparkleCount;
      _stars = [
        ...List.generate(dotCount, (_) => _Star.random(rng, sparkle: false)),
        ...List.generate(sparkleCount, (_) => _Star.random(rng, sparkle: true)),
      ];
    } else if (config.decorations.contains('flame')) {
      final count = (10 * effectiveDensity).round().clamp(0, 100);
      _embers = List.generate(count, (_) => _Ember.random(rng));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(activeThemeIdProvider);
    final animEnabled = ref.watch(animationsEnabledProvider);
    final density = ref.watch(decorationDensityProvider);
    final speed = ref.watch(animationSpeedMultiplierProvider);

    if (_cachedThemeId != themeId || _cachedDensity != density) {
      _rebuildParticles(themeId, density);
    }

    final config = resolveTheme(themeId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use the dedicated page-background field; fall back to flat backgroundColor.
    final pageBackground =
        isDark ? config.darkPageBackground : config.lightPageBackground;
    // Combine theme-internal speed baseline with the user's speed slider.
    final effectiveSpeed = config.speedBaseMultiplier * speed;

    final hasFlakes = animEnabled && (_flakes?.isNotEmpty ?? false);
    final hasStars = animEnabled && (_stars?.isNotEmpty ?? false);
    final hasEmbers = animEnabled && (_embers?.isNotEmpty ?? false);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (pageBackground != null)
          DecoratedBox(decoration: BoxDecoration(gradient: pageBackground))
        else
          ColoredBox(color: config.backgroundColor),
        if (hasFlakes)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => CustomPaint(
              painter: _SnowPainter(
                flakes: _flakes!,
                t: _ctrl.value,
                speedMult: effectiveSpeed,
              ),
            ),
          ),
        if (hasStars)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => CustomPaint(
              painter: _StarPainter(
                stars: _stars!,
                t: _ctrl.value,
                speedMult: effectiveSpeed,
              ),
            ),
          ),
        if (hasEmbers)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => CustomPaint(
              painter: _EmberPainter(
                embers: _embers!,
                t: _ctrl.value,
                speedMult: effectiveSpeed,
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}
