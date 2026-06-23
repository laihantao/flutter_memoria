import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/theme_provider.dart';
import '../theme/theme_config.dart';

/// 2×2 grid of theme preview cards. Tapping a card sets the global active theme.
class ThemePickerGrid extends StatelessWidget {
  const ThemePickerGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.65,
        children: kThemes.map((t) => _ThemeCard(config: t)).toList(),
      ),
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  final ThemeConfig config;
  const _ThemeCard({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeThemeIdProvider);
    final isActive = activeId == config.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? config.darkGradient : config.lightGradient;

    return GestureDetector(
      onTap: () =>
          ref.read(activeThemeIdProvider.notifier).setTheme(config.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Colors.white, width: 2.5)
              : Border.all(color: Colors.white24, width: 1),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: gradient.colors.last.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            if (isActive)
              const Positioned(
                top: 7,
                right: 7,
                child: Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 16),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  config.name,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
