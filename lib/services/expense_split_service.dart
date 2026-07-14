import '../utils/money.dart';

/// Phase 2 settlement math for AA (`split_aa`) expenses.
///
/// Pure and DB-free so the PDF builder, any in-app statement view, and unit
/// tests all share one implementation. See `docs/expenses-split-enhancement-spec.md`.
///
/// Everything is **grouped by `currencyCode` first** (Req F) — each currency
/// yields its own [PaymentStatement] (Req D) and pairwise [ConsolidatedDebt]
/// list (Req E). Currencies are never mixed and `exchangeRateToBase` is ignored.
///
/// Rounding is round-half-up to 2dp (Req H) applied at presentation of each
/// cell / each pair total via [roundHalfUp]; rounded values are not guaranteed
/// to reconcile to the cent.
///
/// ⚠️ Direction convention (Req E, canonical): for an unordered pair {X, Y},
/// `net = oweXtoY − oweYtoX`, where `oweXtoY` = the total X owes on expenses Y
/// paid. `net > 0` → "X pays Y net"; `net < 0` → "Y pays X |net|"; `net ≈ 0` →
/// settled (omitted). NOTE: the spec's §3.2 one-line sanity prose ("A pays Me
/// 95") contradicts this formula — by the formula, {A owes Me 25, Me owes A
/// 120} nets to **"Me pays A 95"**. The formula is authoritative here.

/// One AA expense reduced to what the settlement math needs.
class SplitTxn {
  /// Currency code, expected already normalized (upper-case) by the caller.
  final String currencyCode;

  /// The person who fronted the money.
  final String payerPersonId;

  /// Per-person share for THIS expense (`sharerId` → amount). The payer may
  /// appear here (they share too); a person only *owes* their share on
  /// expenses they did **not** pay, so the payer's own entry creates no debt.
  final Map<String, double> shares;

  const SplitTxn({
    required this.currencyCode,
    required this.payerPersonId,
    required this.shares,
  });
}

/// The row-owes-column matrix for one currency (Req D).
///
/// Rows are all trip participants; columns ([payeePersonIds]) are the people
/// who fronted at least one `split_aa` expense in this currency. `cell[r][p]` is
/// the total person `r` owes person `p`. The diagonal (`r == p`) is always 0.
class PaymentStatement {
  final String currencyCode;
  final List<String> rowPersonIds;
  final List<String> payeePersonIds;
  final Map<String, Map<String, double>> _cells;

  const PaymentStatement({
    required this.currencyCode,
    required this.rowPersonIds,
    required this.payeePersonIds,
    required Map<String, Map<String, double>> cells,
    // ignore: prefer_initializing_formals — named params can't start with `_`.
  }) : _cells = cells;

  /// Amount [row] owes [payee] (0 when settled or self-cell), rounded 2dp.
  double owed(String row, String payee) =>
      roundHalfUp(_cells[row]?[payee] ?? 0);

  /// Total [row] owes across all payees (sum of rounded cells; may be a cent off).
  double rowTotal(String row) =>
      payeePersonIds.fold(0.0, (sum, p) => sum + owed(row, p));

  /// Total owed *to* [payee] across all rows (sum of rounded cells).
  double payeeTotal(String payee) =>
      rowPersonIds.fold(0.0, (sum, r) => sum + owed(r, payee));

  /// No one fronted an AA expense in this currency → nothing to show.
  bool get isEmpty => payeePersonIds.isEmpty;
}

/// A single "X pays Y amount" line after pairwise netting (Req E).
class ConsolidatedDebt {
  final String fromPersonId; // debtor
  final String toPersonId; // payee
  final double amount; // > 0, rounded 2dp
  final String currencyCode;

  const ConsolidatedDebt({
    required this.fromPersonId,
    required this.toPersonId,
    required this.amount,
    required this.currencyCode,
  });
}

/// Everything computed for one currency.
class CurrencySplit {
  final String currencyCode;
  final PaymentStatement statement;
  final List<ConsolidatedDebt> consolidated;

  const CurrencySplit({
    required this.currencyCode,
    required this.statement,
    required this.consolidated,
  });
}

class ExpenseSplitService {
  const ExpenseSplitService();

  /// Groups [transactions] by currency and computes a [CurrencySplit] for each.
  ///
  /// [participantIds] is the trip roster (statement rows, Req D). Any person who
  /// appears in the data but is no longer on the roster is appended so their
  /// debt is never silently dropped (see spec §4 Q3). Currencies come back
  /// sorted for stable output.
  List<CurrencySplit> compute({
    required List<SplitTxn> transactions,
    required List<String> participantIds,
  }) {
    final byCurrency = <String, List<SplitTxn>>{};
    for (final t in transactions) {
      (byCurrency[t.currencyCode] ??= <SplitTxn>[]).add(t);
    }

    final currencies = byCurrency.keys.toList()..sort();
    return [
      for (final c in currencies)
        _computeCurrency(c, byCurrency[c]!, participantIds),
    ];
  }

  CurrencySplit _computeCurrency(
    String currency,
    List<SplitTxn> txns,
    List<String> participantIds,
  ) {
    // owe[debtor][payee] = raw total debtor owes payee in this currency.
    final owe = <String, Map<String, double>>{};
    // People seen in the data (payers + sharers) — for roster-drift safety.
    final seen = <String>{};
    // Payees preserve first-appearance order for stable columns.
    final payeeOrder = <String>[];

    for (final t in txns) {
      seen.add(t.payerPersonId);
      if (!payeeOrder.contains(t.payerPersonId)) payeeOrder.add(t.payerPersonId);
      t.shares.forEach((sharer, share) {
        seen.add(sharer);
        if (sharer == t.payerPersonId) return; // no self-debt
        final row = owe[sharer] ??= <String, double>{};
        row[t.payerPersonId] = (row[t.payerPersonId] ?? 0) + share;
      });
    }

    // Rows: roster first (Req D), then any off-roster person seen in the data.
    final rows = <String>[
      ...participantIds,
      for (final id in seen)
        if (!participantIds.contains(id)) id,
    ];

    final statement = PaymentStatement(
      currencyCode: currency,
      rowPersonIds: rows,
      payeePersonIds: payeeOrder,
      cells: owe,
    );

    // Pairwise consolidation (Req E). Iterate unordered pairs in a stable order.
    final people = rows;
    final consolidated = <ConsolidatedDebt>[];
    for (var i = 0; i < people.length; i++) {
      for (var j = i + 1; j < people.length; j++) {
        final x = people[i];
        final y = people[j];
        final oweXtoY = owe[x]?[y] ?? 0;
        final oweYtoX = owe[y]?[x] ?? 0;
        final net = roundHalfUp(oweXtoY - oweYtoX);
        if (net > 0) {
          consolidated.add(ConsolidatedDebt(
            fromPersonId: x,
            toPersonId: y,
            amount: net,
            currencyCode: currency,
          ));
        } else if (net < 0) {
          consolidated.add(ConsolidatedDebt(
            fromPersonId: y,
            toPersonId: x,
            amount: -net,
            currencyCode: currency,
          ));
        }
        // net == 0 → settled, omit.
      }
    }

    return CurrencySplit(
      currencyCode: currency,
      statement: statement,
      consolidated: consolidated,
    );
  }
}
