import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../data/app_database.dart';
import '../../providers/expense_provider.dart';
import '../../providers/person_provider.dart';
import '../../services/expense_split_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme_extension.dart';

/// Expense-report PDF export (Req G — Pocket Gold pattern).
///
/// Section toggles on top (Expenses ON, Statement OFF, Consolidate ON by
/// default) drive a live [PdfPreview] below; print/share/save come from the
/// `printing` package. Data flows through the `memoryId` FK path and the pure
/// [ExpenseSplitService] via [memorySplitResultsProvider].
class ExpenseExportScreen extends ConsumerStatefulWidget {
  final Memory memory;

  const ExpenseExportScreen({super.key, required this.memory});

  @override
  ConsumerState<ExpenseExportScreen> createState() =>
      _ExpenseExportScreenState();
}

class _ExpenseExportScreenState extends ConsumerState<ExpenseExportScreen> {
  bool _expensesTable = true;
  bool _personCosts = true;
  bool _statement = false;
  bool _consolidate = true;
  // Off by default: this PDF goes to the people you're settling with, and your
  // own 个人 purchases are neither theirs to reimburse nor theirs to read.
  bool _personal = false;

  AppThemeExtension get _t =>
      Theme.of(context).extension<AppThemeExtension>()!;

  String get _memoryId => widget.memory.id;

  Future<Uint8List> _build(
    List<Transaction> transactions,
    List<CurrencySplit> splits,
    List<PersonCostTotals> personCosts,
    Map<String, int> sharerCounts,
    Map<String, String> personNames,
    Map<String, String> categoryNames,
  ) {
    return PdfService.generateExpenseReport(
      memory: widget.memory,
      transactions: transactions,
      personNames: personNames,
      categoryNames: categoryNames,
      splits: splits,
      personCosts: personCosts,
      sharerCounts: sharerCounts,
      includeExpensesTable: _expensesTable,
      includePersonCosts: _personCosts,
      includeStatement: _statement,
      includeConsolidate: _consolidate,
      includePersonal: _personal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final txnsAsync = ref.watch(transactionsByMemoryProvider(_memoryId));
    final splitsAsync = ref.watch(memorySplitResultsProvider(_memoryId));
    // 各人收支 must honour the 个人消费 switch, or the PDF would total up rows
    // it doesn't list.
    final costsAsync = ref.watch(memoryPersonCostsProvider(
        (memoryId: _memoryId, includePersonal: _personal)));
    // Head count per AA expense, so the 明细 can print "AA ÷N" and make an
    // exclusion visible without cross-referencing the statement.
    final resolvedAsync = ref.watch(memoryResolvedExpensesProvider(_memoryId));
    final persons = ref.watch(personsProvider).value ?? const [];
    final me = ref.watch(mePersonProvider).value;
    final categories = ref.watch(categoriesProvider(null)).value ?? const [];

    final personNames = <String, String>{
      for (final p in persons) p.id: p.name,
      if (me != null) me.id: me.name,
    };
    final categoryNames = {for (final c in categories) c.id: c.name};

    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('导出 PDF',
            style: TextStyle(color: t.textPrimary, fontSize: 16)),
        iconTheme: IconThemeData(color: t.textSecondary),
      ),
      body: Column(
        children: [
          _buildToggles(),
          Divider(height: 1, color: t.borderColor),
          Expanded(
            child: _buildPreview(txnsAsync, splitsAsync, costsAsync,
                resolvedAsync, personNames, categoryNames),
          ),
        ],
      ),
    );
  }

  Widget _buildToggles() {
    final t = _t;
    Widget row(String label, String hint, bool value,
        ValueChanged<bool> onChanged) {
      return SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        dense: true,
        activeThumbColor: t.accentColor,
        title: Text(label,
            style: TextStyle(color: t.textPrimary, fontSize: 14)),
        subtitle: Text(hint,
            style: TextStyle(color: t.textSecondary, fontSize: 11)),
        value: value,
        onChanged: onChanged,
      );
    }

    return Container(
      color: t.surfaceColor,
      child: Column(
        children: [
          row('支出明细', '所有支出，按币种分组', _expensesTable,
              (v) => setState(() => _expensesTable = v)),
          row('各人收支', '每人付了多少、承担多少、差额', _personCosts,
              (v) => setState(() => _personCosts = v)),
          row('付款表', '谁欠谁多少（矩阵）', _statement,
              (v) => setState(() => _statement = v)),
          row('最终结算', '两两抵消后的应付', _consolidate,
              (v) => setState(() => _consolidate = v)),
          Divider(height: 1, color: t.borderColor),
          row('包含个人消费', '个人消费不参与结算，通常无需给同行人看', _personal,
              (v) => setState(() => _personal = v)),
        ],
      ),
    );
  }

  Widget _buildPreview(
    AsyncValue<List<Transaction>> txnsAsync,
    AsyncValue<List<CurrencySplit>> splitsAsync,
    AsyncValue<List<PersonCostTotals>> costsAsync,
    AsyncValue<List<ResolvedExpense>> resolvedAsync,
    Map<String, String> personNames,
    Map<String, String> categoryNames,
  ) {
    final t = _t;

    // Nothing selected → no document to render. (个人消费 is a filter, not a
    // section — on its own it produces nothing.)
    if (!_expensesTable && !_personCosts && !_statement && !_consolidate) {
      return Center(
        child: Text('请至少选择一个区块',
            style: TextStyle(color: t.textSecondary, fontSize: 13)),
      );
    }

    // The three sources feed one document, so render only once all have landed
    // rather than nesting three .when()s deep.
    final sources = <AsyncValue<Object>>[
      txnsAsync,
      splitsAsync,
      costsAsync,
      resolvedAsync,
    ];
    for (final a in sources) {
      if (a.hasError) return Center(child: Text('加载失败：${a.error}'));
    }
    if (sources.any((a) => !a.hasValue)) {
      return const Center(child: CircularProgressIndicator());
    }

    return PdfPreview(
      // Force a fresh render whenever the selection changes.
      key: ValueKey(Object.hash(
          _expensesTable, _personCosts, _statement, _consolidate, _personal)),
      build: (_) => _build(
          txnsAsync.value!,
          splitsAsync.value!,
          costsAsync.value!,
          {
            for (final r in resolvedAsync.value!)
              if (r.tx.splitType == 'split_aa') r.tx.id: r.shares.length,
          },
          personNames,
          categoryNames),
      allowPrinting: true,
      allowSharing: true,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      pdfFileName: 'memora_expenses_$_memoryId.pdf',
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }
}
