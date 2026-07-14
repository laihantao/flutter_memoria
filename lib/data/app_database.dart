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
    MemoryBudgets,
    ItineraryItems,
    ItineraryDays,
    ItineraryStops,
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
  int get schemaVersion => 12;

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
            if (v == 11) {
              // Data-only cleanup after the standalone expenses module was
              // removed. No schema change — the Wallets/TransactionTags tables
              // and Transactions.walletId column stay in place, dormant.
              //
              // 1. Purge orphan (non-memory) transactions: they were created by
              //    the deleted standalone ledger and are now unreachable in the
              //    UI. Delete dependent rows first to stay FK-safe.
              final orphanIds = await (select(transactions)
                    ..where((t) => t.memoryId.isNull()))
                  .get()
                  .then((rows) => rows.map((t) => t.id).toList());
              if (orphanIds.isNotEmpty) {
                await (delete(transactionSplits)
                      ..where((t) => t.transactionId.isIn(orphanIds)))
                    .go();
                await (delete(transactionTags)
                      ..where((t) => t.transactionId.isIn(orphanIds)))
                    .go();
                await (delete(transactions)
                      ..where((t) => t.memoryId.isNull()))
                    .go();
              }
              // 2. Wallets are gone from the product. Detach any surviving
              //    (memory-linked) transaction from its wallet, then drop all
              //    wallet rows.
              await (update(transactions)
                    ..where((t) => t.walletId.isNotNull()))
                  .write(const TransactionsCompanion(
                      walletId: Value<String?>(null)));
              await delete(wallets).go();
            }
            if (v == 12) {
              // Per-currency budgets + user-sortable categories.
              // Idempotent: dev builds briefly shipped this work under their
              // own schema v10 (before the itinerary branch was merged), so
              // skip when the table already exists.
              final already = (await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='memory_budgets'",
              ).get())
                  .isNotEmpty;
              if (already) continue;
              await m.createTable(memoryBudgets);
              await m.addColumn(categories, categories.sortOrder);

              // Number existing categories in their current order (per type)
              // so the grid keeps looking the same until the user reorders.
              final cats = await select(categories).get();
              final byType = <String, int>{};
              for (final c in cats) {
                final next = byType[c.type] ?? 0;
                await (update(categories)..where((t) => t.id.equals(c.id)))
                    .write(CategoriesCompanion(sortOrder: Value(next)));
                byType[c.type] = next + 1;
              }

              // Migrate the legacy single-number Memories.budget into one
              // MemoryBudgets row. Currency: the explicit budgetCurrency
              // (added in v9) when set, else the memory's dominant transaction
              // currency, falling back to MYR. The old columns stay dormant.
              final budgeted = await (select(memories)
                    ..where((t) => t.budget.isNotNull()))
                  .get();
              for (final mem in budgeted) {
                if (mem.budget == null || mem.budget! <= 0) continue;
                var currency = mem.budgetCurrency ?? 'MYR';
                if (mem.budgetCurrency == null) {
                  final txs = await (select(transactions)
                        ..where((t) => t.memoryId.equals(mem.id)))
                      .get();
                  final counts = <String, int>{};
                  for (final tx in txs) {
                    counts[tx.currencyCode] =
                        (counts[tx.currencyCode] ?? 0) + 1;
                  }
                  var best = 0;
                  counts.forEach((code, n) {
                    if (n > best) {
                      best = n;
                      currency = code;
                    }
                  });
                }
                await into(memoryBudgets).insert(
                  MemoryBudgetsCompanion.insert(
                    id: newId(),
                    memoryId: mem.id,
                    currencyCode: currency,
                    amount: mem.budget!,
                  ),
                );
              }
            }
            if (v == 9) {
              await m.addColumn(memories, memories.budgetCurrency);
            }
            if (v == 10) {
              await m.createTable(itineraryDays);
              await m.createTable(itineraryStops);
              // Migrate existing ItineraryItems → ItineraryDays + ItineraryStops
              final allMems = await select(memories).get();
              for (final mem in allMems) {
                final items = await (select(itineraryItems)
                      ..where((t) => t.memoryId.equals(mem.id))
                      ..orderBy([
                        (t) => OrderingTerm.asc(t.itemDate),
                        (t) => OrderingTerm.asc(t.sortOrder),
                      ]))
                    .get();
                if (items.isEmpty) continue;
                final byDate = <String, List<ItineraryItem>>{};
                for (final item in items) {
                  final k =
                      '${item.itemDate.year}-${item.itemDate.month.toString().padLeft(2, '0')}-${item.itemDate.day.toString().padLeft(2, '0')}';
                  byDate.putIfAbsent(k, () => []).add(item);
                }
                final sortedDates = byDate.keys.toList()..sort();
                for (var i = 0; i < sortedDates.length; i++) {
                  final dayItems = byDate[sortedDates[i]]!;
                  final dayId = newId();
                  await into(itineraryDays).insert(ItineraryDaysCompanion(
                    id: Value(dayId),
                    memoryId: Value(mem.id),
                    dayNumber: Value(i + 1),
                    date: Value(dayItems.first.itemDate),
                  ));
                  for (var j = 0; j < dayItems.length; j++) {
                    final item = dayItems[j];
                    await into(itineraryStops).insert(ItineraryStopsCompanion(
                      id: Value(newId()),
                      dayId: Value(dayId),
                      orderIndex: Value(j),
                      activityText: Value(item.title),
                      timeLabel: Value(item.itemTime),
                    ));
                  }
                }
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

    // Seed order == display order (categories are shown by sortOrder).
    for (final (i, (name, icon)) in expenseCategories.indexed) {
      await into(categories).insert(CategoriesCompanion.insert(
        id: newId(),
        name: name,
        type: 'expense',
        iconName: Value(icon),
        isDefault: const Value(true),
        sortOrder: Value(i),
      ));
    }
    for (final (i, (name, icon)) in incomeCategories.indexed) {
      await into(categories).insert(CategoriesCompanion.insert(
        id: newId(),
        name: name,
        type: 'income',
        iconName: Value(icon),
        isDefault: const Value(true),
        sortOrder: Value(i),
      ));
    }
  }
}
