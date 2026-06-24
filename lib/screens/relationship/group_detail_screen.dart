import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_ops.dart';
import '../../widgets/person_avatar.dart';
import '../../widgets/theme_background.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
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

  Future<void> _showEditDialog(PersonGroup group) async {
    final l10n = context.l10n;
    String inputName = group.name;
    String inputDesc = group.description ?? '';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.groupNameLabel.replaceAll(' *', '')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                initialValue: group.name,
                decoration: InputDecoration(labelText: l10n.groupNameLabel),
                onChanged: (v) => inputName = v,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.groupNameRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: group.description ?? '',
                decoration:
                    InputDecoration(labelText: l10n.groupDescriptionLabel),
                onChanged: (v) => inputDesc = v,
                maxLines: 3,
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
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final desc = inputDesc.trim();
      await ref.read(personNotifierProvider.notifier).saveGroup(
            existingId: widget.groupId,
            name: inputName.trim(),
            description: desc.isEmpty ? null : desc,
          );
    }
  }

  Future<void> _showAddMemberSheet(
      List<Person> allPersons, List<Person> currentMembers) async {
    final currentIds = currentMembers.map((p) => p.id).toSet();
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MemberPickerSheet(
        groupId: widget.groupId,
        allPersons: allPersons,
        currentMemberIds: currentIds,
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    await ref
        .read(personNotifierProvider.notifier)
        .addGroupMediaAsset(
          groupId: widget.groupId,
          file: file,
          type: 'photo',
        );
  }

  Future<void> _confirmDeleteGroup(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(personNotifierProvider.notifier)
          .deleteGroup(widget.groupId);
      if (!context.mounted) return;
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final personsAsync = ref.watch(personsProvider);
    final isGalleryTab = _tabCtrl.index == 1;

    return groupAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(l10n.errorWith('$e')))),
      data: (group) {
        if (group == null) {
          return Scaffold(
              body: Center(child: Text(l10n.groupsEmpty)));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditDialog(group),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _confirmDeleteGroup(context);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.delete,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [
                Tab(text: l10n.memoryTabOverview),
                Tab(text: l10n.memoryTabGallery),
              ],
            ),
          ),
          body: ThemeBackground(
            child: TabBarView(
            controller: _tabCtrl,
            children: [
              _OverviewTab(
                group: group,
                membersAsync: membersAsync,
                allPersons: personsAsync.value ?? [],
                onAddMember: () => _showAddMemberSheet(
                  personsAsync.value ?? [],
                  membersAsync.value ?? [],
                ),
                onRemoveMember: (personId) => ref
                    .read(personNotifierProvider.notifier)
                    .removePersonFromGroup(widget.groupId, personId),
              ),
              _GalleryTab(groupId: widget.groupId),
            ],
          ),
          ),
          floatingActionButton: isGalleryTab
              ? FloatingActionButton(
                  onPressed: _pickPhoto,
                  child:
                      const Icon(Icons.add_photo_alternate_outlined),
                )
              : FloatingActionButton(
                  onPressed: () => _showAddMemberSheet(
                    personsAsync.value ?? [],
                    membersAsync.value ?? [],
                  ),
                  child: const Icon(Icons.person_add_outlined),
                ),
        );
      },
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final PersonGroup group;
  final AsyncValue<List<Person>> membersAsync;
  final List<Person> allPersons;
  final VoidCallback onAddMember;
  final Future<void> Function(String personId) onRemoveMember;

  const _OverviewTab({
    required this.group,
    required this.membersAsync,
    required this.allPersons,
    required this.onAddMember,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description card
          if (group.description != null && group.description!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warmBeige),
              ),
              child: Text(
                group.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Members header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.groupMembers,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.warmBrown)),
              TextButton.icon(
                onPressed: onAddMember,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.groupAddMember),
              ),
            ],
          ),
          const SizedBox(height: 8),
          membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(l10n.errorWith('$e')),
            data: (members) => members.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l10n.groupAddMember,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: members
                        .map((p) => _MemberTile(
                              person: p,
                              onRemove: () => onRemoveMember(p.id),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Person person;
  final VoidCallback onRemove;
  const _MemberTile({required this.person, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: PersonAvatar(
          name: person.name, imagePath: person.avatarPath, radius: 20),
      title: Text(person.name, style: Theme.of(context).textTheme.bodyLarge),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline,
            size: 20, color: AppColors.dustyRose),
        onPressed: onRemove,
      ),
      onTap: () => context.push('/people/${person.id}'),
    );
  }
}

// ── Member picker bottom sheet ────────────────────────────────────────────────

class _MemberPickerSheet extends ConsumerStatefulWidget {
  final String groupId;
  final List<Person> allPersons;
  final Set<String> currentMemberIds;

  const _MemberPickerSheet({
    required this.groupId,
    required this.allPersons,
    required this.currentMemberIds,
  });

  @override
  ConsumerState<_MemberPickerSheet> createState() =>
      _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<_MemberPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.currentMemberIds);
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
            child: Text(l10n.groupAddMember,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: widget.allPersons.map((p) {
                final inGroup = _selected.contains(p.id);
                return CheckboxListTile(
                  value: inGroup,
                  activeColor: AppColors.primary,
                  secondary: PersonAvatar(
                      name: p.name, imagePath: p.avatarPath, radius: 18),
                  title: Text(p.name),
                  onChanged: (v) async {
                    setState(() {
                      if (v == true) {
                        _selected.add(p.id);
                      } else {
                        _selected.remove(p.id);
                      }
                    });
                    final notifier =
                        ref.read(personNotifierProvider.notifier);
                    if (v == true) {
                      await notifier.addPersonToGroup(widget.groupId, p.id);
                    } else {
                      await notifier.removePersonFromGroup(
                          widget.groupId, p.id);
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

// ── Gallery tab ───────────────────────────────────────────────────────────────

class _GalleryTab extends ConsumerWidget {
  final String groupId;
  const _GalleryTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assetsAsync = ref.watch(groupMediaAssetsProvider(groupId));

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
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: assets.length,
              itemBuilder: (_, i) =>
                  _GroupMediaTile(asset: assets[i], groupId: groupId),
            ),
    );
  }
}

class _GroupMediaTile extends ConsumerStatefulWidget {
  final GroupMediaAsset asset;
  final String groupId;
  const _GroupMediaTile({required this.asset, required this.groupId});

  @override
  ConsumerState<_GroupMediaTile> createState() => _GroupMediaTileState();
}

class _GroupMediaTileState extends ConsumerState<_GroupMediaTile> {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isVideo = widget.asset.type == 'video';

    return GestureDetector(
      onLongPress: () async {
        final messenger = ScaffoldMessenger.of(context);
        final del = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.memoryDeletePhoto),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete,
                    style: const TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        if (del == true) {
          try {
            await ref
                .read(personNotifierProvider.notifier)
                .deleteGroupMediaAsset(widget.asset);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.deletedSuccess),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                  SnackBar(content: Text(l10n.errorWith('$e'))));
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
