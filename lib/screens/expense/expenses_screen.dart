import 'dart:math' show pi, min, cos, sin;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/expense_provider.dart';

// ── Expense-module palette ────────────────────────────────────────────────────
const _kPageBg  = Color(0xFFF5ECD7);
const _kGold    = Color(0xFFF0C23E);
const _kText    = Color(0xFF1A1A1A);
const _kMuted   = Color(0xFF9B9B9B);
const _kNeg     = Color(0xFFF2637C);
const _kPos     = Color(0xFF5BAD8B);
const _kIconBg  = Color(0xFFFBDCE4);
const _kCardBg  = Color(0xFFFFFFFF);
const _kTrack   = Color(0xFFEEE4CC);
const _kDivider = Color(0xFFF0E8D8);

const _kChartColors = [
  Color(0xFFF28B82), Color(0xFFFFAD8B), Color(0xFFF7C59F),
  Color(0xFFE8B4D0), Color(0xFF9AB5CF), Color(0xFFB5C4B1),
  Color(0xFFD4A5C9), Color(0xFFF0C23E),
];

const _kCurrencySymbols = {
  'MYR': 'RM',  'SGD': 'S\$', 'USD': '\$',  'EUR': '€',
  'CNY': '¥',   'JPY': '¥',   'GBP': '£',   'AUD': 'A\$', 'HKD': 'HK\$',
};

String _sym(String code) => _kCurrencySymbols[code] ?? code;

// ─────────────────────────────────────────────────────────────────────────────
// Top-level shell — owns month state and inner nav index
// ─────────────────────────────────────────────────────────────────────────────

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  int _tabIndex = 0;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  String _title(AppLocalizations l10n) {
    final m = l10n.formatMonthYear(_month);
    switch (_tabIndex) {
      case 1:  return '$m统计';
      case 2:  return '钱包';
      default: return '$m明细';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/memories');
      },
      child: Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kPageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kText),
          onPressed: () => context.go('/memories'),
          tooltip: '返回',
        ),
        title: Text(
          _title(l10n),
          style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          if (_tabIndex == 0)
            IconButton(
              icon: const Icon(Icons.add, color: _kText),
              onPressed: () => context.push('/expenses/new'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Month navigator — shared by all tabs, stays fixed
          _MonthNav(month: _month, l10n: l10n, onPrev: _prevMonth, onNext: _nextMonth),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _DetailTab(month: _month),
                _StatsTab(month: _month),
                const _WalletTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ExpensesNavBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
      ),
    );
  }
}

// ── Inner nav bar (gold) ──────────────────────────────────────────────────────

