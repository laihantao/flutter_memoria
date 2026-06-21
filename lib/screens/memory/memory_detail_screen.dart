import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
              _OverviewTab(memory: memory, memoryId: widget.id),
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
  const _OverviewTab({required this.memory, required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dateFmt = DateFormat('d MMM yyyy');
    final participantsAsync =
        ref.watch(memoryParticipantsProvider(memoryId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (memory.description != null) ...[
            Text(memory.description!,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
          ],
          _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: memory.endDate != null
                  ? '${dateFmt.format(memory.startDate)} – ${dateFmt.format(memory.endDate!)}'
                  : dateFmt.format(memory.startDate)),
          if (memory.locationName != null)
            _InfoRow(
                icon: Icons.location_on_outlined,
                text: memory.locationName!),
          const SizedBox(height: 16),
          Text(l10n.memoryParticipantsSection,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          participantsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text(l10n.errorWith('$e')),
            data: (participants) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: participants
                  .map((p) => _ParticipantChip(personId: p.personId))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(l10n.memoryEditDetails),
            onPressed: () => context.push('/memories/$memoryId/edit'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.warmBrown),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _ParticipantChip extends ConsumerWidget {
  final String personId;
  const _ParticipantChip({required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personProvider(personId));
    return personAsync.when(
      loading: () => const SizedBox(),
      error: (_, _) => const SizedBox(),
      data: (person) => person == null
          ? const SizedBox()
          : Chip(
              avatar: PersonAvatar(name: person.name, radius: 12),
              label: Text(person.name),
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
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 8),
      color: isEditing ? AppColors.primary.withValues(alpha: 0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEditing
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: SizedBox(
          width: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.formatMonthDay(item.itemDate),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.primary)),
              if (item.itemTime != null)
                Text(item.itemTime!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warmBrown)),
            ],
          ),
        ),
        title: Text(item.title),
        subtitle: item.locationName != null
            ? Text('📍 ${item.locationName}',
                style: const TextStyle(fontSize: 12))
            : null,
        trailing: IconButton(
          icon: Icon(
            Icons.edit_outlined,
            size: 18,
            color: isEditing ? AppColors.primary : AppColors.warmBrown,
          ),
          onPressed: onEdit,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.formatMonthDay(date),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),
          // Items
          ...items.asMap().entries.map((e) {
            final item = e.value;
            final isFirst = e.key == 0;
            final isEditingThis = editingItemId == item.id;
            return Column(
              children: [
                if (!isFirst)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  tileColor: isEditingThis
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : null,
                  leading: item.itemTime != null
                      ? Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.itemTime!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : const SizedBox(width: 44),
                  title: Text(item.title,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: item.locationName != null
                      ? Text('📍 ${item.locationName}',
                          style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isEditingThis
                              ? AppColors.primary
                              : AppColors.warmBrown,
                        ),
                        onPressed: () => onEdit(item),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: Colors.red.shade400),
                        onPressed: () => onDelete(item),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
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
    if (widget.asset.type == 'video') return; // show play icon; don't decode as image
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
        child: isVideo
            ? Stack(fit: StackFit.expand, children: [
                Container(color: Colors.black54),
                const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 40),
                ),
              ])
            : _bytes != null
                ? Image.memory(_bytes!, fit: BoxFit.cover)
                : const Center(
                    child: Icon(Icons.image_outlined,
                        color: AppColors.warmBrown)),
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
  Widget build(BuildContext context) => GestureDetector(
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: _onDoubleTap,
        child: widget.asset.type == 'video'
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline,
                        color: Colors.white54, size: 72),
                    SizedBox(height: 12),
                    Text('Video preview not supported',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              )
            : InteractiveViewer(
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
          onTapDown: (d) => onIndexChanged(_indexAt(d.localPosition.dx)),
          onPanUpdate: (d) {
            final i = _indexAt(d.localPosition.dx);
            if (i != currentIndex) onIndexChanged(i);
          },
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            // Programmatic scroll only — drag is handled by GestureDetector above.
            physics: const NeverScrollableScrollPhysics(),
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
              ? Container(
                  width: 64,
                  height: 64,
                  color: Colors.black54,
                  child: const Icon(Icons.play_circle_outline,
                      color: Colors.white70, size: 28),
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
