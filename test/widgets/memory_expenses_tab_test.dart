import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/data/app_database.dart';
import 'package:memora_flutter/l10n/app_localizations.dart';
import 'package:memora_flutter/providers/expense_provider.dart';
import 'package:memora_flutter/providers/person_provider.dart';
import 'package:memora_flutter/screens/memory/memory_expenses_tab.dart';
import 'package:memora_flutter/services/expense_split_service.dart';
import 'package:memora_flutter/theme/app_theme.dart';

/// Renders the 费用 dashboard over a fixed trip: one 个人, one 请客 and one AA
/// expense. Every input is a provider, so no database is involved.
///
/// The trip: me and Alice.
///  - 个人  RM 80  — me pays, me bears.
///  - 请客  RM 300 — Alice pays and bears the lot.
///  - AA    RM 100 — me pays, split 50/50 → Alice owes me 50.
const _memoryId = 'trip-1';

final _me = Person(
  id: 'me',
  name: 'Me',
  isSelf: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
final _alice = Person(
  id: 'a',
  name: 'Alice',
  isSelf: false,
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

final _txns = [
  _tx('t1', 80, 'personal', 'me'),
  _tx('t2', 300, 'treat', 'a'),
  _tx('t3', 100, 'split_aa', 'me'),
];

const _category = Category(
  id: 'food',
  name: '餐饮',
  type: 'expense',
  iconName: '🍜',
  isDefault: true,
  sortOrder: 0,
);

// me bears 80 (个人) + 50 (AA half) = 130. Nothing from Alice's 请客.
const _myShares = {'t1': 80.0, 't3': 50.0};

const _personCosts = [
  // me: paid 80 + 100 = 180, borne 130 → owed 50.
  PersonCostTotals(personId: 'me', currencyCode: 'MYR', paid: 180, borne: 130),
  // Alice: paid 300 (请客), borne 300 + 50 = 350 → owes 50.
  PersonCostTotals(personId: 'a', currencyCode: 'MYR', paid: 300, borne: 350),
];

Widget _harness() {
  return ProviderScope(
    overrides: [
      transactionsByMemoryProvider(_memoryId)
          .overrideWith((ref) => Stream.value(_txns)),
      categoriesProvider(null).overrideWith((ref) => Stream.value([_category])),
      memoryBudgetsProvider(_memoryId)
          .overrideWith((ref) => Stream.value(const <MemoryBudget>[])),
      memoryParticipantPersonsProvider(_memoryId)
          .overrideWith((ref) => [_me, _alice]),
      memoryMySharesProvider(_memoryId).overrideWith((ref) async => _myShares),
      memoryPersonCostsProvider((memoryId: _memoryId, includePersonal: true))
          .overrideWith((ref) async => _personCosts),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: const Scaffold(body: MemoryExpensesTab(memoryId: _memoryId)),
    ),
  );
}

/// Pumps on a viewport tall enough for the whole stats ListView to build —
/// otherwise the lower cards stay lazy and finders miss them.
Future<void> _pumpDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness());
  await tester.pumpAndSettle();
}

void main() {
  group('统计 dashboard lenses', () {
    testWidgets('全队 totals every expense at full amount', (tester) async {
      await _pumpDashboard(tester);

      // 80 + 300 + 100, regardless of split mode.
      expect(find.text('全队总消费'), findsOneWidget);
      expect(find.text('RM 480.00'), findsWidgets);
      expect(find.text('3 笔'), findsOneWidget);
    });

    testWidgets('我的 totals only what I bear', (tester) async {
      await _pumpDashboard(tester);
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();

      // 80 (个人) + 50 (my AA half). Alice's 请客 contributes nothing, so it
      // isn't counted as one of my rows either.
      expect(find.text('我实际承担'), findsOneWidget);
      expect(find.text('RM 130.00'), findsWidgets);
      expect(find.text('2 笔'), findsOneWidget);
      expect(find.text('RM 480.00'), findsNothing);
    });

    testWidgets('the budget card is hidden under 我的 — the budget is team-wide',
        (tester) async {
      // A budget is one row per (memory, currency); there is no per-person
      // budget. Showing the same figure under 我的 would invite reading the
      // team's budget as a personal allowance.
      await _pumpDashboard(tester);
      expect(find.text('预算 · 全队'), findsOneWidget);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(find.text('预算 · 全队'), findsNothing);
      expect(find.textContaining('预算'), findsNothing);
    });
  });

  group('各人消费 card', () {
    testWidgets('shows what each person bore, with what they fronted',
        (tester) async {
      await _pumpDashboard(tester);

      expect(find.text('各人消费'), findsOneWidget);
      // 承担 is the headline figure; 垫付 is context.
      expect(find.text('RM 130.00'), findsWidgets); // me bore
      expect(find.text('RM 350.00'), findsOneWidget); // Alice bore
      expect(find.text('垫付 RM 180.00'), findsOneWidget); // me
      expect(find.text('垫付 RM 300.00'), findsOneWidget); // Alice
    });

    testWidgets('never claims 已结清 — net zero does not mean no transfers',
        (tester) async {
      // paid − borne is a *net* position and netting is pairwise, so someone
      // square overall can still owe one person and be owed by another. The
      // card must not editorialise; only the settlement can answer that.
      await _pumpDashboard(tester);
      expect(find.text('已结清'), findsNothing);
      expect(find.textContaining('应收'), findsNothing);
      expect(find.textContaining('应付'), findsNothing);
    });

    testWidgets('is hidden under 我的 — this is a whole-team question',
        (tester) async {
      await _pumpDashboard(tester);
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();

      expect(find.text('各人消费'), findsNothing);
    });
  });
}
