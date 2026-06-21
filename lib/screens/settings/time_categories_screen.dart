import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/memory_provider.dart';
import '../../theme/app_theme.dart';

class TimeCategoriesScreen extends ConsumerWidget {
  const TimeCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final categoriesAsync = ref.watch(timeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCategories)),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
        data: (categories) => categories.isEmpty
            ? Center(
                child: Text(
                  l10n.settingsCategories,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              )
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                itemCount: categories.length,
                onReorderItem: (oldIndex, newIndex) {
                  final reordered = [...categories];
                  final item = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, item);
                  ref
                      .read(memoryNotifierProvider.notifier)
                      .reorderTimeCategories(reordered.map((c) => c.id).toList());
                },
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  return _CategoryTile(
                    key: ValueKey(cat.id),
                    index: i,
                    category: cat,
                    onEdit: () => _showEditDialog(context, ref, l10n, cat),
                    onDelete: cat.isDefault
                        ? null
                        : () => _confirmDelete(context, ref, l10n, cat),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref, l10n),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    String inputText = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.categoryCreateTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.categoryNameLabel),
            onChanged: (v) => inputText = v,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.categoryNameRequired : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(memoryNotifierProvider.notifier)
          .createTimeCategory(inputText.trim());
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TimeCategory cat,
  ) async {
    String inputText = cat.name;
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.categoryEditTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            initialValue: cat.name,
            decoration: InputDecoration(labelText: l10n.categoryNameLabel),
            onChanged: (v) => inputText = v,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.categoryNameRequired : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(memoryNotifierProvider.notifier)
          .renameTimeCategory(cat.id, inputText.trim());
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TimeCategory cat,
  ) async {
    final count = await ref
        .read(memoryNotifierProvider.notifier)
        .getTimeCategoryRecordCount(cat.id);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(
          count > 0
              ? l10n.categoryDeleteHasRecords(cat.name, count)
              : l10n.categoryDeleteConfirm(cat.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(memoryNotifierProvider.notifier)
          .deleteTimeCategoryById(cat.id);
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final int index;
  final TimeCategory category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryTile({
    super.key,
    required this.index,
    required this.category,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle, color: AppColors.textSecondary),
      ),
      title: Text(category.name),
      subtitle: category.isDefault
          ? Text(
              '预设',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warmBrown.withValues(alpha: 0.7),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppColors.warmBrown,
            ),
            onPressed: onEdit,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: onDelete,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
