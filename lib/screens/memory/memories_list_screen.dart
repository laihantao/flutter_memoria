import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/memory_provider.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/file_ops.dart';
import '../../widgets/person_avatar.dart';
import '../../widgets/theme_background.dart';

String _cardTypeEmoji(String type) => switch (type) {
      '旅行' => '✈️',
      '聚会' => '👥',
      '纪念日' => '❤️',
      '美食' => '🍜',
      '活动' => '🎉',
      '日常' => '☀️',
      '成就' => '🏆',
      _ => '📌',
    };

class MemoriesListScreen extends ConsumerWidget {
  const MemoriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final memoriesAsync = ref.watch(memoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.memoriesTitle),
      ),
      body: ThemeBackground(
        child: memoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
          data: (memories) => memories.isEmpty
              ? _EmptyState(onAdd: () => context.push('/memories/new'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: memories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) =>
                      _MemoryCard(memory: memories[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/memories/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Memory card ───────────────────────────────────────────────────────────────

class _MemoryCard extends ConsumerWidget {
  final Memory memory;
  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr =
        context.l10n.memoryDateRange(memory.startDate, memory.endDate);

    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final primaryDeep = isDark ? AppColors.darkPrimaryDeep : AppColors.primaryDeep;

    final themeExt = Theme.of(context).extension<AppThemeExtension>()!;

    final assetsAsync = ref.watch(mediaAssetsProvider(memory.id));
    final assets = assetsAsync.value;
    final String? coverPath = (assets == null || assets.isEmpty)
        ? null
        : assets
            .firstWhere((a) => a.type == 'photo', orElse: () => assets.first)
            .filePath;

    final participantsAsync = ref.watch(memoryParticipantsProvider(memory.id));

    return GestureDetector(
      onTap: () => context.push('/memories/${memory.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: themeExt.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: themeExt.cardShadow.withValues(alpha: 0.38),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: -10,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover with gradient overlay
            _CoverBanner(
              filePath: coverPath,
              isDark: isDark,
              primaryColor: primaryColor,
              primaryDeep: primaryDeep,
              typeEmoji: _cardTypeEmoji(memory.type),
              typeName: memory.type,
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location (if any)
                  if (memory.locationName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Text('📍',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              memory.locationName!,
                              style: GoogleFonts.notoSansSc(
                                fontSize: 12,
                                color: textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Title
                  Text(
                    memory.title,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),

                  // Date
                  Row(
                    children: [
                      Text('📅',
                          style: TextStyle(
                              fontSize: 11,
                              color: textMuted)),
                      const SizedBox(width: 5),
                      Text(
                        dateStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),

                  // Participants
                  participantsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (participants) {
                      if (participants.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _ParticipantAvatarRow(
                          personIds:
                              participants.map((p) => p.personId).toList(),
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cover banner ──────────────────────────────────────────────────────────────

class _CoverBanner extends StatefulWidget {
  final String? filePath;
  final bool isDark;
  final Color primaryColor;
  final Color primaryDeep;
  final String typeEmoji;
  final String typeName;

  const _CoverBanner({
    this.filePath,
    required this.isDark,
    required this.primaryColor,
    required this.primaryDeep,
    required this.typeEmoji,
    required this.typeName,
  });

  @override
  State<_CoverBanner> createState() => _CoverBannerState();
}

class _CoverBannerState extends State<_CoverBanner> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CoverBanner old) {
    super.didUpdateWidget(old);
    if (old.filePath != widget.filePath) _load();
  }

  Future<void> _load() async {
    final path = widget.filePath;
    if (path == null) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma != -1 && mounted) {
        setState(() => _bytes = base64Decode(path.substring(comma + 1)));
      }
      return;
    }
    if (kIsWeb) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    final bytes = await readAppDocFileBytes(path);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = _bytes != null;
    final gradient = Theme.of(context).extension<AppThemeExtension>()!.coverGradient;

    return SizedBox(
      height: hasCover ? 180 : 100,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: photo or gradient
          if (hasCover)
            Image.memory(_bytes!, fit: BoxFit.cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: gradient),
            ),

          // Radial highlight on gradient placeholder
          if (!hasCover)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.5, -0.7),
                  radius: 1.4,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

          // Bottom gradient overlay for text readability (photo only)
          if (hasCover)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF30180C).withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // Type badge pill
          Positioned(
            top: 12,
            left: 13,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasCover
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.typeEmoji} ${widget.typeName}',
                style: GoogleFonts.notoSansSc(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.primaryDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Participant avatar row ────────────────────────────────────────────────────

class _ParticipantAvatarRow extends ConsumerWidget {
  final List<String> personIds;
  final bool isDark;
  const _ParticipantAvatarRow(
      {required this.personIds, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const maxShow = 5;
    final shown = personIds.take(maxShow).toList();
    final extra = personIds.length - shown.length;
    final muted = isDark ? AppColors.darkMuted : AppColors.muted;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

    return Row(
      children: [
        ...shown.map((id) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _MiniAvatar(personId: id),
            )),
        if (extra > 0)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: muted,
            ),
            child: Center(
              child: Text(
                '+$extra',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniAvatar extends ConsumerWidget {
  final String personId;
  const _MiniAvatar({required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personProvider(personId));
    return personAsync.when(
      loading: () => const SizedBox(width: 26, height: 26),
      error: (_, _) => const SizedBox(width: 26, height: 26),
      data: (person) => person == null
          ? const SizedBox(width: 26, height: 26)
          : PersonAvatar(
              name: person.name,
              imagePath: person.avatarPath,
              radius: 13,
            ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final muted = isDark ? AppColors.darkMuted : AppColors.muted;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: muted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('📸', style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.memoriesEmpty,
            style: GoogleFonts.notoSansSc(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.memoriesEmptyHint,
            style: GoogleFonts.notoSansSc(
              fontSize: 14,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.memoriesAdd),
          ),
        ],
      ),
    );
  }
}
