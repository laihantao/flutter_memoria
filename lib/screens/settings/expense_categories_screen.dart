import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme_extension.dart';

/// Curated emoji presets, grouped so a fitting icon is found in seconds.
const _kEmojiGroups = <String, List<String>>{
  '餐饮': ['🍜', '🍚', '🍔', '🍕', '🍣', '🥗', '🍦', '🧋', '☕', '🍺'],
  '出行': ['🚌', '🚕', '✈️', '🚄', '⛽', '🅿️', '🚲', '🛵', '🚢', '🗺️'],
  '购物': ['🛍️', '👕', '👟', '💄', '💍', '🎁', '📱', '💻', '🧸', '⌚'],
  '生活': ['🏠', '🧻', '💡', '🔧', '🧺', '🏥', '💊', '🐱', '🌿', '🧴'],
  '玩乐': ['🎮', '🎬', '🎤', '🏖️', '🎡', '⚽', '🏃', '🎨', '🎿', '🎣'],
  '其他': ['📚', '✏️', '💼', '🧧', '❤️', '👥', '💰', '📝', '🎓', '🙏'],
};

/// Manage expense categories: add / rename / re-icon / delete / drag-reorder.
/// Order here is exactly the order of the grid in the expense form.
class ExpenseCategoriesScreen extends ConsumerWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;
    final catsAsync = ref.watch(categoriesProvider('expense'));

    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.backgroundColor,
        title: const Text('费用分类'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
        data: (cats) {
          if (cats.isEmpty) {
            return Center(
              child: Text('还没有分类，点右下角添加',
                  style: TextStyle(color: t.textSecondary)),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.swipe_vertical_outlined,
                        size: 15, color: t.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '长按拖动排序 — 记账时的分类格按此顺序显示',
                        style:
                            TextStyle(fontSize: 12, color: t.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: cats.length,
                  // onReorderItem already adjusts newIndex for the removal.
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = cats.map((c) => c.id).toList();
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    ref
                        .read(expenseNotifierProvider.notifier)
                        .reorderCategories(ids);
                  },
                  itemBuilder: (context, i) => _CategoryTile(
                    key: ValueKey(cats[i].id),
                    category: cats[i],
                    onTap: () =>
                        _showEditSheet(context, ref, existing: cats[i]),
                    onDelete: () => _confirmDelete(context, ref, cats[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category cat) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${cat.name}」？'),
        content: const Text('已有记账记录的分类无法删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await ref
        .read(expenseNotifierProvider.notifier)
        .deleteCategory(cat.id);
    if (!deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该分类已有记账记录，无法删除')),
      );
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref,
      {Category? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CategoryEditSheet(existing: existing),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CategoryTile({
    super.key,
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Material (not a colored Container) so ListTile ink renders correctly.
      child: Material(
        color: t.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.borderColor, width: 0.5),
        ),
        child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(color: t.mutedColor, shape: BoxShape.circle),
          child: Center(
            child: Text(category.iconName ?? '•',
                style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(category.name,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: t.textPrimary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: t.textSecondary),
              onPressed: onDelete,
            ),
            Icon(Icons.drag_handle, color: t.textSecondary, size: 20),
            const SizedBox(width: 4),
          ],
        ),
        ),
      ),
    );
  }
}

class _CategoryEditSheet extends ConsumerStatefulWidget {
  final Category? existing;
  const _CategoryEditSheet({this.existing});

  @override
  ConsumerState<_CategoryEditSheet> createState() =>
      _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late final TextEditingController _nameCtrl;
  late String _emoji;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _emoji = widget.existing?.iconName ?? '🍜';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入分类名称')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(expenseNotifierProvider.notifier).saveCategory(
            existingId: widget.existing?.id,
            name: name,
            type: 'expense',
            iconName: _emoji,
            // New categories go to the end of the grid.
            sortOrder: widget.existing == null ? 1 << 20 : null,
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? '新分类' : '编辑分类',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: t.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: t.accentColor, width: 1.5),
                  ),
                  child: Center(
                      child:
                          Text(_emoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    autofocus: widget.existing == null,
                    maxLength: 8,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: '分类名称',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Emoji picker — grouped presets, scrolls within a capped height.
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.32),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in _kEmojiGroups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(group.key,
                            style: TextStyle(
                                fontSize: 12, color: t.textSecondary)),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: group.value.map((e) {
                          final selected = e == _emoji;
                          return GestureDetector(
                            onTap: () => setState(() => _emoji = e),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: selected
                                    ? t.accentColor.withValues(alpha: 0.18)
                                    : t.mutedColor,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(
                                        color: t.accentColor, width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                  child: Text(e,
                                      style:
                                          const TextStyle(fontSize: 19))),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
