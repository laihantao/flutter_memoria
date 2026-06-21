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

final selfPersonStreamProvider = FutureProvider<Person?>((ref) {
  return ref.watch(databaseProvider).personDao.getSelfPerson();
});

final personsProvider = StreamProvider<List<Person>>((ref) {
  return ref.watch(databaseProvider).personDao.watchAllPersons();
});

final personProvider =
    StreamProvider.family<Person?, String>((ref, id) {
  return ref.watch(databaseProvider).personDao.watchPerson(id);
});

final phonesProvider =
    StreamProvider.family<List<PersonPhone>, String>((ref, personId) {
  return ref.watch(databaseProvider).personDao.watchPhones(personId);
});

final addressesProvider =
    StreamProvider.family<List<PersonAddressesData>, String>((ref, personId) {
  return ref.watch(databaseProvider).personDao.watchAddresses(personId);
});

final personTagsProvider =
    StreamProvider.family<List<PersonTag>, String>((ref, personId) {
  return ref.watch(databaseProvider).personDao.watchTags(personId);
});

final remarksProvider =
    StreamProvider.family<List<PersonRemark>, String>((ref, personId) {
  return ref.watch(databaseProvider).personDao.watchRemarks(personId);
});

final partnerExtensionProvider =
    StreamProvider.family<PartnerExtension?, String>((ref, personId) {
  return ref.watch(databaseProvider).personDao.watchPartnerExtension(personId);
});

final anniversariesProvider =
    StreamProvider.family<List<PartnerAnniversary>, String>(
        (ref, partnerExtId) {
  return ref
      .watch(databaseProvider)
      .personDao
      .watchAnniversaries(partnerExtId);
});

final wishlistProvider =
    StreamProvider.family<List<PartnerWishlistItem>, String>(
        (ref, partnerExtId) {
  return ref.watch(databaseProvider).personDao.watchWishlist(partnerExtId);
});

final partnerTagsProvider = StreamProvider<List<PersonTag>>((ref) {
  return ref.watch(databaseProvider).personDao.watchPartnerTags();
});

final groupsProvider = StreamProvider<List<PersonGroup>>((ref) {
  return ref.watch(databaseProvider).personDao.watchAllGroups();
});

final groupProvider =
    StreamProvider.family<PersonGroup?, String>((ref, groupId) {
  return ref.watch(databaseProvider).personDao.watchGroup(groupId);
});

final personGroupDetailsProvider =
    StreamProvider.family<List<PersonGroup>, String>((ref, personId) {
  return ref.watch(databaseProvider).personDao.watchPersonGroupDetails(personId);
});

final groupMembersProvider =
    StreamProvider.family<List<Person>, String>((ref, groupId) {
  return ref
      .watch(databaseProvider)
      .personDao
      .watchGroupMemberDetails(groupId);
});

