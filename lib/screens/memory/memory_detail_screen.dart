import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/person_provider.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/file_ops.dart';
import '../../widgets/person_avatar.dart';
import '../../widgets/theme_background.dart';
import '../../widgets/theme_picker_grid.dart';
import 'expense_export_screen.dart';
import 'memory_expenses_tab.dart';

// ── Shared helpers ─────────────────────────────────────────────────────────────

String _durationText(Memory memory, AppLocalizations l10n) {
  if (memory.endDate == null) return '';
  final diff = memory.endDate!.difference(memory.startDate).inDays;
  if (diff <= 0) return '';
  return l10n.memoryDurationNights(diff + 1, diff);
}

String _dateText(Memory memory, AppLocalizations l10n) =>
    l10n.memoryDateRange(memory.startDate, memory.endDate);

String _countdownText(DateTime startDate, AppLocalizations l10n) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final diff = start.difference(today).inDays;
  if (diff > 0) return l10n.memoryCountdownDays(diff);
  if (diff == 0) return l10n.memoryCountdownToday;
  return l10n.memoryCountdownPast;
}

String _typeEmoji(String type) => switch (type) {
      '旅行' => '✈️',
      '聚会' => '👥',
      '纪念日' => '❤️',
      '美食' => '🍜',
      '活动' => '🎉',
      '日常' => '☀️',
      '成就' => '🏆',
      _ => '📌',
    };

String _currencySym(List<Transaction> txns) =>
    const {'MYR': 'RM', 'SGD': 'S\$'}[txns.firstOrNull?.currencyCode] ??
    (txns.firstOrNull?.currencyCode ?? 'RM');

String _formatAmt(double total, String sym) {
  if (total >= 1000) return '$sym ${(total / 1000).toStringAsFixed(1)}k';
  return '$sym ${total.toStringAsFixed(2)}';
}

// ── Main screen ────────────────────────────────────────────────────────────────

class MemoryDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const MemoryDetailScreen({super.key, required this.id});

  @override
  ConsumerState<MemoryDetailScreen> createState() =>
      _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final ScrollController _overviewScrollCtrl;
  bool _heroExpanded = true;

  @override
  void initState() {
    super.initState();
    _overviewScrollCtrl = ScrollController();
    _overviewScrollCtrl.addListener(_onOverviewScroll);
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (!mounted) return;
    setState(() {
      if (_tabs.index != 0) {
        _heroExpanded = false;
      } else {
        final offset = _overviewScrollCtrl.hasClients
            ? _overviewScrollCtrl.offset
            : 0.0;
        // Only expand if already at very top
        _heroExpanded = offset <= 0;
      }
    });
  }

  void _onOverviewScroll() {
    if (!mounted || _tabs.index != 0) return;
    final offset = _overviewScrollCtrl.offset;
    if (_heroExpanded && offset >= 80) {
      setState(() => _heroExpanded = false);
    }
    // Re-expanding is handled by _onTopOverscroll (second upward gesture at top)
  }

  void _onTopOverscroll() {
    if (!mounted || _tabs.index != 0 || _heroExpanded) return;
    setState(() => _heroExpanded = true);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
    _overviewScrollCtrl.removeListener(_onOverviewScroll);
    _overviewScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(Memory memory) async {
    final l10n = context.l10n;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.memoryExportPdfMobileOnly)),
      );
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.memoryExportTitle),
        content: Text(l10n.memoryExportChoice),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'keepsake'),
              child: Text(l10n.memoryExportKeepsake)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'settlement'),
              child: Text(l10n.memoryExportSettlement)),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    // 分账 / expenses: dedicated preview screen with per-section toggles and a
    // per-currency Payment Statement + Final Consolidate (Req G).
    if (choice == 'settlement') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExpenseExportScreen(memory: memory),
      ));
      return;
    }

    // Keepsake: cover + itinerary + photo grid, shared directly.
    try {
      final itinerary = await ref.read(itineraryProvider(widget.id).future);
      final mediaAssets =
          await ref.read(mediaAssetsProvider(widget.id).future);

      final pdfBytes = await PdfService.generateKeepsake(
        memory: memory,
        itinerary: itinerary,
        mediaAssets: mediaAssets,
        participantNames: const [],
      );

      if (!mounted) return;
      await Share.shareXFiles([
        XFile.fromData(pdfBytes,
            name: 'memora_keepsake_${memory.id}.pdf',
            mimeType: 'application/pdf'),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.memoryExportFailed('$e'))),
        );
      }
    }
  }

  Future<void> _pickMedia() async {
    final l10n = context.l10n;
    final notifier = ref.read(memoryNotifierProvider.notifier);
    int addedCount = 0;
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.media,
          withData: true,
        );
        if (result == null) return;
        for (final pf in result.files) {
          if (pf.bytes == null) continue;
          final xf = XFile.fromData(pf.bytes!, name: pf.name);
          final type = (pf.extension ?? '').toLowerCase();
          final isVideo =
              ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(type);
          await notifier.addMediaAsset(
            memoryId: widget.id,
            file: xf,
            type: isVideo ? 'video' : 'photo',
          );
          addedCount++;
        }
      } else {
        final files = await ImagePicker().pickMultipleMedia();
        for (final file in files) {
          final name = file.name.isNotEmpty ? file.name : file.path;
          final ext =
              name.contains('.') ? name.split('.').last.toLowerCase() : '';
          final isVideo =
              const {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'}.contains(ext);
          await notifier.addMediaAsset(
            memoryId: widget.id,
            file: file,
            type: isVideo ? 'video' : 'photo',
          );
          addedCount++;
        }
      }
      if (addedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.addedSuccess),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWith('$e'))),
        );
      }
    }
  }

  Future<void> _deleteMemory(Memory memory) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.memoryDeleteTitle),
        content: Text(l10n.memoryDeleteBody(memory.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.memoryDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(memoryNotifierProvider.notifier).deleteMemory(widget.id);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deletedSuccess),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.memoryDeleteFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final l10n = context.l10n;
    final memoryAsync = ref.watch(memoryProvider(widget.id));

    return memoryAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(l10n.errorWith('$e')))),
      data: (memory) {
        if (memory == null) {
          return Scaffold(body: Center(child: Text(l10n.memoryNotFound)));
        }
        return Scaffold(
          body: ThemeBackground(
           child: Column(
            children: [
              // Hero / mini-header area — animates between full hero and compact bar
              ClipRect(
               child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _heroExpanded ? (260.0 + topPad) : (topPad + 56.0),
                child: SizedBox(
                  height: 260 + topPad,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _HeroCover(
                        memory: memory,
                        memoryId: widget.id,
                        onBack: () => context.pop(),
                        onEdit: () =>
                            context.push('/memories/${widget.id}/edit'),
                      ),
                      // Mini header fades in when hero collapses
                      AnimatedOpacity(
                        opacity: _heroExpanded ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        child: IgnorePointer(
                          ignoring: _heroExpanded,
                          child: _MiniHeader(
                            memory: memory,
                            topPad: topPad,
                            onBack: () => context.pop(),
                            onEdit: () =>
                                context.push('/memories/${widget.id}/edit'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
               ),
              ),
              _MemoryTabBar(controller: _tabs, l10n: l10n),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 280),
                firstChild: const SizedBox(width: double.infinity),
                secondChild: _CollapsedInfoStrip(
                  memory: memory,
                  memoryId: widget.id,
                ),
                crossFadeState: (_heroExpanded || _tabs.index != 0)
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(
                      memory: memory,
                      memoryId: widget.id,
                      onTabNavigate: _tabs.animateTo,
                      scrollController: _overviewScrollCtrl,
                      onTopOverscroll: _onTopOverscroll,
                    ),
                    _ItineraryTab(memoryId: widget.id, memory: memory),
                    _GalleryTab(memoryId: widget.id),
                    MemoryExpensesTab(memoryId: widget.id),
                    _SettingsTab(
              onExport: () => _exportPdf(memory),
              onDelete: () => _deleteMemory(memory),
            ),
                  ],
                ),
              ),
            ],
           ),
          ),
          floatingActionButton: _tabs.index == 2
              ? FloatingActionButton(
                  onPressed: _pickMedia,
                  child: const Icon(Icons.add_photo_alternate_outlined),
                )
              : _tabs.index == 3
                  ? FloatingActionButton(
                      onPressed: () =>
                          context.push('/memories/${widget.id}/expenses/new'),
                      child: const Icon(Icons.add),
                    )
                  : null,
        );
      },
    );
  }
}

