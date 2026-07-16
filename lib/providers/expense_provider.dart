import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../services/expense_split_service.dart';
import '../utils/file_ops.dart';
import '../utils/money.dart';
import 'database_provider.dart';
import 'person_provider.dart';

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

/// One memory expense paired with who bears it — the `(payer, shares)` shape all
/// three split modes reduce to. The single source for settlement, the
/// per-person cost totals, and the dashboard's 我的 lens.
typedef ResolvedExpense = ({Transaction tx, Map<String, double> shares});

/// Splits for the memory's transactions, kept live off the splits table.
/// Public so tests can drive [memoryResolvedExpensesProvider] without a DB.
final memorySplitRowsProvider =
    StreamProvider.family<List<TransactionSplit>, String>((ref, memoryId) {
  return ref.watch(databaseProvider).expenseDao.watchSplitsByMemory(memoryId);
});

/// The memory's expenses with their shares resolved.
///
/// No `splitType` filter is needed: 个人 and 请客 name the payer as their own
/// sole bearer, so they carry no debt and drop out of the settlement math on
/// their own (see `buildShares` in utils/split_math.dart). They do still count
/// toward [memoryPersonCostsProvider], which is the point.
///
/// Composed from the two underlying **streams**, so it recomputes whenever a
/// transaction or a split changes. It must not read the DAO one-shot: the
/// dashboard mounts this for the whole life of the 费用 tab, and a one-shot read
/// would freeze it at whatever existed when the tab opened while the (streamed)
/// totals card carried on updating around it.
final memoryResolvedExpensesProvider =
    FutureProvider.family<List<ResolvedExpense>, String>((ref, memoryId) async {
  final txns =
      await ref.watch(transactionsByMemoryProvider(memoryId).future);
  final splits = await ref.watch(memorySplitRowsProvider(memoryId).future);

  final expenses = txns
      .where((t) => t.type == 'expense' && t.payerPersonId != null)
      .toList();

  final splitsByTx = <String, List<TransactionSplit>>{};
  for (final s in splits) {
    (splitsByTx[s.transactionId] ??= <TransactionSplit>[]).add(s);
  }

  return [
    for (final t in expenses)
      (
        tx: t,
        shares: (splitsByTx[t.id] ?? const []).isEmpty
            // Rows saved before shares were materialized for every mode carry no
            // splits — for 个人/请客 the payer bore the lot, which is exactly
            // this. It's also the safe degenerate for an AA row whose splits are
            // missing: payer bears all → no debt, as that row behaved before.
            ? {t.payerPersonId!: t.amount}
            : {
                for (final s in splitsByTx[t.id]!) s.personId: s.shareAmount,
              },
      ),
  ];
});

List<SplitTxn> _toSplitTxns(List<ResolvedExpense> resolved) => [
      for (final r in resolved)
        SplitTxn(
          currencyCode: normalizeCurrency(r.tx.currencyCode),
          payerPersonId: r.tx.payerPersonId!,
          amount: r.tx.amount,
          shares: r.shares,
        ),
    ];

/// txId → what "Me" bears of that expense. A missing key means Me bears none of
/// it (someone else's 请客, or an AA Me was excluded from). Powers the 我的 lens.
final memoryMySharesProvider =
    FutureProvider.family<Map<String, double>, String>((ref, memoryId) async {
  final me = ref.watch(mePersonProvider).value;
  if (me == null) return const {};
  final resolved =
      await ref.watch(memoryResolvedExpensesProvider(memoryId).future);
  return {
    for (final r in resolved)
      if (r.shares[me.id] != null) r.tx.id: r.shares[me.id]!,
  };
});

/// Per-currency settlement (Payment Statement + Final Consolidate) for a memory.
///
/// Runs the pure [ExpenseSplitService] over the memory's expenses and the trip
/// roster. Feeds the PDF preview and any in-app settlement view, and tracks
/// edits live via [memoryResolvedExpensesProvider].
final memorySplitResultsProvider =
    FutureProvider.family<List<CurrencySplit>, String>((ref, memoryId) async {
  final inputs = _toSplitTxns(
      await ref.watch(memoryResolvedExpensesProvider(memoryId).future));
  final rosterIds = ref
      .watch(memoryParticipantPersonsProvider(memoryId))
      .map((p) => p.id)
      .toList();

  return const ExpenseSplitService()
      .compute(transactions: inputs, participantIds: rosterIds);
});

typedef PersonCostsArgs = ({String memoryId, bool includePersonal});

/// What each person actually **bore** vs **fronted**, per currency (各人收支).
///
/// [PersonCostTotals.net] = paid − borne, which is exactly that person's net
/// creditor position — it reconciles against the consolidated debts, so the two
/// views cross-check each other.
///
/// `includePersonal: false` drops 个人 rows, for the shared PDF where your own
/// purchases aren't the group's business. A 个人 expense adds the same amount to
/// its payer's paid and borne, so excluding it shifts both columns but leaves
/// every `net` — and therefore the settlement — untouched.
final memoryPersonCostsProvider =
    FutureProvider.family<List<PersonCostTotals>, PersonCostsArgs>(
        (ref, args) async {
  final resolved =
      await ref.watch(memoryResolvedExpensesProvider(args.memoryId).future);
  final inputs = _toSplitTxns(args.includePersonal
      ? resolved
      : resolved.where((r) => r.tx.splitType != 'personal').toList());
  final rosterIds = ref
      .watch(memoryParticipantPersonsProvider(args.memoryId))
      .map((p) => p.id)
      .toList();

  return const ExpenseSplitService()
      .personCosts(transactions: inputs, participantIds: rosterIds);
});

/// One expense's contribution to a person's 承担 total.
///
/// [sharerCount] is how many people bore that expense, i.e. the ÷N behind an AA
/// share. It is 1 for 个人/请客, where the payer bore the whole amount.
typedef BorneLine = ({Transaction tx, double share, int sharerCount});

/// Key into [memoryPersonBreakdownProvider]. Currency is normalized to match the
/// grouping [memoryPersonCostsProvider] uses.
String personBorneKey(String personId, String currencyCode) =>
    '$personId|${normalizeCurrency(currencyCode)}';

/// `personBorneKey(...)` → the expenses that add up to that person's `borne`.
///
/// The line items behind [memoryPersonCostsProvider]'s totals: same source, same
/// 个人 filter, same shares. Their sum reconciles to `borne` because a share is
/// already rounded where it is stored, so nothing is rounded twice here.
final memoryPersonBreakdownProvider =
    FutureProvider.family<Map<String, List<BorneLine>>, PersonCostsArgs>(
        (ref, args) async {
  final resolved =
      await ref.watch(memoryResolvedExpensesProvider(args.memoryId).future);

  final out = <String, List<BorneLine>>{};
  for (final r in resolved) {
    if (!args.includePersonal && r.tx.splitType == 'personal') continue;
    r.shares.forEach((personId, share) {
      if (share == 0) return;
      (out[personBorneKey(personId, r.tx.currencyCode)] ??= []).add(
        (tx: r.tx, share: share, sharerCount: r.shares.length),
      );
    });
  }
  // Biggest bite first — the question the breakdown answers is "what made this
  // number so big", and the answer should be the first line.
  for (final lines in out.values) {
    lines.sort((a, b) => b.share.compareTo(a.share));
  }
  return out;
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
