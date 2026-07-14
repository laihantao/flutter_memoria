import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'memory_dao.g.dart';

@DriftAccessor(tables: [
  Memories,
  MemoryParticipants,
  MemoryLocations,
  ItineraryItems,
  ItineraryDays,
  ItineraryStops,
  MediaAssets,
  Tags,
  TimeCategories,
])
class MemoryDao extends DatabaseAccessor<AppDatabase> with _$MemoryDaoMixin {
  MemoryDao(super.db);

  // ── Memories ──────────────────────────────────────────────────────────────────

  Stream<List<Memory>> watchAllMemories() =>
      (select(memories)
            ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
          .watch();

  Stream<Memory?> watchMemory(String id) =>
      (select(memories)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<Memory?> getMemory(String id) =>
      (select(memories)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertMemory(MemoriesCompanion companion) =>
      into(memories).insertOnConflictUpdate(companion);

  Future<void> deleteMemory(String id) =>
      (delete(memories)..where((t) => t.id.equals(id))).go();

  // ── Participants ──────────────────────────────────────────────────────────────

  Stream<List<MemoryParticipant>> watchParticipants(String memoryId) =>
      (select(memoryParticipants)
            ..where((t) => t.memoryId.equals(memoryId)))
          .watch();

  Future<List<MemoryParticipant>> getParticipants(String memoryId) =>
      (select(memoryParticipants)
            ..where((t) => t.memoryId.equals(memoryId)))
          .get();

  Future<void> addParticipant(MemoryParticipantsCompanion companion) =>
      into(memoryParticipants).insertOnConflictUpdate(companion);

  Future<void> removeParticipant(String memoryId, String personId) =>
      (delete(memoryParticipants)
            ..where((t) =>
                t.memoryId.equals(memoryId) & t.personId.equals(personId)))
          .go();

  Future<void> clearParticipants(String memoryId) =>
      (delete(memoryParticipants)
            ..where((t) => t.memoryId.equals(memoryId)))
          .go();

  // Get memories where a specific person is a participant
  Future<List<String>> getMemoryIdsForPerson(String personId) async {
    final rows = await (select(memoryParticipants)
          ..where((t) => t.personId.equals(personId)))
        .get();
    return rows.map((r) => r.memoryId).toList();
  }

  // ── Locations ─────────────────────────────────────────────────────────────────

  Stream<List<MemoryLocation>> watchLocations(String memoryId) =>
      (select(memoryLocations)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<MemoryLocation>> getLocations(String memoryId) =>
      (select(memoryLocations)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<void> upsertLocation(MemoryLocationsCompanion companion) =>
      into(memoryLocations).insertOnConflictUpdate(companion);

  Future<void> deleteLocation(String id) =>
      (delete(memoryLocations)..where((t) => t.id.equals(id))).go();

  Future<void> clearLocations(String memoryId) =>
      (delete(memoryLocations)..where((t) => t.memoryId.equals(memoryId))).go();

  // ── Itinerary ─────────────────────────────────────────────────────────────────

  Stream<List<ItineraryItem>> watchItinerary(String memoryId) =>
      (select(itineraryItems)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.itemDate),
              (t) => OrderingTerm.asc(t.itemTime),
              (t) => OrderingTerm.asc(t.sortOrder),
            ]))
          .watch();

  Future<void> upsertItineraryItem(ItineraryItemsCompanion companion) =>
      into(itineraryItems).insertOnConflictUpdate(companion);

  Future<void> deleteItineraryItem(String id) =>
      (delete(itineraryItems)..where((t) => t.id.equals(id))).go();

  Future<void> clearItineraryItems(String memoryId) =>
      (delete(itineraryItems)..where((t) => t.memoryId.equals(memoryId))).go();

  // ── Itinerary Days ────────────────────────────────────────────────────────────

  Stream<List<ItineraryDay>> watchItineraryDays(String memoryId) =>
      (select(itineraryDays)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
          .watch();

  Future<List<ItineraryDay>> getItineraryDays(String memoryId) =>
      (select(itineraryDays)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
          .get();

  Future<void> upsertItineraryDay(ItineraryDaysCompanion companion) =>
      into(itineraryDays).insertOnConflictUpdate(companion);

  Future<void> deleteItineraryDay(String id) =>
      (delete(itineraryDays)..where((t) => t.id.equals(id))).go();

  Future<void> clearItineraryDays(String memoryId) =>
      (delete(itineraryDays)..where((t) => t.memoryId.equals(memoryId))).go();

  // ── Itinerary Stops ───────────────────────────────────────────────────────────

  Stream<List<ItineraryStop>> watchItineraryStops(String dayId) =>
      (select(itineraryStops)
            ..where((t) => t.dayId.equals(dayId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Stream<List<ItineraryStop>> watchAllItineraryStopsForMemory(String memoryId) =>
      (select(itineraryStops).join([
        innerJoin(
            itineraryDays, itineraryDays.id.equalsExp(itineraryStops.dayId)),
      ])
            ..where(itineraryDays.memoryId.equals(memoryId))
            ..orderBy([
              OrderingTerm.asc(itineraryDays.dayNumber),
              OrderingTerm.asc(itineraryStops.orderIndex),
            ]))
          .watch()
          .map((rows) =>
              rows.map((r) => r.readTable(itineraryStops)).toList());

  Future<List<ItineraryStop>> getItineraryStops(String dayId) =>
      (select(itineraryStops)
            ..where((t) => t.dayId.equals(dayId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<void> upsertItineraryStop(ItineraryStopsCompanion companion) =>
      into(itineraryStops).insertOnConflictUpdate(companion);

  Future<void> deleteItineraryStop(String id) =>
      (delete(itineraryStops)..where((t) => t.id.equals(id))).go();

  Future<void> clearItineraryStops(String dayId) =>
      (delete(itineraryStops)..where((t) => t.dayId.equals(dayId))).go();

  Future<void> clearAllItineraryStopsForMemory(String memoryId) async {
    final days = await getItineraryDays(memoryId);
    for (final day in days) {
      await clearItineraryStops(day.id);
    }
  }

  Future<void> updateItineraryStopOrder(String stopId, int newOrder) =>
      (update(itineraryStops)..where((t) => t.id.equals(stopId)))
          .write(ItineraryStopsCompanion(orderIndex: Value(newOrder)));

  // ── Media Assets ──────────────────────────────────────────────────────────────

  Stream<List<MediaAsset>> watchMediaAssets(String memoryId) =>
      (select(mediaAssets)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<MediaAsset>> getMediaAssets(String memoryId) =>
      (select(mediaAssets)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<void> upsertMediaAsset(MediaAssetsCompanion companion) =>
      into(mediaAssets).insertOnConflictUpdate(companion);

  Future<void> deleteMediaAsset(String id) =>
      (delete(mediaAssets)..where((t) => t.id.equals(id))).go();

  Future<void> clearMediaAssets(String memoryId) =>
      (delete(mediaAssets)..where((t) => t.memoryId.equals(memoryId))).go();

  // ── Tags ──────────────────────────────────────────────────────────────────────

  Stream<List<Tag>> watchAllTags() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.label)])).watch();

  Future<void> upsertTag(TagsCompanion companion) =>
      into(tags).insertOnConflictUpdate(companion);

  Future<void> linkTagToMemory(String tagId, String memoryId) =>
      (update(tags)..where((t) => t.id.equals(tagId)))
          .write(TagsCompanion(memoryId: Value(memoryId)));

  Future<List<Tag>> getTagsByMemoryId(String memoryId) =>
      (select(tags)..where((t) => t.memoryId.equals(memoryId))).get();

  Future<void> clearTagsForMemory(String memoryId) =>
      (delete(tags)..where((t) => t.memoryId.equals(memoryId))).go();

  // ── Time Categories ───────────────────────────────────────────────────────────

  Stream<List<TimeCategory>> watchAllTimeCategories() =>
      (select(timeCategories)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<TimeCategory?> getTimeCategoryById(String id) =>
      (select(timeCategories)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<TimeCategory?> getTimeCategoryByName(String name) =>
      (select(timeCategories)..where((t) => t.name.equals(name)))
          .getSingleOrNull();

  Future<void> upsertTimeCategory(TimeCategoriesCompanion companion) =>
      into(timeCategories).insertOnConflictUpdate(companion);

  Future<void> deleteTimeCategoryById(String id) =>
      (delete(timeCategories)..where((t) => t.id.equals(id))).go();

  Future<int> countMemoriesWithType(String typeName) async {
    final count = countAll();
    final q = selectOnly(memories)
      ..addColumns([count])
      ..where(memories.type.equals(typeName));
    final row = await q.getSingleOrNull();
    return row?.read(count) ?? 0;
  }

  Future<void> migrateMemoriesType(String fromType, String toType) =>
      (update(memories)..where((t) => t.type.equals(fromType)))
          .write(MemoriesCompanion(type: Value(toType)));
}