// ── Hero Cover ─────────────────────────────────────────────────────────────────

class _HeroCover extends ConsumerStatefulWidget {
  final Memory memory;
  final String memoryId;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const _HeroCover({
    required this.memory,
    required this.memoryId,
    required this.onBack,
    required this.onEdit,
  });

  @override
  ConsumerState<_HeroCover> createState() => _HeroCoverState();
}

class _HeroCoverState extends ConsumerState<_HeroCover> {
  Uint8List? _coverBytes;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    final path = widget.memory.coverMediaPath;
    if (path != null) _loadPath(path);
  }

  @override
  void didUpdateWidget(_HeroCover old) {
    super.didUpdateWidget(old);
    final path = widget.memory.coverMediaPath;
    if (path != old.memory.coverMediaPath && path != null) _loadPath(path);
  }

  Future<void> _loadPath(String path) async {
    if (path == _loadedPath) return;
    _loadedPath = path;
    Uint8List? bytes;
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma != -1) bytes = base64Decode(path.substring(comma + 1));
    } else if (!kIsWeb) {
      bytes = await readAppDocFileBytes(path);
    }
    if (mounted && bytes != null) setState(() => _coverBytes = bytes);
  }

  void _maybeLoadFallback(String path) {
    if (path == _loadedPath) return;
    _loadPath(path);
  }

  @override
  Widget build(BuildContext context) {
    final gradient = Theme.of(context).extension<AppThemeExtension>()!.coverGradient;
    final memory = widget.memory;

    // Fallback: first photo asset when no coverMediaPath
    if (_coverBytes == null && memory.coverMediaPath == null) {
      final assets = ref.watch(mediaAssetsProvider(widget.memoryId)).value;
      if (assets != null && assets.isNotEmpty) {
        final first = assets.firstWhere(
          (a) => a.type == 'photo',
          orElse: () => assets.first,
        );
        _maybeLoadFallback(first.filePath);
      }
    }

    final l10n = context.l10n;
    final participantsAsync =
        ref.watch(memoryParticipantsProvider(widget.memoryId));
    final participants = participantsAsync.value ?? [];
    final duration = _durationText(memory, l10n);
    final dateStr = _dateText(memory, l10n);
    final countdown = _countdownText(memory.startDate, l10n);
    final topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 260 + topPad,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image or gradient
          if (_coverBytes != null)
            Image.memory(_coverBytes!, fit: BoxFit.cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: gradient),
            ),

          // Radial highlight
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.4, -0.8),
                radius: 1.2,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Bottom dark overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: (260 + topPad) * 0.62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF30180C).withValues(alpha: 0.78),
                    const Color(0xFF30180C).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Back + edit + pdf buttons
          Positioned(
            top: topPad + 6,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassButton(
                  onTap: widget.onBack,
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
                _GlassButton(
                  onTap: widget.onEdit,
                  child: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 16),
                ),
              ],
            ),
          ),

          // Countdown pill
          Positioned(
            top: topPad + 52,
            right: 16,
            child: _CountdownPill(text: countdown),
          ),

          // Bottom info: type + duration + title + date + avatars
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type badge + duration chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_typeEmoji(memory.type)} ${memory.type}',
                        style: GoogleFonts.notoSansSc(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                    if (duration.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          duration,
                          style: GoogleFonts.notoSansSc(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  memory.title,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Date
                Row(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 7),
                    Text(
                      dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                // Avatar stack + participant count
                _HeroAvatarStack(
                  participants: participants,
                  memoryId: widget.memoryId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini header (shown when hero is collapsed) ─────────────────────────────────

class _MiniHeader extends StatelessWidget {
  final Memory memory;
  final double topPad;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const _MiniHeader({
    required this.memory,
    required this.topPad,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).extension<AppThemeExtension>()!.backgroundColor;
    final muted = Theme.of(context).extension<AppThemeExtension>()!.mutedColor;
    final primary = Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final textColor = Theme.of(context).extension<AppThemeExtension>()!.textPrimary;

    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 10),
      child: Row(
        children: [
          _MiniCircleBtn(
            onTap: onBack,
            bg: muted,
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              memory.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansSc(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _MiniCircleBtn(
            onTap: onEdit,
            bg: muted,
            child: Icon(Icons.edit_outlined, size: 15, color: primary),
          ),
        ],
      ),
    );
  }
}

class _MiniCircleBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color bg;
  const _MiniCircleBtn({required this.onTap, required this.child, required this.bg});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Center(child: child),
        ),
      );
}

// ── Collapsed info strip (shown below tab bar when hero is hidden) ─────────────

class _CollapsedInfoStrip extends ConsumerWidget {
  final Memory memory;
  final String memoryId;
  const _CollapsedInfoStrip({required this.memory, required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = Theme.of(context).extension<AppThemeExtension>()!.backgroundColor;
    final border = Theme.of(context).extension<AppThemeExtension>()!.borderColor;
    final textMuted = Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final primary = Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final primaryTint = Theme.of(context).extension<AppThemeExtension>()!.accentColor.withValues(alpha: 0.18);

    final l10n = context.l10n;
    final duration = _durationText(memory, l10n);
    final dateStr = _dateText(memory, l10n);

    final participantsAsync = ref.watch(memoryParticipantsProvider(memoryId));
    final participants = participantsAsync.value ?? [];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_typeEmoji(memory.type)} ${memory.type}',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 11, fontWeight: FontWeight.w700, color: primary,
                  ),
                ),
              ),
              if (duration.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  duration,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w600, color: textMuted,
                  ),
                ),
              ],
              const Spacer(),
              const Text('📅', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5, fontWeight: FontWeight.w500, color: textMuted,
                ),
              ),
            ],
          ),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: _AvatarStack(
                    participants: participants,
                    diameter: 26,
                    borderColor: bg,
                    overflowFill: Theme.of(context)
                        .extension<AppThemeExtension>()!
                        .mutedColor,
                    overflowText: textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.memoryParticipantCount(participants.length),
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12, fontWeight: FontWeight.w600, color: textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Glass button (hero overlay) ────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _GlassButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x2EFFFFFF),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      );
}

// ── Countdown pill ─────────────────────────────────────────────────────────────

