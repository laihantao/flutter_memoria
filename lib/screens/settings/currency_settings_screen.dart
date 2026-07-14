import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/currency_provider.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/money.dart';

/// Full currency names for the catalog (code -> label).
const _kCurrencyNames = {
  'MYR': '马来西亚令吉',
  'SGD': '新加坡元',
  'USD': '美元',
  'EUR': '欧元',
  'CNY': '人民币',
  'GBP': '英镑',
  'JPY': '日元',
  'THB': '泰铢',
  'HKD': '港元',
  'TWD': '新台币',
};

/// Lets the user pick which currencies appear in the expense form and budget
/// sheet. At least one must stay enabled.
class CurrencySettingsScreen extends ConsumerWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppThemeExtension>()!;
    final enabled = ref.watch(enabledCurrenciesProvider);

    return Scaffold(
      backgroundColor: t.backgroundColor,
      appBar: AppBar(
        backgroundColor: t.backgroundColor,
        title: const Text('货币'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '勾选记账和预算时可用的货币，至少保留一个',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          ),
          for (final code in kCurrencyCatalog)
            CheckboxListTile(
              value: enabled.contains(code),
              onChanged: (checked) {
                final next = [...enabled];
                if (checked == true) {
                  next.add(code);
                } else {
                  // Keep at least one currency enabled.
                  if (enabled.length <= 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('至少保留一个货币')),
                    );
                    return;
                  }
                  next.remove(code);
                }
                ref
                    .read(enabledCurrenciesProvider.notifier)
                    .setCurrencies(next);
              },
              activeColor: t.accentColor,
              title: Text(
                '${_kCurrencyNames[code] ?? code} ($code)',
                style: TextStyle(fontSize: 15, color: t.textPrimary),
              ),
              secondary: SizedBox(
                width: 44,
                child: Text(
                  currencySymbol(code),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
