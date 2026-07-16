import 'dart:math' show pi, min, cos, sin;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/person_provider.dart';
import '../../services/expense_split_service.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/money.dart';

/// Rejects any edit that isn't a valid money amount: digits, at most one
/// decimal point, at most two decimal places. Guards keyboards (web/desktop)
/// that would otherwise let letters through a numeric TextField.
class MoneyInputFormatter extends TextInputFormatter {
  static final _re = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    return _re.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// Theme-agnostic pastel palette for the category donut.
const _kChartColors = [
  Color(0xFFF28B82), Color(0xFFFFAD8B), Color(0xFFF7C59F),
  Color(0xFFE8B4D0), Color(0xFF9AB5CF), Color(0xFFB5C4B1),
  Color(0xFFD4A5C9), Color(0xFFF0C23E),
];

/// Memory-detail 费用 tab: 统计 dashboard + 明细 list.
///
/// Multi-currency by design — amounts are grouped and shown per currency,
/// never converted (no exchange-rate guessing).
class MemoryExpensesTab extends ConsumerStatefulWidget {
  final String memoryId;
  const MemoryExpensesTab({super.key, required this.memoryId});

  @override
  ConsumerState<MemoryExpensesTab> createState() => _MemoryExpensesTabState();
}

class _MemoryExpensesTabState extends ConsumerState<MemoryExpensesTab> {
  int _view = 0; // 0 = 统计, 1 = 明细
  int _lens = 0; // 0 = 全队, 1 = 我的
  String? _donutCurrency; // null → dominant currency

  AppThemeExtension get _t =>
      Theme.of(context).extension<AppThemeExtension>()!;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final txAsync = ref.watch(transactionsByMemoryProvider(widget.memoryId));
    final catAsync = ref.watch(categoriesProvider(null));
    final budgetsAsync = ref.watch(memoryBudgetsProvider(widget.memoryId));

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
      data: (txns) {
        final budgets = budgetsAsync.value ?? const <MemoryBudget>[];
        if (txns.isEmpty && budgets.isEmpty) return _emptyState(l10n);

        final catMap = {
          for (final c in catAsync.value ?? <Category>[]) c.id: c
        };
        return Column(
          children: [
            _SegmentedToggle(
              index: _view,
              labels: [
                '📊 ${l10n.memoryExpensesStatsTab}',
                '🧾 ${l10n.memoryExpensesListTab}',
              ],
              onChanged: (i) => setState(() => _view = i),
            ),
            Expanded(
              child: _view == 0
                  ? _StatsView(
                      memoryId: widget.memoryId,
                      txns: txns,
                      budgets: budgets,
                      catMap: catMap,
                      lens: _lens,
                      onLens: (i) => setState(() => _lens = i),
                      donutCurrency: _donutCurrency,
                      onDonutCurrency: (c) =>
                          setState(() => _donutCurrency = c),
                    )
                  : _DetailList(
                      memoryId: widget.memoryId, txns: txns, catMap: catMap),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    final t = _t;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: t.textSecondary),
          const SizedBox(height: 12),
          Text(l10n.memoryNoExpenses),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () =>
                context.push('/memories/${widget.memoryId}/expenses/new'),
            icon: const Icon(Icons.add),
            label: Text(l10n.memoryRecordExpense),
          ),
          TextButton(
            onPressed: () => showBudgetSheet(context, ref, widget.memoryId),
            child: Text(l10n.memoryBudgetSetButton),
          ),
        ],
      ),
    );
  }
}

// ── Segmented toggle ──────────────────────────────────────────────────────────

