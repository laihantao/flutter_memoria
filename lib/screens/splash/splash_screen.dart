import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  static const _captions = [
    '把时光，好好收藏',
    '留住每一个值得记住的瞬间',
    '收藏点滴，温暖如初',
    '把日子，过成故事',
    '写给时间的情书',
    '时光不老，记忆不散',
    '你的生活，值得被好好记录',
    '记录生活的温度',
    '慢下来，记住每一刻',
  ];

  late final String _caption;

  late final AnimationController _logoCtrl;
  late final AnimationController _captionCtrl;
  late final AnimationController _dotsCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _nameSlide;
  late final Animation<double> _nameFade;
  late final Animation<double> _captionSlide;
  late final Animation<double> _captionFade;

  bool _dotsVisible = false;

  @override
  void initState() {
    super.initState();
    _caption = _captions[math.Random().nextInt(_captions.length)];

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _captionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Icon: elastic scale-in + fade
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // App name: slide up from +12px + fade
    _nameSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    // Caption: slide up from +16px + fade (separate controller, fires later)
    _captionSlide = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(parent: _captionCtrl, curve: Curves.easeOutCubic),
    );
    _captionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _captionCtrl, curve: Curves.easeIn),
    );

    // Staggered start: logo @ 300ms, caption @ 800ms, dots @ 1000ms
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _logoCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _captionCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _dotsVisible = true);
    });

    _runSequence();
  }

  Future<void> _runSequence() async {
    bool isOnboarded = false;
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2500)),
      ref.read(databaseProvider).personDao.getSelfPerson().then((p) {
        isOnboarded = p != null;
      }),
    ]);
    if (mounted) context.go(isOnboarded ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _captionCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  // Three bouncing dots — same pattern as Pocket Gold
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final delay = i * (200.0 / 1200.0);
        final phase = (_dotsCtrl.value + delay) % 1.0;
        final sinV = math.sin(phase * math.pi);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: (0.6 + 0.6 * sinV).clamp(0.6, 1.2),
            child: Opacity(
              opacity: (0.3 + 0.7 * sinV).clamp(0.3, 1.0),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pocket Gold pattern:
    //   Scaffold → Stack → Center (icon/name/caption) + Positioned bottom (dots)
    //
    // Stack fills Scaffold.body with tight constraints.
    // Center fills the Stack and centers its child — guaranteed regardless of
    // any upstream constraint looseness. Column uses mainAxisSize.min so it
    // wraps content; Center handles the positioning.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Main content: icon + app name + caption ───────────────────
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_logoCtrl, _captionCtrl]),
              builder: (_, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon — elastic bounce
                  Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/icon.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App name — slides up
                  Transform.translate(
                    offset: Offset(0, _nameSlide.value),
                    child: Opacity(
                      opacity: _nameFade.value,
                      child: Text(
                        'Pocket Memora',
                        style: GoogleFonts.fredoka(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Caption — slides up after 800ms
                  Transform.translate(
                    offset: Offset(0, _captionSlide.value),
                    child: Opacity(
                      opacity: _captionFade.value,
                      child: Text(
                        _caption,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading dots — pinned to bottom ──────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _dotsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedBuilder(
                animation: _dotsCtrl,
                builder: (_, _) => _buildDots(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
