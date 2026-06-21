import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';

const _kCurrencies = ['MYR', 'SGD', 'USD', 'CNY', 'EUR'];

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final walletsAsync = ref.watch(walletsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWallet(context, ref),
          ),
        ],
      ),
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWith('$e'))),
        data: (wallets) => wallets.isEmpty
            ? _EmptyState(onAdd: () => _showAddWallet(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: wallets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _WalletCard(wallet: wallets[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWallet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final Wallet wallet;
  const _WalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = wallet.colorHex != null
        ? Color(int.parse('FF${wallet.colorHex!.replaceAll('#', '')}',
            radix: 16))
        : AppColors.primary;

    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.account_balance_wallet_outlined, color: color),
        ),
        title: Text(wallet.name),
        subtitle: Text(wallet.currencyCode),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${wallet.currencyCode} ${NumberFormat('#,##0.00').format(wallet.initialBalance)}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(l10n.walletsInitialBalance,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: () =>
            context.push('/settings/wallets/${wallet.id}/transactions'),
      ),
    );
  }
}

Future<void> _showAddWallet(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController();
  String selectedCurrency = 'MYR';
  final balanceCtrl = TextEditingController(text: '0');

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.walletsNewWallet,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.walletsNameLabel),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedCurrency,
                  decoration:
                      InputDecoration(labelText: l10n.walletsCurrencyLabel),
                  items: _kCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => selectedCurrency = v ?? 'MYR'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: balanceCtrl,
                  decoration: InputDecoration(
                      labelText: l10n.walletsInitialBalance),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  await ref
                      .read(expenseNotifierProvider.notifier)
                      .saveWallet(
                        name: nameCtrl.text.trim(),
                        currencyCode: selectedCurrency,
                        initialBalance:
                            double.tryParse(balanceCtrl.text) ?? 0,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.savedSuccess),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text(l10n.walletsCreateButton),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: AppColors.warmBeige),
          const SizedBox(height: 16),
          Text(l10n.walletsEmpty,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.walletsAddButton),
          ),
        ],
      ),
    );
  }
}
