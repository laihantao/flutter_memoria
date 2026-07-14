import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/services/expense_split_service.dart';

/// Helper: build an AA expense from a payer + per-person shares.
SplitTxn tx(
  String currency,
  String payer,
  Map<String, double> shares,
) =>
    SplitTxn(currencyCode: currency, payerPersonId: payer, shares: shares);

void main() {
  const service = ExpenseSplitService();

  group('single currency — spec §3.2 sanity example', () {
    // "A owes Me 25" → Me paid an expense on which A's share is 25.
    // "Me owes A 120" → A paid an expense on which Me's share is 120.
    // Canonical Req E formula nets to "Me pays A 95" (the spec's one-line prose
    // "A pays Me 95" is a documented error — see service header).
    final result = service.compute(
      transactions: [
        tx('MYR', 'me', {'me': 10, 'a': 25}),
        tx('MYR', 'a', {'a': 30, 'me': 120}),
      ],
      participantIds: ['me', 'a'],
    );

    test('one currency group', () {
      expect(result, hasLength(1));
      expect(result.single.currencyCode, 'MYR');
    });

    test('consolidate: Me pays A 95', () {
      final debts = result.single.consolidated;
      expect(debts, hasLength(1));
      expect(debts.single.fromPersonId, 'me');
      expect(debts.single.toPersonId, 'a');
      expect(debts.single.amount, 95);
    });

    test('statement matrix cells', () {
      final s = result.single.statement;
      expect(s.owed('a', 'me'), 25); // A owes Me 25
      expect(s.owed('me', 'a'), 120); // Me owes A 120
      expect(s.owed('me', 'me'), 0); // no self-debt
      expect(s.payeePersonIds.toSet(), {'me', 'a'});
    });
  });

  group('exclude / no-debt modes', () {
    test('payer owes nobody for their own expense', () {
      final r = service.compute(
        transactions: [
          tx('MYR', 'me', {'me': 20, 'a': 20, 'b': 20}),
        ],
        participantIds: ['me', 'a', 'b'],
      );
      final debts = r.single.consolidated;
      // A→me 20, B→me 20; me owes nothing.
      expect(debts, hasLength(2));
      expect(debts.every((d) => d.toPersonId == 'me'), isTrue);
      expect(debts.firstWhere((d) => d.fromPersonId == 'a').amount, 20);
    });

    test('excluded person (absent from shares) owes nothing', () {
      final r = service.compute(
        transactions: [
          // b excluded → not in shares.
          tx('MYR', 'me', {'me': 30, 'a': 30}),
        ],
        participantIds: ['me', 'a', 'b'],
      );
      final debts = r.single.consolidated;
      expect(debts, hasLength(1));
      expect(debts.single.fromPersonId, 'a');
      expect(debts.single.amount, 30);
      // b still appears as a statement row but owes 0.
      expect(r.single.statement.rowTotal('b'), 0);
    });

    test('empty input yields no currency groups', () {
      expect(service.compute(transactions: [], participantIds: ['me']),
          isEmpty);
    });
  });

  group('multi-currency (Req F) — never mixed', () {
    final r = service.compute(
      transactions: [
        tx('MYR', 'me', {'me': 50, 'a': 50}), // A owes Me 50 MYR
        tx('SGD', 'a', {'a': 40, 'me': 40}), // Me owes A 40 SGD
      ],
      participantIds: ['me', 'a'],
    );

    test('two separate currency groups, sorted', () {
      expect(r.map((c) => c.currencyCode).toList(), ['MYR', 'SGD']);
    });

    test('MYR: A pays Me 50', () {
      final myr = r.firstWhere((c) => c.currencyCode == 'MYR');
      expect(myr.consolidated.single.fromPersonId, 'a');
      expect(myr.consolidated.single.toPersonId, 'me');
      expect(myr.consolidated.single.amount, 50);
    });

    test('SGD: Me pays A 40', () {
      final sgd = r.firstWhere((c) => c.currencyCode == 'SGD');
      expect(sgd.consolidated.single.fromPersonId, 'me');
      expect(sgd.consolidated.single.toPersonId, 'a');
      expect(sgd.consolidated.single.amount, 40);
    });
  });

  group('pairwise netting (Req E) — no global minimization', () {
    // Classic 3-person cycle that a global optimizer would collapse but pairwise
    // keeps as direct pair debts.
    // me paid, a & b each owe 30.  a paid, me owes 30.  → net: a→me 0? check.
    final r = service.compute(
      transactions: [
        tx('MYR', 'me', {'me': 30, 'a': 30, 'b': 30}), // a→me30, b→me30
        tx('MYR', 'a', {'a': 15, 'me': 30}), // me→a30
      ],
      participantIds: ['me', 'a', 'b'],
    );
    final debts = r.single.consolidated;

    test('pair {me,a} nets to settled (30 vs 30)', () {
      // a owes me 30, me owes a 30 → net 0, omitted.
      expect(debts.where((d) => {d.fromPersonId, d.toPersonId}.contains('a')),
          isEmpty);
    });

    test('pair {me,b} stays as b pays me 30 (not routed through a)', () {
      final mb = debts.singleWhere((d) => d.fromPersonId == 'b');
      expect(mb.toPersonId, 'me');
      expect(mb.amount, 30);
    });
  });

  group('rounding (Req H) — round-half-up at pair total', () {
    test('nets and rounds half-up', () {
      final r = service.compute(
        transactions: [
          tx('MYR', 'me', {'me': 0, 'a': 33.335}),
        ],
        participantIds: ['me', 'a'],
      );
      expect(r.single.consolidated.single.amount, 33.34);
    });
  });
}
