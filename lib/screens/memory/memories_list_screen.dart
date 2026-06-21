import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/memory_provider.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_ops.dart';
import '../../widgets/person_avatar.dart';

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
      body: memoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
        data: (memories) => memories.isEmpty
            ? _EmptyState(onAdd: () => context.push('/memories/new'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: memories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _MemoryCard(memory: memories[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/memories/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MemoryCard extends ConsumerWidget {
  final Memory memory;
  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dateFmt = DateFormat('d MMM yyyy');
    final dateStr = memory.endDate != null
        ? '${dateFmt.format(memory.startDate)} – ${dateFmt.format(memory.endDate!)}'
        : dateFmt.format(memory.startDate);

    // First photo from gallery as cover (null when no assets exist).
    final assetsAsync = ref.watch(mediaAssetsProvider(memory.id));
    final assets = assetsAsync.value;
    final String? coverPath = (assets == null || assets.isEmpty)
        ? null
        : assets
            .firstWhere((a) => a.type == 'photo', orElse: () => assets.first)
            .filePath;

    // Participants.
    final participantsAsync = ref.watch(memoryParticipantsProvider(memory.id));

    return GestureDetector(
      onTap: () => context.push('/memories/${memory.id}'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(filePath: coverPath),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.memoryTypeName(memory.type).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (memory.locationName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            memory.locationName!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(memory.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(dateStr,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.warmBrown)),
                  // Participants row
                  participantsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (participants) {
                      if (participants.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ParticipantAvatarRow(
                            personIds:
                                participants.map((p) => p.personId).toList()),
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

// ── Participant avatar row ────────────────────────────────────────────────────

class _ParticipantAvatarRow extends ConsumerWidget {
  final List<String> personIds;
  const _ParticipantAvatarRow({required this.personIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const maxShow = 5;
    final shown = personIds.take(maxShow).toList();
    final extra = personIds.length - shown.length;

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
              color: AppColors.warmBeige,
            ),
            child: Center(
              child: Text('+$extra',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warmBrown)),
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

// ── Cover image ───────────────────────────────────────────────────────────────

class _CoverImage extends StatefulWidget {
  final String? filePath;
  const _CoverImage({this.filePath});

  @override
  State<_CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<_CoverImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CoverImage old) {
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
    if (_bytes != null) {
      return Container(
        height: 180,
        width: double.infinity,
        color: AppColors.warmBeige,
        child: Image.memory(_bytes!, fit: BoxFit.contain),
      );
    }
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.warmBeige,
      child: const Center(
        child: Icon(Icons.photo_outlined, size: 48, color: AppColors.warmBrown),
      ),
    );
  }
}

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
          Icon(Icons.photo_album_outlined,
              size: 64, color: AppColors.warmBeige),
          const SizedBox(height: 16),
          Text(l10n.memoriesEmpty,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n.memoriesEmptyHint,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF8A7060))),
          const SizedBox(height: 24),
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