class _ExpensesNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _ExpensesNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, -1))],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.list_alt_rounded,                label: '明细', selected: currentIndex == 0, onTap: () => onTap(0)),
          _NavItem(icon: Icons.pie_chart_rounded,               label: '统计', selected: currentIndex == 1, onTap: () => onTap(1)),
          _NavItem(icon: Icons.account_balance_wallet_rounded,  label: '钱包', selected: currentIndex == 2, onTap: () => onTap(2)),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
            size: 22,
            color: selected ? _kText : _kText.withValues(alpha: 0.38)),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? _kText : _kText.withValues(alpha: 0.38),
            )),
          const SizedBox(height: 2),
          Container(
            width: 20, height: 2.5,
            decoration: BoxDecoration(
              color: selected ? _kText : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Shared month navigator ────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final AppLocalizations l10n;
  final VoidCallback onPrev, onNext;
  const _MonthNav({required this.month, required this.l10n, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left, color: _kText), onPressed: onPrev),
        Text(l10n.formatMonthYear(month),
          style: const TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w600)),
        IconButton(icon: const Icon(Icons.chevron_right, color: _kText), onPressed: onNext),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL TAB  (明细) — scrollable list with summary table at top
// ─────────────────────────────────────────────────────────────────────────────

class _DetailTab extends ConsumerWidget {
  final DateTime month;
  const _DetailTab({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final txAsync = ref.watch(transactionsByMonthProvider((month.year, month.month)));
    final categoriesAsync = ref.watch(categoriesProvider(null));

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
      data: (txs) {
        final catMap = {for (final c in categoriesAsync.value ?? <Category>[]) c.id: c};
        return _buildList(context, txs, catMap, l10n);
      },
    );
  }

  Widget _buildList(BuildContext context, List<Transaction> txs,
      Map<String, Category> catMap, AppLocalizations l10n) {
    // Per-currency totals
    final Map<String, ({double income, double expense})> byCurrency = {};
    for (final t in txs) {
      final c = t.currencyCode;
      final prev = byCurrency[c] ?? (income: 0.0, expense: 0.0);
      if (t.type == 'income') {
        byCurrency[c] = (income: prev.income + t.amount, expense: prev.expense);
      } else {
        byCurrency[c] = (income: prev.income, expense: prev.expense + t.amount);
      }
    }
    final currencies = byCurrency.keys.toList()
      ..sort((a, b) => a == 'MYR' ? -1 : b == 'MYR' ? 1 : a.compareTo(b));

    // Group transactions by date
    final Map<String, List<Transaction>> byDay = {};
    for (final t in txs) {
      final key = '${t.txnDate.year}-${t.txnDate.month.toString().padLeft(2, '0')}-${t.txnDate.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(t);
    }
    final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    if (txs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: _kMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(l10n.expensesNoRecord, style: const TextStyle(color: _kMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      // item 0 = summary table; items 1+ = day groups
      itemCount: dayKeys.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _SummaryRow(currencies: currencies, byCurrency: byCurrency, l10n: l10n);
        }
        final key = dayKeys[i - 1];
        return _DayGroup(dateKey: key, transactions: byDay[key]!, catMap: catMap, l10n: l10n);
      },
    );
  }
}

// ── Compact summary table (scrolls with list) ─────────────────────────────────
// Header row appears once; one value row per currency (no repeated labels).

class _SummaryRow extends StatelessWidget {
  final List<String> currencies;
  final Map<String, ({double income, double expense})> byCurrency;
  final AppLocalizations l10n;
  const _SummaryRow({required this.currencies, required this.byCurrency, required this.l10n});

  Widget _divider() => Container(width: 1, height: 16, color: _kTrack);

  @override
  Widget build(BuildContext context) {
    final effectiveCurrencies = currencies.isEmpty ? ['MYR'] : currencies;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header row — labels shown once
          Row(
            children: [
              Expanded(child: Text(l10n.expensesMonthBalance, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: _kMuted))),
              _divider(),
              Expanded(child: Text(l10n.expensesMonthExpense, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: _kMuted))),
              _divider(),
              Expanded(child: Text(l10n.expensesMonthIncome, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: _kMuted))),
            ],
          ),
          const SizedBox(height: 8),
          // One value row per currency
          for (int i = 0; i < effectiveCurrencies.length; i++) ...[
            if (i > 0) const Divider(height: 10, indent: 16, endIndent: 16, color: _kTrack),
            _SummaryValRow(
              symbol: _sym(effectiveCurrencies[i]),
              balance: currencies.isEmpty ? 0 : byCurrency[effectiveCurrencies[i]]!.income - byCurrency[effectiveCurrencies[i]]!.expense,
              expense: currencies.isEmpty ? 0 : byCurrency[effectiveCurrencies[i]]!.expense,
              income: currencies.isEmpty ? 0 : byCurrency[effectiveCurrencies[i]]!.income,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryValRow extends StatelessWidget {
  final String symbol;
  final double balance, expense, income;
  const _SummaryValRow({required this.symbol, required this.balance, required this.expense, required this.income});

  Widget _vdiv() => Container(width: 1, height: 24, color: _kTrack);

  @override
  Widget build(BuildContext context) {
    final isNeg = balance < 0;
    return Row(
      children: [
        Expanded(child: Text(
          '${isNeg ? "- " : ""}$symbol ${balance.abs().toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isNeg ? _kNeg : _kPos),
        )),
        _vdiv(),
        Expanded(child: Text(
          '$symbol ${expense.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kText),
        )),
        _vdiv(),
        Expanded(child: Text(
          income == 0 ? '暂无' : '$symbol ${income.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kText),
        )),
      ],
    );
  }
}

// ── Day group ─────────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final String dateKey;
  final List<Transaction> transactions;
  final Map<String, Category> catMap;
  final AppLocalizations l10n;
  const _DayGroup({required this.dateKey, required this.transactions, required this.catMap, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(dateKey);
    final weekday = l10n.weekdays[date.weekday];
    final dateLabel = l10n.formatMonthDay(date);

    // Daily balance per currency
    final Map<String, double> dayBal = {};
    for (final t in transactions) {
      dayBal[t.currencyCode] = (dayBal[t.currencyCode] ?? 0) +
          (t.type == 'income' ? t.amount : -t.amount);
    }
    final balStr = dayBal.entries.map((e) {
      final v = e.value;
      return '${v < 0 ? "- " : ""}${_sym(e.key)} ${v.abs().toStringAsFixed(2)}';
    }).join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header: gold accent bar | date + weekday | balance
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 3, height: 14,
                    decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('$dateLabel $weekday',
                    style: const TextStyle(fontSize: 13, color: _kText, fontWeight: FontWeight.w500)),
                ],
              ),
              Text('结余 $balStr', style: const TextStyle(fontSize: 12, color: _kMuted)),
            ],
          ),
        ),
        // Transactions card
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              for (int i = 0; i < transactions.length; i++) ...[
                _TxRow(tx: transactions[i], cat: catMap[transactions[i].categoryId]),
                if (i < transactions.length - 1)
                  const Divider(height: 1, indent: 64, endIndent: 16, color: _kDivider),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ── Transaction row ───────────────────────────────────────────────────────────

class _TxRow extends StatelessWidget {
  final Transaction tx;
  final Category? cat;
  const _TxRow({required this.tx, this.cat});

  @override
  Widget build(BuildContext context) {
    final isExpense = tx.type == 'expense';
    final symbol = _sym(tx.currencyCode);
    final amountStr = '${isExpense ? "- " : "+ "}$symbol ${tx.amount.toStringAsFixed(2)}';

    return InkWell(
      onTap: () => context.push('/expenses/${tx.id}/edit'),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(color: _kIconBg, shape: BoxShape.circle),
              child: Center(child: Text(cat?.iconName ?? '•', style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat?.name ?? tx.categoryId,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kText)),
                  if ((tx.note ?? '').isNotEmpty)
                    Text(tx.note!,
                      style: const TextStyle(fontSize: 12, color: _kMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(amountStr,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isExpense ? _kNeg : _kPos)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS TAB  (统计)
// ─────────────────────────────────────────────────────────────────────────────

class _StatsTab extends ConsumerStatefulWidget {
  final DateTime month;
  const _StatsTab({required this.month});

  @override
  ConsumerState<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<_StatsTab> {
  String _type = 'expense';

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsByMonthProvider((widget.month.year, widget.month.month)));
    final categoriesAsync = ref.watch(categoriesProvider(null));

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('错误: $e')),
      data: (txs) {
        final catMap = {for (final c in categoriesAsync.value ?? <Category>[]) c.id: c};
        final filtered = txs.where((t) => t.type == _type).toList();
        return _buildStats(filtered, catMap);
      },
    );
  }

  Widget _buildStats(List<Transaction> txs, Map<String, Category> catMap) {
    // Aggregate by category
    final Map<String, double> byCategory = {};
    for (final t in txs) {
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amount;
    }
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = byCategory.values.fold(0.0, (a, b) => a + b);
    final maxCatAmt = sortedCats.isNotEmpty ? sortedCats.first.value : 1.0;

    final sortedTxs = (List<Transaction>.from(txs)..sort((a, b) => b.amount.compareTo(a.amount))).take(10).toList();
    final sym = _sym(txs.isNotEmpty ? txs.first.currencyCode : 'MYR');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 支出 / 收入 toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ToggleText(label: '支出', selected: _type == 'expense', onTap: () => setState(() => _type = 'expense')),
              const Text(' / ', style: TextStyle(color: _kMuted, fontSize: 15)),
              _ToggleText(label: '收入', selected: _type == 'income', onTap: () => setState(() => _type = 'income')),
            ],
          ),
          const SizedBox(height: 12),

          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(
                '本月暂无${_type == 'expense' ? '支出' : '收入'}记录',
                style: const TextStyle(color: _kMuted, fontSize: 14),
              )),
            )
          else ...[
            // Donut chart
            _StatCard(
              title: _type == 'expense' ? '支出占比概况' : '收入占比概况',
              child: _DonutSection(
                segments: sortedCats.asMap().entries.map((e) => _Segment(
                  label: catMap[e.value.key]?.name ?? e.value.key,
                  value: e.value.value,
                  color: _kChartColors[e.key % _kChartColors.length],
                )).toList(),
                total: total,
                symbol: sym,
              ),
            ),
            const SizedBox(height: 12),

            // Category ranking
            _StatCard(
              title: _type == 'expense' ? '支出类目排行' : '收入类目排行',
              child: Column(
                children: sortedCats.asMap().entries.map((e) => _CatRankItem(
                  icon: catMap[e.value.key]?.iconName ?? '•',
                  name: catMap[e.value.key]?.name ?? e.value.key,
                  amount: e.value.value,
                  symbol: sym,
                  ratio: e.value.value / maxCatAmt,
                  count: txs.where((t) => t.categoryId == e.value.key).length,
                  isExpense: _type == 'expense',
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Transaction ranking (top 10)
            _StatCard(
              title: _type == 'expense' ? '支出明细排行' : '收入明细排行',
              child: Column(
                children: [
                  for (int i = 0; i < sortedTxs.length; i++) ...[
                    _TxRankItem(tx: sortedTxs[i], cat: catMap[sortedTxs[i].categoryId], isExpense: _type == 'expense'),
                    if (i < sortedTxs.length - 1)
                      const Divider(height: 1, indent: 54, color: _kDivider),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleText extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleText({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Text(label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? _kText : _kMuted,
      )),
  );
}

// ── Donut chart + legend ──────────────────────────────────────────────────────

class _Segment {
  final String label;
  final double value;
  final Color color;
  const _Segment({required this.label, required this.value, required this.color});
}

class _DonutSection extends StatelessWidget {
  final List<_Segment> segments;
  final double total;
  final String symbol;
  const _DonutSection({required this.segments, required this.total, required this.symbol});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(double.infinity, 200),
              painter: _DonutPainter(
                values: segments.map((s) => s.value).toList(),
                colors: segments.map((s) => s.color).toList(),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('总计', style: TextStyle(fontSize: 11, color: _kMuted)),
                const SizedBox(height: 2),
                Text('$symbol ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kText)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Legend
      Wrap(
        spacing: 14, runSpacing: 8,
        children: segments.map((s) {
          final pct = total > 0 ? (s.value / total * 100).round() : 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 4),
              Text('${s.label} $pct%', style: const TextStyle(fontSize: 12, color: _kText)),
            ],
          );
        }).toList(),
      ),
    ],
  );
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outerR = min(size.width, size.height) / 2 - 8;
    final innerR = outerR * 0.58;
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    // Draw segments
    double start = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: outerR),
        start, sweep, true,
        Paint()..color = colors[i % colors.length]..style = PaintingStyle.fill,
      );
      start += sweep;
    }

    // White separation lines from center → edge at each segment boundary
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    start = -pi / 2;
    for (final v in values) {
      canvas.drawLine(
        c,
        Offset(c.dx + outerR * cos(start), c.dy + outerR * sin(start)),
        linePaint,
      );
      start += v / total * 2 * pi;
    }

    // White center hole to form the donut
    canvas.drawCircle(c, innerR, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

// ── Stat card wrapper ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _StatCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kText)),
        const SizedBox(height: 6),
        const Divider(color: _kTrack),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

// ── Category rank item ────────────────────────────────────────────────────────

class _CatRankItem extends StatelessWidget {
  final String icon, name, symbol;
  final double amount, ratio;
  final int count;
  final bool isExpense;
  const _CatRankItem({
    required this.icon, required this.name, required this.symbol,
    required this.amount, required this.ratio, required this.count,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(color: _kIconBg, shape: BoxShape.circle),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kText)),
                  Text('${isExpense ? '支出' : '收入'}$count笔',
                    style: const TextStyle(fontSize: 12, color: _kMuted)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: _kTrack,
                  valueColor: const AlwaysStoppedAnimation(_kNeg),
                ),
              ),
              const SizedBox(height: 3),
              Text('本月共${isExpense ? '支出' : '收入'}：$symbol ${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: _kMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Transaction rank item ─────────────────────────────────────────────────────

class _TxRankItem extends StatelessWidget {
  final Transaction tx;
  final Category? cat;
  final bool isExpense;
  const _TxRankItem({required this.tx, this.cat, required this.isExpense});

  @override
  Widget build(BuildContext context) {
    final symbol = _sym(tx.currencyCode);
    final amtStr = '${isExpense ? "- " : "+ "}$symbol ${tx.amount.toStringAsFixed(2)}';

    final datePart = '${tx.txnDate.month.toString().padLeft(2, '0')}.${tx.txnDate.day.toString().padLeft(2, '0')}';
    final parts = <String>[datePart];
    if ((tx.title ?? '').isNotEmpty) parts.add(tx.title!);
    if ((tx.note ?? '').isNotEmpty) parts.add(tx.note!);
    final subtitle = parts.join(' · ');

    return InkWell(
      onTap: () => context.push('/expenses/${tx.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(color: _kIconBg, shape: BoxShape.circle),
              child: Center(child: Text(cat?.iconName ?? '•', style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat?.name ?? tx.categoryId,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kText)),
                  Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: _kMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(amtStr,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kText)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WALLET TAB  (钱包)
// ─────────────────────────────────────────────────────────────────────────────

class _WalletTab extends ConsumerWidget {
  const _WalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletsProvider);

    return walletsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('错误: $e')),
      data: (wallets) => wallets.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: _kMuted),
                  SizedBox(height: 12),
                  Text('暂无钱包', style: TextStyle(color: _kMuted)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: wallets.length,
              itemBuilder: (ctx, i) => _WalletCard(wallet: wallets[i]),
            ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final Wallet wallet;
  const _WalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/settings/wallets/${wallet.id}/transactions'),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: _kText, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallet.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kText)),
                Text(wallet.currencyCode, style: const TextStyle(fontSize: 13, color: _kMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _kMuted, size: 20),
        ],
      ),
    ),
  );
}