class _CountdownPill extends StatelessWidget {
  final String text;
  const _CountdownPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero avatar stack ──────────────────────────────────────────────────────────

class _HeroAvatarStack extends ConsumerWidget {
  final List<MemoryParticipant> participants;
  final String memoryId;
  const _HeroAvatarStack(
      {required this.participants, required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openPicker() => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ParticipantPickerSheet(memoryId: memoryId),
        );

    return GestureDetector(
      onTap: openPicker,
      child: Row(
        children: [
          // Flexible so the count and the add button keep their room and the
          // stack tightens instead of overflowing.
          if (participants.isNotEmpty) ...[
            Flexible(
              child: _AvatarStack(
                participants: participants,
                diameter: 31,
                borderColor: AppColors.primaryDeep,
                overflowFill: AppColors.primaryDeep,
                overflowText: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            context.l10n.memoryParticipantCount(participants.length),
            style: GoogleFonts.notoSansSc(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: openPicker,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7), width: 1.5),
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Tab Bar ─────────────────────────────────────────────────────────────

class _MemoryTabBar extends StatelessWidget {
  final TabController controller;
  final AppLocalizations l10n;
  const _MemoryTabBar({required this.controller, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final textMuted = Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final bg = Theme.of(context).extension<AppThemeExtension>()!.backgroundColor;
    final border = Theme.of(context).extension<AppThemeExtension>()!.borderColor;
    final tabs = [
      l10n.memoryTabOverview,
      l10n.memoryTabItinerary,
      l10n.memoryTabGallery,
      l10n.memoryTabExpenses,
      l10n.memoryTabSettings,
    ];

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        color: bg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Five labels whose width depends on the language: two glyphs each
            // in Chinese, whole words in English. Scroll rather than overflow,
            // while still filling the bar whenever they do fit.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minWidth: constraints.maxWidth - 40),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: tabs.asMap().entries.map((e) {
                      final i = e.key;
                      final label = e.value;
                      final active = controller.index == i;
                      return GestureDetector(
                        onTap: () => controller.animateTo(i),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: i == tabs.length - 1 ? 0 : 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 15),
                              Text(
                                label,
                                style: GoogleFonts.notoSansSc(
                                  fontSize: 15,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active ? primary : textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: active ? 22 : 0,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: border),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final Memory memory;
  final String memoryId;
  final void Function(int) onTabNavigate;
  final ScrollController scrollController;
  final VoidCallback? onTopOverscroll;
  const _OverviewTab({
    required this.memory,
    required this.memoryId,
    required this.onTabNavigate,
    required this.scrollController,
    this.onTopOverscroll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(mediaAssetsProvider(memoryId));
    final allStopsAsync = ref.watch(allItineraryStopsProvider(memoryId));
    final itineraryDaysAsync = ref.watch(itineraryDaysProvider(memoryId));
    final txAsync = ref.watch(transactionsByMemoryProvider(memoryId));
    final locationsAsync = ref.watch(memoryLocationsProvider(memoryId));

    final days = itineraryDaysAsync.value ?? [];
    final allStops = allStopsAsync.value ?? [];
    final locations = locationsAsync.value ?? [];

    return NotificationListener<OverscrollNotification>(
      onNotification: (n) {
        if (n.overscroll < 0) onTopOverscroll?.call();
        return false;
      },
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QuickStatsRow(
                photoCount: assetsAsync.value?.length ?? 0,
                itineraryCount: allStops.length,
                txns: txAsync.value ?? [],
                budget: memory.budget,
                budgetCurrency: memory.budgetCurrency,
                onPhotosTap: () => onTabNavigate(2),
                onItineraryTap: () => onTabNavigate(1),
                onExpensesTap: () => onTabNavigate(3),
              ),
            ),

            if (memory.description != null &&
                memory.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(context.l10n.memoryDescriptionLabel),
                    const SizedBox(height: 6),
                    _QuoteBar(text: memory.description!),
                  ],
                ),
              ),
            ],

            // Itinerary days section (new) — or fallback to location pool
            if (days.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ItineraryDaysSection(
                days: days,
                allStops: allStops,
                locations: locations,
                onTap: () => onTabNavigate(1),
              ),
            ] else if (locations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LocationsSection(locations: locations),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Quick Stats Row ────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final int photoCount;
  final int itineraryCount;
  final List<Transaction> txns;
  final double? budget;
  final String? budgetCurrency;
  final VoidCallback onPhotosTap;
  final VoidCallback onItineraryTap;
  final VoidCallback onExpensesTap;

  const _QuickStatsRow({
    required this.photoCount,
    required this.itineraryCount,
    required this.txns,
    required this.budget,
    this.budgetCurrency,
    required this.onPhotosTap,
    required this.onItineraryTap,
    required this.onExpensesTap,
  });

  String get _expenseLabel {
    if (txns.isEmpty) return '-';
    double total = 0;
    for (final t in txns) {
      if (t.type == 'expense') total += t.amount;
    }
    if (total == 0) return '-';
    return _formatAmt(total, _currencySym(txns));
  }

  String _budgetSym() {
    if (budgetCurrency != null) {
      return const {'MYR': 'RM', 'SGD': 'S\$'}[budgetCurrency] ?? budgetCurrency!;
    }
    return _currencySym(txns);
  }

  String get _budgetLabel => _formatAmt(budget!, _budgetSym());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasBudget = budget != null && budget! > 0;
    final compact = hasBudget;

    final cards = <Widget>[
      Expanded(
        child: _StatCard(
          emoji: '🖼️',
          value: '$photoCount',
          label: l10n.memoryTabGallery,
          compact: compact,
          onTap: onPhotosTap,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatCard(
          emoji: '🗺️',
          value: '$itineraryCount',
          label: l10n.memoryStatStops,
          compact: compact,
          onTap: onItineraryTap,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatCard(
          emoji: '🧾',
          value: _expenseLabel,
          label: l10n.memoryTabExpenses,
          compact: compact,
          isAmount: true,
          onTap: onExpensesTap,
        ),
      ),
      if (hasBudget) ...[
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            emoji: '👛',
            value: _budgetLabel,
            label: l10n.memoryStatBudget,
            compact: compact,
            isAmount: true,
            isPrimary: true,
            onTap: onExpensesTap,
          ),
        ),
      ],
    ];

    return Row(children: cards);
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final bool compact;
  final bool isAmount;
  final bool isPrimary;
  final VoidCallback onTap;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.isAmount = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {

    final double emojiSize = compact ? 17 : 18;
    final double valueFontSize =
        isAmount ? (compact ? 14 : 17) : (compact ? 18 : 21);
    final double vPad = compact ? 13 : 15;
    final double hPad = compact ? 4 : 8;
    final double radius = compact ? 16 : 18;

    if (isPrimary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.5, -1.0),
              end: const Alignment(0.5, 1.0),
              colors: [
                Theme.of(context).extension<AppThemeExtension>()!.accentColor,
                Color.lerp(Theme.of(context).extension<AppThemeExtension>()!.accentColor, Colors.black, 0.28)!,
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).extension<AppThemeExtension>()!.accentColor.withValues(alpha: 0.55),
                offset: const Offset(0, 6),
                blurRadius: 16,
                spreadRadius: -7,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: emojiSize)),
              const SizedBox(height: 5),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: GoogleFonts.notoSansSc(
                  fontSize: 11,
                  color: const Color(0xFFF3D9C8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final textColor = Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted = Theme.of(context).extension<AppThemeExtension>()!.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).extension<AppThemeExtension>()!.surfaceColor,
              Color.lerp(Theme.of(context).extension<AppThemeExtension>()!.surfaceColor,
                  Theme.of(context).extension<AppThemeExtension>()!.mutedColor, 0.6)!,
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF78461E).withValues(alpha: 0.3),
              offset: const Offset(0, 4),
              blurRadius: 14,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: emojiSize)),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.notoSansSc(
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quote Bar (description) ────────────────────────────────────────────────────

class _QuoteBar extends StatelessWidget {
  final String text;
  const _QuoteBar({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).extension<AppThemeExtension>()!.mutedColor;
    final accent = Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final textColor = isDark
        ? const Color(0xFFD9C7B8)
        : const Color(0xFF5E4A3C);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.notoSansSc(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.notoSansSc(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary,
      ),
    );
  }
}

// ── Locations section (horizontal scroll) ─────────────────────────────────────

const _kLocationGradients = [
  [Color(0xFFD69A6E), Color(0xFFA8572F)],
  [Color(0xFFCBB089), Color(0xFF9C7B4E)],
  [Color(0xFF9FB07A), Color(0xFF5E7B3F)],
  [Color(0xFFE8A765), Color(0xFFB65A28)],
  [Color(0xFF9FB6C4), Color(0xFF5E7E92)],
];

class _LocationsSection extends StatelessWidget {
  final List<MemoryLocation> locations;
  const _LocationsSection({required this.locations});

  Future<void> _openMaps(BuildContext context, String name) async {
    final uri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(name)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.memoryMapOpenFailed),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted = Theme.of(context).extension<AppThemeExtension>()!.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  context.l10n.memoryLocationsTitle,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.memoryStopCount(locations.length),
                  style: GoogleFonts.notoSansSc(
                      fontSize: 12, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            itemCount: locations.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                  right: i < locations.length - 1 ? 12 : 0),
              child: _LocationCard(
                location: locations[i],
                index: i,
                isDark: isDark,
                onTap: () => _openMaps(context, locations[i].name),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final MemoryLocation location;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _LocationCard({
    required this.location,
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).extension<AppThemeExtension>()!.surfaceColor;
    final textColor = Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted = Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final grad = _kLocationGradients[index % _kLocationGradients.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF78461E).withValues(alpha: 0.4),
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
            Container(
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          grad[0].withValues(alpha: 0.8),
                          grad[1].withValues(alpha: 0.8)
                        ]
                      : grad,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 11,
                    bottom: 9,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                      child: const Center(
                        child: Text('📍',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.memoryStopNumber(index + 1),
                    style: GoogleFonts.notoSansSc(
                        fontSize: 11.5, color: textMuted),
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

// ── Avatar circle ──────────────────────────────────────────────────────────────

class _AvatarCircle extends ConsumerWidget {
  final String personId;
  final double diameter;
  final Color borderColor;
  const _AvatarCircle({
    required this.personId,
    required this.diameter,
    this.borderColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personProvider(personId));
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: personAsync.when(
        loading: () => Container(color: Theme.of(context).extension<AppThemeExtension>()!.mutedColor),
        error: (_, _) => const SizedBox(),
        data: (person) => person == null
            ? Container(color: Theme.of(context).extension<AppThemeExtension>()!.mutedColor)
            : PersonAvatar(
                name: person.name,
                imagePath: person.avatarPath,
                radius: diameter / 2,
              ),
      ),
    );
  }
}

// ── Avatar stack ───────────────────────────────────────────────────────────────

/// Overlapping participant bubbles: up to [maxFaces] faces, then a trailing
/// "+N" bubble standing in for whoever is left.
///
/// The exposed slice of each bubble starts roomy and tightens toward a floor as
/// the group grows, so a stack of ten still fits the width it is handed. Give it
/// a bounded width (a [Flexible] in a Row) or it falls back to the roomy slice.
class _AvatarStack extends StatelessWidget {
  final List<MemoryParticipant> participants;
  final double diameter;
  final Color borderColor;
  final Color overflowFill;
  final Color overflowText;

  static const maxFaces = 10;

  const _AvatarStack({
    required this.participants,
    required this.diameter,
    required this.borderColor,
    required this.overflowFill,
    required this.overflowText,
  });

  @override
  Widget build(BuildContext context) {
    final faces = participants.take(maxFaces).toList();
    final extra = participants.length - faces.length;
    final bubbles = faces.length + (extra > 0 ? 1 : 0);
    if (bubbles == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = diameter * 0.65;
        final tight = diameter * 0.3;
        var slice = roomy;
        if (bubbles > 1) {
          slice = ((constraints.maxWidth - diameter) / (bubbles - 1))
              .clamp(tight, roomy);
        }

        return SizedBox(
          width: diameter + (bubbles - 1) * slice,
          height: diameter,
          child: Stack(
            children: [
              for (int i = 0; i < faces.length; i++)
                Positioned(
                  left: i * slice,
                  child: _AvatarCircle(
                    personId: faces[i].personId,
                    diameter: diameter,
                    borderColor: borderColor,
                  ),
                ),
              if (extra > 0)
                Positioned(
                  left: faces.length * slice,
                  child: Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: overflowFill,
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$extra',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: diameter * 0.32,
                        fontWeight: FontWeight.w800,
                        color: overflowText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Participant Picker Sheet ───────────────────────────────────────────────────

class _ParticipantPickerSheet extends ConsumerWidget {
  final String memoryId;
  const _ParticipantPickerSheet({required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).extension<AppThemeExtension>()!.surfaceColor;
    final border = Theme.of(context).extension<AppThemeExtension>()!.borderColor;

    final personsAsync = ref.watch(personsProvider);
    final selfAsync = ref.watch(selfPersonStreamProvider);
    final participantsAsync =
        ref.watch(memoryParticipantsProvider(memoryId));
    final notifier = ref.read(memoryNotifierProvider.notifier);

    final currentIds =
        participantsAsync.value?.map((p) => p.personId).toSet() ?? {};

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(context.l10n.memoryParticipantsSection,
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: personsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (persons) {
                  final self = selfAsync.value;
                  final all = [?self, ...persons];
                  if (all.isEmpty) {
                    return Center(child: Text(context.l10n.memoryNoContacts));
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: all.length,
                    itemBuilder: (_, i) {
                      final person = all[i];
                      final selected = currentIds.contains(person.id);
                      return ListTile(
                        leading: PersonAvatar(
                          name: person.name,
                          imagePath: person.avatarPath,
                          radius: 18,
                        ),
                        title: Text(person.name),
                        subtitle: person.isSelf
                            ? Text(context.l10n.memoryYouSuffix)
                            : null,
                        trailing: selected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary)
                            : const Icon(Icons.radio_button_unchecked,
                                color: AppColors.textMuted),
                        onTap: () async {
                          if (selected) {
                            await notifier.removeParticipant(
                                memoryId, person.id);
                          } else {
                            await notifier.addParticipant(
                                memoryId, person.id);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Itinerary Tab (day-structured) ─────────────────────────────────────────────

class _ItineraryTab extends ConsumerStatefulWidget {
  final String memoryId;
  final Memory memory;
  const _ItineraryTab({required this.memoryId, required this.memory});

  @override
  ConsumerState<_ItineraryTab> createState() => _ItineraryTabState();
}

class _ItineraryTabState extends ConsumerState<_ItineraryTab> {
  Future<void> _addDay() async {
    await ref
        .read(memoryNotifierProvider.notifier)
        .addItineraryDayWithAutoNumber(
          widget.memoryId,
          startDate: widget.memory.startDate,
          endDate: widget.memory.endDate,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final daysAsync = ref.watch(itineraryDaysProvider(widget.memoryId));
    final primary =
        Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final bg =
        Theme.of(context).extension<AppThemeExtension>()!.backgroundColor;
    final border =
        Theme.of(context).extension<AppThemeExtension>()!.borderColor;
    final textMuted =
        Theme.of(context).extension<AppThemeExtension>()!.textSecondary;

    final currentDays = daysAsync.valueOrNull ?? [];
    final endDate = widget.memory.endDate;
    final maxDays = endDate != null
        ? endDate.difference(widget.memory.startDate).inDays + 1
        : null;
    final atMax = maxDays != null && currentDays.length >= maxDays;

    return Column(
      children: [
        Expanded(
          child: daysAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
            data: (days) {
              if (days.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.memoryNoItinerary,
                        style: GoogleFonts.notoSansSc(
                            fontSize: 14, color: textMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addDay,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.memoryAddFirstDay),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: days.length,
                itemBuilder: (context, i) => _DaySection(
                  day: days[i],
                  dayNumber: i + 1,
                  memoryId: widget.memoryId,
                ),
              );
            },
          ),
        ),
        // Bottom bar
        Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: bg,
            border: Border(top: BorderSide(color: border, width: 1)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Opacity(
              opacity: atMax ? 0.4 : 1.0,
              child: GestureDetector(
                onTap: atMax ? null : _addDay,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 16, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        l10n.memoryAddDay,
                        style: GoogleFonts.notoSansSc(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Day section ────────────────────────────────────────────────────────────────

class _DaySection extends ConsumerStatefulWidget {
  final ItineraryDay day;
  final int dayNumber;
  final String memoryId;
  const _DaySection(
      {required this.day, required this.dayNumber, required this.memoryId});

  @override
  ConsumerState<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends ConsumerState<_DaySection> {
  List<ItineraryStop> _sortByTime(List<ItineraryStop> stops) {
    final result = List<ItineraryStop>.from(stops);
    result.sort((a, b) {
      if (a.timeLabel != null && b.timeLabel != null) {
        return a.timeLabel!.compareTo(b.timeLabel!);
      }
      if (a.timeLabel != null) return -1;
      if (b.timeLabel != null) return 1;
      return a.orderIndex.compareTo(b.orderIndex);
    });
    return result;
  }

  Future<void> _addStop() async {
    final stops =
        await ref.read(databaseProvider).memoryDao.getItineraryStops(widget.day.id);
    final nextOrder = stops.isEmpty
        ? 0
        : stops.map((s) => s.orderIndex).reduce((a, b) => a > b ? a : b) + 1;
    final locations =
        await ref.read(databaseProvider).memoryDao.getLocations(widget.memoryId);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StopEditorSheet(
        memoryId: widget.memoryId,
        dayId: widget.day.id,
        locations: locations,
        nextOrder: nextOrder,
      ),
    );
  }

  Future<void> _editStop(ItineraryStop stop) async {
    final locations =
        await ref.read(databaseProvider).memoryDao.getLocations(widget.memoryId);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StopEditorSheet(
        memoryId: widget.memoryId,
        dayId: widget.day.id,
        locations: locations,
        nextOrder: stop.orderIndex,
        editingStop: stop,
      ),
    );
  }

  Future<void> _deleteStop(ItineraryStop stop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.memoryDeleteStopTitle),
        content: Text(context.l10n.memoryDeleteStopBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.delete,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(memoryNotifierProvider.notifier).deleteItineraryStop(stop.id);
  }

  Future<void> _deleteDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.memoryDeleteDayTitle),
        content: Text(context.l10n.memoryDeleteDayBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.delete,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(memoryNotifierProvider.notifier)
        .deleteItineraryDay(widget.day.id);
  }

  Future<void> _onReorder(int oldIdx, int newIdx) async {
    final rawStops = ref.read(itineraryStopsProvider(widget.day.id)).value ?? [];
    if (rawStops.isEmpty) return;
    final list = _sortByTime(rawStops);
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);
    await ref
        .read(memoryNotifierProvider.notifier)
        .reorderItineraryStops(widget.day.id, list.map((s) => s.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final stopsAsync = ref.watch(itineraryStopsProvider(widget.day.id));
    final locationsAsync = ref.watch(memoryLocationsProvider(widget.memoryId));
    final locationMap = {
      for (final l in locationsAsync.value ?? <MemoryLocation>[]) l.id: l
    };

    final primary =
        Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final textColor =
        Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted =
        Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final surface =
        Theme.of(context).extension<AppThemeExtension>()!.surfaceColor;

    final l10n = context.l10n;
    final dayLabel = l10n.memoryDayLabel(widget.dayNumber);
    final dateLabel = widget.day.date != null
        ? ' · ${l10n.formatMonthDay(widget.day.date!)}'
        : '';

    final stops = _sortByTime(stopsAsync.value ?? []);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Row(
            children: [
              Flexible(
                child: Text(
                  '$dayLabel$dateLabel',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _deleteDay,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('🗑', style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day note (if any)
          if (widget.day.dayNote?.isNotEmpty ?? false) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.day.dayNote!,
                style: GoogleFonts.notoSansSc(
                    fontSize: 12, color: textMuted),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Stop list
          if (stops.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                context.l10n.memoryNoStops,
                style: GoogleFonts.notoSansSc(
                    fontSize: 12, color: textMuted),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stops.length,
              onReorderItem: (oldIdx, newIdx) => _onReorder(oldIdx, newIdx),
              itemBuilder: (context, i) {
                final stop = stops[i];
                return _StopRow(
                  key: Key('stop_${stop.id}'),
                  stop: stop,
                  stopIndex: i,
                  location: stop.locationId != null
                      ? locationMap[stop.locationId]
                      : null,
                  onEdit: () => _editStop(stop),
                  onDelete: () => _deleteStop(stop),
                );
              },
            ),

          // Add stop button
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _addStop,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 16, color: primary),
                const SizedBox(width: 4),
                Text(
                  context.l10n.memoryAddStop,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stop row (in day section) ──────────────────────────────────────────────────

class _StopRow extends StatelessWidget {
  final ItineraryStop stop;
  final int stopIndex;
  final MemoryLocation? location;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StopRow({
    super.key,
    required this.stop,
    required this.stopIndex,
    this.location,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final textColor =
        Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted =
        Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final surface =
        Theme.of(context).extension<AppThemeExtension>()!.surfaceColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF78461E).withValues(alpha: 0.18),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: stopIndex,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Icon(Icons.drag_handle,
                  color: Color(0xFFCDBFAE), size: 18),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (location != null)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(
                            'https://maps.google.com/?q=${Uri.encodeComponent(location!.name)}');
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📍 ',
                              style: TextStyle(fontSize: 11)),
                          Expanded(
                            child: Text(
                              location!.name,
                              style: GoogleFonts.notoSansSc(
                                  fontSize: 11,
                                  color: primary,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    stop.activityText,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (stop.timeLabel != null)
                    Text(
                      '🕘 ${stop.timeLabel}',
                      style: GoogleFonts.notoSansSc(
                          fontSize: 11, color: textMuted),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('✎',
                  style: TextStyle(
                      fontSize: 16, color: Color(0xFFCDBFAE))),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('🗑', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Stop editor bottom sheet ───────────────────────────────────────────────────

class _StopEditorSheet extends ConsumerStatefulWidget {
  final String memoryId;
  final String dayId;
  final List<MemoryLocation> locations;
  final int nextOrder;
  final ItineraryStop? editingStop;

  const _StopEditorSheet({
    required this.memoryId,
    required this.dayId,
    required this.locations,
    required this.nextOrder,
    this.editingStop,
  });

  @override
  ConsumerState<_StopEditorSheet> createState() => _StopEditorSheetState();
}

class _StopEditorSheetState extends ConsumerState<_StopEditorSheet> {
  final _activityCtrl = TextEditingController();
  late List<MemoryLocation> _locations;
  String? _selectedLocationId;
  String? _timeLabel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.locations);
    if (widget.editingStop != null) {
      _activityCtrl.text = widget.editingStop!.activityText;
      _selectedLocationId = widget.editingStop!.locationId;
      _timeLabel = widget.editingStop!.timeLabel;
    }
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    TimeOfDay? initial;
    if (_timeLabel != null) {
      final parts = _timeLabel!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
      }
    }
    final t = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (t != null && mounted) {
      setState(() => _timeLabel =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _showLocationPicker() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.memoryPickLocation),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading:
                    const Text('📝', style: TextStyle(fontSize: 18)),
                title: Text(context.l10n.memoryNoLocation),
                selected: _selectedLocationId == null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ..._locations.map((loc) => ListTile(
                    leading: const Text('📍',
                        style: TextStyle(fontSize: 18)),
                    title: Text(loc.name),
                    selected: loc.id == _selectedLocationId,
                    onTap: () => Navigator.pop(ctx, loc.id),
                  )),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.l10n.memoryAddLocation),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _promptAddNewLocation();
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedLocationId = picked.isEmpty ? null : picked);
  }

  Future<void> _promptAddNewLocation() async {
    String name = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (nameCtx) => AlertDialog(
        title: Text(context.l10n.memoryAddLocation),
        content: TextField(
          autofocus: true,
          decoration:
              InputDecoration(hintText: context.l10n.memoryLocationNameHint),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(nameCtx, false),
              child: Text(context.l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(nameCtx, true),
              child: Text(context.l10n.add)),
        ],
      ),
    );
    if (ok != true || name.trim().isEmpty || !mounted) return;
    final id = await ref
        .read(memoryNotifierProvider.notifier)
        .addMemoryLocation(widget.memoryId, name.trim());
    final updated =
        await ref.read(databaseProvider).memoryDao.getLocations(widget.memoryId);
    if (!mounted) return;
    setState(() {
      _locations = updated;
      _selectedLocationId = id;
    });
  }

  Future<void> _save() async {
    final activity = _activityCtrl.text.trim();
    if (activity.isEmpty) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(memoryNotifierProvider.notifier);
      if (widget.editingStop != null) {
        await notifier.updateItineraryStop(ItineraryStop(
          id: widget.editingStop!.id,
          dayId: widget.editingStop!.dayId,
          locationId: _selectedLocationId,
          orderIndex: widget.editingStop!.orderIndex,
          activityText: activity,
          timeLabel: _timeLabel,
        ));
      } else {
        await notifier.addItineraryStop(
          dayId: widget.dayId,
          locationId: _selectedLocationId,
          orderIndex: widget.nextOrder,
          activityText: activity,
          timeLabel: _timeLabel,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).extension<AppThemeExtension>()!.accentColor;
    final bg =
        Theme.of(context).extension<AppThemeExtension>()!.backgroundColor;
    final surface =
        Theme.of(context).extension<AppThemeExtension>()!.surfaceColor;
    final textColor =
        Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted =
        Theme.of(context).extension<AppThemeExtension>()!.textSecondary;

    final isEditing = widget.editingStop != null;
    final selectedLocation =
        _locations.where((l) => l.id == _selectedLocationId).firstOrNull;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  isEditing
                      ? context.l10n.memoryEditStop
                      : context.l10n.memoryAddStop,
                  style: GoogleFonts.notoSansSc(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel,
                      style: GoogleFonts.notoSansSc(
                          fontSize: 13, color: primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Location picker
            GestureDetector(
              onTap: _showLocationPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      selectedLocation != null ? '📍' : '📝',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedLocation?.name ??
                            context.l10n.memoryPickLocationOptional,
                        style: GoogleFonts.notoSansSc(
                          fontSize: 14,
                          color: selectedLocation != null
                              ? textColor
                              : textMuted,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: textMuted, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Activity text
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: TextField(
                controller: _activityCtrl,
                autofocus: widget.editingStop == null,
                style: GoogleFonts.notoSansSc(
                    fontSize: 14, color: textColor),
                decoration: InputDecoration.collapsed(
                  hintText: context.l10n.memoryStopActivityHint,
                  hintStyle: GoogleFonts.notoSansSc(
                      fontSize: 14, color: textMuted),
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 10),
            // Time + save row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _timeLabel == null
                              ? '🕘 ${context.l10n.memoryTimeOptional}'
                              : '🕘 $_timeLabel',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 14,
                            color:
                                _timeLabel != null ? primary : textMuted,
                            fontWeight: _timeLabel != null
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_timeLabel != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _timeLabel = null),
                    child: Icon(Icons.close, size: 16, color: textMuted),
                  ),
                ],
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary,
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Icon(
                              isEditing
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: Colors.white,
                              size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Itinerary days section (overview) ─────────────────────────────────────────

class _ItineraryDaysSection extends StatelessWidget {
  final List<ItineraryDay> days;
  final List<ItineraryStop> allStops;
  final List<MemoryLocation> locations;
  final VoidCallback onTap;

  const _ItineraryDaysSection({
    required this.days,
    required this.allStops,
    required this.locations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted =
        Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final locationMap = {for (final l in locations) l.id: l};
    final stopsByDay = <String, List<ItineraryStop>>{};
    for (final stop in allStops) {
      stopsByDay.putIfAbsent(stop.dayId, () => []).add(stop);
    }
    final multiDay = days.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  context.l10n.memoryItineraryStopsTitle,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.memoryDaysAndStops(
                      multiDay ? days.length : 0, allStops.length),
                  style:
                      GoogleFonts.notoSansSc(fontSize: 12, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (multiDay)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: days.asMap().entries.map((e) {
              final day = e.value;
              final dayStops = stopsByDay[day.id] ?? [];
              return _DayStopsRow(
                day: day,
                dayNumber: e.key + 1,
                dayStops: dayStops,
                locationMap: locationMap,
                multiDay: true,
                isDark: isDark,
                onTap: onTap,
              );
            }).toList(),
          )
        else if (days.isNotEmpty)
          _DayStopsRow(
            day: days.first,
            dayNumber: 1,
            dayStops: stopsByDay[days.first.id] ?? [],
            locationMap: locationMap,
            multiDay: false,
            isDark: isDark,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _DayStopsRow extends StatelessWidget {
  final ItineraryDay day;
  final int dayNumber;
  final List<ItineraryStop> dayStops;
  final Map<String, MemoryLocation> locationMap;
  final bool multiDay;
  final bool isDark;
  final VoidCallback onTap;

  const _DayStopsRow({
    required this.day,
    required this.dayNumber,
    required this.dayStops,
    required this.locationMap,
    required this.multiDay,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted =
        Theme.of(context).extension<AppThemeExtension>()!.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (multiDay)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text(
                  context.l10n.memoryDayLabel(dayNumber),
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (day.date != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· ${context.l10n.formatMonthDay(day.date!)}',
                    style: GoogleFonts.notoSansSc(
                        fontSize: 12, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
        if (dayStops.isEmpty && (day.dayNote?.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              day.dayNote!,
              style: GoogleFonts.notoSansSc(fontSize: 13, color: textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else if (dayStops.isNotEmpty)
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              itemCount: dayStops.length,
              itemBuilder: (context, i) => Padding(
                padding:
                    EdgeInsets.only(right: i < dayStops.length - 1 ? 12 : 0),
                child: _StopCard(
                  stop: dayStops[i],
                  stopNumber: i + 1,
                  location: dayStops[i].locationId != null
                      ? locationMap[dayStops[i].locationId]
                      : null,
                  index: dayStops[i].orderIndex,
                  isDark: isDark,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        if (multiDay) const SizedBox(height: 4),
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  final ItineraryStop stop;
  final int stopNumber;
  final MemoryLocation? location;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _StopCard({
    required this.stop,
    required this.stopNumber,
    this.location,
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface =
        Theme.of(context).extension<AppThemeExtension>()!.surfaceColor;
    final textColor =
        Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted =
        Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final grad = _kLocationGradients[index % _kLocationGradients.length];

    return GestureDetector(
      onTap: onTap,
      onLongPress: location != null
          ? () async {
              final uri = Uri.parse(
                  'https://maps.google.com/?q=${Uri.encodeComponent(location!.name)}');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          : null,
      child: Container(
        width: 152,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF78461E).withValues(alpha: 0.4),
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
            Container(
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          grad[0].withValues(alpha: 0.8),
                          grad[1].withValues(alpha: 0.8),
                        ]
                      : grad,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 11,
                    bottom: 9,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                      child: Center(
                        child: Text(
                          location != null ? '📍' : '📝',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location?.name ?? stop.activityText,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.memoryStopNumber(stopNumber),
                    style:
                        GoogleFonts.notoSansSc(fontSize: 11.5, color: textMuted),
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

// ── Gallery Tab ────────────────────────────────────────────────────────────────

class _GalleryTab extends ConsumerWidget {
  final String memoryId;
  const _GalleryTab({required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assetsAsync = ref.watch(mediaAssetsProvider(memoryId));

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
      data: (assets) => assets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 56,
                      color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
                  const SizedBox(height: 12),
                  Text(l10n.memoryNoPhotos,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
              ),
              itemCount: assets.length,
              itemBuilder: (context, i) =>
                  _MediaTile(asset: assets[i], memoryId: memoryId),
            ),
    );
  }
}

// ── Media tile ────────────────────────────────────────────────────────────────

class _MediaTile extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final String memoryId;
  const _MediaTile({required this.asset, required this.memoryId});

  @override
  ConsumerState<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends ConsumerState<_MediaTile> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.asset.filePath;
    if (path.startsWith('data:')) {
      if (widget.asset.type != 'video') {
        final comma = path.indexOf(',');
        if (comma != -1 && mounted) {
          setState(() => _bytes = base64Decode(path.substring(comma + 1)));
        }
      }
      return;
    }
    if (kIsWeb) return;
    if (widget.asset.type == 'video') {
      final docs = await getDocsPath();
      final absPath = joinPath(docs, path);
      final thumb = await VideoThumbnail.thumbnailData(
        video: absPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      if (mounted) setState(() => _bytes = thumb);
      return;
    }
    final bytes = await readAppDocFileBytes(path);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isVideo = widget.asset.type == 'video';
    return GestureDetector(
      onTap: () {
        final allAssets =
            ref.read(mediaAssetsProvider(widget.memoryId)).value ?? [];
        final idx =
            allAssets.indexWhere((a) => a.id == widget.asset.id);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _PhotoViewerScreen(
            assets: allAssets,
            initialIndex: idx >= 0 ? idx : 0,
          ),
          fullscreenDialog: true,
        ));
      },
      onLongPress: () async {
        final messenger = ScaffoldMessenger.of(context);
        final del = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.memoryDeletePhoto),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.delete,
                      style: const TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (del == true) {
          try {
            await ref
                .read(memoryNotifierProvider.notifier)
                .deleteMediaAsset(widget.asset);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.deletedSuccess),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.errorWith('$e'))),
              );
            }
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).extension<AppThemeExtension>()!.mutedColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_bytes != null)
              Image.memory(_bytes!, fit: BoxFit.cover)
            else if (isVideo)
              Container(color: Colors.black54)
            else
              Center(
                child: Icon(Icons.image_outlined,
                    color: Theme.of(context).extension<AppThemeExtension>()!.textSecondary),
              ),
            if (isVideo)
              Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  child: const Center(
                    child: Icon(Icons.play_arrow_rounded,
                        color: AppColors.primaryDeep, size: 24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Photo Viewer ───────────────────────────────────────────────────────────────

class _PhotoViewerScreen extends StatefulWidget {
  final List<MediaAsset> assets;
  final int initialIndex;
  const _PhotoViewerScreen(
      {required this.assets, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _pageCtrl;
  late final ScrollController _thumbCtrl;
  int _current = 0;
  bool _isZoomed = false;

  static const double _thumbW = 64.0;
  static const double _thumbGap = 4.0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
    _thumbCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollThumbTo(_current),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  void _goTo(int index, {bool animatePage = true}) {
    if (index < 0 || index >= widget.assets.length) return;
    setState(() => _current = index);
    if (animatePage) {
      _pageCtrl.animateToPage(index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut);
    } else {
      _pageCtrl.jumpToPage(index);
    }
    _scrollThumbTo(index);
  }

  void _scrollThumbTo(int index) {
    if (!_thumbCtrl.hasClients) return;
    final viewW = MediaQuery.of(context).size.width;
    final offset =
        (index * (_thumbW + _thumbGap)) - (viewW - _thumbW) / 2;
    final clamped =
        offset.clamp(0.0, _thumbCtrl.position.maxScrollExtent);
    _thumbCtrl.animateTo(clamped,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.assets.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              onPageChanged: (i) {
                setState(() {
                  _current = i;
                  _isZoomed = false;
                });
                _scrollThumbTo(i);
              },
              itemCount: widget.assets.length,
              itemBuilder: (_, i) => _ZoomablePage(
                asset: widget.assets[i],
                onZoomChanged: (zoomed) {
                  if (_isZoomed != zoomed) {
                    setState(() => _isZoomed = zoomed);
                  }
                },
              ),
            ),
          ),
          _ThumbnailStrip(
            assets: widget.assets,
            currentIndex: _current,
            scrollController: _thumbCtrl,
            onIndexChanged: (i) => _goTo(i, animatePage: false),
          ),
        ],
      ),
    );
  }
}

// ── Single zoomable photo page ─────────────────────────────────────────────────

class _ZoomablePage extends StatefulWidget {
  final MediaAsset asset;
  final ValueChanged<bool> onZoomChanged;
  const _ZoomablePage(
      {required this.asset, required this.onZoomChanged});

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final _ctrl = TransformationController();
  Uint8List? _bytes;
  bool _zoomed = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTransform);
    _loadBytes();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTransform);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTransform() {
    final scale = _ctrl.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  Future<void> _loadBytes() async {
    if (widget.asset.type == 'video') return;
    final path = widget.asset.filePath;
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma != -1 && mounted) {
        setState(() => _bytes = base64Decode(path.substring(comma + 1)));
      }
      return;
    }
    if (kIsWeb) return;
    final bytes = await readAppDocFileBytes(path);
    if (mounted) setState(() => _bytes = bytes);
  }

  void _onDoubleTapDown(TapDownDetails d) => _doubleTapDetails = d;

  void _onDoubleTap() {
    if (_zoomed) {
      _ctrl.value = Matrix4.identity();
    } else {
      const scale = 2.5;
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      final tx = pos.dx * (1 - scale);
      final ty = pos.dy * (1 - scale);
      _ctrl.value = Matrix4.translationValues(tx, ty, 0) *
          Matrix4.diagonal3Values(scale, scale, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asset.type == 'video') {
      return _VideoPlayerPage(asset: widget.asset);
    }
    return GestureDetector(
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _ctrl,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: _bytes != null
              ? Image.memory(_bytes!, fit: BoxFit.contain)
              : const Icon(Icons.image_outlined,
                  color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}

// ── Video player page ──────────────────────────────────────────────────────────

class _VideoPlayerPage extends StatefulWidget {
  final MediaAsset asset;
  const _VideoPlayerPage({required this.asset});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (kIsWeb) return;
    try {
      final docs = await getDocsPath();
      final absPath = joinPath(docs, widget.asset.filePath);
      final ctrl = VideoPlayerController.file(File(absPath));
      ctrl.addListener(_onUpdate);
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _initialized = true;
      });
      ctrl.play();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onUpdate);
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl == null) return;
    _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
  }

  void _openFullscreen() async {
    final pos = _ctrl?.value.position ?? Duration.zero;
    _ctrl?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(
            asset: widget.asset, startPosition: pos),
      ),
    );
    if (mounted && _initialized) _ctrl?.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Text(context.l10n.memoryVideoFailed,
                style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (!_initialized || _ctrl == null) {
      return const Center(
        child: CircularProgressIndicator(
            color: Colors.white54, strokeWidth: 2),
      );
    }
    final isPlaying = _ctrl!.value.isPlaying;
    return GestureDetector(
      onTap: _togglePlay,
      child: Center(
        child: AspectRatio(
          aspectRatio: _ctrl!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_ctrl!),
              if (!isPlaying)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 44),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: VideoProgressIndicator(
                        _ctrl!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openFullscreen,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: Icon(Icons.fullscreen,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fullscreen video page ──────────────────────────────────────────────────────

class _FullscreenVideoPage extends StatefulWidget {
  final MediaAsset asset;
  final Duration startPosition;
  const _FullscreenVideoPage(
      {required this.asset, required this.startPosition});

  @override
  State<_FullscreenVideoPage> createState() =>
      _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (kIsWeb) return;
    try {
      final docs = await getDocsPath();
      final absPath = joinPath(docs, widget.asset.filePath);
      final ctrl = VideoPlayerController.file(File(absPath));
      ctrl.addListener(_onUpdate);
      await ctrl.initialize();
      await ctrl.seekTo(widget.startPosition);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _initialized = true;
      });
      ctrl.play();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onUpdate);
    _ctrl?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl == null) return;
    _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _hasError
          ? const Center(
              child: Icon(Icons.error_outline,
                  color: Colors.white54, size: 48))
          : !_initialized || _ctrl == null
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white54, strokeWidth: 2))
              : GestureDetector(
                  onTap: _togglePlay,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _ctrl!.value.aspectRatio,
                          child: VideoPlayer(_ctrl!),
                        ),
                      ),
                      if (!_ctrl!.value.isPlaying)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 52),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.fullscreen_exit,
                                    color: Colors.white),
                                onPressed: () =>
                                    Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: VideoProgressIndicator(
                            _ctrl!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white12,
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ── Thumbnail scrubber strip ───────────────────────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  final List<MediaAsset> assets;
  final int currentIndex;
  final ScrollController scrollController;
  final ValueChanged<int> onIndexChanged;

  static const double _thumbW = 64.0;
  static const double _thumbGap = 4.0;

  const _ThumbnailStrip({
    required this.assets,
    required this.currentIndex,
    required this.scrollController,
    required this.onIndexChanged,
  });

  int _indexAt(double localX) {
    final offset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;
    final x = localX + offset - 8.0;
    return (x / (_thumbW + _thumbGap))
        .floor()
        .clamp(0, assets.length - 1);
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        height: 88,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => onIndexChanged(_indexAt(d.localPosition.dx)),
          onLongPressStart: (d) {
            HapticFeedback.mediumImpact();
            onIndexChanged(_indexAt(d.localPosition.dx));
          },
          onLongPressMoveUpdate: (d) =>
              onIndexChanged(_indexAt(d.localPosition.dx)),
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 12),
            itemCount: assets.length,
            itemExtent: _thumbW + _thumbGap,
            itemBuilder: (_, i) => _ThumbnailItem(
              asset: assets[i],
              selected: i == currentIndex,
            ),
          ),
        ),
      );
}

class _ThumbnailItem extends StatefulWidget {
  final MediaAsset asset;
  final bool selected;
  const _ThumbnailItem({required this.asset, required this.selected});

  @override
  State<_ThumbnailItem> createState() => _ThumbnailItemState();
}

class _ThumbnailItemState extends State<_ThumbnailItem> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.asset.filePath;
    if (path.startsWith('data:')) {
      if (widget.asset.type != 'video') {
        final comma = path.indexOf(',');
        if (comma != -1 && mounted) {
          setState(() =>
              _bytes = base64Decode(path.substring(comma + 1)));
        }
      }
      return;
    }
    if (kIsWeb) return;
    if (widget.asset.type == 'video') {
      final docs = await getDocsPath();
      final absPath = joinPath(docs, path);
      final thumb = await VideoThumbnail.thumbnailData(
        video: absPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 100,
        quality: 60,
      );
      if (mounted) setState(() => _bytes = thumb);
      return;
    }
    final bytes = await readAppDocFileBytes(path);
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.selected
                  ? Colors.white
                  : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.asset.type == 'video'
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _bytes != null
                        ? Image.memory(_bytes!, fit: BoxFit.cover)
                        : Container(color: Colors.black54),
                    const Center(
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white70, size: 28),
                    ),
                  ],
                )
              : _bytes != null
                  ? Image.memory(_bytes!,
                      fit: BoxFit.cover, width: 64, height: 64)
                  : Container(
                      width: 64,
                      height: 64,
                      color: Colors.white12,
                      child: const Icon(Icons.image_outlined,
                          color: Colors.white54, size: 24),
                    ),
        ),
      );
}

// ── Settings Tab ───────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  final VoidCallback onExport;
  final VoidCallback onDelete;
  const _SettingsTab({required this.onExport, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final border = Theme.of(context).extension<AppThemeExtension>()!.borderColor;
    final text = Theme.of(context).extension<AppThemeExtension>()!.textPrimary;
    final textMuted = Theme.of(context).extension<AppThemeExtension>()!.textSecondary;
    final primary = Theme.of(context).extension<AppThemeExtension>()!.accentColor;

    Widget sectionHeader(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            label,
            style: GoogleFonts.notoSansSc(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textMuted,
              letterSpacing: 0.4,
            ),
          ),
        );

    Widget divider() => Divider(height: 1, thickness: 1, color: border);

    return ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── 导出 section ──
          sectionHeader(l10n.memoryExportSection),
          Column(
            children: [
              divider(),
              InkWell(
                  onTap: onExport,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined,
                            size: 20, color: primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.memoryExportPdfButton,
                            style: GoogleFonts.notoSansSc(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: text,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: textMuted),
                      ],
                    ),
                  ),
                ),
                divider(),
            ],
          ),

          // ── 主题 section ──
          sectionHeader(l10n.memoryThemeSection),
          const ThemePickerGrid(),

          // ── 删除 section — visually separate, fixed danger red regardless of theme ──
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD93025),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          l10n.memoryDeleteTitle,
                          style: GoogleFonts.notoSansSc(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.memoryDeleteIrreversible,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
    );
  }
}
