import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';

const _kCurrencies = ['MYR', 'SGD', 'USD', 'EUR', 'CNY'];
const _kCurrencySymbols = {
  'MYR': 'RM',
  'SGD': 'S\$',
  'USD': '\$',
  'EUR': '€',
  'CNY': '¥',
};

const _kSplitTypes = ['personal', 'split_aa', 'treat'];

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String? transactionId;
  final String? memoryId;
  final String? walletId;

  const ExpenseFormScreen({
    super.key,
    this.transactionId,
    this.memoryId,
    this.walletId,
  });

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _noteCtrl = TextEditingController();

  bool _isExpense = true;
  String _categoryId = '';
  String _amountStr = '0';
  String _currency = 'MYR';
  DateTime _date = DateTime.now();
  String? _walletId;
  String? _memoryId;
  String _splitType = 'personal';
  String? _payerPersonId;
  final Set<String> _splitParticipants = {};
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {
          _isExpense = _tabs.index == 0;
          _categoryId = '';
        });
      }
    });
    _walletId = widget.walletId;
    _memoryId = widget.memoryId;
    _initSelf();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSelf() async {
    final self = await ref.read(databaseProvider).personDao.getSelfPerson();
    if (self != null && mounted) {
      setState(() {
        _payerPersonId = self.id;
        _splitParticipants.add(self.id);
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
      _isExpense = tx.type == 'expense';
      _tabs.index = _isExpense ? 0 : 1;
      _categoryId = tx.categoryId;
      _amountStr = tx.amount
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.?0+$'), '');
      _currency = tx.currencyCode;
      _date = tx.txnDate;
      _noteCtrl.text = tx.note ?? '';
      _walletId = tx.walletId;
      _memoryId = tx.memoryId;
      _splitType = tx.splitType;
      if (tx.payerPersonId != null) _payerPersonId = tx.payerPersonId;
      if (splits.isNotEmpty) {
        _splitParticipants.clear();
        _splitParticipants.addAll(splits.map((s) => s.personId));
      }
    });
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
          if (!_amountStr.contains('.')) _amountStr += '.';
        case '+':
          _tabs.index = 1;
          _isExpense = false;
          _categoryId = '';
        case '-':
          _tabs.index = 0;
          _isExpense = true;
          _categoryId = '';
        default:
          if (_amountStr == '0') {
            _amountStr = key;
          } else if (_amountStr.length < 10) {
            final dotIdx = _amountStr.indexOf('.');
            if (dotIdx == -1 || _amountStr.length - dotIdx <= 2) {
              _amountStr += key;
            }
          }
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
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
      final splits =
          _splitType == 'split_aa' && _splitParticipants.isNotEmpty
              ? _splitParticipants
                  .map((pid) => (
                        personId: pid,
                        shareType: 'equal',
                        shareAmount: amount / _splitParticipants.length,
                      ))
                  .toList()
              : <({String personId, String shareType, double shareAmount})>[];

      await ref.read(expenseNotifierProvider.notifier).saveTransaction(
            existingId: widget.transactionId,
            walletId: _walletId,
            memoryId: _memoryId,
            type: _isExpense ? 'expense' : 'income',
            categoryId: _categoryId,
            amount: amount,
            currencyCode: _currency,
            txnDate: _date,
            note: note.isEmpty ? null : note,
            splitType: _splitType,
            payerPersonId: _payerPersonId,
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
    final categoriesAsync =
        ref.watch(categoriesProvider(_isExpense ? 'expense' : 'income'));
    final walletsAsync = ref.watch(walletsProvider);
    final memoriesAsync = ref.watch(memoriesProvider);
    final personsAsync = ref.watch(personsProvider);
    final symbol = _kCurrencySymbols[_currency] ?? _currency;

    return Scaffold(
      // Transparent — gradient from main.dart shows through the scrollable area.
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: _pickDate,
          child: Text(
            _formatDate(_date, l10n),
            style: const TextStyle(
              color: AppColors.textPrimary,
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
            itemBuilder: (_) => _kCurrencies
                .map((c) => PopupMenuItem(value: c, child: Text(c)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_currency,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const Icon(Icons.arrow_drop_down,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Type tabs
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor:
                  AppColors.textSecondary.withValues(alpha: 0.6),
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: l10n.expenseFormExpense),
                Tab(text: l10n.expenseFormIncome),
              ],
            ),
          ),
          // Scrollable content sections (shows gradient bg through transparent scaffold)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySection(categoriesAsync, l10n),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  _buildWalletSection(walletsAsync.value ?? [], l10n),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  _buildMemorySection(memoriesAsync, l10n),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  _buildSplitSection(personsAsync, l10n),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Note + amount row — warm ivory background
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.expenseFormNoteHint,
                      hintStyle: TextStyle(
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 4),
                      isDense: true,
                    ),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$symbol $_amountStr',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Numpad — Psyduck-yellow background
          Container(
            color: AppColors.emphasis,
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
          itemCount: cats.length,
          itemBuilder: (context, i) {
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
                      // Chip-sand bg; coral-orange border when selected
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.chipBg,
                      border: selected
                          ? Border.all(
                              color: AppColors.primary, width: 2)
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
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
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

  // ── Wallet picker ───────────────────────────────────────────────────────────

  Widget _buildWalletSection(List<Wallet> wallets, AppLocalizations l10n) {
    final selectedWallet =
        wallets.where((w) => w.id == _walletId).firstOrNull;
    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        Icons.account_balance_wallet_outlined,
        color: AppColors.textSecondary.withValues(alpha: 0.7),
        size: 20,
      ),
      title: Text(
        selectedWallet?.name ?? l10n.expenseFormNoWallet,
        style: TextStyle(
          fontSize: 14,
          color: selectedWallet != null
              ? AppColors.textPrimary
              : AppColors.textSecondary.withValues(alpha: 0.5),
        ),
      ),
      subtitle: selectedWallet != null
          ? Text(selectedWallet.currencyCode,
              style: const TextStyle(fontSize: 11))
          : null,
      trailing: Icon(Icons.chevron_right,
          size: 18,
          color: AppColors.textSecondary.withValues(alpha: 0.4)),
      onTap: wallets.isEmpty ? null : () => _showWalletPicker(wallets, l10n),
    );
  }

  void _showWalletPicker(List<Wallet> wallets, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.do_not_disturb_alt_outlined),
            title: Text(l10n.expenseFormNoWallet),
            onTap: () {
              setState(() => _walletId = null);
              Navigator.pop(context);
            },
          ),
          ...wallets.map((w) => ListTile(
                leading: const Icon(
                    Icons.account_balance_wallet_outlined),
                title: Text(w.name),
                subtitle: Text(w.currencyCode),
                trailing: _walletId == w.id
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _walletId = w.id);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Memory section ──────────────────────────────────────────────────────────

  Widget _buildMemorySection(
      AsyncValue<List<Memory>> memoriesAsync, AppLocalizations l10n) {
    final memories = memoriesAsync.value;
    if (memories == null || memories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.photo_album_outlined,
                  size: 18,
                  color: AppColors.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text('记忆',
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          AppColors.textSecondary.withValues(alpha: 0.7))),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label:
                      const Text('无', style: TextStyle(fontSize: 12)),
                  selected: _memoryId == null,
                  onSelected: (_) =>
                      setState(() => _memoryId = null),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ...memories.map((m) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(m.title,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      selected: _memoryId == m.id,
                      onSelected: (_) =>
                          setState(() => _memoryId = m.id),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Split section ───────────────────────────────────────────────────────────

  Widget _buildSplitSection(
      AsyncValue<List<Person>> personsAsync, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.people_outline,
                  size: 18,
                  color: AppColors.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(l10n.txFormSplitTypeLabel,
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          AppColors.textSecondary.withValues(alpha: 0.7))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: _kSplitTypes
                .map((s) => ChoiceChip(
                      label: Text(l10n.splitTypeName(s),
                          style: const TextStyle(fontSize: 12)),
                      selected: _splitType == s,
                      onSelected: (_) =>
                          setState(() => _splitType = s),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ),
        if (_splitType == 'split_aa') _buildParticipantPicker(personsAsync),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildParticipantPicker(AsyncValue<List<Person>> personsAsync) {
    return personsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (persons) {
        if (persons.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: persons.map((p) {
              final selected = _splitParticipants.contains(p.id);
              return FilterChip(
                avatar: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.chipBg,
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                ),
                label: Text(p.name,
                    style: const TextStyle(fontSize: 11)),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _splitParticipants.add(p.id);
                  } else {
                    _splitParticipants.remove(p.id);
                  }
                }),
                padding:
                    const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Numpad ──────────────────────────────────────────────────────────────────

  Widget _buildNumpad(BuildContext context, AppLocalizations l10n) {
    final todayLabel = l10n.expenseFormToday;
    final doneLabel = l10n.expenseFormDone;
    final keys = [
      ['7', '8', '9', todayLabel],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '-'],
      ['.', '0', '⌫', doneLabel],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          children: row.map((key) {
            final isDone = key == doneLabel;
            final isToday = key == todayLabel;
            final isAction =
                isToday || key == '⌫' || key == '+' || key == '-';
            return Expanded(
              child: GestureDetector(
                onTap: isDone
                    ? (_saving ? null : _save)
                    : isToday
                        ? _pickDate
                        : () => _numpadPress(key),
                child: Container(
                  height: 52,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.primary    // coral orange CTA
                        : isAction
                            ? AppColors.keyboardActionKey  // sandy action keys
                            : AppColors.surface,           // cream-white number keys
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _saving && isDone
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(
                            key,
                            style: TextStyle(
                              fontSize: isDone ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? Colors.white
                                  : AppColors.textPrimary,
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
