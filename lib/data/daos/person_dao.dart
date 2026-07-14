import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'person_dao.g.dart';

@DriftAccessor(tables: [
  Persons,
  PersonPhones,
  PersonAddresses,
  PersonTags,
  PersonRemarks,
  PartnerExtensions,
  PartnerAnniversaries,
  PartnerWishlistItems,
  PersonGroups,
  PersonGroupMembers,
  GroupMediaAssets,
])
class PersonDao extends DatabaseAccessor<AppDatabase> with _$PersonDaoMixin {
  PersonDao(super.db);

  // ── Persons ─────────────────────────────────────────────────────────────────

  Future<Person?> getSelfPerson() =>
      (select(persons)..where((t) => t.isSelf.equals(true)))
          .getSingleOrNull();

  /// Live "Me" — the single onboarding-created [Persons] row with isSelf == true.
  /// This is the app's current-user identity used as default payer, the
  /// never-excludable payer, and the "Me" row/column in split statements.
  Stream<Person?> watchSelfPerson() =>
      (select(persons)..where((t) => t.isSelf.equals(true)))
          .watchSingleOrNull();

  Stream<List<Person>> watchAllPersons() =>
      (select(persons)..where((t) => t.isSelf.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<Person?> watchPerson(String id) =>
      (select(persons)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<void> upsertPerson(PersonsCompanion companion) =>
      into(persons).insertOnConflictUpdate(companion);

  Future<void> deletePerson(String id) =>
      (delete(persons)..where((t) => t.id.equals(id))).go();

  // ── Phones ──────────────────────────────────────────────────────────────────

  Stream<List<PersonPhone>> watchPhones(String personId) =>
      (select(personPhones)
            ..where((t) => t.personId.equals(personId)))
          .watch();

  Future<void> upsertPhone(PersonPhonesCompanion companion) =>
      into(personPhones).insertOnConflictUpdate(companion);

  Future<void> deletePhone(String id) =>
      (delete(personPhones)..where((t) => t.id.equals(id))).go();

  Future<void> deletePhonesForPerson(String personId) =>
      (delete(personPhones)..where((t) => t.personId.equals(personId))).go();

  // ── Addresses ────────────────────────────────────────────────────────────────

  Stream<List<PersonAddressesData>> watchAddresses(String personId) =>
      (select(personAddresses)
            ..where((t) => t.personId.equals(personId)))
          .watch();

  Future<void> upsertAddress(PersonAddressesCompanion companion) =>
      into(personAddresses).insertOnConflictUpdate(companion);

  Future<void> deleteAddress(String id) =>
      (delete(personAddresses)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAddressesForPerson(String personId) =>
      (delete(personAddresses)
            ..where((t) => t.personId.equals(personId)))
          .go();

  // ── Tags ─────────────────────────────────────────────────────────────────────

  Stream<List<PersonTag>> watchTags(String personId) =>
      (select(personTags)..where((t) => t.personId.equals(personId))).watch();

  Future<void> upsertTag(PersonTagsCompanion companion) =>
      into(personTags).insertOnConflictUpdate(companion);

  Future<void> deleteTag(String id) =>
      (delete(personTags)..where((t) => t.id.equals(id))).go();

  Future<void> deleteTagsForPerson(String personId) =>
      (delete(personTags)..where((t) => t.personId.equals(personId))).go();

  Future<List<PersonTag>> getTagsForPerson(String personId) =>
      (select(personTags)..where((t) => t.personId.equals(personId))).get();

  // ── Remarks ──────────────────────────────────────────────────────────────────

  Stream<List<PersonRemark>> watchRemarks(String personId) =>
      (select(personRemarks)
            ..where((t) => t.personId.equals(personId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> insertRemark(PersonRemarksCompanion companion) =>
      into(personRemarks).insert(companion);

  // ── Partner Extensions ───────────────────────────────────────────────────────

  Stream<PartnerExtension?> watchPartnerExtension(String personId) =>
      (select(partnerExtensions)
            ..where((t) => t.personId.equals(personId)))
          .watchSingleOrNull();

  Future<PartnerExtension?> getPartnerExtension(String personId) =>
      (select(partnerExtensions)
            ..where((t) => t.personId.equals(personId)))
          .getSingleOrNull();

  Future<void> upsertPartnerExtension(PartnerExtensionsCompanion companion) =>
      into(partnerExtensions).insertOnConflictUpdate(companion);

  // ── Anniversaries ─────────────────────────────────────────────────────────────

  Stream<List<PartnerAnniversary>> watchAnniversaries(
          String partnerExtensionId) =>
      (select(partnerAnniversaries)
            ..where((t) => t.partnerExtensionId.equals(partnerExtensionId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .watch();

  Future<void> upsertAnniversary(PartnerAnniversariesCompanion companion) =>
      into(partnerAnniversaries).insertOnConflictUpdate(companion);

  Future<void> deleteAnniversary(String id) =>
      (delete(partnerAnniversaries)..where((t) => t.id.equals(id))).go();

  // ── Wishlist ──────────────────────────────────────────────────────────────────

  Stream<List<PartnerWishlistItem>> watchWishlist(
          String partnerExtensionId) =>
      (select(partnerWishlistItems)
            ..where((t) => t.partnerExtensionId.equals(partnerExtensionId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertWishlistItem(PartnerWishlistItemsCompanion companion) =>
      into(partnerWishlistItems).insertOnConflictUpdate(companion);

  Future<void> deleteWishlistItem(String id) =>
      (delete(partnerWishlistItems)..where((t) => t.id.equals(id))).go();

  // ── Partner tag lookup ────────────────────────────────────────────────────────

  Stream<List<PersonTag>> watchPartnerTags() =>
      (select(personTags)
        ..where((t) => t.tagLabel.isIn(['伴侣', 'Partner', 'partner'])))
          .watch();

  // ── Groups ────────────────────────────────────────────────────────────────────

  Stream<List<PersonGroup>> watchAllGroups() =>
      (select(personGroups)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<PersonGroup?> watchGroup(String id) =>
      (select(personGroups)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  Future<void> upsertGroup(PersonGroupsCompanion companion) =>
      into(personGroups).insertOnConflictUpdate(companion);

  Future<void> deleteGroup(String id) =>
      (delete(personGroups)..where((t) => t.id.equals(id))).go();

  // Returns groups that the given person belongs to (with group details).
  Stream<List<PersonGroup>> watchPersonGroupDetails(String personId) {
    final query = select(personGroups).join([
      innerJoin(
        personGroupMembers,
        personGroupMembers.groupId.equalsExp(personGroups.id),
      ),
    ])
      ..where(personGroupMembers.personId.equals(personId))
      ..orderBy([OrderingTerm.asc(personGroups.name)]);
    return query.watch().map(
        (rows) => rows.map((r) => r.readTable(personGroups)).toList());
  }

  // Returns persons who are members of the given group.
  Stream<List<Person>> watchGroupMemberDetails(String groupId) {
    final query = select(persons).join([
      innerJoin(
        personGroupMembers,
        personGroupMembers.personId.equalsExp(persons.id),
      ),
    ])
      ..where(personGroupMembers.groupId.equals(groupId))
      ..orderBy([OrderingTerm.asc(persons.name)]);
    return query.watch().map(
        (rows) => rows.map((r) => r.readTable(persons)).toList());
  }

  Future<void> addGroupMember(PersonGroupMembersCompanion companion) =>
      into(personGroupMembers).insertOnConflictUpdate(companion);

  Future<void> removeGroupMember(String groupId, String personId) =>
      (delete(personGroupMembers)
        ..where((t) =>
            t.groupId.equals(groupId) & t.personId.equals(personId)))
          .go();

  Future<List<PersonGroupMember>> getGroupMemberships(String personId) =>
      (select(personGroupMembers)
        ..where((t) => t.personId.equals(personId)))
          .get();

  // ── Group media assets ────────────────────────────────────────────────────────

  Stream<List<GroupMediaAsset>> watchGroupMediaAssets(String groupId) =>
      (select(groupMediaAssets)
        ..where((t) => t.groupId.equals(groupId))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<GroupMediaAsset>> getGroupMediaAssets(String groupId) =>
      (select(groupMediaAssets)
        ..where((t) => t.groupId.equals(groupId)))
          .get();

  Future<void> upsertGroupMediaAsset(GroupMediaAssetsCompanion companion) =>
      into(groupMediaAssets).insertOnConflictUpdate(companion);

  Future<void> deleteGroupMediaAsset(String id) =>
      (delete(groupMediaAssets)..where((t) => t.id.equals(id))).go();
}
