import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [
  Wallets,
  Categories,
  Transactions,
  TransactionSplits,
  TransactionTags,
  Tags,
  MemoryBudgets,
])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  // ── Wallets ───────────────────────────────────────────────────────────────────

  Stream<List<Wallet>> watchAllWallets() =>
      (select(wallets)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<Wallet?> watchWallet(String id) =>
      (select(wallets)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<List<Wallet>> getAllWallets() => select(wallets).get();

  Future<void> upsertWallet(WalletsCompanion companion) =>
      into(wallets).insertOnConflictUpdate(companion);

  Future<void> deleteWallet(String id) =>
      (delete(wallets)..where((t) => t.id.equals(id))).go();

  // ── Categories ────────────────────────────────────────────────────────────────

  Stream<List<Category>> watchCategories({String? type}) {
    final query = select(categories);
    if (type != null) query.where((t) => t.type.equals(type));
    query.orderBy([
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.asc(t.name),
    ]);
    return query.watch();
  }

  Future<List<Category>> getCategories({String? type}) {
    final query = select(categories);
    if (type != null) query.where((t) => t.type.equals(type));
    return query.get();
  }

  Future<void> upsertCategory(CategoriesCompanion companion) =>
      into(categories).insertOnConflictUpdate(companion);

  Future<void> deleteCategory(String id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  /// How many transactions reference [categoryId]. Guards deletion: a category
  /// with history must not be removed (rows would render as raw ids).
  Future<int> countTransactionsByCategory(String categoryId) async {
    final countExp = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([countExp])
      ..where(transactions.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Persists a full reorder of one type's categories in a single batch.
  Future<void> reorderCategories(List<String> orderedIds) =>
      batch((b) {
        for (var i = 0; i < orderedIds.length; i++) {
          b.update(
            categories,
            CategoriesCompanion(sortOrder: Value(i)),
            where: (t) => t.id.equals(orderedIds[i]),
          );
        }
      });

  // ── Memory budgets ────────────────────────────────────────────────────────────

  Stream<List<MemoryBudget>> watchBudgets(String memoryId) =>
      (select(memoryBudgets)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.asc(t.currencyCode)]))
          .watch();

  Future<void> upsertBudget(MemoryBudgetsCompanion companion) =>
      into(memoryBudgets).insertOnConflictUpdate(companion);

  Future<void> deleteBudget(String id) =>
      (delete(memoryBudgets)..where((t) => t.id.equals(id))).go();

  // ── Transactions ──────────────────────────────────────────────────────────────

  Stream<List<Transaction>> watchTransactionsByWallet(String walletId) =>
      (select(transactions)
            ..where((t) => t.walletId.equals(walletId))
            ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
          .watch();

  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)
            ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
          .watch();

  Stream<List<Transaction>> watchTransactionsByMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (select(transactions)
          ..where((t) =>
              t.txnDate.isBiggerOrEqualValue(start) &
              t.txnDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsByWalletAndMonth(
      String walletId, int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (select(transactions)
          ..where((t) =>
              t.walletId.equals(walletId) &
              t.txnDate.isBiggerOrEqualValue(start) &
              t.txnDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsByMemory(String memoryId) =>
      (select(transactions)
            ..where((t) => t.memoryId.equals(memoryId))
            ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
          .watch();

  Future<Transaction?> getTransaction(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Transaction>> getTransactionsByMemoryId(String memoryId) =>
      (select(transactions)..where((t) => t.memoryId.equals(memoryId))).get();

  Future<void> upsertTransaction(TransactionsCompanion companion) =>
      into(transactions).insertOnConflictUpdate(companion);

  Future<void> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> clearTransactionsByMemoryId(String memoryId) =>
      (delete(transactions)..where((t) => t.memoryId.equals(memoryId))).go();

  // Get transactions linked to a memory (via tags)
  Future<List<Transaction>> getTransactionsForMemory(String memoryId) async {
    final tagRows = await (select(tags)
          ..where((t) => t.memoryId.equals(memoryId)))
        .get();
    if (tagRows.isEmpty) return [];

    final tagIds = tagRows.map((t) => t.id).toList();
    final txTagRows = await (select(transactionTags)
          ..where((t) => t.tagId.isIn(tagIds)))
        .get();
    if (txTagRows.isEmpty) return [];

    final txIds = txTagRows.map((t) => t.transactionId).toSet().toList();
    return (select(transactions)..where((t) => t.id.isIn(txIds))).get();
  }

  // ── Splits ────────────────────────────────────────────────────────────────────

  Stream<List<TransactionSplit>> watchSplits(String transactionId) =>
      (select(transactionSplits)
            ..where((t) => t.transactionId.equals(transactionId)))
          .watch();

  Future<List<TransactionSplit>> getSplits(String transactionId) =>
      (select(transactionSplits)
            ..where((t) => t.transactionId.equals(transactionId)))
          .get();

  /// All splits for a set of transactions in one query (settlement math).
  Future<List<TransactionSplit>> getSplitsForTransactions(
      List<String> transactionIds) {
    if (transactionIds.isEmpty) return Future.value(const []);
    return (select(transactionSplits)
          ..where((t) => t.transactionId.isIn(transactionIds)))
        .get();
  }

  Future<void> upsertSplit(TransactionSplitsCompanion companion) =>
      into(transactionSplits).insertOnConflictUpdate(companion);

  Future<void> clearSplits(String transactionId) =>
      (delete(transactionSplits)
            ..where((t) => t.transactionId.equals(transactionId)))
          .go();

  Future<void> clearSplitsByTransactionIds(List<String> transactionIds) {
    if (transactionIds.isEmpty) return Future.value();
    return (delete(transactionSplits)
          ..where((t) => t.transactionId.isIn(transactionIds)))
        .go();
  }

  // ── Transaction Tags ──────────────────────────────────────────────────────────

  Future<List<TransactionTag>> getTransactionTags(String transactionId) =>
      (select(transactionTags)
            ..where((t) => t.transactionId.equals(transactionId)))
          .get();

  Future<void> addTransactionTag(TransactionTagsCompanion companion) =>
      into(transactionTags).insertOnConflictUpdate(companion);

  Future<void> removeTransactionTag(
          String transactionId, String tagId) =>
      (delete(transactionTags)
            ..where((t) =>
                t.transactionId.equals(transactionId) &
                t.tagId.equals(tagId)))
          .go();

  Future<void> clearTransactionTagsByTransactionIds(
      List<String> transactionIds) {
    if (transactionIds.isEmpty) return Future.value();
    return (delete(transactionTags)
          ..where((t) => t.transactionId.isIn(transactionIds)))
        .go();
  }

  Future<void> clearTransactionTagsByTagIds(List<String> tagIds) {
    if (tagIds.isEmpty) return Future.value();
    return (delete(transactionTags)
          ..where((t) => t.tagId.isIn(tagIds)))
        .go();
  }

  Future<void> bulkTagTransactions(
      List<String> transactionIds, String tagId) async {
    for (final txId in transactionIds) {
      await into(transactionTags).insertOnConflictUpdate(
        TransactionTagsCompanion(
          id: Value('${txId}_$tagId'),
          transactionId: Value(txId),
          tagId: Value(tagId),
        ),
      );
    }
  }
}
