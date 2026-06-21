import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/database_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/person_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/person_avatar.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final String walletId;
  final String? transactionId;
  const TransactionFormScreen(
      {super.key, required this.walletId, this.transactionId});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '1.0');
  String _type = 'expense';
  String? _categoryId;
  DateTime _txnDate = DateTime.now();
  String _splitType = 'personal';
  String? _payerPersonId;
  final Set<String> _splitParticipants = {};
  String? _linkedMemoryId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final self = await ref.read(databaseProvider).personDao.getSelfPerson();
    if (self != null) {
      _payerPersonId = self.id;
      _splitParticipants.add(self.id);
    }

    if (widget.transactionId != null) {
      final tx = await ref
          .read(databaseProvider)
          .expenseDao
          .getTransaction(widget.transactionId!);
      if (tx != null) {
        _type = tx.type;
        _categoryId = tx.categoryId;
        _amountCtrl.text = tx.amount.toString();
        _titleCtrl.text = tx.title ?? '';
        _noteCtrl.text = tx.note ?? '';
        _txnDate = tx.txnDate;
        _splitType = tx.splitType;
        _payerPersonId = tx.payerPersonId;
        _linkedMemoryId = tx.memoryId;
        _rateCtrl.text = tx.exchangeRateToBase.toString();

        final splits = await ref
            .read(databaseProvider)
            .expenseDao
            .getSplits(widget.transactionId!);
        _splitParticipants.addAll(splits.map((s) => s.personId));
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _txnDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) setState(() => _txnDate = d);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.txFormCategoryRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountCtrl.text);
      final rate = double.tryParse(_rateCtrl.text) ?? 1.0;

      final wallets =
          await ref.read(databaseProvider).expenseDao.getAllWallets();
      final wallet = wallets.firstWhere((w) => w.id == widget.walletId);

      final splits = _splitType == 'split_aa'
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
            walletId: widget.walletId,
            memoryId: _linkedMemoryId,
            type: _type,
            categoryId: _categoryId!,
            amount: amount,
            currencyCode: wallet.currencyCode,
            exchangeRateToBase: rate,
            txnDate: _txnDate,
            title: _titleCtrl.text.trim().isEmpty
                ? null
                : _titleCtrl.text.trim(),
            note: _noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim(),
            splitType: _splitType,
            payerPersonId: _payerPersonId!,
            splits: splits,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedSuccess),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = context.l10n;
    final categoriesAsync = ref.watch(categoriesProvider(_type));
    final personsAsync = ref.watch(personsProvider);
    final memoriesAsync = ref.watch(memoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId == null
            ? l10n.txFormNew
            : l10n.txFormEdit),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.save),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: l10n.txFormExpense,
                      selected: _type == 'expense',
                      color: AppColors.expense,
                      onTap: () => setState(
                          () {_type = 'expense'; _categoryId = null;}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeButton(
                      label: l10n.txFormIncome,
                      selected: _type == 'income',
                      color: AppColors.income,
                      onTap: () => setState(
                          () {_type = 'income'; _categoryId = null;}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                decoration: InputDecoration(
                    labelText: l10n.txFormAmountLabel,
                    prefixIcon: const Icon(Icons.attach_money)),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.txFormAmountRequired;
                  if (double.tryParse(v) == null) {
                    return l10n.txFormInvalidAmount;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rateCtrl,
                decoration: InputDecoration(
                    labelText: l10n.txFormExchangeRateLabel,
                    prefixIcon: const Icon(Icons.currency_exchange)),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Text(l10n.txFormCategoryLabel,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              categoriesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text(l10n.errorWith('$e')),
                data: (cats) => Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: cats
                      .map((c) => ChoiceChip(
                            label: Text(c.name),
                            selected: _categoryId == c.id,
                            onSelected: (_) =>
                                setState(() => _categoryId = c.id),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                    labelText: l10n.txFormTitleLabel,
                    prefixIcon: const Icon(Icons.title)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                    labelText: l10n.txFormNoteLabel,
                    prefixIcon: const Icon(Icons.notes)),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined,
                    color: AppColors.warmBrown),
                title: Text(DateFormat('d MMM yyyy').format(_txnDate)),
                onTap: _pickDate,
              ),
              const Divider(),
              // Memory link — only visible when memories exist.
              memoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (memories) {
                  if (memories.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.memoriesTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('无'),
                            selected: _linkedMemoryId == null,
                            onSelected: (_) =>
                                setState(() => _linkedMemoryId = null),
                          ),
                          ...memories.map((m) => ChoiceChip(
                                label: Text(m.title,
                                    overflow: TextOverflow.ellipsis),
                                selected: _linkedMemoryId == m.id,
                                onSelected: (_) =>
                                    setState(() => _linkedMemoryId = m.id),
                              )),
                        ],
                      ),
                      const Divider(),
                    ],
                  );
                },
              ),
              Text(l10n.txFormSplitTypeLabel,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in ['personal', 'split_aa', 'treat'])
                    ChoiceChip(
                      label: Text(l10n.splitTypeName(s)),
                      selected: _splitType == s,
                      onSelected: (_) => setState(() => _splitType = s),
                    ),
                ],
              ),
              if (_splitType == 'split_aa') ...[
                const SizedBox(height: 12),
                Text(l10n.txFormPayer,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                personsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text(l10n.errorWith('$e')),
                  data: (persons) => Wrap(
                    spacing: 8,
                    children: persons
                        .map((p) => ChoiceChip(
                              avatar:
                                  PersonAvatar(name: p.name, radius: 12),
                              label: Text(p.name),
                              selected: _payerPersonId == p.id,
                              onSelected: (_) =>
                                  setState(() => _payerPersonId = p.id),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.txFormSplitWith,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                personsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text(l10n.errorWith('$e')),
                  data: (persons) => Wrap(
                    spacing: 8,
                    children: persons
                        .map((p) => FilterChip(
                              avatar:
                                  PersonAvatar(name: p.name, radius: 12),
                              label: Text(p.name),
                              selected: _splitParticipants.contains(p.id),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _splitParticipants.add(p.id);
                                } else {
                                  _splitParticipants.remove(p.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
          // Date toolbar that floats above the keyboard when it opens.
          Builder(builder: (context) {
            final kb = MediaQuery.of(context).viewInsets.bottom;
            if (kb < 50) return const SizedBox.shrink();
            return Positioned(
              bottom: kb,
              left: 0,
              right: 0,
              child: Material(
                color: AppColors.parchment,
                elevation: 2,
                child: InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 15, color: AppColors.warmBrown),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('d/M/yyyy').format(_txnDate),
                          style: const TextStyle(
                              color: AppColors.warmBrown,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(l10n.memoryEditDetails,
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
              color: selected ? color : AppColors.warmBeige, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppColors.warmBrown,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
