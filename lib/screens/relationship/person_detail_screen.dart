import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/copyable_field.dart';
import '../../widgets/person_avatar.dart';
import '../../widgets/timeline_note.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const PersonDetailScreen({super.key, required this.id});

  @override
  ConsumerState<PersonDetailScreen> createState() =>
      _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  final _remarkCtrl = TextEditingController();

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _addRemark() async {
    final text = _remarkCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ref
          .read(personNotifierProvider.notifier)
          .addRemark(widget.id, text);
      if (mounted) {
        _remarkCtrl.clear();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final personAsync = ref.watch(personProvider(widget.id));
    final phonesAsync = ref.watch(phonesProvider(widget.id));
    final addressesAsync = ref.watch(addressesProvider(widget.id));
    final tagsAsync = ref.watch(personTagsProvider(widget.id));
    final remarksAsync = ref.watch(remarksProvider(widget.id));

    return personAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(l10n.errorWith('$e')))),
      data: (person) {
        if (person == null) {
          return Scaffold(
              body: Center(child: Text(l10n.personNotFound)));
        }

        final hasPartnerTag = tagsAsync.when(
          data: (tags) => tags.any((t) =>
              t.tagLabel == '伴侣' ||
              t.tagLabel.toLowerCase() == 'partner'),
          loading: () => false,
          error: (_, _) => false,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(person.name),
            actions: [
              if (hasPartnerTag)
                IconButton(
                  icon: const Icon(Icons.favorite_outline),
                  tooltip: l10n.personPartnerTooltip,
                  onPressed: () =>
                      context.push('/people/${widget.id}/partner'),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/people/${widget.id}/edit'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      PersonAvatar(
                          name: person.name,
                          radius: 48,
                          imagePath: person.avatarPath),
                      const SizedBox(height: 12),
                      Text(person.name,
                          style:
                              Theme.of(context).textTheme.headlineMedium),
                      if (person.birthday != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '🎂 ${DateFormat('d MMM yyyy').format(person.birthday!)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.warmBrown),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tags
                tagsAsync.when(
                  data: (tags) => tags.isEmpty
                      ? const SizedBox()
                      : Wrap(
                          spacing: 8,
                          children: tags
                              .map((t) => Chip(label: Text(t.tagLabel)))
                              .toList(),
                        ),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
                const SizedBox(height: 16),
                // Phones
                phonesAsync.when(
                  data: (phones) => phones.isEmpty
                      ? const SizedBox()
                      : _Section(
                          title: l10n.personPhoneNumbers,
                          children: phones
                              .map((p) => CopyableField(
                                    label: p.label,
                                    value: p.phoneNumber,
                                    icon: Icons.phone_outlined,
                                  ))
                              .toList(),
                        ),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
                // Addresses
                addressesAsync.when(
                  data: (addresses) => addresses.isEmpty
                      ? const SizedBox()
                      : _Section(
                          title: l10n.personAddresses,
                          children: addresses
                              .map((a) => CopyableField(
                                    label: a.label,
                                    value: a.address,
                                    icon: Icons.home_outlined,
                                  ))
                              .toList(),
                        ),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
                // Groups
                _GroupsSection(personId: widget.id),
                // Notes
                _Section(
                  title: l10n.personNotes,
                  trailing: null,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _remarkCtrl,
                            decoration: InputDecoration(
                              hintText: l10n.personAddNoteHint,
                              isDense: true,
                            ),
                            maxLines: null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addRemark,
                          icon: const Icon(Icons.send_outlined,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    remarksAsync.when(
                      data: (remarks) => remarks.isEmpty
                          ? Text(l10n.personNoNotes,
                              style: Theme.of(context).textTheme.bodySmall)
                          : Column(
                              children: remarks
                                  .asMap()
                                  .entries
                                  .map((e) => TimelineNote(
                                        content: e.value.content,
                                        createdAt: e.value.createdAt,
                                        isFirst: e.key == 0,
                                        isLast:
                                            e.key == remarks.length - 1,
                                      ))
                                  .toList(),
                            ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) =>
                          Text(l10n.errorWith('$e')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Groups section ────────────────────────────────────────────────────────────

class _GroupsSection extends ConsumerWidget {
  final String personId;
  const _GroupsSection({required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final personGroupsAsync = ref.watch(personGroupDetailsProvider(personId));
    final allGroupsAsync = ref.watch(groupsProvider);

    return _Section(
      title: l10n.groupSection,
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline,
            color: AppColors.primary, size: 20),
        onPressed: () =>
            _showGroupPicker(context, ref, allGroupsAsync.value ?? []),
        tooltip: l10n.groupAddToGroup,
      ),
      children: [
        personGroupsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (groups) => groups.isEmpty
              ? Text('${l10n.groupSection} —',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary))
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: groups
                      .map((g) => ActionChip(
                            label: Text(g.name,
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () =>
                                context.push('/people/groups/${g.id}'),
                            avatar: const Icon(Icons.group_outlined,
                                size: 14),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _showGroupPicker(
    BuildContext context,
    WidgetRef ref,
    List<PersonGroup> allGroups,
  ) async {
    final l10n = context.l10n;

    if (allGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupsEmpty)),
      );
      return;
    }

    final currentGroups = await ref
        .read(databaseProvider)
        .personDao
        .getGroupMemberships(personId);
    final currentGroupIds = currentGroups.map((m) => m.groupId).toSet();

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _GroupPickerSheet(
        personId: personId,
        allGroups: allGroups,
        currentGroupIds: currentGroupIds,
      ),
    );
  }
}

class _GroupPickerSheet extends ConsumerStatefulWidget {
  final String personId;
  final List<PersonGroup> allGroups;
  final Set<String> currentGroupIds;

  const _GroupPickerSheet({
    required this.personId,
    required this.allGroups,
    required this.currentGroupIds,
  });

  @override
  ConsumerState<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends ConsumerState<_GroupPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.currentGroupIds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(l10n.groupAddToGroup,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: widget.allGroups.map((g) {
                final inGroup = _selected.contains(g.id);
                return CheckboxListTile(
                  value: inGroup,
                  title: Text(g.name),
                  activeColor: AppColors.primary,
                  onChanged: (v) async {
                    setState(() {
                      if (v == true) {
                        _selected.add(g.id);
                      } else {
                        _selected.remove(g.id);
                      }
                    });
                    if (v == true) {
                      await ref
                          .read(personNotifierProvider.notifier)
                          .addPersonToGroup(g.id, widget.personId);
                    } else {
                      await ref
                          .read(personNotifierProvider.notifier)
                          .removePersonFromGroup(g.id, widget.personId);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.confirm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _Section({
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.warmBrown)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warmBeige),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