class _SegmentedToggle extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _SegmentedToggle(
      {required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.mutedColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? t.surfaceColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: t.cardShadow.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? t.textPrimary : t.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── 统计 view ─────────────────────────────────────────────────────────────────

/// 统计 dashboard, read through one of two lenses:
///
/// - **全队** — every expense at its full amount, whatever the split mode.
///   Answers "what did this trip cost in total".
/// - **我的** — only what *I* bear: my 个人 expenses in full, my per-head slice
///   of each AA, the full amount of a 请客 I hosted, nothing for one I didn't.
///   Answers "what did this trip cost me".
///
/// A budget is one row per (memory, currency) — there is no per-person budget to
/// show, so the budget card only appears under 全队, measured against team spend.
class _StatsView extends ConsumerWidget {
  final String memoryId;
  final List<Transaction> txns;
  final List<MemoryBudget> budgets;
  final Map<String, Category> catMap;
  final int lens; // 0 = 全队, 1 = 我的
  final ValueChanged<int> onLens;
  final String? donutCurrency;
  final ValueChanged<String> onDonutCurrency;
  const _StatsView({
    required this.memoryId,
    required this.txns,
    required this.budgets,
    required this.catMap,
    required this.lens,
    required this.onLens,
    required this.donutCurrency,
    required this.onDonutCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;
    final mine = lens == 1;
    final myShares = ref.watch(memoryMySharesProvider(memoryId)).value;

    if (mine && myShares == null) {
      return const Center(child: CircularProgressIndicator());
    }

    /// What this row contributes under the current lens.
    double weight(Transaction tx) =>
        mine ? (myShares![tx.id] ?? 0) : tx.amount;

    // Per-currency expense totals (income excluded — legacy rows only).
    final spentByCurrency = <String, double>{};
    final countByCurrency = <String, int>{};
    for (final tx in txns) {
      if (tx.type != 'expense') continue;
      final w = weight(tx);
      // Under 我的, a row I bear none of isn't mine to count at all.
      if (mine && w == 0) continue;
      spentByCurrency[tx.currencyCode] =
          (spentByCurrency[tx.currencyCode] ?? 0) + w;
      countByCurrency[tx.currencyCode] =
          (countByCurrency[tx.currencyCode] ?? 0) + 1;
    }
    final currencies = spentByCurrency.keys.toList()..sort();

    // Donut defaults to the currency with the most rows.
    var donutCcy = donutCurrency;
    if (donutCcy == null || !spentByCurrency.containsKey(donutCcy)) {
      var best = -1;
      for (final e in countByCurrency.entries) {
        if (e.value > best) {
          best = e.value;
          donutCcy = e.key;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _SegmentedToggle(
          index: lens,
          labels: [l10n.memoryLensTeam, l10n.memoryLensMine],
          onChanged: onLens,
        ),
        const SizedBox(height: 8),
        // 我的 asks what this trip cost *me*; the budget is a whole-memory
        // figure, so pairing it with my slice would compare unlike things.
        if (!mine) ...[
          _BudgetCard(
            memoryId: memoryId,
            budgets: budgets,
            spentByCurrency: spentByCurrency,
          ),
          const SizedBox(height: 12),
        ],
        if (currencies.isNotEmpty) ...[
          _TotalsCard(
            spentByCurrency: spentByCurrency,
            countByCurrency: countByCurrency,
            mine: mine,
          ),
          const SizedBox(height: 12),
          if (donutCcy != null)
            _CategoryCard(
              txns: txns,
              catMap: catMap,
              currencies: currencies,
              currency: donutCcy,
              onCurrency: onDonutCurrency,
              weight: weight,
            ),
          // 收支 is a whole-team question — it has no meaning under 我的.
          if (!mine) ...[
            const SizedBox(height: 12),
            _PersonCostsCard(memoryId: memoryId, catMap: catMap),
          ],
        ] else
          _StatCard(
            title: mine ? l10n.memoryMyExpenses : l10n.memoryTotalExpenses,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  mine ? l10n.memoryNoMyExpenses : l10n.memoryNoExpensesYet,
                  style: GoogleFonts.notoSansSc(
                      fontSize: 13, color: t.textSecondary)),
            ),
          ),
      ],
    );
  }
}

// ── Card shell ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _StatCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow.withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 14,
            spreadRadius: -9,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.notoSansSc(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary)),
              ?action,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Budget card ───────────────────────────────────────────────────────────────

/// Only rendered under the 全队 lens — see [_StatsView].
class _BudgetCard extends ConsumerWidget {
  final String memoryId;
  final List<MemoryBudget> budgets;
  final Map<String, double> spentByCurrency;
  const _BudgetCard({
    required this.memoryId,
    required this.budgets,
    required this.spentByCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;

    return _StatCard(
      title: l10n.memoryBudgetTeamTitle,
      action: IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.edit_outlined, size: 18, color: t.textSecondary),
        onPressed: () => showBudgetSheet(context, ref, memoryId),
        tooltip: l10n.memoryBudgetEditTooltip,
      ),
      child: budgets.isEmpty
          ? InkWell(
              onTap: () => showBudgetSheet(context, ref, memoryId),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline,
                        size: 18, color: t.accentColor),
                    const SizedBox(width: 8),
                    Text(l10n.memoryBudgetSetCta,
                        style: GoogleFonts.notoSansSc(
                            fontSize: 13, color: t.accentColor)),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < budgets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _BudgetRow(
                    budget: budgets[i],
                    spent: spentByCurrency[budgets[i].currencyCode] ?? 0,
                  ),
                ],
                const SizedBox(height: 8),
                Text(l10n.memoryBudgetTeamOnlyHint,
                    style: GoogleFonts.notoSansSc(
                        fontSize: 11, color: t.textSecondary)),
              ],
            ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final MemoryBudget budget;
  final double spent;
  const _BudgetRow({required this.budget, required this.spent});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final over = spent > budget.amount;
    final remaining = budget.amount - spent;
    final progress =
        budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
    final overColor = Colors.red.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatMoneyWithSymbol(budget.amount, budget.currencyCode),
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary),
            ),
            Text(
              over
                  ? context.l10n.memoryBudgetOver(
                      formatMoneyWithSymbol(-remaining, budget.currencyCode))
                  : context.l10n.memoryBudgetLeft(
                      formatMoneyWithSymbol(remaining, budget.currencyCode)),
              style: GoogleFonts.notoSansSc(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: over ? overColor : t.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: t.mutedColor,
            valueColor:
                AlwaysStoppedAnimation(over ? overColor : t.accentColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.memoryBudgetSpent(
              formatMoneyWithSymbol(spent, budget.currencyCode)),
          style:
              GoogleFonts.notoSansSc(fontSize: 11, color: t.textSecondary),
        ),
      ],
    );
  }
}

