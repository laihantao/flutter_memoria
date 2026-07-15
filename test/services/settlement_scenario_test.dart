import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/services/expense_split_service.dart';
import 'package:memora_flutter/utils/money.dart';

/// End-to-end audit of the statement a 记忆 exports: one realistic trip, every
/// number worked out by hand below, plus the structural properties that must
/// hold for *any* trip.
///
/// ── The trip ─────────────────────────────────────────────────────────────────
/// Roster: me, tommy, alex.
///
///  #1  我付 AA 晚餐     RM 300  split 3 ways      → 100 each
///  #2  Tommy 请客 早餐  RM  60  tommy bears all   → no debt
///  #3  Alex 付 AA 车费  RM  90  split 3 ways      → 30 each
///  #4  我 个人 纪念品   RM  50  me bears all      → no debt
///  #5  Tommy 付 AA 酒店 RM 600  alex excluded     → 300 each (me, tommy)
///
/// ── Who owes whom, before netting ────────────────────────────────────────────
///  #1 → tommy owes me 100, alex owes me 100
///  #3 → me owes alex 30,  tommy owes alex 30
///  #5 → me owes tommy 300
///
/// ── Pairwise netting (Req E: per pair, never routed through a third party) ───
///  {me, tommy}: me→tommy 300 vs tommy→me 100  → me pays tommy 200
///  {me, alex} : me→alex   30 vs alex→me  100  → alex pays me   70
///  {tommy,alex}: tommy→alex 30 vs alex→tommy 0 → tommy pays alex 30
///
/// ── Cross-check against 各人收支 (paid − borne) ──────────────────────────────
///  me   : paid 300+50=350, borne 100+30+50+300=480 → net −130
///  tommy: paid  60+600=660, borne 100+60+30+300=490 → net +170
///  alex : paid        90,   borne 100+30       =130 → net  −40
///  Nets sum to 0, and each person's net equals their cash flow through the
///  consolidated debts:
///    me   : −200 (to tommy) +70 (from alex) = −130 ✓
///    tommy: +200 (from me)  −30 (to alex)   = +170 ✓
///    alex : −70  (to me)    +30 (from tommy)=  −40 ✓
const _me = 'me';
const _tommy = 'tommy';
const _alex = 'alex';
const _roster = [_me, _tommy, _alex];

/// (transaction, splitType) — splitType only matters for the 个人 filter the
/// PDF applies; the math never branches on it.
final _trip = <({SplitTxn txn, String splitType})>[
  (
    txn: SplitTxn(
      currencyCode: 'MYR',
      payerPersonId: _me,
      amount: 300,
      shares: {_me: 100, _tommy: 100, _alex: 100},
    ),
    splitType: 'split_aa',
  ),
  (
    txn: SplitTxn(
      currencyCode: 'MYR',
      payerPersonId: _tommy,
      amount: 60,
      shares: {_tommy: 60},
    ),
    splitType: 'treat',
  ),
  (
    txn: SplitTxn(
      currencyCode: 'MYR',
      payerPersonId: _alex,
      amount: 90,
      shares: {_me: 30, _tommy: 30, _alex: 30},
    ),
    splitType: 'split_aa',
  ),
  (
    txn: SplitTxn(
      currencyCode: 'MYR',
      payerPersonId: _me,
      amount: 50,
      shares: {_me: 50},
    ),
    splitType: 'personal',
  ),
  (
    txn: SplitTxn(
      currencyCode: 'MYR',
      payerPersonId: _tommy,
      amount: 600,
      shares: {_me: 300, _tommy: 300},
    ),
    splitType: 'split_aa',
  ),
];

List<SplitTxn> _txns({bool includePersonal = true}) => [
      for (final e in _trip)
        if (includePersonal || e.splitType != 'personal') e.txn,
    ];

