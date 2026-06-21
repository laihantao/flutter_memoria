import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../theme/app_theme.dart';

const _kSymbols = {'MYR': 'RM', 'SGD': 'S\$', 'USD': '\$', 'CNY': '¥', 'EUR': '€'};

class TransactionsScreen extends ConsumerStatefulWidget {
  final String walletId;
  const TransactionsScreen({super.key, required this.walletId});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final Set<String> _selected = {};
  bool _selectMode = false;
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

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider(widget.walletId));
    final allTxAsync = ref.watch(transactionsByWalletProvider(widget.walletId));
    final monthTxAsync = ref.watch(
        transactionsByWalletMonthProvider(
            (widget.walletId, _month.year, _month.month)));
    final categoriesAsync = ref.watch(categoriesProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: walletAsync.when(
          loading: () => Text(context.l10n.transactionsDefaultTitle),
          error: (e, _) => Text(context.l10n.transactionsDefaultTitle),
          data: (w) => Text(w?.name ?? context.l10n.transactionsDefaultTitle),
        ),
        actions: [
          if (_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.label_outline),
              tooltip: context.l10n.transactionsBulkTagTooltip,
              onPressed: () => _showBulkTagDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectMode = false;
                _selected.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _selectMode = true),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push(
                  '/settings/wallets/${widget.walletId}/transactions/new'),
            ),
          ],
        ],
      ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.push(
                  '/settings/wallets/${widget.walletId}/transactions/new'),
              child: const Icon(Icons.add),
            ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (wallet) {
          if (wallet == null) {
            return Center(child: Text(context.l10n.transactionsNotExist));
          }
          final allTxs = allTxAsync.value ?? [];
          final monthTxs = monthTxAsync.value ?? [];
          final cats = {
            for (final c in categoriesAsync.value ?? <Category>[]) c.id: c
          };

          double allIncome = 0, allExpense = 0;
          for (final t in allTxs) {
            if (t.type == 'income') {
              allIncome += t.amount;
            } else {
              allExpense += t.amount;
            }
          }

          double monthIncome = 0, monthExpense = 0;
          for (final t in monthTxs) {
            if (t.type == 'income') {
              monthIncome += t.amount;
            } else {
              monthExpense += t.amount;
            }
          }

          final balance = wallet.initialBalance + allIncome - allExpense;
          final sym = _kSymbols[wallet.currencyCode] ?? wallet.currencyCode;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Dashboard(
                  wallet: wallet,
                  sym: sym,
                  balance: balance,
                  monthIncome: monthIncome,
                  monthExpense: monthExpense,
                  month: _month,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                ),
              ),
              if (monthTxs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 56,
                            color: AppColors.warmBrown.withValues(alpha: 0.25)),
                        const SizedBox(height: 12),
                        Text(context.l10n.transactionsNoRecord),
                      ],
                    ),
                  ),
                )
              else
                ..._buildDayGroups(monthTxs, cats),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDayGroups(
      List<Transaction> txs, Map<String, Category> cats) {
    final Map<String, List<Transaction>> byDay = {};
    for (final t in txs) {
      final key = DateFormat('yyyy-MM-dd').format(t.txnDate);
      byDay.putIfAbsent(key, () => []).add(t);
    }
    final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    final slivers = <Widget>[];
    for (final key in dayKeys) {
      final dayTxs = byDay[key]!;
      slivers.add(SliverToBoxAdapter(
        child: _DayHeader(dateKey: key, transactions: dayTxs),
      ));
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _TxRow(
            tx: dayTxs[i],
            cat: cats[dayTxs[i].categoryId],
            walletId: widget.walletId,
            selectMode: _selectMode,
            selected: _selected.contains(dayTxs[i].id),
            onSelectChanged: (v) => setState(() {
              if (v) {
                _selected.add(dayTxs[i].id);
              } else {
                _selected.remove(dayTxs[i].id);
              }
            }),
          ),
          childCount: dayTxs.length,
        ),
      ));
    }
    return slivers;
  }

  Future<void> _showBulkTagDialog(BuildContext context) async {
    final l10n = context.l10n;
    String inputTag = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.transactionsBulkTagTitle),
        content: TextFormField(
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.transactionsBulkTagHint),
          onChanged: (v) => inputTag = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () async {
              if (inputTag.trim().isEmpty) return;
              final tagId = await ref
                  .read(memoryNotifierProvider.notifier)
                  .createOrGetTag(inputTag.trim());
              await ref
                  .read(expenseNotifierProvider.notifier)
                  .bulkTagTransactions(_selected.toList(), tagId);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {
                _selectMode = false;
                _selected.clear();
              });
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard ──────────────────────────────────────────────────────────────────

