import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../utils/file_ops.dart';
import 'database_provider.dart';

const _uuid = Uuid();

// ── Watches ───────────────────────────────────────────────────────────────────

final memoriesProvider = StreamProvider<List<Memory>>((ref) {
  return ref.watch(databaseProvider).memoryDao.watchAllMemories();
});

final memoryProvider =
    StreamProvider.family<Memory?, String>((ref, id) {
  return ref.watch(databaseProvider).memoryDao.watchMemory(id);
});

final memoryParticipantsProvider =
    StreamProvider.family<List<MemoryParticipant>, String>((ref, memoryId) {
  return ref.watch(databaseProvider).memoryDao.watchParticipants(memoryId);
});

final itineraryProvider =
    StreamProvider.family<List<ItineraryItem>, String>((ref, memoryId) {
  return ref.watch(databaseProvider).memoryDao.watchItinerary(memoryId);
});

final mediaAssetsProvider =
    StreamProvider.family<List<MediaAsset>, String>((ref, memoryId) {
  return ref.watch(databaseProvider).memoryDao.watchMediaAssets(memoryId);
});

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(databaseProvider).memoryDao.watchAllTags();
});

final timeCategoriesProvider = StreamProvider<List<TimeCategory>>((ref) {
  return ref.watch(databaseProvider).memoryDao.watchAllTimeCategories();
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class MemoryNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<String> saveMemory({
    String? existingId,
    required String title,
    required String type,
    String? description,
    String? coverMediaPath,
    required DateTime startDate,
    DateTime? endDate,
    String? locationName,
    List<String> participantIds = const [],
  }) async {
    final id = existingId ?? _uuid.v4();
    final now = DateTime.now();

    await _db.memoryDao.upsertMemory(MemoriesCompanion(
      id: Value(id),
      title: Value(title),
      type: Value(type),
      description: Value(description),
      coverMediaPath: Value(coverMediaPath),
      startDate: Value(startDate),
      endDate: Value(endDate),
      locationName: Value(locationName),
      createdAt: existingId == null ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    ));

    await _db.memoryDao.clearParticipants(id);
    for (final pid in participantIds) {
      await _db.memoryDao.addParticipant(MemoryParticipantsCompanion(
        id: Value(_uuid.v4()),
        memoryId: Value(id),
        personId: Value(pid),
      ));
    }

    return id;
  }

  Future<void> deleteMemory(String id) async {
    final assets = await _db.memoryDao.getMediaAssets(id);
    for (final asset in assets) {
      await deleteAppDocFile(asset.filePath);
      if (asset.thumbnailPath != null) {
        await deleteAppDocFile(asset.thumbnailPath!);
      }
    }
    await _db.memoryDao.deleteMemory(id);
  }

  Future<void> addItineraryItem({
    required String memoryId,
    required DateTime itemDate,
    String? itemTime,
    required String title,
    String? locationName,
    String? notes,
    int sortOrder = 0,
  }) async {
    await _db.memoryDao.upsertItineraryItem(ItineraryItemsCompanion(
      id: Value(_uuid.v4()),
      memoryId: Value(memoryId),
      itemDate: Value(itemDate),
      itemTime: Value(itemTime),
      title: Value(title),
      locationName: Value(locationName),
      notes: Value(notes),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> updateItineraryItem(ItineraryItem item) async {
    await _db.memoryDao.upsertItineraryItem(ItineraryItemsCompanion(
      id: Value(item.id),
      memoryId: Value(item.memoryId),
      itemDate: Value(item.itemDate),
      itemTime: Value(item.itemTime),
      title: Value(item.title),
      locationName: Value(item.locationName),
      notes: Value(item.notes),
      sortOrder: Value(item.sortOrder),
    ));
  }

  Future<void> deleteItineraryItem(String id) async {
    await _db.memoryDao.deleteItineraryItem(id);
  }

  Future<void> addMediaAsset({
    required String memoryId,
    required XFile file,
    required String type,
    String? caption,
    DateTime? takenAt,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final bytes = await file.readAsBytes();

    final String filePath;
    if (kIsWeb) {
      // Web has no writable file system — store bytes as a data URI in DB.
      filePath = 'data:image;base64,${base64Encode(bytes)}';
    } else {
      final ext = p.extension(file.name.isNotEmpty ? file.name : file.path);
      filePath = 'media/memories/$memoryId/$id$ext';
      await writeAppDocFileBytes(filePath, bytes);
    }

    await _db.memoryDao.upsertMediaAsset(MediaAssetsCompanion(
      id: Value(id),
      memoryId: Value(memoryId),
      type: Value(type),
      filePath: Value(filePath),
      caption: Value(caption),
      takenAt: Value(takenAt),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteMediaAsset(MediaAsset asset) async {
    await deleteAppDocFile(asset.filePath);
    if (asset.thumbnailPath != null) {
      await deleteAppDocFile(asset.thumbnailPath!);
    }
    await _db.memoryDao.deleteMediaAsset(asset.id);
  }

  // ── Time category CRUD ────────────────────────────────────────────────────────

  Future<TimeCategory> createTimeCategory(String name) async {
    final trimmed = name.trim();
    final existing = await _db.memoryDao.getTimeCategoryByName(trimmed);
    if (existing != null) return existing;

    final all = await _db.memoryDao.watchAllTimeCategories().first;
    final nextOrder = all.isEmpty
        ? 0
        : all.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final id = _uuid.v4();
    await _db.memoryDao.upsertTimeCategory(TimeCategoriesCompanion(
      id: Value(id),
      name: Value(trimmed),
      isDefault: const Value(false),
      sortOrder: Value(nextOrder),
    ));
    return (await _db.memoryDao.getTimeCategoryById(id))!;
  }

  Future<void> renameTimeCategory(String id, String newName) async {
    final cat = await _db.memoryDao.getTimeCategoryById(id);
    if (cat == null) return;
    await _db.memoryDao.upsertTimeCategory(TimeCategoriesCompanion(
      id: Value(id),
      name: Value(newName.trim()),
      isDefault: Value(cat.isDefault),
      sortOrder: Value(cat.sortOrder),
    ));
    await _db.memoryDao.migrateMemoriesType(cat.name, newName.trim());
  }

  Future<int> getTimeCategoryRecordCount(String id) async {
    final cat = await _db.memoryDao.getTimeCategoryById(id);
    if (cat == null) return 0;
    return _db.memoryDao.countMemoriesWithType(cat.name);
  }

  Future<void> deleteTimeCategoryById(String id) async {
    final cat = await _db.memoryDao.getTimeCategoryById(id);
    if (cat == null) return;
    if (cat.name != '日常') {
      await _db.memoryDao.migrateMemoriesType(cat.name, '日常');
    }
    await _db.memoryDao.deleteTimeCategoryById(id);
  }

  Future<void> reorderTimeCategories(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final cat = await _db.memoryDao.getTimeCategoryById(orderedIds[i]);
      if (cat != null) {
        await _db.memoryDao.upsertTimeCategory(TimeCategoriesCompanion(
          id: Value(cat.id),
          name: Value(cat.name),
          isDefault: Value(cat.isDefault),
          sortOrder: Value(i),
        ));
      }
    }
  }

  Future<String> createOrGetTag(String label) async {
    final db = _db;
    final existing = await (db.select(db.tags)
          ..where((t) => t.label.equals(label)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = _uuid.v4();
    await db.memoryDao.upsertTag(TagsCompanion(
      id: Value(id),
      label: Value(label),
    ));
    return id;
  }
}

final memoryNotifierProvider =
    AsyncNotifierProvider<MemoryNotifier, void>(MemoryNotifier.new);