// ── Totals card ───────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final Map<String, double> spentByCurrency;
  final Map<String, int> countByCurrency;
  final bool mine;
  const _TotalsCard({
    required this.spentByCurrency,
    required this.countByCurrency,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final currencies = spentByCurrency.keys.toList()..sort();

    return _StatCard(
      title: mine
          ? context.l10n.memoryMyShareTitle
          : context.l10n.memoryTeamTotalTitle,
      child: Column(
        children: [
          for (int i = 0; i < currencies.length; i++) ...[
            if (i > 0)
              Divider(height: 16, color: t.borderColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatMoneyWithSymbol(
                      spentByCurrency[currencies[i]]!, currencies[i]),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary),
                ),
                Text(
                  context.l10n.memoryTxnCount(countByCurrency[currencies[i]]!),
                  style: GoogleFonts.notoSansSc(
                      fontSize: 12, color: t.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Category donut card ───────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final List<Transaction> txns;
  final Map<String, Category> catMap;
  final List<String> currencies;
  final String currency;
  final ValueChanged<String> onCurrency;
  /// What each row contributes under the active lens (full amount, or my share).
  final double Function(Transaction) weight;
  const _CategoryCard({
    required this.txns,
    required this.catMap,
    required this.currencies,
    required this.currency,
    required this.onCurrency,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;

    final byCategory = <String, double>{};
    for (final tx in txns) {
      if (tx.type != 'expense' || tx.currencyCode != currency) continue;
      final w = weight(tx);
      if (w == 0) continue;
      byCategory[tx.categoryId] = (byCategory[tx.categoryId] ?? 0) + w;
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = byCategory.values.fold(0.0, (a, b) => a + b);

    return _StatCard(
      title: context.l10n.memoryCategoryBreakdown,
      action: currencies.length > 1
          ? Wrap(
              spacing: 4,
              children: currencies.map((c) {
                final selected = c == currency;
                return GestureDetector(
                  onTap: () => onCurrency(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected ? t.accentColor : t.mutedColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      c,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? (ThemeData.estimateBrightnessForColor(
                                        t.accentColor) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black87)
                            : t.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          : null,
      child: total <= 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(context.l10n.memoryNoSpendInCurrency,
                  style: GoogleFonts.notoSansSc(
                      fontSize: 13, color: t.textSecondary)),
            )
          : Column(
              children: [
                SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _DonutPainter(
                          values: sorted.map((e) => e.value).toList(),
                          colors: [
                            for (int i = 0; i < sorted.length; i++)
                              _kChartColors[i % _kChartColors.length],
                          ],
                          holeColor: t.surfaceColor,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.l10n.memoryTotal,
                              style: GoogleFonts.notoSansSc(
                                  fontSize: 11, color: t.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            formatMoneyWithSymbol(total, currency),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: t.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < sorted.length; i++)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color:
                                  _kChartColors[i % _kChartColors.length],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${catMap[sorted[i].key]?.name ?? sorted[i].key} '
                            '${(sorted[i].value / total * 100).round()}%',
                            style: GoogleFonts.notoSansSc(
                                fontSize: 12, color: t.textPrimary),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color holeColor;
  const _DonutPainter(
      {required this.values, required this.colors, required this.holeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outerR = min(size.width, size.height) / 2 - 8;
    final innerR = outerR * 0.58;
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    double start = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: outerR),
        start, sweep, true,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.fill,
      );
      start += sweep;
    }

    // Separation lines + center hole in the card's surface color so the
    // donut visually sits on the card in any theme.
    final linePaint = Paint()
      ..color = holeColor
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
    canvas.drawCircle(
        c, innerR, Paint()..color = holeColor..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.holeColor != holeColor;
}

// ── 各人消费 card ─────────────────────────────────────────────────────────────

/// What the trip cost each person (承担), with what they fronted (付款) as
/// context.
///
/// Deliberately shows no 差额 / 已结清. paid − borne is a person's *net*
/// position, and netting is pairwise: someone can be square overall and still
/// owe one companion while another owes them, so "已结清" would be a lie
/// exactly when it matters. Who-pays-whom is the PDF statement's job.
///
/// Each row expands to the expenses behind its 承担 figure — the RM 26 + 7.60 +
/// 16.25 that makes a bare "RM 49.85" trustworthy without opening every expense.
class _PersonCostsCard extends ConsumerStatefulWidget {
  final String memoryId;
  final Map<String, Category> catMap;
  const _PersonCostsCard({required this.memoryId, required this.catMap});

  @override
  ConsumerState<_PersonCostsCard> createState() => _PersonCostsCardState();
}

class _PersonCostsCardState extends ConsumerState<_PersonCostsCard> {
  /// Expanded rows, by [personBorneKey]. Person+currency, not person: the same
  /// person has one row per currency and they open independently.
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;
    // This dashboard is the user's own — nothing to withhold, unlike the
    // shared PDF, so 个人 rows count toward 付款/承担 here.
    const includePersonal = true;
    final args = (memoryId: widget.memoryId, includePersonal: includePersonal);
    final rows = ref.watch(memoryPersonCostsProvider(args)).value;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final breakdown =
        ref.watch(memoryPersonBreakdownProvider(args)).value ?? const {};

    final roster = ref.watch(memoryParticipantPersonsProvider(widget.memoryId));
    final names = {for (final p in roster) p.id: p.name};
    String label(String id) => names[id] ?? l10n.memoryPersonRemoved;

    // Group by currency, preserving the service's (sorted) currency order.
    final byCurrency = <String, List<PersonCostTotals>>{};
    for (final r in rows) {
      (byCurrency[r.currencyCode] ??= []).add(r);
    }

    final keys = [
      for (final r in rows) personBorneKey(r.personId, r.currencyCode),
    ];
    final allOpen = keys.every(_expanded.contains);

    return _StatCard(
      title: l10n.memoryPerPersonTitle,
      action: TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => setState(() {
          _expanded.clear();
          if (!allOpen) _expanded.addAll(keys);
        }),
        child: Text(
          allOpen
              ? l10n.memoryPerPersonCollapseAll
              : l10n.memoryPerPersonExpandAll,
          style: GoogleFonts.notoSansSc(
              fontSize: 12, fontWeight: FontWeight.w600, color: t.accentColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in byCurrency.entries) ...[
            if (byCurrency.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(entry.key,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.textSecondary)),
              ),
            for (int i = 0; i < entry.value.length; i++) ...[
              if (i > 0) Divider(height: 14, color: t.borderColor),
              Builder(builder: (context) {
                final key = personBorneKey(
                    entry.value[i].personId, entry.value[i].currencyCode);
                return _PersonCostRow(
                  name: label(entry.value[i].personId),
                  totals: entry.value[i],
                  lines: breakdown[key] ?? const [],
                  catMap: widget.catMap,
                  expanded: _expanded.contains(key),
                  onToggle: () => setState(() =>
                      _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key)),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}

class _PersonCostRow extends StatelessWidget {
  final String name;
  final PersonCostTotals totals;
  final List<BorneLine> lines;
  final Map<String, Category> catMap;
  final bool expanded;
  final VoidCallback onToggle;
  const _PersonCostRow({
    required this.name,
    required this.totals,
    required this.lines,
    required this.catMap,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final c = totals.currencyCode;
    // Nothing to open when the breakdown hasn't loaded (or a roster-drift row
    // has no lines) — don't offer an affordance that expands to emptiness.
    final canExpand = lines.isNotEmpty;
    final open = expanded && canExpand;

    return Column(
      children: [
        InkWell(
          onTap: canExpand ? onToggle : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: t.mutedColor,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 11, color: t.textSecondary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.notoSansSc(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.memoryPaidUpfront(
                            formatMoneyWithSymbol(totals.paid, c)),
                        style: GoogleFonts.notoSansSc(
                            fontSize: 11.5, color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoneyWithSymbol(totals.borne, c),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary),
                ),
                if (canExpand)
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 18, color: t.textSecondary),
                  )
                else
                  const SizedBox(width: 18),
              ],
            ),
          ),
        ),
        // AnimatedSize, not AnimatedCrossFade: a collapsed breakdown must leave
        // the tree, not merely stop being painted — it is still a11y-reachable
        // and findable otherwise.
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? _BorneBreakdown(lines: lines, catMap: catMap)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The expenses behind one person's 承担: what it was, and how their slice of it
/// was arrived at (`RM 130.00 ÷ 5`).
class _BorneBreakdown extends StatelessWidget {
  final List<BorneLine> lines;
  final Map<String, Category> catMap;
  const _BorneBreakdown({required this.lines, required this.catMap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;

    return Container(
      // Indented under the name, not the avatar, so it reads as that person's.
      margin: const EdgeInsets.only(left: 36, top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.mutedColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (int i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Builder(builder: (context) {
              final line = lines[i];
              final tx = line.tx;
              final ccy = tx.currencyCode;
              final note = (tx.note ?? '').trim();
              final title = note.isNotEmpty
                  ? note
                  : (catMap[tx.categoryId]?.name ?? tx.categoryId);
              // ÷1 is noise — 个人/请客 bear the whole amount, and the amount
              // alone already says so.
              final formula = line.sharerCount > 1
                  ? '${formatMoneyWithSymbol(tx.amount, ccy)} ÷ ${line.sharerCount}'
                  : formatMoneyWithSymbol(tx.amount, ccy);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansSc(
                              fontSize: 12, color: t.textPrimary),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${l10n.formatMonthDay(tx.txnDate)} · $formula',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatMoneyWithSymbol(line.share, ccy),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── 明细 list ─────────────────────────────────────────────────────────────────

/// Small 分摊方式 tag on a 明细 row — 个人 / AA / 请客 at a glance, without
/// opening the expense.
class _SplitBadge extends StatelessWidget {
  final String splitType;
  const _SplitBadge({required this.splitType});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final label = context.l10n.splitTypeName(splitType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.mutedColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansSc(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: t.textSecondary),
      ),
    );
  }
}

class _DetailList extends ConsumerWidget {
  final String memoryId;
  final List<Transaction> txns;
  final Map<String, Category> catMap;
  const _DetailList(
      {required this.memoryId, required this.txns, required this.catMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Roster resolves payer ids to names for the 请客 "who paid" line.
    final roster = ref.watch(memoryParticipantPersonsProvider(memoryId));
    final names = {for (final p in roster) p.id: p.name};

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: txns.length,
      itemBuilder: (context, i) {
        final tx = txns[i];
        return _ExpenseRow(
          key: ValueKey(tx.id),
          tx: tx,
          category: catMap[tx.categoryId],
          payerName: tx.payerPersonId == null
              ? null
              : names[tx.payerPersonId] ?? context.l10n.memoryPersonRemoved,
          onEdit: () =>
              context.push('/memories/$memoryId/expenses/${tx.id}/edit'),
          onConfirmDelete: () => _confirmDelete(context, ref, tx),
        );
      },
    );
  }

  /// Confirmation → delete → feedback. Returns true when the row was deleted, so
  /// the swipe wrapper knows whether to spring shut (cancelled) or let the list
  /// drop the row (deleted).
  Future<bool> _confirmDelete(
      BuildContext context, WidgetRef ref, Transaction tx) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expenseDeleteTitle),
        content: Text(l10n.expenseDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete,
                  style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (ok != true) return false;
    await ref.read(expenseNotifierProvider.notifier).deleteTransaction(tx.id);
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.expenseDeleted),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
    return true;
  }
}

/// One 明细 row: the expense card, wrapped so a left-swipe reveals a delete
/// action on its right.
///
/// Card layout leads with the **description** (the note) — what the expense
/// actually was — and demotes the category to a subtitle tag. A 请客 row also
/// names who paid, since that's the whole point of a treat.
class _ExpenseRow extends StatelessWidget {
  final Transaction tx;
  final Category? category;
  final String? payerName;
  final VoidCallback onEdit;
  final Future<bool> Function() onConfirmDelete;
  const _ExpenseRow({
    super.key,
    required this.tx,
    required this.category,
    required this.payerName,
    required this.onEdit,
    required this.onConfirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;
    final isExp = tx.type == 'expense';
    final note = (tx.note ?? '').trim();
    final categoryName = category?.name ?? tx.categoryId;
    // Title is the description; fall back to the category when there's no note,
    // so the row is never headed by an empty string.
    final title = note.isNotEmpty ? note : categoryName;

    // Subtitle parts: the category (unless it's already the title), the date,
    // and — for a treat — who fronted it.
    final parts = <String>[
      if (note.isNotEmpty) categoryName,
      l10n.formatMonthDay(tx.txnDate),
      if (tx.splitType == 'treat' && payerName != null)
        l10n.expenseListPaidBy(payerName!),
    ];

    return _SwipeToDelete(
      borderRadius: BorderRadius.circular(18),
      onTap: onEdit,
      onDelete: onConfirmDelete,
      deleteLabel: l10n.expenseSwipeDelete,
      child: Container(
        decoration: BoxDecoration(
          color: t.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: t.cardShadow.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 14,
              spreadRadius: -9,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.mutedColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(category?.iconName ?? '💰',
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSansSc(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _SplitBadge(splitType: tx.splitType),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          parts.join(' · '),
                          style: GoogleFonts.notoSansSc(
                              fontSize: 12, color: t.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              // Per-row currency — a trip can mix RM and S$ rows.
              '${isExp ? '−' : '+'}${formatMoneyWithSymbol(tx.amount, tx.currencyCode)}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipe-left-to-reveal a delete action, then tap to fire it.
///
/// Not [Dismissible]: the ask is a revealed button you deliberately tap (which
/// then confirms), not a fling that deletes on release. The card tracks the
/// finger up to [_revealWidth] and springs to the nearer end on release. A tap
/// on an open card closes it; a tap on a closed card is [onTap].
class _SwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  /// Runs the confirm+delete flow. Resolves true when the row was deleted (the
  /// list drops it), false when cancelled (we spring shut).
  final Future<bool> Function() onDelete;
  final String deleteLabel;
  final BorderRadius borderRadius;
  const _SwipeToDelete({
    required this.child,
    required this.onTap,
    required this.onDelete,
    required this.deleteLabel,
    required this.borderRadius,
  });

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const double _revealWidth = 88;
  // Row gap, kept in sync with the ListView's per-item spacing below so the red
  // panel lines up with the card and not its bottom margin.
  static const double _rowGap = 10;

  late final AnimationController _ctrl;
  Animation<double>? _snap;
  double _drag = 0; // 0 = closed, −_revealWidth = fully open. Never positive.

  bool get _open => _drag <= -_revealWidth + 0.5;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _ctrl.addListener(() {
      if (_snap != null) setState(() => _drag = _snap!.value);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _snap = Tween<double>(begin: _drag, end: target)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _snap = null; // hand control back to the finger
    setState(() => _drag = (_drag + d.delta.dx).clamp(-_revealWidth, 0.0));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    // Fling decides direction; otherwise snap to whichever end is nearer.
    final target = v < -300
        ? -_revealWidth
        : v > 300
            ? 0.0
            : (_drag < -_revealWidth / 2 ? -_revealWidth : 0.0);
    _animateTo(target);
  }

  Future<void> _fireDelete() async {
    final deleted = await widget.onDelete();
    if (!deleted && mounted) _animateTo(0); // cancelled → spring shut
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _rowGap),
      child: Stack(
        children: [
          // Delete panel behind the card, filling its height (not the gap).
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _fireDelete,
                child: Container(
                  width: _revealWidth,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: widget.borderRadius,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline,
                          color: Colors.white, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        widget.deleteLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_drag, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onTap: _open ? () => _animateTo(0) : widget.onTap,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget editor sheet ───────────────────────────────────────────────────────

/// One row per supported currency; empty field = no budget for that currency.
/// Clearing a previously-set field deletes the budget row.
void showBudgetSheet(BuildContext context, WidgetRef ref, String memoryId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _BudgetSheet(memoryId: memoryId),
    ),
  );
}

class _BudgetSheet extends ConsumerStatefulWidget {
  final String memoryId;
  const _BudgetSheet({required this.memoryId});

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  // Controllers are created lazily per displayed currency.
  final Map<String, TextEditingController> _ctrls = {};
  Map<String, MemoryBudget> _existing = {};
  // Currencies shown this build — iterated on save so a cleared field deletes
  // its budget. Kept in sync in build().
  List<String> _currencies = const [];
  bool _initialized = false;
  bool _saving = false;

  TextEditingController _ctrlFor(String code) =>
      _ctrls.putIfAbsent(code, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) =>
      v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(expenseNotifierProvider.notifier);
      for (final code in _currencies) {
        final text = _ctrlFor(code).text.trim();
        final amount = double.tryParse(text);
        final existing = _existing[code];
        if (amount != null && amount > 0) {
          await notifier.saveBudget(
            existingId: existing?.id,
            memoryId: widget.memoryId,
            currencyCode: code,
            amount: amount,
          );
        } else if (existing != null) {
          await notifier.deleteBudget(existing.id);
        }
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = context.l10n;
    final enabled = ref.watch(enabledCurrenciesProvider);
    final budgetsAsync = ref.watch(memoryBudgetsProvider(widget.memoryId));
    final budgets = budgetsAsync.value ?? const <MemoryBudget>[];

    // Show the enabled currencies, plus any currency that already has a budget
    // (so a budget in a since-disabled currency stays visible and editable).
    final present = <String>{
      ...enabled,
      for (final b in budgets) b.currencyCode,
    };
    _currencies = [
      ...kCurrencyCatalog.where(present.contains),
      // Defensive: a stored code outside the known catalog.
      for (final b in budgets)
        if (!kCurrencyCatalog.contains(b.currencyCode)) b.currencyCode,
    ];

    // Prefill once from the stream's first data.
    if (!_initialized && budgetsAsync.hasValue) {
      _existing = {for (final b in budgets) b.currencyCode: b};
      for (final b in budgets) {
        _ctrlFor(b.currencyCode).text = _fmt(b.amount);
      }
      _initialized = true;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.memoryStatBudget,
                style: GoogleFonts.notoSansSc(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
            const SizedBox(height: 4),
            Text(l10n.memoryBudgetSheetHint,
                style: GoogleFonts.notoSansSc(
                    fontSize: 12, color: t.textSecondary)),
            const SizedBox(height: 12),
            for (final code in _currencies)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Fixed-width symbol so every amount field starts at the
                    // same x regardless of symbol length (RM / S$ / ¥ ...).
                    SizedBox(
                      width: 48,
                      child: Text(currencySymbol(code),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrlFor(code),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [MoneyInputFormatter()],
                        // Right-align so the numbers line up down the column.
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
