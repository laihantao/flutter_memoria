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

final walletsProvider = StreamProvider<List<Wallet>>((ref) {
  return ref.watch(databaseProvider).expenseDao.watchAllWallets();
});

final walletProvider = StreamProvider.family<Wallet?, String>((ref, id) {
  return ref.watch(databaseProvider).expenseDao.watchWallet(id);
});

// (walletId, year, month) key
final transactionsByWalletMonthProvider =
    StreamProvider.family<List<Transaction>, (String, int, int)>(
        (ref, key) {
  return ref
      .watch(databaseProvider)
      .expenseDao
      .watchTransactionsByWalletAndMonth(key.$1, key.$2, key.$3);
});

final categoriesProvider =
    StreamProvider.family<List<Category>, String?>((ref, type) {
  return ref.watch(databaseProvider).expenseDao.watchCategories(type: type);
});

final transactionsByWalletProvider =
    StreamProvider.family<List<Transaction>, String>((ref, walletId) {
  return ref
      .watch(databaseProvider)
      .expenseDao
      .watchTransactionsByWallet(walletId);
});

final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(databaseProvider).expenseDao.watchAllTransactions();
});

// (year, month) tuple key
final transactionsByMonthProvider =
    StreamProvider.family<List<Transaction>, (int, int)>((ref, ym) {
  return ref
      .watch(databaseProvider)
      .expenseDao
      .watchTransactionsByMonth(ym.$1, ym.$2);
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

// ── Notifier ──────────────────────────────────────────────────────────────────

class ExpenseNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<String> saveWallet({
    String? existingId,
    required String name,
    required String currencyCode,
    String? iconName,
    String? colorHex,
    double initialBalance = 0.0,
  }) async {
    final id = existingId ?? _uuid.v4();
    await _db.expenseDao.upsertWallet(WalletsCompanion(
      id: Value(id),
      name: Value(name),
      currencyCode: Value(currencyCode),
      iconName: Value(iconName),
      colorHex: Value(colorHex),
      initialBalance: Value(initialBalance),
      createdAt:
          existingId == null ? Value(DateTime.now()) : const Value.absent(),
    ));
    return id;
  }

  Future<void> deleteWallet(String id) async {
    await _db.expenseDao.deleteWallet(id);
  }

  /// Simple expense/income save — wallet and payer are optional.
  Future<String> saveExpense({
    String? existingId,
    String? walletId,
    String? memoryId,
    required String type,
    required String categoryId,
    required double amount,
    required String currencyCode,
    DateTime? txnDate,
    String? note,
    String? title,
  }) async {
    final id = existingId ?? _uuid.v4();
    final now = DateTime.now();
    final self = await _db.personDao.getSelfPerson();

    await _db.expenseDao.upsertTransaction(TransactionsCompanion(
      id: Value(id),
      walletId: Value(walletId),
      memoryId: Value(memoryId),
      type: Value(type),
      categoryId: Value(categoryId),
      amount: Value(amount),
      currencyCode: Value(currencyCode),
      txnDate: Value(txnDate ?? now),
      title: Value(title),
      note: Value(note),
      payerPersonId: Value(self?.id),
      createdAt: existingId == null ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    ));

    return id;
  }

  /// Full transaction save (legacy wallet-based flow).
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

  Future<void> bulkTagTransactions(
      List<String> transactionIds, String tagId) async {
    await _db.expenseDao.bulkTagTransactions(transactionIds, tagId);
  }

  Future<void> addCategory({
    required String name,
    required String type,
    String? iconName,
  }) async {
    await _db.expenseDao.upsertCategory(CategoriesCompanion(
      id: Value(_uuid.v4()),
      name: Value(name),
      type: Value(type),
      iconName: Value(iconName),
    ));
  }
}

final expenseNotifierProvider =
    AsyncNotifierProvider<ExpenseNotifier, void>(ExpenseNotifier.new);
