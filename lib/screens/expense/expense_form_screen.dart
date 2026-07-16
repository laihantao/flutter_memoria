import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/currency_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/money.dart';
import '../../utils/split_math.dart';

const _kSplitTypes = ['personal', 'split_aa', 'treat'];

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? memoryId;

  const ExpenseFormScreen({
    super.key,
    this.transactionId,
    this.memoryId,
  });

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseFormScreen> {
  final _noteCtrl = TextEditingController();

  // Kept only so editing a legacy income row doesn't silently flip it to an
  // expense on save. New transactions are always 'expense' — the income tab
  // was removed when the standalone ledger split off.
  String _type = 'expense';
  String _categoryId = '';
  // Amount is an arithmetic expression, e.g. "12.50+3.9-1". The +/- numpad
  // keys append operators; "=" collapses it before saving.
  String _amountStr = '0';
  String _currency = 'MYR';
  DateTime _date = DateTime.now();
  String? _memoryId;
  String _splitType = 'personal';
  // Who fronted the money. For 个人 this is always _selfId (enforced on mode
  // switch and again on save); for AA/请客 the user picks it.
  String? _payerPersonId;
  // "Me" in 人脉 — the forced payer for 个人, and the default elsewhere.
  String? _selfId;
  // People EXCLUDED from an AA split (default: nobody excluded → everyone shares).
  final Set<String> _excludedIds = {};
  // When editing a saved AA expense, we reconstruct the exclude set from the
  // persisted sharers once the trip roster has resolved (D1).
  Set<String> _loadedSharerIds = {};
  bool _pendingExcludeInit = false;
  bool _saving = false;
  bool _loading = true;

  AppThemeExtension get _t =>
      Theme.of(context).extension<AppThemeExtension>()!;

  @override
  void initState() {
    super.initState();
    _memoryId = widget.memoryId;
    // New expenses default to the first enabled currency; editing overrides
    // this from the saved transaction in _loadExisting.
    final enabled = ref.read(enabledCurrenciesProvider);
    if (enabled.isNotEmpty) _currency = enabled.first;
    _initSelf();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSelf() async {
    final self = await ref.read(databaseProvider).personDao.getSelfPerson();
    if (self != null && mounted) {
      setState(() {
        _selfId = self.id;
        _payerPersonId = self.id;
      });
    }
    if (widget.transactionId != null) await _loadExisting();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadExisting() async {
    final db = ref.read(databaseProvider);
    final tx = await db.expenseDao.getTransaction(widget.transactionId!);
    if (tx == null || !mounted) return;
    final splits = await db.expenseDao.getSplits(widget.transactionId!);
    setState(() {
      _type = tx.type;
      _categoryId = tx.categoryId;
      _amountStr = tx.amount
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.?0+$'), '');
      _currency = tx.currencyCode;
      _date = tx.txnDate;
      _noteCtrl.text = tx.note ?? '';
      _memoryId = tx.memoryId;
      _splitType = tx.splitType;
      if (tx.payerPersonId != null) _payerPersonId = tx.payerPersonId;
      if (tx.splitType == 'split_aa' && splits.isNotEmpty) {
        // Defer exclude reconstruction until the roster resolves in build().
        _loadedSharerIds = splits.map((s) => s.personId).toSet();
        _pendingExcludeInit = true;
      }
    });
  }

  // ── Amount expression helpers ─────────────────────────────────────────────

  /// Whether the expression still has an operator to collapse ("12+3").
  bool get _hasPendingOp =>
      _amountStr.contains('+') || _amountStr.contains('-');

  /// The operand currently being typed (after the last operator).
  String get _currentOperand {
    final i = _amountStr.lastIndexOf(RegExp(r'[+\-]'));
    return i == -1 ? _amountStr : _amountStr.substring(i + 1);
  }

  /// Sums the signed operands. "12.5+3-1.2" → 14.3 (round-half-up 2dp).
  double _evaluate() {
    var total = 0.0;
    var sign = 1;
    var buf = '';
    void flush() {
      if (buf.isNotEmpty) total += sign * (double.tryParse(buf) ?? 0);
      buf = '';
    }

    for (final ch in _amountStr.split('')) {
      if (ch == '+' || ch == '-') {
        flush();
        sign = ch == '+' ? 1 : -1;
      } else {
        buf += ch;
      }
    }
    flush();
    return roundHalfUp(total);
  }

  static String _fmtNum(double v) =>
      v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  void _collapseExpression() {
    final result = _evaluate();
    // A non-positive running total is not a valid expense — reset.
    _amountStr = result > 0 ? _fmtNum(result) : '0';
  }

  void _numpadPress(String key) {
    setState(() {
      switch (key) {
        case '⌫':
          if (_amountStr.length <= 1) {
            _amountStr = '0';
          } else {
            _amountStr = _amountStr.substring(0, _amountStr.length - 1);
          }
        case '.':
          if (_currentOperand.contains('.')) return;
          // Starting an operand with "." reads as "0."
          _amountStr += _currentOperand.isEmpty ? '0.' : '.';
        case '+':
        case '-':
          if (_amountStr.length > 24) return;
          final last = _amountStr[_amountStr.length - 1];
          if (last == '+' || last == '-') {
            // Retyping the operator swaps it.
            _amountStr = _amountStr.substring(0, _amountStr.length - 1) + key;
          } else if (last == '.') {
            _amountStr =
                _amountStr.substring(0, _amountStr.length - 1) + key;
          } else {
            _amountStr += key;
          }
        default: // digit
          final op = _currentOperand;
          if (op == '0') {
            // Replace a lone leading zero within the current operand.
            _amountStr =
                _amountStr.substring(0, _amountStr.length - 1) + key;
          } else if (op.length < 9) {
            final dotIdx = op.indexOf('.');
            if (dotIdx == -1 || op.length - dotIdx <= 2) {
              _amountStr += key;
            }
          }
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    // Defensive: collapse any dangling expression before validating.
    if (_hasPendingOp) setState(_collapseExpression);
    final amount = double.tryParse(_amountStr) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseFormAmountRequired)),
      );
      return;
    }
    if (_categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseFormCategoryRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final note = _noteCtrl.text.trim();
      final currency = normalizeCurrency(_currency); // D7

      // Split modes are only valid on a memory-linked expense; otherwise 个人.
      final effectiveSplit = _memoryId == null ? 'personal' : _splitType;
      // 个人 is always borne by me, whatever a previous mode left in state.
      final payerId =
          effectiveSplit == 'personal' ? _selfId : _payerPersonId;

      var splits =
          const <({String personId, String shareType, double shareAmount})>[];
      if (_memoryId != null) {
        final rosterIds = ref
            .read(memoryParticipantPersonsProvider(_memoryId!))
            .map((p) => p.id)
            .toList();
        final shares = buildShares(
          splitType: effectiveSplit,
          amount: amount,
          payerId: payerId,
          rosterIds: rosterIds,
          excludedIds: _excludedIds,
        );
        final shareType = shareTypeFor(effectiveSplit);
        splits = [
          for (final e in shares.entries)
            (personId: e.key, shareType: shareType, shareAmount: e.value),
        ];
      }

      await ref.read(expenseNotifierProvider.notifier).saveTransaction(
            existingId: widget.transactionId,
            memoryId: _memoryId,
            type: _type,
            categoryId: _categoryId,
            amount: amount,
            currencyCode: currency,
            txnDate: _date,
            note: note.isEmpty ? null : note,
            splitType: effectiveSplit,
            payerPersonId: payerId,
            splits: splits,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.savedSuccess),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String _formatDate(DateTime d, AppLocalizations l10n) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return l10n.today;
    }
    return l10n.formatMonthDay(d);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = context.l10n;
    final t = _t;
    final categoriesAsync = ref.watch(categoriesProvider(_type));
    final symbol = currencySymbol(_currency);
    // Currency picker = the user's enabled set, plus the current value so
    // editing a transaction in a since-disabled currency still shows it.
    final enabledCurrencies = ref.watch(enabledCurrenciesProvider);
    final pickerCurrencies = [
      ...enabledCurrencies,
      if (!enabledCurrencies.contains(_currency)) _currency,
    ];

    // Reconstruct the exclude set for an edited AA expense once the roster
    // resolves (D1). Safe to run in build: it only fires while the pending flag
    // is set and stops after the first non-empty roster.
    if (_pendingExcludeInit && _memoryId != null) {
      final rosterIds = ref
          .read(memoryParticipantPersonsProvider(_memoryId!))
          .map((p) => p.id)
          .toList();
      if (rosterIds.isNotEmpty) {
        _excludedIds
          ..clear()
          ..addAll(reconstructExcluded(
              rosterIds: rosterIds, sharerIds: _loadedSharerIds));
        _pendingExcludeInit = false;
      }
    }

    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: t.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: _pickDate,
          child: Text(
            _formatDate(_date, l10n),
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            initialValue: _currency,
            onSelected: (c) => setState(() => _currency = c),
            itemBuilder: (_) => pickerCurrencies
                .map((c) => PopupMenuItem(value: c, child: Text(c)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_currency, style: TextStyle(color: t.textSecondary)),
                  Icon(Icons.arrow_drop_down, color: t.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable content sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySection(categoriesAsync, l10n),
                  Divider(height: 1, color: t.borderColor),
                  _buildSplitSection(l10n),
                  // Editing an existing expense: offer to delete it here, at the
                  // bottom of the form. Absent when creating (nothing to delete).
                  if (widget.transactionId != null) _buildDeleteButton(l10n),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Note + amount row
          Container(
            decoration: BoxDecoration(
              color: t.surfaceColor,
              border: Border(top: BorderSide(color: t.borderColor)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.expenseFormNoteHint,
                      hintStyle: TextStyle(
                        color: t.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 4),
                      isDense: true,
                    ),
                    style: TextStyle(color: t.textPrimary, fontSize: 13),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$symbol $_amountStr',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    // Highlight while an expression is pending collapse.
                    color: _hasPendingOp ? t.accentColor : t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Numpad
          Container(
            color: t.backgroundColor,
            child: Column(
              children: [
                _buildNumpad(context, l10n),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Category grid ───────────────────────────────────────────────────────────

  Widget _buildCategorySection(
      AsyncValue<List<Category>> categoriesAsync, AppLocalizations l10n) {
    final t = _t;
    return categoriesAsync.when(
      loading: () => const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(l10n.errorWith('$e')),
      ),
      data: (cats) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.88,
            mainAxisSpacing: 4,
            crossAxisSpacing: 2,
          ),
          // Trailing cell jumps to category management.
          itemCount: cats.length + 1,
          itemBuilder: (context, i) {
            if (i == cats.length) {
              return GestureDetector(
                onTap: () => context.push('/settings/expense-categories'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: t.borderColor, width: 1.5),
                      ),
                      child: Icon(Icons.settings_outlined,
                          size: 20, color: t.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.expenseFormManage,
                      style: TextStyle(
                          fontSize: 10, color: t.textSecondary),
                    ),
                  ],
                ),
              );
            }
            final cat = cats[i];
            final selected = cat.id == _categoryId;
            return GestureDetector(
              onTap: () => setState(() => _categoryId = cat.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? t.accentColor.withValues(alpha: 0.15)
                          : t.mutedColor,
                      border: selected
                          ? Border.all(color: t.accentColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        cat.iconName ?? '•',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? t.accentColor : t.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Widget _buildDeleteButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saving ? null : _delete,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(l10n.expenseFormDelete),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade400,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
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
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(expenseNotifierProvider.notifier)
          .deleteTransaction(widget.transactionId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.expenseDeleted),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Split section ───────────────────────────────────────────────────────────

  Widget _buildSplitSection(AppLocalizations l10n) {
    final t = _t;
    // Split modes require the expense to be tagged to a 记忆 (A). Without one,
    // only 个人 is allowed; the other two chips render disabled.
    final linked = _memoryId != null;
    if (!linked && _splitType != 'personal') {
      // Safety net: keep state consistent if we arrive here un-linked.
      _splitType = 'personal';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.people_outline,
                  size: 18, color: t.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(l10n.txFormSplitTypeLabel,
                  style: TextStyle(
                      fontSize: 13,
                      color: t.textSecondary.withValues(alpha: 0.7))),
              if (!linked) ...[
                const SizedBox(width: 8),
                Text(l10n.expenseFormLinkMemoryHint,
                    style: TextStyle(
                        fontSize: 11,
                        color: t.textSecondary.withValues(alpha: 0.5))),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: _kSplitTypes.map((s) {
              // 个人 always enabled; AA制/请客 only when linked to a 记忆.
              final enabled = linked || s == 'personal';
              return ChoiceChip(
                label: Text(l10n.splitTypeName(s),
                    style: const TextStyle(fontSize: 12)),
                selected: _splitType == s,
                onSelected: enabled
                    ? (_) => setState(() {
                          _splitType = s;
                          if (s != 'split_aa') _excludedIds.clear();
                          // 个人 is borne by me — don't carry over a payer the
                          // user picked for AA/请客.
                          if (s == 'personal') _payerPersonId = _selfId;
                        })
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
        if (linked && _splitType == 'split_aa') _buildAaControls(l10n),
        if (linked && _splitType == 'treat') _buildTreatControls(),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 请客: pick the one person who treats. They front the money AND bear all of
  /// it, so the expense settles to zero — nobody owes the treater anything.
  Widget _buildTreatControls() {
    final t = _t;
    final roster = ref.watch(memoryParticipantPersonsProvider(_memoryId!));
    if (roster.isEmpty) return _rosterEmptyNote();

    final treaterId = _normalizedPayerId(roster);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(context.l10n.expenseFormTreatWho,
              style: TextStyle(
                  fontSize: 12,
                  color: t.textSecondary.withValues(alpha: 0.8))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: roster.map((p) {
              return ChoiceChip(
                avatar: _initialAvatar(p.name),
                label: Text(p.name, style: const TextStyle(fontSize: 11)),
                selected: treaterId == p.id,
                onSelected: (_) => setState(() => _payerPersonId = p.id),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(context.l10n.expenseFormPersonalHint,
              style: TextStyle(
                  fontSize: 11,
                  color: t.textSecondary.withValues(alpha: 0.7))),
        ),
      ],
    );
  }

  Widget _rosterEmptyNote() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(context.l10n.expenseFormNoParticipants,
            style: TextStyle(fontSize: 11, color: _t.textSecondary)),
      );

  /// Keeps the payer valid against the trip roster, falling back to the first
  /// member. Writes the fallback back to state (without setState — we're inside
  /// build and the returned value is what we render) so an untouched picker
  /// saves the person it actually displayed as selected.
  String _normalizedPayerId(List<Person> roster) {
    final ids = roster.map((p) => p.id).toList();
    final id = (_payerPersonId != null && ids.contains(_payerPersonId))
        ? _payerPersonId!
        : ids.first;
    _payerPersonId = id;
    return id;
  }

  // Payer picker + exclude multiselect + live per-head preview, sourced from
  // the trip roster (people from 人脉 via MemoryParticipants, "Me" included).
  Widget _buildAaControls(AppLocalizations l10n) {
    final t = _t;
    final roster = ref.watch(memoryParticipantPersonsProvider(_memoryId!));
    if (roster.isEmpty) return _rosterEmptyNote();

    final rosterIds = roster.map((p) => p.id).toList();
    final payerId = _normalizedPayerId(roster);

    final sharers = computeSharerIds(
      rosterIds: rosterIds,
      excludedIds: _excludedIds,
      payerId: payerId,
    );
    final amount = _evaluate();
    final perHead = perHeadShare(amount, sharers.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Payer picker (single-select).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(l10n.txFormPayer,
              style: TextStyle(
                  fontSize: 12,
                  color: t.textSecondary.withValues(alpha: 0.8))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: roster.map((p) {
              return ChoiceChip(
                avatar: _initialAvatar(p.name),
                label: Text(p.name, style: const TextStyle(fontSize: 11)),
                selected: payerId == p.id,
                onSelected: (_) => setState(() {
                  _payerPersonId = p.id;
                  // The payer always shares — never excluded (B).
                  _excludedIds.remove(p.id);
                }),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
        // Exclude multiselect. Selected = excluded from the split.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(context.l10n.expenseFormExcluded,
              style: TextStyle(
                  fontSize: 12,
                  color: t.textSecondary.withValues(alpha: 0.8))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: roster.map((p) {
              final isPayer = p.id == payerId;
              final excluded = _excludedIds.contains(p.id);
              return FilterChip(
                avatar: _initialAvatar(p.name),
                label: Text(
                  isPayer
                      ? context.l10n.expenseFormPayerSuffix(p.name)
                      : p.name,
                  style: const TextStyle(fontSize: 11),
                ),
                selected: excluded,
                // The payer can never be excluded (B) → chip disabled.
                onSelected: isPayer
                    ? null
                    : (v) => setState(() {
                          if (v) {
                            _excludedIds.add(p.id);
                          } else {
                            _excludedIds.remove(p.id);
                          }
                        }),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
        // Live per-head preview.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            context.l10n.expenseFormPerHead(
                formatMoneyWithSymbol(perHead, _currency), sharers.length),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.accentColor),
          ),
        ),
      ],
    );
  }

  Widget _initialAvatar(String name) => CircleAvatar(
        radius: 10,
        backgroundColor: _t.mutedColor,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 10, color: _t.textSecondary),
        ),
      );

  // ── Numpad ──────────────────────────────────────────────────────────────────

  Widget _buildNumpad(BuildContext context, AppLocalizations l10n) {
    final t = _t;
    // Date key reflects the chosen date ("今天" only when it really is today),
    // so picking another day is visible on the keypad, not just the app bar.
    final dateLabel = _formatDate(_date, l10n);
    // With a pending expression the CTA collapses it; otherwise it saves.
    final pending = _hasPendingOp;
    final doneLabel = pending ? '=' : l10n.expenseFormDone;
    // Legible text on the accent CTA regardless of theme (gold on 星夜 needs
    // dark text; terracotta on 暖陶 needs light text).
    final ctaText =
        ThemeData.estimateBrightnessForColor(t.accentColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final keys = [
      ['7', '8', '9', dateLabel],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '-'],
      ['.', '0', '⌫', doneLabel],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          children: row.map((key) {
            final isDone = key == doneLabel;
            final isDate = key == dateLabel;
            final isAction = isDate || key == '⌫' || key == '+' || key == '-';
            return Expanded(
              child: GestureDetector(
                onTap: isDone
                    ? (_saving
                        ? null
                        : pending
                            ? () => setState(_collapseExpression)
                            : _save)
                    : isDate
                        ? _pickDate
                        : () => _numpadPress(key),
                child: Container(
                  height: 52,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDone
                        ? t.accentColor
                        : isAction
                            ? t.mutedColor
                            : t.surfaceColor,
                    border: isDone
                        ? null
                        : Border.all(color: t.borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _saving && isDone
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: ctaText))
                        : Text(
                            key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              // Date labels are multi-char — shrink to fit.
                              fontSize: isDate ? 14 : (isDone ? 16 : 18),
                              fontWeight: FontWeight.w600,
                              color: isDone ? ctaText : t.textPrimary,
                            ),
                          ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
