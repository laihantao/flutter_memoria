import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/theme_background.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';

class PartnerDashboardScreen extends ConsumerStatefulWidget {
  final String personId;
  const PartnerDashboardScreen({super.key, required this.personId});

  @override
  ConsumerState<PartnerDashboardScreen> createState() =>
      _PartnerDashboardState();
}

class _PartnerDashboardState extends ConsumerState<PartnerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _wishlistCtrl = TextEditingController();
  final _anniversaryLabelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(personNotifierProvider.notifier)
          .ensurePartnerExtension(widget.personId);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _wishlistCtrl.dispose();
    _anniversaryLabelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final personAsync = ref.watch(personProvider(widget.personId));
    final extAsync = ref.watch(partnerExtensionProvider(widget.personId));

    return Scaffold(
      appBar: AppBar(
        title: personAsync.when(
          data: (p) => Text(p?.name ?? ''),
          loading: () => const SizedBox(),
          error: (_, _) => const SizedBox(),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.partnerTabAnniversaries),
            Tab(text: l10n.partnerTabWishlist),
            Tab(text: l10n.partnerTabMemories),
          ],
        ),
      ),
      body: extAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
        data: (ext) {
          if (ext == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ThemeBackground(
            child: TabBarView(
            controller: _tabs,
            children: [
              _AnniversariesTab(
                  extId: ext.id,
                  notifier: ref.read(personNotifierProvider.notifier)),
              _WishlistTab(
                  extId: ext.id,
                  notifier: ref.read(personNotifierProvider.notifier)),
              _MemoriesTab(personId: widget.personId),
            ],
          ),
          );
        },
      ),
    );
  }
}

// ── Anniversaries Tab ──────────────────────────────────────────────────────────

class _AnniversariesTab extends ConsumerStatefulWidget {
  final String extId;
  final dynamic notifier;
  const _AnniversariesTab({required this.extId, required this.notifier});

  @override
  ConsumerState<_AnniversariesTab> createState() => _AnniversariesTabState();
}

class _AnniversariesTabState extends ConsumerState<_AnniversariesTab> {
  final _labelCtrl = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final anniversariesAsync =
        ref.watch(anniversariesProvider(widget.extId));

    return Column(
      children: [
        Expanded(
          child: anniversariesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
            data: (items) => items.isEmpty
                ? Center(child: Text(l10n.partnerNoAnniversaries))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final daysUntil = _daysUntil(item.date);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.favorite,
                              color: AppColors.dustyRose),
                          title: Text(item.label),
                          subtitle: Text(
                              DateFormat('d MMM').format(item.date)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                daysUntil == 0
                                    ? l10n.partnerToday
                                    : l10n.partnerDaysToGo(daysUntil),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: daysUntil == 0
                                      ? AppColors.primary
                                      : AppColors.warmBrown,
                                  fontSize: 13,
                                ),
                              ),
                              if (daysUntil > 0)
                                Text(l10n.partnerToGo,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                            ],
                          ),
                          onLongPress: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await _confirm(
                                context, l10n.partnerDeleteConfirm(item.label));
                            if (ok) {
                              try {
                                await ref
                                    .read(personNotifierProvider.notifier)
                                    .deleteAnniversary(item.id);
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
                        ),
                      );
                    },
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _labelCtrl,
                  decoration: InputDecoration(
                      hintText: l10n.partnerAnniversaryLabelHint),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Text(
                    _date == null
                        ? l10n.partnerDateLabel
                        : DateFormat('d MMM').format(_date!)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                onPressed: () async {
                  if (_labelCtrl.text.isEmpty || _date == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(personNotifierProvider.notifier)
                        .addAnniversary(widget.extId, _labelCtrl.text, _date!);
                    _labelCtrl.clear();
                    setState(() => _date = null);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.addedSuccess),
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
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, date.month, date.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

// ── Wishlist Tab ───────────────────────────────────────────────────────────────

class _WishlistTab extends ConsumerStatefulWidget {
  final String extId;
  final dynamic notifier;
  const _WishlistTab({required this.extId, required this.notifier});

  @override
  ConsumerState<_WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends ConsumerState<_WishlistTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ref
          .read(personNotifierProvider.notifier)
          .addWishlistItem(widget.extId, text);
      _ctrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.addedSuccess),
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

  Future<void> _deleteItem(String id) async {
    try {
      await ref
          .read(personNotifierProvider.notifier)
          .deleteWishlistItem(id);
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wishlistAsync = ref.watch(wishlistProvider(widget.extId));

    return Column(
      children: [
        Expanded(
          child: wishlistAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
            data: (items) => items.isEmpty
                ? Center(child: Text(l10n.partnerWishlistEmpty))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return CheckboxListTile(
                        value: item.isFulfilled,
                        onChanged: (_) => ref
                            .read(personNotifierProvider.notifier)
                            .toggleWishlistItem(item),
                        title: Text(
                          item.content,
                          style: TextStyle(
                            decoration: item.isFulfilled
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isFulfilled
                                ? Colors.grey
                                : null,
                          ),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.dustyRose, size: 20),
                          onPressed: () => _deleteItem(item.id),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration:
                      InputDecoration(hintText: l10n.partnerWishHint),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                onPressed: _addItem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Memories Tab ───────────────────────────────────────────────────────────────

class _MemoriesTab extends ConsumerWidget {
  final String personId;
  const _MemoriesTab({required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Text(context.l10n.partnerMemoriesNote,
          textAlign: TextAlign.center),
    );
  }
}

Future<bool> _confirm(BuildContext context, String message) async {
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.partnerConfirm),
          content: Text(message),
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
      ) ??
      false;
}