class _Dashboard extends StatelessWidget {
  final Wallet wallet;
  final String sym;
  final double balance;
  final double monthIncome;
  final double monthExpense;
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _Dashboard({
    required this.wallet,
    required this.sym,
    required this.balance,
    required this.monthIncome,
    required this.monthExpense,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final monthNet = monthIncome - monthExpense;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x1A4A3728), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x108B7355),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Month nav
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.textSecondary,
                    onPressed: onPrev,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Text(
                    l10n.formatMonthYear(month),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: AppColors.textSecondary,
                    onPressed: onNext,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEED8B8)),
            // 3-column summary: income | expense | net
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCell(
                        label: l10n.transactionsMonthIncome,
                        value: '+$sym ${_fmt(monthIncome)}',
                        color: AppColors.secondaryAccent,
                      ),
                    ),
                    const VerticalDivider(
                      color: Color(0xFFEED8B8),
                      width: 1,
                      thickness: 1,
                    ),
                    Expanded(
                      child: _SummaryCell(
                        label: l10n.transactionsMonthExpense,
                        value: '-$sym ${_fmt(monthExpense)}',
                        color: AppColors.expenseNegative,
                      ),
                    ),
                    const VerticalDivider(
                      color: Color(0xFFEED8B8),
                      width: 1,
                      thickness: 1,
                    ),
                    Expanded(
                      child: _SummaryCell(
                        label: l10n.transactionsSurplus,
                        value: '${monthNet < 0 ? '-' : '+'}$sym ${_fmt(monthNet)}',
                        color: monthNet >= 0
                            ? AppColors.secondaryAccent
                            : AppColors.expenseNegative,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEED8B8)),
            // Donut + account balance
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DonutChart(
                    income: monthIncome,
                    expense: monthExpense,
                    balance: balance,
                    sym: sym,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.transactionsAccountBalance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$sym ${_fmt(balance)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: balance >= 0
                                ? AppColors.secondaryAccent
                                : AppColors.expenseNegative,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.transactionsInitialBalance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$sym ${_fmt(wallet.initialBalance)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v.abs());
}

// ── Summary cell (3-column header stats) ──────────────────────────────────────

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Donut chart ────────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;
  final String sym;

  const _DonutChart({
    required this.income,
    required this.expense,
    required this.balance,
    required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _DonutPainter(income: income, expense: expense),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sym,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10),
              ),
              Text(
                _fmt(balance.abs()),
                style: TextStyle(
                  color: balance >= 0
                      ? AppColors.secondaryAccent
                      : AppColors.expenseNegative,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                balance >= 0
                    ? context.l10n.transactionsSurplus
                    : context.l10n.transactionsOverspend,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _DonutPainter extends CustomPainter {
  final double income;
  final double expense;

  _DonutPainter({required this.income, required this.expense});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeW = 12.0;
    final inset = strokeW / 2 + 2;
    final rect = Rect.fromLTRB(
        inset, inset, size.width - inset, size.height - inset);
    final total = income + expense;

    final bgPaint = Paint()
      ..color = AppColors.warmBeige.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    canvas.drawArc(rect, 0, math.pi * 2, false, bgPaint);

    if (total <= 0) return;

    final incomeFrac = income / total;
    final expenseFrac = expense / total;

    if (income > 0) {
      final p = Paint()
        ..color = AppColors.secondaryAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
          rect, -math.pi / 2, math.pi * 2 * incomeFrac, false, p);
    }

    if (expense > 0) {
      final p = Paint()
        ..color = AppColors.expenseNegative
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
          rect,
          -math.pi / 2 + math.pi * 2 * incomeFrac,
          math.pi * 2 * expenseFrac,
          false,
          p);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.income != income || old.expense != expense;
}

// ── Day header ────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final String dateKey;
  final List<Transaction> transactions;

  const _DayHeader({required this.dateKey, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = DateTime.parse(dateKey);

    double dayExp = 0, dayInc = 0;
    for (final t in transactions) {
      if (t.type == 'expense') {
        dayExp += t.amount;
      } else {
        dayInc += t.amount;
      }
    }
    final sym = _kSymbols[transactions.first.currencyCode] ??
        transactions.first.currencyCode;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5ECD8), // very light warm sand
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3), // coral accent bar
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 7, 16, 7),
      child: Row(
        children: [
          Text(
            '${l10n.formatMonthDay(date)} ${l10n.weekdays[date.weekday]}',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (dayExp > 0)
            Flexible(
              child: Text(
                l10n.dayExpenseLabel(sym, dayExp.toStringAsFixed(2)),
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.expenseNegative),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (dayExp > 0 && dayInc > 0) const SizedBox(width: 6),
          if (dayInc > 0)
            Flexible(
              child: Text(
                l10n.dayIncomeLabel(sym, dayInc.toStringAsFixed(2)),
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryAccent),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Transaction row ───────────────────────────────────────────────────────────

class _TxRow extends StatelessWidget {
  final Transaction tx;
  final Category? cat;
  final String walletId;
  final bool selectMode;
  final bool selected;
  final ValueChanged<bool> onSelectChanged;

  const _TxRow({
    required this.tx,
    required this.cat,
    required this.walletId,
    required this.selectMode,
    required this.selected,
    required this.onSelectChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isExp = tx.type == 'expense';
    final sym = _kSymbols[tx.currencyCode] ?? tx.currencyCode;
    final amtStr =
        '${isExp ? "-" : "+"}$sym ${tx.amount.toStringAsFixed(2)}';

    return InkWell(
      onTap: selectMode
          ? () => onSelectChanged(!selected)
          : () => context.push(
              '/settings/wallets/$walletId/transactions/${tx.id}/edit'),
      child: Container(
        color: selected
            ? AppColors.emphasis.withValues(alpha: 0.12)
            : AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (selectMode)
              Checkbox(
                value: selected,
                onChanged: (v) => onSelectChanged(v ?? false),
              )
            else
              // Icon circle: unified chip-sand background
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.chipBg,
                ),
                child: Center(
                  child: Text(cat?.iconName ?? '•',
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat?.name ?? tx.categoryId,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                  ),
                  if (tx.note != null && tx.note!.isNotEmpty)
                    Text(
                      tx.note!,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              amtStr,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isExp
                    ? AppColors.expenseNegative
                    : AppColors.secondaryAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
