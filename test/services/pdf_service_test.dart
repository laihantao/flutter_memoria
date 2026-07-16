import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/data/app_database.dart';
import 'package:memora_flutter/services/expense_split_service.dart';
import 'package:memora_flutter/services/pdf_service.dart';

/// Generates the real expense report. These are layout tests: the pdf package
/// asserts during layout, so a section that doesn't fit throws rather than
/// producing a bad document — which is what the export preview surfaced.
///
/// The first export downloads the CJK font, so these need network once.
const _memoryId = 'trip-1';

final _memory = Memory(
  id: _memoryId,
  title: '北海道家族旅行',
  type: '旅行',
  startDate: DateTime(2026, 2, 10),
  endDate: DateTime(2026, 2, 16),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// The seeded expense categories, which is what a real trip draws from.
const _seededCategories = [
  '餐饮', '购物', '日用', '交通', '蔬菜', '水果', '零食', '运动',
  '娱乐', '通讯', '服饰', '美容', '住房', '家庭', '社交', '旅行',
];

Transaction _tx(String id, String cat, double amount, String split, String payer) =>
    Transaction(
      id: id,
      memoryId: _memoryId,
      type: 'expense',
      categoryId: cat,
      amount: amount,
      currencyCode: 'MYR',
      exchangeRateToBase: 1,
      txnDate: DateTime(2026, 2, 10),
      splitType: split,
      payerPersonId: payer,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// A trip spending across [categoryCount] of the seeded categories.
Future<void> _report(int categoryCount, {bool everySection = false}) {
  const people = ['p0', 'p1', 'p2'];
  // Every row AA: a 个人 row is filtered out of 分类占比 unless includePersonal,
  // which would quietly halve the category count under test.
  final txns = [
    for (var i = 0; i < categoryCount; i++)
      _tx('t$i', 'c$i', 1234.56 + i * 700, 'split_aa', 'p0'),
  ];
  final resolved = <ExpenseShares>[
    for (final t in txns)
      (tx: t, shares: {for (final p in people) p: t.amount / people.length}),
  ];
  return PdfService.generateExpenseReport(
    memory: _memory,
    transactions: txns,
    personNames: const {'p0': '我', 'p1': 'Alice', 'p2': 'Bob'},
    categoryNames: {
      for (var i = 0; i < categoryCount; i++) 'c$i': _seededCategories[i],
    },
    splits: [
      CurrencySplit(
        currencyCode: 'MYR',
        statement: PaymentStatement(
          currencyCode: 'MYR',
          rowPersonIds: const ['p1', 'p2'],
          payeePersonIds: const ['p0'],
          cells: const {
            'p1': {'p0': 1500.00},
            'p2': {'p0': 1500.00},
          },
        ),
        consolidated: const [
          ConsolidatedDebt(
              fromPersonId: 'p1',
              toPersonId: 'p0',
              amount: 1500.00,
              currencyCode: 'MYR'),
          ConsolidatedDebt(
              fromPersonId: 'p2',
              toPersonId: 'p0',
              amount: 1500.00,
              currencyCode: 'MYR'),
        ],
      ),
    ],
    resolved: resolved,
    includeStatement: everySection,
    includePersonal: everySection,
  );
}

void main() {
  setUp(PdfService.resetFontCache);

  // 分类占比 puts a table beside the donut. It used to flex that table, and
  // pw.Table sums scaled column widths to a float that can land a hair over the
  // allotment, tripping Expanded's assert and taking the export preview down.
  // Whether it lands over depends on the exact column widths, so this sweeps
  // category counts rather than trusting one; 16 is the case that caught it.
  for (final n in [1, 2, 4, 8, 12, 16]) {
    test('expense report renders across $n categories', () async {
      await expectLater(_report(n), completes);
    });
  }

  test('expense report renders with every section on', () async {
    await expectLater(_report(16, everySection: true), completes);
  });
}