final groupMediaAssetsProvider =
    StreamProvider.family<List<GroupMediaAsset>, String>((ref, groupId) {
  return ref.watch(databaseProvider).personDao.watchGroupMediaAssets(groupId);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class PersonNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<String> savePerson({
    String? existingId,
    required String name,
    XFile? avatarFile,
    DateTime? birthday,
    bool isSelf = false,
    List<({String label, String phone, bool isPrimary})> phones = const [],
    List<({String label, String address, bool isPrimary})> addresses = const [],
    List<String> tagLabels = const [],
  }) async {
    final id = existingId ?? _uuid.v4();

    String? avatarPath;
    bool effectiveIsSelf = isSelf;
    if (existingId != null) {
      final existing =
          await (_db.select(_db.persons)..where((t) => t.id.equals(id)))
              .getSingleOrNull();
      avatarPath = existing?.avatarPath;
      effectiveIsSelf = existing?.isSelf ?? isSelf;
    }
    if (avatarFile != null) {
      final bytes = await avatarFile.readAsBytes();
      if (kIsWeb) {
        // Web has no writable file system — store bytes as a data URI in DB.
        avatarPath = 'data:image;base64,${base64Encode(bytes)}';
      } else {
        final ext = p.extension(
            avatarFile.name.isNotEmpty ? avatarFile.name : avatarFile.path);
        final destRel = 'avatars/$id/$id$ext';
        await writeAppDocFileBytes(destRel, bytes);
        avatarPath = destRel;
      }
    }

    final now = DateTime.now();
    await _db.personDao.upsertPerson(PersonsCompanion(
      id: Value(id),
      name: Value(name),
      avatarPath: Value(avatarPath),
      birthday: Value(birthday),
      isSelf: Value(effectiveIsSelf),
      createdAt: existingId == null ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    ));

    // Replace phones
    await _db.personDao.deletePhonesForPerson(id);
    for (final ph in phones) {
      await _db.personDao.upsertPhone(PersonPhonesCompanion(
        id: Value(_uuid.v4()),
        personId: Value(id),
        label: Value(ph.label),
        phoneNumber: Value(ph.phone),
        isPrimary: Value(ph.isPrimary),
      ));
    }

    // Replace addresses
    await _db.personDao.deleteAddressesForPerson(id);
    for (final addr in addresses) {
      await _db.personDao.upsertAddress(PersonAddressesCompanion(
        id: Value(_uuid.v4()),
        personId: Value(id),
        label: Value(addr.label),
        address: Value(addr.address),
        isPrimary: Value(addr.isPrimary),
      ));
    }

    // Replace tags
    await _db.personDao.deleteTagsForPerson(id);
    for (final label in tagLabels) {
      await _db.personDao.upsertTag(PersonTagsCompanion(
        id: Value(_uuid.v4()),
        personId: Value(id),
        tagLabel: Value(label),
      ));
    }

    return id;
  }

  Future<void> addRemark(String personId, String content) async {
    await _db.personDao.insertRemark(PersonRemarksCompanion(
      id: Value(_uuid.v4()),
      personId: Value(personId),
      content: Value(content),
    ));
  }

  Future<void> deletePerson(String id) async {
    await _db.personDao.deletePerson(id);
  }

  Future<void> ensurePartnerExtension(String personId) async {
    final existing = await _db.personDao.getPartnerExtension(personId);
    if (existing == null) {
      await _db.personDao.upsertPartnerExtension(PartnerExtensionsCompanion(
        id: Value(_uuid.v4()),
        personId: Value(personId),
      ));
    }
  }

  Future<void> addAnniversary(
      String partnerExtId, String label, DateTime date) async {
    await _db.personDao.upsertAnniversary(PartnerAnniversariesCompanion(
      id: Value(_uuid.v4()),
      partnerExtensionId: Value(partnerExtId),
      label: Value(label),
      date: Value(date),
    ));
  }

  Future<void> deleteAnniversary(String id) async {
    await _db.personDao.deleteAnniversary(id);
  }

  Future<void> addWishlistItem(String partnerExtId, String content) async {
    await _db.personDao.upsertWishlistItem(PartnerWishlistItemsCompanion(
      id: Value(_uuid.v4()),
      partnerExtensionId: Value(partnerExtId),
      content: Value(content),
    ));
  }

  Future<void> toggleWishlistItem(PartnerWishlistItem item) async {
    await _db.personDao.upsertWishlistItem(PartnerWishlistItemsCompanion(
      id: Value(item.id),
      partnerExtensionId: Value(item.partnerExtensionId),
      content: Value(item.content),
      isFulfilled: Value(!item.isFulfilled),
    ));
  }

  Future<void> deleteWishlistItem(String id) async {
    await _db.personDao.deleteWishlistItem(id);
  }

  // ── Groups ────────────────────────────────────────────────────────────────────

  Future<String> saveGroup({
    String? existingId,
    required String name,
    String? description,
  }) async {
    final id = existingId ?? _uuid.v4();
    await _db.personDao.upsertGroup(PersonGroupsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
    ));
    return id;
  }

  Future<void> deleteGroup(String groupId) async {
    final assets = await _db.personDao.getGroupMediaAssets(groupId);
    for (final asset in assets) {
      await deleteAppDocFile(asset.filePath);
      if (asset.thumbnailPath != null) {
        await deleteAppDocFile(asset.thumbnailPath!);
      }
    }
    await _db.personDao.deleteGroup(groupId);
  }

  Future<void> addPersonToGroup(String groupId, String personId) async {
    await _db.personDao.addGroupMember(PersonGroupMembersCompanion(
      id: Value(_uuid.v4()),
      groupId: Value(groupId),
      personId: Value(personId),
    ));
  }

  Future<void> removePersonFromGroup(String groupId, String personId) async {
    await _db.personDao.removeGroupMember(groupId, personId);
  }

  Future<void> addGroupMediaAsset({
    required String groupId,
    required XFile file,
    required String type,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final bytes = await file.readAsBytes();

    final String filePath;
    if (kIsWeb) {
      filePath = 'data:image;base64,${base64Encode(bytes)}';
    } else {
      final ext = p.extension(file.name.isNotEmpty ? file.name : file.path);
      filePath = 'media/groups/$groupId/$id$ext';
      await writeAppDocFileBytes(filePath, bytes);
    }

    await _db.personDao.upsertGroupMediaAsset(GroupMediaAssetsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      type: Value(type),
      filePath: Value(filePath),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteGroupMediaAsset(GroupMediaAsset asset) async {
    await deleteAppDocFile(asset.filePath);
    if (asset.thumbnailPath != null) {
      await deleteAppDocFile(asset.thumbnailPath!);
    }
    await _db.personDao.deleteGroupMediaAsset(asset.id);
  }
}

final personNotifierProvider =
    AsyncNotifierProvider<PersonNotifier, void>(PersonNotifier.new);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Resolves a relative avatar path to its absolute path on disk.
/// Returns null on web or when path is null.
Future<String?> resolveAvatarAbsPath(String? relPath) async {
  if (relPath == null) return null;
  final docs = await getDocsPath();
  if (docs.isEmpty) return null;
  return joinPath(docs, relPath);
}
