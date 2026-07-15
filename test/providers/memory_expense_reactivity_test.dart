import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/data/app_database.dart';
import 'package:memora_flutter/providers/expense_provider.dart';
import 'package:memora_flutter/providers/person_provider.dart';

/// Regression: the settlement views must track edits.
///
/// `memoryResolvedExpensesProvider` used to read the DAO one-shot, so it froze
/// at whatever existed when the 费用 tab mounted — the (streamed) totals card
/// kept updating while 各人收支 and the 我的 lens showed a stale snapshot. These
/// tests drive the two source streams directly and assert the derived views
/// follow.
const _memoryId = 'trip-1';
const _costsArgs = (memoryId: _memoryId, includePersonal: true);

final _me = Person(
  id: 'me',
  name: 'Me',
  isSelf: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Transaction _tx(String id, double amount, String splitType, String payer) =>
    Transaction(
      id: id,
      memoryId: _memoryId,
      type: 'expense',
      categoryId: 'food',
      amount: amount,
      currencyCode: 'MYR',
      exchangeRateToBase: 1,
      txnDate: DateTime(2026, 7, 1),
      splitType: splitType,
      payerPersonId: payer,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TransactionSplit _split(String txId, String person, double amount) =>
    TransactionSplit(
      id: '$txId-$person',
      transactionId: txId,
      personId: person,
      shareType: 'equal',
      shareAmount: amount,
    );

void main() {
  late StreamController<List<Transaction>> txStream;
  late StreamController<List<TransactionSplit>> splitStream;
  late ProviderContainer container;

  setUp(() {
    txStream = StreamController<List<Transaction>>.broadcast();
    splitStream = StreamController<List<TransactionSplit>>.broadcast();
    container = ProviderContainer(overrides: [
      transactionsByMemoryProvider(_memoryId)
          .overrideWith((ref) => txStream.stream),
      memorySplitRowsProvider(_memoryId)
          .overrideWith((ref) => splitStream.stream),
      memoryParticipantPersonsProvider(_memoryId).overrideWith((ref) => [_me]),
      mePersonProvider.overrideWith((ref) => Stream.value(_me)),
    ]);
    // Subscribe both sources up front. The resolver awaits transactions before
    // it ever reaches the splits watch, so the splits provider wouldn't be
    // mounted yet — and a broadcast stream drops events that have no listener.
    // Real drift streams replay current state on subscribe, so this is a test
    // artifact, not something production hits.
    for (final p in [
      transactionsByMemoryProvider(_memoryId),
      memorySplitRowsProvider(_memoryId),
    ]) {
      final sub = container.listen(p, (_, _) {});
      addTearDown(sub.close);
    }
  });

  tearDown(() {
    container.dispose();
    txStream.close();
    splitStream.close();
  });

  /// Subscribes like the dashboard does, so the provider stays mounted across
  /// emissions — which is the whole point of these tests.
  void mount<T>(ProviderListenable<AsyncValue<T>> p) {
    final sub = container.listen<AsyncValue<T>>(p, (_, _) {});
    addTearDown(sub.close);
  }

  /// Pushes one snapshot of the world onto both streams and lets it settle.
  Future<void> emit(
      List<Transaction> txns, List<TransactionSplit> splits) async {
    txStream.add(txns);
    splitStream.add(splits);
    await pumpEventQueue();
  }

  test('各人收支 recomputes when an expense is added', () async {
    mount(memoryPersonCostsProvider(_costsArgs));
    await emit([], []);
    expect(await container.read(memoryPersonCostsProvider(_costsArgs).future),
        isEmpty);

    // The tab is open; the user adds an expense.
    await emit([_tx('t1', 80, 'personal', 'me')], [_split('t1', 'me', 80)]);

    final rows =
        await container.read(memoryPersonCostsProvider(_costsArgs).future);
    expect(rows, hasLength(1));
    expect(rows.single.personId, 'me');
    expect(rows.single.paid, 80);
    expect(rows.single.borne, 80);
  });

  test('我的 lens recomputes when an expense is added', () async {
    mount(memoryMySharesProvider(_memoryId));
    await emit([], []);
    expect(await container.read(memoryMySharesProvider(_memoryId).future),
        isEmpty);

    await emit([_tx('t1', 100, 'split_aa', 'me')], [_split('t1', 'me', 50)]);

    expect(await container.read(memoryMySharesProvider(_memoryId).future),
        {'t1': 50.0});
  });

  test('settlement recomputes when an expense is added', () async {
    mount(memorySplitResultsProvider(_memoryId));
    await emit([], []);
    expect(await container.read(memorySplitResultsProvider(_memoryId).future),
        isEmpty);

    await emit(
      [_tx('t1', 100, 'split_aa', 'me')],
      [_split('t1', 'me', 50), _split('t1', 'a', 50)],
    );

    final splits =
        await container.read(memorySplitResultsProvider(_memoryId).future);
    expect(splits, hasLength(1));
    expect(splits.single.consolidated.single.fromPersonId, 'a');
    expect(splits.single.consolidated.single.amount, 50);
  });

  test('deleting the last expense empties the views again', () async {
    mount(memoryPersonCostsProvider(_costsArgs));
    await emit([_tx('t1', 80, 'personal', 'me')], [_split('t1', 'me', 80)]);
    expect(await container.read(memoryPersonCostsProvider(_costsArgs).future),
        hasLength(1));

    await emit([], []);
    expect(await container.read(memoryPersonCostsProvider(_costsArgs).future),
        isEmpty);
  });

  test('a split edit alone moves the numbers (splits are watched, not re-read)',
      () async {
    mount(memoryMySharesProvider(_memoryId));
    final tx = _tx('t1', 100, 'split_aa', 'me');
    await emit([tx], [_split('t1', 'me', 50), _split('t1', 'a', 50)]);
    expect(await container.read(memoryMySharesProvider(_memoryId).future),
        {'t1': 50.0});

    // Same transaction row, different sharers — e.g. someone was excluded.
    await emit([tx], [_split('t1', 'me', 100)]);
    expect(await container.read(memoryMySharesProvider(_memoryId).future),
        {'t1': 100.0});
  });
}