void main() {
  const service = ExpenseSplitService();

  PersonCostTotals costOf(List<PersonCostTotals> rows, String id) =>
      rows.singleWhere((r) => r.personId == id);

  /// Net cash a person moves through the consolidated debts: positive = they
  /// end up receiving.
  double cashFlow(List<ConsolidatedDebt> debts, String id) {
    var net = 0.0;
    for (final d in debts) {
      if (d.toPersonId == id) net += d.amount;
      if (d.fromPersonId == id) net -= d.amount;
    }
    return roundHalfUp(net);
  }

  group('the worked trip', () {
    final result =
        service.compute(transactions: _txns(), participantIds: _roster).single;
    final costs =
        service.personCosts(transactions: _txns(), participantIds: _roster);

    test('one MYR group', () {
      expect(result.currencyCode, 'MYR');
    });

    test('statement matrix matches the hand-computed debts', () {
      final s = result.statement;
      expect(s.owed(_tommy, _me), 100); // #1
      expect(s.owed(_alex, _me), 100); // #1
      expect(s.owed(_me, _alex), 30); // #3
      expect(s.owed(_tommy, _alex), 30); // #3
      expect(s.owed(_me, _tommy), 300); // #5
      // Alex was excluded from the hotel, so he owes tommy nothing.
      expect(s.owed(_alex, _tommy), 0);
      // Nobody owes themselves.
      for (final p in _roster) {
        expect(s.owed(p, p), 0, reason: p);
      }
    });

    test('row totals are what each person owes gross', () {
      final s = result.statement;
      expect(s.rowTotal(_me), 330); // 30 to alex + 300 to tommy
      expect(s.rowTotal(_tommy), 130); // 100 to me + 30 to alex
      expect(s.rowTotal(_alex), 100); // 100 to me
    });

    test('consolidate nets each pair, and only each pair', () {
      final debts = result.consolidated;
      expect(debts, hasLength(3));

      final meTommy = debts.singleWhere((d) => d.fromPersonId == _me);
      expect(meTommy.toPersonId, _tommy);
      expect(meTommy.amount, 200); // 300 − 100

      final alexMe = debts.singleWhere((d) => d.fromPersonId == _alex);
      expect(alexMe.toPersonId, _me);
      expect(alexMe.amount, 70); // 100 − 30

      final tommyAlex = debts.singleWhere((d) => d.fromPersonId == _tommy);
      expect(tommyAlex.toPersonId, _alex);
      expect(tommyAlex.amount, 30);
    });

    test('各人收支 paid/borne match the hand-computed totals', () {
      expect(costOf(costs, _me).paid, 350);
      expect(costOf(costs, _me).borne, 480);
      expect(costOf(costs, _tommy).paid, 660);
      expect(costOf(costs, _tommy).borne, 490);
      expect(costOf(costs, _alex).paid, 90);
      expect(costOf(costs, _alex).borne, 130);
    });

    test('每人的差额 equals their cash flow through the consolidated debts', () {
      // This is the load-bearing cross-check: the 各人收支 table and the
      // settlement are computed by different code paths and must agree.
      for (final p in _roster) {
        expect(costOf(costs, p).net, cashFlow(result.consolidated, p),
            reason: p);
      }
      expect(costOf(costs, _me).net, -130);
      expect(costOf(costs, _tommy).net, 170);
      expect(costOf(costs, _alex).net, -40);
    });

    test('个人 and 请客 add no debt of their own', () {
      // Drop #2 (请客) and #4 (个人) — settlement must be identical.
      final withoutNoDebtModes = [
        for (final e in _trip)
          if (e.splitType == 'split_aa') e.txn,
      ];
      final lean = service
          .compute(transactions: withoutNoDebtModes, participantIds: _roster)
          .single;
      expect(
        lean.consolidated
            .map((d) => '${d.fromPersonId}->${d.toPersonId}:${d.amount}')
            .toList(),
        result.consolidated
            .map((d) => '${d.fromPersonId}->${d.toPersonId}:${d.amount}')
            .toList(),
      );
    });

    test('excluding 个人 shifts paid and borne but never 差额', () {
      // What the PDF does by default. It must not change who owes whom.
      final shared = service.personCosts(
          transactions: _txns(includePersonal: false),
          participantIds: _roster);
      expect(costOf(shared, _me).paid, 300); // 350 − 50
      expect(costOf(shared, _me).borne, 430); // 480 − 50
      for (final p in _roster) {
        expect(costOf(shared, p).net, costOf(costs, p).net, reason: p);
      }
    });
  });

  group('properties that must hold for any trip', () {
    test('nets sum to zero — money is conserved', () {
      final costs =
          service.personCosts(transactions: _txns(), participantIds: _roster);
      final sum = costs.fold<double>(0, (a, r) => a + r.net);
      expect(roundHalfUp(sum), 0);
    });

    test('consolidated debts sum to zero across all participants', () {
      final result =
          service.compute(transactions: _txns(), participantIds: _roster).single;
      final sum = _roster.fold<double>(
          0, (a, p) => a + cashFlow(result.consolidated, p));
      expect(roundHalfUp(sum), 0);
    });

    test('no debt is ever negative or self-directed', () {
      final result =
          service.compute(transactions: _txns(), participantIds: _roster).single;
      for (final d in result.consolidated) {
        expect(d.amount, greaterThan(0));
        expect(d.fromPersonId, isNot(d.toPersonId));
      }
    });

    test('a fully settled pair is omitted rather than shown as zero', () {
      // me pays 100 split 2 ways; alex pays 100 split 2 ways → both owe 50.
      final r = service.compute(
        transactions: [
          SplitTxn(
              currencyCode: 'MYR',
              payerPersonId: _me,
              amount: 100,
              shares: {_me: 50, _alex: 50}),
          SplitTxn(
              currencyCode: 'MYR',
              payerPersonId: _alex,
              amount: 100,
              shares: {_me: 50, _alex: 50}),
        ],
        participantIds: [_me, _alex],
      );
      expect(r.single.consolidated, isEmpty);
    });

    test('currencies never mix — each settles independently', () {
      final r = service.compute(
        transactions: [
          ..._txns(),
          SplitTxn(
              currencyCode: 'SGD',
              payerPersonId: _alex,
              amount: 80,
              shares: {_me: 40, _alex: 40}),
        ],
        participantIds: _roster,
      );
      expect(r.map((c) => c.currencyCode).toList(), ['MYR', 'SGD']);
      // The MYR settlement is untouched by the SGD row.
      final myr = r.firstWhere((c) => c.currencyCode == 'MYR');
      expect(myr.consolidated, hasLength(3));
      // SGD stands alone: me owes alex 40, and no MYR debt leaks in.
      final sgd = r.firstWhere((c) => c.currencyCode == 'SGD');
      expect(sgd.consolidated.single.fromPersonId, _me);
      expect(sgd.consolidated.single.toPersonId, _alex);
      expect(sgd.consolidated.single.amount, 40);
    });
  });
}
