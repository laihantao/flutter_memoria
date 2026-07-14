import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../utils/file_ops.dart';
import 'database_provider.dart';

const _uuid = Uuid();

// ── Watches ───────────────────────────────────────────────────────────────────

final categoriesProvider =
    StreamProvider.family<List<Category>, String?>((ref, type) {
  return ref.watch(databaseProvider).expenseDao.watchCategories(type: type);
});

final transactionsByMemoryProvider =
    StreamProvider.family<List<Transaction>, String>((ref, memoryId) {
  return ref
      .watch(databaseProvider)
      .expenseDao
      .watchTransactionsByMemory(memoryId);
});

final transactionSplitsProvider =
    StreamProvider.family<List<TransactionSplit>, String>((ref, txId) {
  return ref.watch(databaseProvider).expenseDao.watchSplits(txId);
});

final memoryBudgetsProvider =
    StreamProvider.family<List<MemoryBudget>, String>((ref, memoryId) {
  return ref.watch(databaseProvider).expenseDao.watchBudgets(memoryId);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class ExpenseNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AppDatabase get _db => ref.read(databaseProvider);

  /// Full transaction save.
  Future<String> saveTransaction({
    String? existingId,
    String? walletId,
    String? memoryId,
    required String type,
    required String categoryId,
    required double amount,
    required String currencyCode,
    double exchangeRateToBase = 1.0,
    required DateTime txnDate,
    String? title,
    String? note,
    XFile? receiptFile,
    String splitType = 'personal',
    String? payerPersonId,
    List<({String personId, String shareType, double shareAmount})> splits =
        const [],
    List<String> tagIds = const [],
  }) async {
    final id = existingId ?? _uuid.v4();
    final now = DateTime.now();

    String? receiptPath;
    if (receiptFile != null) {
      final ext = p.extension(receiptFile.path);
      final relPath = 'media/receipts/$id$ext';
      await copyToAppDocs(receiptFile.path, relPath);
      receiptPath = relPath;
    } else if (existingId != null) {
      final existing = await _db.expenseDao.getTransaction(existingId);
      receiptPath = existing?.receiptMediaPath;
    }

    final self = await _db.personDao.getSelfPerson();

    await _db.expenseDao.upsertTransaction(TransactionsCompanion(
      id: Value(id),
      walletId: Value(walletId),
      memoryId: Value(memoryId),
      type: Value(type),
      categoryId: Value(categoryId),
      amount: Value(amount),
      currencyCode: Value(currencyCode),
      exchangeRateToBase: Value(exchangeRateToBase),
      txnDate: Value(txnDate),
      title: Value(title),
      note: Value(note),
      receiptMediaPath: Value(receiptPath),
      splitType: Value(splitType),
      payerPersonId: Value(payerPersonId ?? self?.id),
      createdAt: existingId == null ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    ));

    await _db.expenseDao.clearSplits(id);
    for (final s in splits) {
      await _db.expenseDao.upsertSplit(TransactionSplitsCompanion(
        id: Value(_uuid.v4()),
        transactionId: Value(id),
        personId: Value(s.personId),
        shareType: Value(s.shareType),
        shareAmount: Value(s.shareAmount),
      ));
    }

    for (final tagId in tagIds) {
      await _db.expenseDao.addTransactionTag(TransactionTagsCompanion(
        id: Value('${id}_$tagId'),
        transactionId: Value(id),
        tagId: Value(tagId),
      ));
    }

    return id;
  }

  Future<void> deleteTransaction(String id) async {
    final tx = await _db.expenseDao.getTransaction(id);
    if (tx?.receiptMediaPath != null) {
      await deleteAppDocFile(tx!.receiptMediaPath!);
    }
    await _db.expenseDao.deleteTransaction(id);
  }

  Future<void> saveCategory({
    String? existingId,
    required String name,
    required String type,
    String? iconName,
    int? sortOrder,
  }) async {
    await _db.expenseDao.upsertCategory(CategoriesCompanion(
      id: Value(existingId ?? _uuid.v4()),
      name: Value(name),
      type: Value(type),
      iconName: Value(iconName),
      sortOrder:
          sortOrder != null ? Value(sortOrder) : const Value.absent(),
    ));
  }

  /// Deletes a category unless transactions still reference it.
  /// Returns true when deleted, false when blocked by existing history.
  Future<bool> deleteCategory(String id) async {
    final used = await _db.expenseDao.countTransactionsByCategory(id);
    if (used > 0) return false;
    await _db.expenseDao.deleteCategory(id);
    return true;
  }

  Future<void> reorderCategories(List<String> orderedIds) =>
      _db.expenseDao.reorderCategories(orderedIds);

  // ── Memory budgets ──────────────────────────────────────────────────────────

  Future<void> saveBudget({
    String? existingId,
    required String memoryId,
    required String currencyCode,
    required double amount,
  }) async {
    await _db.expenseDao.upsertBudget(MemoryBudgetsCompanion(
      id: Value(existingId ?? _uuid.v4()),
      memoryId: Value(memoryId),
      currencyCode: Value(currencyCode),
      amount: Value(amount),
    ));
  }

  Future<void> deleteBudget(String id) => _db.expenseDao.deleteBudget(id);
}

final expenseNotifierProvider =
    AsyncNotifierProvider<ExpenseNotifier, void>(ExpenseNotifier.new);
