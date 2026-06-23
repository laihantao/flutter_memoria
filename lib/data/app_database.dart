import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';
import 'daos/person_dao.dart';
import 'daos/memory_dao.dart';
import 'daos/expense_dao.dart';
import 'connection/connection.dart'
    if (dart.library.io) 'connection/native.dart'
    if (dart.library.html) 'connection/web.dart';

part 'app_database.g.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

@DriftDatabase(
  tables: [
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
    Memories,
    MemoryParticipants,
    MemoryLocations,
    ItineraryItems,
    MediaAssets,
    Wallets,
    Categories,
    Transactions,
    TransactionSplits,
    Tags,
    TransactionTags,
    TimeCategories,
  ],
  daos: [PersonDao, MemoryDao, ExpenseDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openAppDatabaseConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
          await _seedTimeCategories();
        },
        onUpgrade: (m, from, to) async {
          for (var v = from + 1; v <= to; v++) {
            if (v == 2) {
              // Rebuild transactions: walletId/payerPersonId now nullable, add memoryId
              await m.alterTable(TableMigration(transactions));
              // Replace default categories with emoji-based ones
              await (delete(categories)
                    ..where((t) => t.isDefault.equals(true)))
                  .go();
              await _seedCategories();
            }
            if (v == 3) {
              await m.createTable(personGroups);
              await m.createTable(personGroupMembers);
              await m.createTable(groupMediaAssets);
            }
            if (v == 5) {
              // Replace default categories with new order (adds 约会, moves 日常 to 2nd)
              await (delete(timeCategories)
                    ..where((t) => t.isDefault.equals(true)))
                  .go();
              await _seedTimeCategories();
            }
            if (v == 6) {
              await m.createTable(memoryLocations);
              // Seed from existing Memories.locationName
              final existing = await (select(memories)
                    ..where((t) => t.locationName.isNotNull()))
                  .get();
              for (final mem in existing) {
                if (mem.locationName != null) {
                  await into(memoryLocations).insert(
                    MemoryLocationsCompanion.insert(
                      id: newId(),
                      memoryId: mem.id,
                      name: mem.locationName!,
                    ),
                  );
                }
              }
            }
            if (v == 7) {
              await m.addColumn(memories, memories.budget);
            }
            if (v == 8) {
              // Idempotent: add budget column only if not already present.
              // Handles devices where v7 migration ran but the column was not
              // persisted (e.g., schema version was already set to 7 on device
              // before this migration was written).
              final cols = await customSelect(
                'PRAGMA table_info("memories")',
              ).get();
              final hasBudget =
                  cols.any((r) => r.read<String>('name') == 'budget');
              if (!hasBudget) {
                await customStatement(
                  'ALTER TABLE "memories" ADD COLUMN "budget" REAL',
                );
              }
            }
            if (v == 4) {
              await m.createTable(timeCategories);
              await _seedTimeCategories();
              // Migrate old English type codes to Chinese category names
              const typeMap = [
                ('trip', '旅行'),
                ('gathering', '聚会'),
                ('memory', '日常'),
                ('event', '活动'),
                ('custom', '日常'),
              ];
              for (final (from, to) in typeMap) {
                await (update(memories)
                      ..where((t) => t.type.equals(from)))
                    .write(MemoriesCompanion(type: Value(to)));
              }
            }
          }
        },
      );

  Future<void> _seedTimeCategories() async {
    const defaults = [
      ('约会', 0),
      ('日常', 1),
      ('旅行', 2),
      ('聚会', 3),
      ('纪念日', 4),
      ('美食', 5),
      ('活动', 6),
      ('成就', 7),
    ];
    for (final (name, order) in defaults) {
      await into(timeCategories).insert(TimeCategoriesCompanion.insert(
        id: newId(),
        name: name,
        isDefault: const Value(true),
        sortOrder: Value(order),
      ));
    }
  }

  Future<void> _seedCategories() async {
    const expenseCategories = [
      ('餐饮', '🍜'),
      ('购物', '🛍️'),
      ('日用', '🧻'),
      ('交通', '🚌'),
      ('蔬菜', '🥦'),
      ('水果', '🍎'),
      ('零食', '🧁'),
      ('运动', '🏃'),
      ('娱乐', '🎮'),
      ('通讯', '📱'),
      ('服饰', '👕'),
      ('美容', '💄'),
      ('住房', '🏠'),
      ('家庭', '❤️'),
      ('社交', '👥'),
      ('旅行', '✈️'),
    ];
    const incomeCategories = [
      ('工资', '💼'),
      ('红包', '🧧'),
      ('租金', '🏘️'),
      ('礼金', '🎀'),
      ('分红', '📊'),
      ('理财', '📈'),
      ('年终奖', '🎁'),
      ('其它', '📝'),
      ('借入', '↩️'),
      ('收款', '📬'),
    ];

    for (final (name, icon) in expenseCategories) {
      await into(categories).insert(CategoriesCompanion.insert(
        id: newId(),
        name: name,
        type: 'expense',
        iconName: Value(icon),
        isDefault: const Value(true),
      ));
    }
    for (final (name, icon) in incomeCategories) {
      await into(categories).insert(CategoriesCompanion.insert(
        id: newId(),
        name: name,
        type: 'income',
        iconName: Value(icon),
        isDefault: const Value(true),
      ));
    }
  }
}
