import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
import '../../services/settle_up_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_ops.dart';
import '../../widgets/money_chip.dart';
import '../../widgets/person_avatar.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
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

    try {
      final itinerary = await ref.read(itineraryProvider(widget.id).future);
      final mediaAssets =
          await ref.read(mediaAssetsProvider(widget.id).future);

      Uint8List pdfBytes;
      String fileName;

      if (choice == 'keepsake') {
        pdfBytes = await PdfService.generateKeepsake(
          memory: memory,
          itinerary: itinerary,
          mediaAssets: mediaAssets,
          participantNames: const [],
        );
        fileName = 'memora_keepsake_${memory.id}.pdf';
      } else {
        final transactions = await ref
            .read(databaseProvider)
            .expenseDao
            .getTransactionsForMemory(widget.id);

        final splitMap = <String, List<TransactionSplit>>{};
        for (final tx in transactions) {
          splitMap[tx.id] =
              await ref.read(databaseProvider).expenseDao.getSplits(tx.id);
        }

        final settlements = SettleUpService().compute(
          transactions: transactions,
          splitsByTxId: splitMap,
          baseCurrency: 'MYR',
        );

        final categories =
            await ref.read(databaseProvider).expenseDao.getCategories();
        final categoryNames = {for (final c in categories) c.id: c.name};

        pdfBytes = await PdfService.generateSettlement(
          memory: memory,
          transactions: transactions,
          personNames: const {},
          categoryNames: categoryNames,
          settlements: settlements,
        );
        fileName = 'memora_settlement_${memory.id}.pdf';
      }

      if (!mounted) return;
      await Share.shareXFiles([
        XFile.fromData(pdfBytes,
            name: fileName, mimeType: 'application/pdf'),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final memoryAsync = ref.watch(memoryProvider(widget.id));

    return memoryAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(l10n.errorWith('$e')))),
      data: (memory) {
        if (memory == null) {
          return Scaffold(
              body: Center(child: Text(l10n.memoryNotFound)));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(memory.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.memoryEditDetails,
                onPressed: () =>
                    context.push('/memories/${widget.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n.memoryExportPdfTooltip,
                onPressed: () => _exportPdf(memory),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: [
                Tab(text: l10n.memoryTabOverview),
                Tab(text: l10n.memoryTabItinerary),
                Tab(text: l10n.memoryTabGallery),
                Tab(text: l10n.memoryTabExpenses),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(
                memory: memory,
                memoryId: widget.id,
                onTabNavigate: _tabs.animateTo,
              ),
              _ItineraryTab(memoryId: widget.id),
              _GalleryTab(memoryId: widget.id),
              _ExpensesTab(memoryId: widget.id),
            ],
          ),
          floatingActionButton: _tabs.index == 2
              ? FloatingActionButton(
                  onPressed: _pickMedia,
                  child:
                      const Icon(Icons.add_photo_alternate_outlined),
                )
              : null,
        );
      },
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final Memory memory;
  final String memoryId;
  final void Function(int) onTabNavigate;
  const _OverviewTab({
    required this.memory,
    required this.memoryId,
    required this.onTabNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(memoryParticipantsProvider(memoryId));
    final assetsAsync = ref.watch(mediaAssetsProvider(memoryId));
    final itineraryAsync = ref.watch(itineraryProvider(memoryId));
    final txAsync = ref.watch(transactionsByMemoryProvider(memoryId));
    final locationsAsync = ref.watch(memoryLocationsProvider(memoryId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(
            memory: memory,
            memoryId: memoryId,
            participantsAsync: participantsAsync,
          ),
          const SizedBox(height: 12),
          _QuickStatsRow(
            photoCount: assetsAsync.value?.length ?? 0,
            itineraryCount: itineraryAsync.value?.length ?? 0,
            txns: txAsync.value ?? [],
            onPhotosTap: () => onTabNavigate(2),
            onItineraryTap: () => onTabNavigate(1),
            onExpensesTap: () => onTabNavigate(3),
          ),
          if (memory.description != null &&
              memory.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionLabel('描述'),
            _DescriptionCard(description: memory.description!),
          ],
          locationsAsync.when(
            data: (locations) => locations.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _SectionLabel('地点 · ${locations.length}'),
                      _LocationsCard(locations: locations),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Memory memory;
  final String memoryId;
  final AsyncValue<List<MemoryParticipant>> participantsAsync;

  const _SummaryCard({
    required this.memory,
    required this.memoryId,
    required this.participantsAsync,
  });

  String _durationText() {
    if (memory.endDate == null) return '';
    final diff = memory.endDate!.difference(memory.startDate).inDays;
    if (diff <= 0) return '';
    return '${diff + 1}天$diff夜';
  }

  String _dateText() {
    final yearFmt = DateFormat('d MMM yyyy');
    final shortFmt = DateFormat('d MMM');
    if (memory.endDate == null) return yearFmt.format(memory.startDate);
    final sameYear = memory.startDate.year == memory.endDate!.year;
    final start = sameYear
        ? shortFmt.format(memory.startDate)
        : yearFmt.format(memory.startDate);
    return '$start – ${yearFmt.format(memory.endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _durationText();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryBadge(type: memory.type),
              const Spacer(),
              if (duration.isNotEmpty) _DurationBadge(text: duration),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.warmBrown),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateText(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFDDC9A8)),
          const SizedBox(height: 10),
          participantsAsync.when(
            loading: () => const SizedBox(height: 26),
            error: (_, _) => const SizedBox(height: 26),
            data: (participants) => _ParticipantRow(
              participants: participants,
              memoryId: memoryId,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String type;
  const _CategoryBadge({required this.type});

  static IconData _iconFor(String type) => switch (type) {
        '旅行' => Icons.flight_outlined,
        '聚会' => Icons.people_outline,
        '纪念日' => Icons.favorite_border,
        '美食' => Icons.restaurant_outlined,
        '活动' => Icons.event_outlined,
        '日常' => Icons.wb_sunny_outlined,
        '成就' => Icons.emoji_events_outlined,
        _ => Icons.label_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(type), size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            type,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final String text;
  const _DurationBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warmBeige,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.warmBrown,
        ),
      ),
    );
  }
}

class _ParticipantRow extends ConsumerWidget {
  final List<MemoryParticipant> participants;
  final String memoryId;
  const _ParticipantRow(
      {required this.participants, required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double avatarD = 26;
    const double overlapStep = 18;
    final shown = participants.take(5).toList();
    final stackWidth = shown.isEmpty
        ? 0.0
        : avatarD + (shown.length - 1) * overlapStep;

    return Row(
      children: [
        if (shown.isNotEmpty)
          SizedBox(
            width: stackWidth,
            height: avatarD,
            child: Stack(
              children: [
                for (int i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * overlapStep,
                    child: _AvatarCircle(
                      personId: shown[i].personId,
                      diameter: avatarD,
                    ),
                  ),
              ],
            ),
          ),
        if (shown.isNotEmpty) const SizedBox(width: 8),
        Text(
          '${participants.length}人',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.warmBrown,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _ParticipantPickerSheet(memoryId: memoryId),
          ),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const Icon(Icons.add, size: 14, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _AvatarCircle extends ConsumerWidget {
  final String personId;
  final double diameter;
  const _AvatarCircle(
      {required this.personId, required this.diameter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personProvider(personId));
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.chipBg, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: personAsync.when(
        loading: () => Container(color: AppColors.warmBeige),
        error: (_, _) => const SizedBox(),
        data: (person) => person == null
            ? Container(color: AppColors.warmBeige)
            : PersonAvatar(
                name: person.name,
                imagePath: person.avatarPath,
                radius: diameter / 2,
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
  final VoidCallback onPhotosTap;
  final VoidCallback onItineraryTap;
  final VoidCallback onExpensesTap;

  const _QuickStatsRow({
    required this.photoCount,
    required this.itineraryCount,
    required this.txns,
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
    final sym =
        const {'MYR': 'RM', 'SGD': 'S\$'}[txns.first.currencyCode] ??
            txns.first.currencyCode;
    if (total >= 1000) return '$sym${(total / 1000).toStringAsFixed(1)}k';
    return '$sym${total.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.photo_library_outlined,
            value: '$photoCount',
            label: '相册',
            onTap: onPhotosTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.map_outlined,
            value: '$itineraryCount',
            label: '行程站',
            onTap: onItineraryTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long_outlined,
            value: _expenseLabel,
            label: '费用',
            onTap: onExpensesTap,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.warmBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Description Card ──────────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: AppColors.primary),
            Expanded(
              child: Container(
                color: AppColors.chipBg,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
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

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.warmBrown,
            letterSpacing: 0.4,
          ),
        ),
      );
}

// ── Locations grouped card ────────────────────────────────────────────────────

class _LocationsCard extends StatelessWidget {
  final List<MemoryLocation> locations;
  const _LocationsCard({required this.locations});

  Future<void> _openMaps(BuildContext context, String name) async {
    final uri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(name)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开地图'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: locations.asMap().entries.map((e) {
          final loc = e.value;
          final isLast = e.key == locations.length - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map_outlined,
                          size: 16, color: AppColors.warmBrown),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: '在地图中查看',
                      onPressed: () => _openMaps(context, loc.name),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 38,
                    color: Color(0xFFDDC9A8)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Participant Picker Sheet ──────────────────────────────────────────────────

class _ParticipantPickerSheet extends ConsumerWidget {
  final String memoryId;
  const _ParticipantPickerSheet({required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personsAsync = ref.watch(personsProvider);
    final selfAsync = ref.watch(selfPersonStreamProvider);
    final participantsAsync = ref.watch(memoryParticipantsProvider(memoryId));
    final notifier = ref.read(memoryNotifierProvider.notifier);

    final currentIds = participantsAsync.value?.map((p) => p.personId).toSet() ?? {};

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.warmBeige,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('参与者',
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
                    return const Center(child: Text('暂无联系人'));
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
                        subtitle: person.isSelf ? const Text('（我）') : null,
                        trailing: selected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary)
                            : const Icon(Icons.radio_button_unchecked,
                                color: AppColors.warmBrown),
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

// ── Itinerary Tab ─────────────────────────────────────────────────────────────

class _ItineraryTab extends ConsumerStatefulWidget {
  final String memoryId;
  const _ItineraryTab({required this.memoryId});

  @override
  ConsumerState<_ItineraryTab> createState() => _ItineraryTabState();
}

class _ItineraryTabState extends ConsumerState<_ItineraryTab> {
  final _titleCtrl = TextEditingController();
  DateTime? _itemDate;
  TimeOfDay? _itemTime;
  ItineraryItem? _editingItem;
  bool _groupByDate = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String? get _itemTimeStr {
    if (_itemTime == null) return null;
    final h = _itemTime!.hour.toString().padLeft(2, '0');
    final m = _itemTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _startEdit(ItineraryItem item) {
    _titleCtrl.text = item.title;
    setState(() {
      _editingItem = item;
      _itemDate = item.itemDate;
      _itemTime = _parseTime(item.itemTime);
    });
  }

  void _cancelEdit() {
    _titleCtrl.clear();
    setState(() {
      _editingItem = null;
      _itemDate = null;
      _itemTime = null;
    });
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _saveOrUpdate() async {
    if (_titleCtrl.text.trim().isEmpty || _itemDate == null) return;
    final notifier = ref.read(memoryNotifierProvider.notifier);
    try {
      if (_editingItem != null) {
        await notifier.updateItineraryItem(ItineraryItem(
          id: _editingItem!.id,
          memoryId: _editingItem!.memoryId,
          itemDate: _itemDate!,
          itemTime: _itemTimeStr,
          title: _titleCtrl.text.trim(),
          locationName: _editingItem!.locationName,
          notes: _editingItem!.notes,
          sortOrder: _editingItem!.sortOrder,
        ));
      } else {
        await notifier.addItineraryItem(
          memoryId: widget.memoryId,
          itemDate: _itemDate!,
          itemTime: _itemTimeStr,
          title: _titleCtrl.text.trim(),
        );
      }
      _titleCtrl.clear();
      setState(() {
        _editingItem = null;
        _itemDate = null;
        _itemTime = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.savedSuccess),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorWith('$e'))),
        );
      }
    }
  }

  Future<bool?> _confirmDelete(BuildContext ctx) {
    final l10n = ctx.l10n;
    return showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.memoryDeleteItineraryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(ItineraryItem item) async {
    final confirmed = await _confirmDelete(context);
    if (confirmed != true) return;
    if (_editingItem?.id == item.id) _cancelEdit();
    try {
      await ref
          .read(memoryNotifierProvider.notifier)
          .deleteItineraryItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.deletedSuccess),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorWith('$e'))),
        );
      }
    }
  }

  Widget _buildDismissible(ItineraryItem item) {
    return Dismissible(
      key: Key('it_${item.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        if (_editingItem?.id == item.id) _cancelEdit();
        try {
          await ref
              .read(memoryNotifierProvider.notifier)
              .deleteItineraryItem(item.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.deletedSuccess),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.errorWith('$e'))),
            );
          }
        }
      },
      child: _ItineraryCard(
        item: item,
        onEdit: () => _startEdit(item),
        isEditing: _editingItem?.id == item.id,
      ),
    );
  }

  Widget _buildFlatList(List<ItineraryItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildDismissible(items[i]),
    );
  }

  Widget _buildGroupedList(List<ItineraryItem> items) {
    final grouped = <String, List<ItineraryItem>>{};
    for (final item in items) {
      final key =
          '${item.itemDate.year}-${item.itemDate.month.toString().padLeft(2, '0')}-${item.itemDate.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, i) {
        final dateItems = grouped[sortedKeys[i]]!;
        return _DateGroup(
          date: dateItems.first.itemDate,
          items: dateItems,
          editingItemId: _editingItem?.id,
          onEdit: _startEdit,
          onDelete: _deleteItem,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final itineraryAsync = ref.watch(itineraryProvider(widget.memoryId));
    final isEditing = _editingItem != null;

    return Column(
      children: [
        Expanded(
          child: itineraryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
            data: (items) {
              if (items.isEmpty) {
                return Center(child: Text(l10n.memoryNoItinerary));
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: Icon(
                            _groupByDate
                                ? Icons.view_list_outlined
                                : Icons.view_agenda_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _groupByDate
                                ? l10n.memoryListView
                                : l10n.memoryGroupByDate,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () =>
                              setState(() => _groupByDate = !_groupByDate),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _groupByDate
                        ? _buildGroupedList(items)
                        : _buildFlatList(items),
                  ),
                ],
              );
            },
          ),
        ),
        // ── Bottom form (add / edit) ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: isEditing
                ? AppColors.primary.withValues(alpha: 0.04)
                : AppColors.cardBg,
            border: Border(
              top: BorderSide(
                color:
                    isEditing ? AppColors.primary : AppColors.warmBeige,
                width: isEditing ? 1.5 : 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    isEditing
                        ? l10n.memoryEditItinerary
                        : l10n.memoryAddItinerary,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isEditing ? AppColors.primary : null,
                        ),
                  ),
                  if (isEditing) ...[
                    const Spacer(),
                    TextButton(
                      onPressed: _cancelEdit,
                      child: Text(l10n.cancel),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                    hintText: l10n.memoryActivityHint, isDense: true),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _itemDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _itemDate = d);
                    },
                    label: Text(_itemDate == null
                        ? l10n.memoryDateLabel
                        : '${_itemDate!.day}/${_itemDate!.month}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_outlined, size: 16),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _itemTime ?? TimeOfDay.now(),
                      );
                      if (t != null) setState(() => _itemTime = t);
                    },
                    label: Text(_itemTime == null
                        ? l10n.memoryTimeLabel
                        : _itemTime!.format(context)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    isEditing ? Icons.check_circle_outline : Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  tooltip: isEditing ? l10n.save : l10n.add,
                  onPressed: _saveOrUpdate,
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Itinerary card (flat list) ────────────────────────────────────────────────

class _ItineraryCard extends StatelessWidget {
  final ItineraryItem item;
  final VoidCallback onEdit;
  final bool isEditing;
  const _ItineraryCard({
    required this.item,
    required this.onEdit,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: isEditing
          ? AppColors.primary.withValues(alpha: 0.06)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isEditing
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : const BorderSide(color: Color(0xFFEDD3A8), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            // Date + time column
            SizedBox(
              width: 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.formatMonthDay(item.itemDate),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (item.itemTime != null)
                    Text(
                      item.itemTime!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warmBrown,
                      ),
                    ),
                ],
              ),
            ),
            Container(width: 1, height: 22, color: AppColors.warmBeige),
            const SizedBox(width: 10),
            // Title + optional location
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.locationName != null)
                    Text(
                      '📍 ${item.locationName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warmBrown,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Edit button
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 14,
                color: isEditing ? AppColors.primary : AppColors.warmBrown,
              ),
              padding: const EdgeInsets.all(5),
              constraints: const BoxConstraints(),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date group card (grouped list) ────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  final DateTime date;
  final List<ItineraryItem> items;
  final String? editingItemId;
  final void Function(ItineraryItem) onEdit;
  final void Function(ItineraryItem) onDelete;

  const _DateGroup({
    required this.date,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    this.editingItemId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact date header
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 11, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  l10n.formatMonthDay(date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Events card with timeline
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDD3A8), width: 0.5),
            ),
            child: Column(
              children: items.asMap().entries.map((e) {
                final item = e.value;
                final isLast = e.key == items.length - 1;
                final isEditingThis = editingItemId == item.id;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline column: dot + vertical line
                      SizedBox(
                        width: 28,
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Center(
                                  child: Container(
                                    width: 1.5,
                                    color: AppColors.warmBeige,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      // Event content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              color: isEditingThis
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : null,
                              padding:
                                  const EdgeInsets.fromLTRB(2, 5, 4, 5),
                              child: Row(
                                children: [
                                  // Time label — fixed width prevents wrap
                                  if (item.itemTime != null) ...[
                                    SizedBox(
                                      width: 38,
                                      child: Text(
                                        item.itemTime!,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isEditingThis
                                              ? AppColors.primary
                                              : AppColors.warmBrown,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ] else
                                    const SizedBox(width: 8),
                                  // Title + optional location
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isEditingThis
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.locationName != null)
                                          Text(
                                            '📍 ${item.locationName}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.warmBrown,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Action buttons — visually small, tap target padded
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 14,
                                          color: isEditingThis
                                              ? AppColors.primary
                                              : AppColors.warmBrown,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => onEdit(item),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 14,
                                          color: Colors.red.shade400,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => onDelete(item),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              const Divider(
                                height: 1,
                                thickness: 0.5,
                                color: Color(0xFFEDD3A8),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gallery Tab ───────────────────────────────────────────────────────────────

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
                      size: 56, color: AppColors.warmBeige),
                  const SizedBox(height: 12),
                  Text(l10n.memoryNoPhotos,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: assets.length,
              itemBuilder: (context, i) =>
                  _MediaTile(asset: assets[i], memoryId: memoryId),
            ),
    );
  }
}

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
        final idx = allAssets.indexWhere((a) => a.id == widget.asset.id);
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
          color: AppColors.warmBeige,
          borderRadius: BorderRadius.circular(8),
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
              const Center(
                child: Icon(Icons.image_outlined, color: AppColors.warmBrown),
              ),
            if (isVideo)
              const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white, size: 40),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Expenses Tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  final String memoryId;
  const _ExpensesTab({required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final txAsync = ref.watch(transactionsByMemoryProvider(memoryId));
    final catAsync = ref.watch(categoriesProvider(null));

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
      data: (txns) {
        if (txns.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 48,
                    color: AppColors.warmBrown.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(l10n.memoryNoExpenses),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/memories/$memoryId/expenses/new'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.memoryRecordExpense),
                ),
              ],
            ),
          );
        }
        final catMap = {
          for (final c in catAsync.value ?? <Category>[]) c.id: c
        };
        double total = 0;
        for (final t in txns) {
          total += t.type == 'expense' ? -t.amount : t.amount;
        }
        final sym = txns.isNotEmpty
            ? (const {'MYR': 'RM', 'SGD': 'S\$'}[txns.first.currencyCode] ??
                txns.first.currencyCode)
            : 'RM';
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              color: AppColors.warmBrown.withValues(alpha: 0.08),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.memoryExpenseCount(txns.length),
                      style: const TextStyle(
                          color: AppColors.warmBrown)),
                  Text(
                    l10n.memoryExpenseTotal(sym, total.abs().toStringAsFixed(2)),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: total >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: txns.length,
                itemBuilder: (context, i) {
                  final tx = txns[i];
                  final cat = catMap[tx.categoryId];
                  final isExp = tx.type == 'expense';
                  return Card(
                    child: ListTile(
                      leading: Text(
                        cat?.iconName ?? '•',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(cat?.name ?? tx.categoryId),
                      subtitle:
                          Text(l10n.formatMonthDay(tx.txnDate)),
                      trailing: MoneyChip(
                        amount: tx.amount,
                        currency: tx.currencyCode,
                        isExpense: isExp,
                      ),
                      onTap: () =>
                          context.push('/expenses/${tx.id}/edit'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Photo Viewer ──────────────────────────────────────────────────────────────

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
        duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
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

// ── Single zoomable photo page ────────────────────────────────────────────────

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
    if (widget.asset.type == 'video') return; // no image decoding for video
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
      // Zoom to the tapped point: keep that point fixed on screen.
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

// ── Video player page ─────────────────────────────────────────────────────────

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
        builder: (_) =>
            _FullscreenVideoPage(asset: widget.asset, startPosition: pos),
      ),
    );
    if (mounted && _initialized) _ctrl?.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 48),
            SizedBox(height: 8),
            Text('无法播放视频', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (!_initialized || _ctrl == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
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
                bottom: 0, left: 0, right: 0,
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
                        padding: const EdgeInsets.symmetric(vertical: 6),
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

// ── Fullscreen video page ─────────────────────────────────────────────────────

class _FullscreenVideoPage extends StatefulWidget {
  final MediaAsset asset;
  final Duration startPosition;
  const _FullscreenVideoPage(
      {required this.asset, required this.startPosition});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Unlock all orientations so portrait videos default to portrait
    // and the user can rotate to landscape freely.
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
    // Explicitly restore both status bar and nav bar — edgeToEdge alone
    // leaves the nav bar hidden, making the whole app appear fullscreen.
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
              child: Icon(Icons.error_outline, color: Colors.white54, size: 48))
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
                        top: 0, left: 0, right: 0,
                        child: SafeArea(
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.fullscreen_exit,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: SafeArea(
                          child: VideoProgressIndicator(
                            _ctrl!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white12,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ── Thumbnail scrubber strip ──────────────────────────────────────────────────

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
    final offset =
        scrollController.hasClients ? scrollController.offset : 0.0;
    // 8px leading padding, then each slot = _thumbW + _thumbGap
    final x = localX + offset - 8.0;
    return (x / (_thumbW + _thumbGap)).floor().clamp(0, assets.length - 1);
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        height: 88,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tap to jump to a specific thumbnail.
          onTapUp: (d) => onIndexChanged(_indexAt(d.localPosition.dx)),
          // Hold 1 s → haptic → drag to scrub photos (does not block normal scroll).
          onLongPressStart: (d) {
            HapticFeedback.mediumImpact();
            onIndexChanged(_indexAt(d.localPosition.dx));
          },
          onLongPressMoveUpdate: (d) =>
              onIndexChanged(_indexAt(d.localPosition.dx)),
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
              color: widget.selected ? Colors.white : Colors.transparent,
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
