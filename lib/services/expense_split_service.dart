import '../utils/money.dart';

/// Settlement math over memory expenses.
///
/// Takes every expense in the unified `(payer, shares)` shape — see
/// `buildShares` in utils/split_math.dart — with no split-mode branch: 个人 and
/// 请客 name the payer as their own sole bearer, so they produce no debt here
/// and fall out of the statement naturally. They still count toward
/// [ExpenseSplitService.personCosts], which is what makes them visible.
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

/// One expense reduced to what the settlement math needs.
class SplitTxn {
  /// Currency code, expected already normalized (upper-case) by the caller.
  final String currencyCode;

  /// The person who fronted the money.
  final String payerPersonId;

  /// The expense's full amount. Carried separately from [shares] because
  /// per-head shares are rounded to 2dp and can sum to a cent off — what the
  /// payer actually handed over is this, exactly.
  final double amount;

  /// Per-person share for THIS expense (`sharerId` → amount). The payer may
  /// appear here (they share too); a person only *owes* their share on
  /// expenses they did **not** pay, so the payer's own entry creates no debt.
  final Map<String, double> shares;

  const SplitTxn({
    required this.currencyCode,
    required this.payerPersonId,
    required this.amount,
    required this.shares,
  });
}

/// The row-owes-column matrix for one currency (Req D).
///
/// Rows are all trip participants; columns ([payeePersonIds]) are the people
/// someone actually owes in this currency. `cell[r][p]` is the total person `r`
/// owes person `p`. The diagonal (`r == p`) is always 0.
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

/// What one person fronted vs actually bore, in one currency.
///
/// [paid] counts every expense they were the payer of, at full amount — 个人,
/// AA and 请客 alike. [borne] sums their shares: their own 个人 expenses in
/// full, their per-head slice of each AA expense, the full amount of any 请客
/// they hosted, and nothing for a 请客 someone else hosted.
class PersonCostTotals {
  final String personId;
  final String currencyCode;
  final double paid;
  final double borne;

  const PersonCostTotals({
    required this.personId,
    required this.currencyCode,
    required this.paid,
    required this.borne,
  });

  /// paid − borne: their net position, i.e. the sum of everything they will
  /// receive minus everything they will pay.
  ///
  /// ⚠️ **`net == 0` does NOT mean "settled"** — do not present it that way.
  /// Netting is pairwise, never global (Req E), so someone can owe A and be
  /// owed the same by B and still have to make both transfers. Only the
  /// consolidated debts say whether anyone has to move money.
  ///
  /// Useful as a cross-check (it must equal their total cash flow across
  /// [ConsolidatedDebt]s) rather than as something to show a reader.
  double get net => roundHalfUp(paid - borne);
}

class ExpenseSplitService {
  const ExpenseSplitService();

  /// Per-person `paid` / `borne` totals, one row per (person, currency).
  ///
  /// Rows follow [participantIds] order, then any off-roster person seen in the
  /// data; currencies are sorted. A person with no activity in a currency gets
  /// no row for it.
  List<PersonCostTotals> personCosts({
    required List<SplitTxn> transactions,
    required List<String> participantIds,
  }) {
    // currency → personId → (paid, borne)
    final paid = <String, Map<String, double>>{};
    final borne = <String, Map<String, double>>{};
    final seen = <String>{};

    for (final t in transactions) {
      seen.add(t.payerPersonId);
      final paidC = paid[t.currencyCode] ??= <String, double>{};
      paidC[t.payerPersonId] = (paidC[t.payerPersonId] ?? 0) + t.amount;

      final borneC = borne[t.currencyCode] ??= <String, double>{};
      t.shares.forEach((sharer, share) {
        seen.add(sharer);
        borneC[sharer] = (borneC[sharer] ?? 0) + share;
      });
    }

    final people = <String>[
      ...participantIds,
      for (final id in seen)
        if (!participantIds.contains(id)) id,
    ];
    final currencies = {...paid.keys, ...borne.keys}.toList()..sort();

    return [
      for (final c in currencies)
        for (final id in people)
          if ((paid[c]?[id] ?? 0) != 0 || (borne[c]?[id] ?? 0) != 0)
            PersonCostTotals(
              personId: id,
              currencyCode: c,
              paid: roundHalfUp(paid[c]?[id] ?? 0),
              borne: roundHalfUp(borne[c]?[id] ?? 0),
            ),
    ];
  }

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
      t.shares.forEach((sharer, share) {
        seen.add(sharer);
        if (sharer == t.payerPersonId) return; // no self-debt
        final row = owe[sharer] ??= <String, double>{};
        row[t.payerPersonId] = (row[t.payerPersonId] ?? 0) + share;
        // Column only once someone actually owes them — a 个人/请客 payer is
        // their own sole bearer and would otherwise add an all-zero column.
        if (!payeeOrder.contains(t.payerPersonId)) {
          payeeOrder.add(t.payerPersonId);
        }
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
