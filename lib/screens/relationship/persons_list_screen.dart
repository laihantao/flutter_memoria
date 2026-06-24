import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../widgets/theme_background.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/person_avatar.dart';

// Pink palette for the partner card.
const _partnerBg = Color(0xFFFCE4EC);
const _partnerBorder = Color(0xFFF48FB1);
const _partnerAccent = Color(0xFFE91E8C);

class PersonsListScreen extends ConsumerStatefulWidget {
  const PersonsListScreen({super.key});

  @override
  ConsumerState<PersonsListScreen> createState() => _PersonsListScreenState();
}

class _PersonsListScreenState extends ConsumerState<PersonsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateGroupDialog() async {
    final l10n = context.l10n;
    String inputName = '';
    String inputDesc = '';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.groupCreate),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.groupNameLabel),
                onChanged: (v) => inputName = v,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.groupNameRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(labelText: l10n.groupDescriptionLabel),
                onChanged: (v) => inputDesc = v,
                maxLines: 2,
              ),
            ],
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

    if (confirmed == true && mounted) {
      final desc = inputDesc.trim();
      final groupId = await ref.read(personNotifierProvider.notifier).saveGroup(
            name: inputName.trim(),
            description: desc.isEmpty ? null : desc,
          );
      if (mounted) context.push('/people/groups/$groupId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isGroupTab = _tabCtrl.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.personsTitle),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: l10n.personsTabLabel),
            Tab(text: l10n.groupsTabLabel),
          ],
        ),
      ),
      body: ThemeBackground(
        child: TabBarView(
          controller: _tabCtrl,
          children: const [
            _PersonsTabBody(),
            _GroupsTabBody(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isGroupTab
            ? _showCreateGroupDialog
            : () => context.push('/people/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Persons tab ───────────────────────────────────────────────────────────────

class _PersonsTabBody extends ConsumerStatefulWidget {
  const _PersonsTabBody();

  @override
  ConsumerState<_PersonsTabBody> createState() => _PersonsTabBodyState();
}

class _PersonsTabBodyState extends ConsumerState<_PersonsTabBody> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final personsAsync = ref.watch(personsProvider);
    final partnerTagsAsync = ref.watch(partnerTagsProvider);

    return personsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
      data: (allPersons) {
        final partnerPersonId = partnerTagsAsync.value?.firstOrNull?.personId;

        final partner = partnerPersonId != null
            ? allPersons.where((p) => p.id == partnerPersonId).firstOrNull
            : null;

        var others = allPersons.where((p) => p.id != partnerPersonId).toList();

        final query = _searchQuery.toLowerCase().trim();
        Person? visiblePartner = partner;
        if (query.isNotEmpty) {
          if (visiblePartner != null &&
              !visiblePartner.name.toLowerCase().contains(query)) {
            visiblePartner = null;
          }
          others = others
              .where((p) => p.name.toLowerCase().contains(query))
              .toList();
        }

        if (!_sortAsc) others = others.reversed.toList();

        final hasResults = visiblePartner != null || others.isNotEmpty;

        return Column(
          children: [
            // Search + sort bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.searchByNameHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _searchCtrl.clear,
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _sortAsc ? 'Z → A' : 'A → Z',
                    icon: Icon(
                      _sortAsc ? Icons.sort_by_alpha : Icons.sort,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _sortAsc = !_sortAsc),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: !hasResults && allPersons.isEmpty
                  ? _EmptyState(onAdd: () => context.push('/people/new'))
                  : !hasResults
                      ? Center(
                          child: Text(
                            l10n.searchByNameHint,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount:
                              (visiblePartner != null ? 1 : 0) + others.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            if (visiblePartner != null && i == 0) {
                              return _PartnerCard(person: visiblePartner);
                            }
                            final idx = i - (visiblePartner != null ? 1 : 0);
                            return _PersonCard(person: others[idx]);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Partner card ──────────────────────────────────────────────────────────────

class _PartnerCard extends ConsumerWidget {
  final Person person;
  const _PartnerCard({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/people/${person.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF0F5), _partnerBg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _partnerBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _partnerBorder.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              PersonAvatar(
                name: person.name,
                imagePath: person.avatarPath,
                radius: 24,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite,
                      size: 12, color: _partnerAccent),
                ),
              ),
            ],
          ),
          title: Text(
            person.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF880E4F),
                ),
          ),
          subtitle: Text(
            '伴侣',
            style: const TextStyle(
              fontSize: 12,
              color: _partnerAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing:
              const Icon(Icons.chevron_right, color: _partnerBorder),
        ),
      ),
    );
  }
}

// ── Regular person card — fake-glass effect ───────────────────────────────────
//
// Uses a semi-transparent themed tint (glassTintColor) + thin white-ish border
// so the gradient/decoration layer shows through without any BackdropFilter
// cost. BackdropFilter over an animated background in a scrolling list would
// composite+blur every visible card on every animation frame, causing jank.

class _PersonCard extends ConsumerWidget {
  final Person person;
  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(personTagsProvider(person.id));
    final glassTint =
        Theme.of(context).extension<AppThemeExtension>()?.glassTintColor ??
        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: glassTint,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: PersonAvatar(
              name: person.name,
              imagePath: person.avatarPath,
              radius: 24,
            ),
            title: Text(person.name,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: tagsAsync.when(
              data: (tags) => tags.isEmpty
                  ? null
                  : Wrap(
                      spacing: 4,
                      children: tags
                          .map((t) => Chip(
                                label: Text(t.tagLabel,
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
              loading: () => null,
              error: (_, _) => null,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/people/${person.id}'),
          ),
        ),
      ),
    );
  }
}

// ── Groups tab ────────────────────────────────────────────────────────────────

class _GroupsTabBody extends ConsumerWidget {
  const _GroupsTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(groupsProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
      data: (groups) => groups.isEmpty
          ? _GroupEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _GroupCard(group: groups[i]),
            ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final PersonGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membersAsync = ref.watch(groupMembersProvider(group.id));

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.secondaryAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.group_outlined,
              color: AppColors.secondaryAccent, size: 26),
        ),
        title: Text(group.name,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: membersAsync.when(
          data: (members) => Text(
            '${members.length} ${l10n.groupMembers}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          loading: () => null,
          error: (_, _) => null,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/people/groups/${group.id}'),
      ),
    );
  }
}

class _GroupEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64, color: AppColors.warmBeige),
          const SizedBox(height: 16),
          Text(l10n.groupsEmpty,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n.groupsEmptyHint,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Empty state (contacts) ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.warmBeige),
          const SizedBox(height: 16),
          Text(l10n.personsEmpty,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n.personsEmptyHint,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF8A7060))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.personsAdd),
          ),
        ],
      ),
    );
  }
}
