import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/money.dart';

const _kCurrenciesKey = 'enabled_currencies';

/// Currencies enabled by default (the user lives in Malaysia; SGD is the common
/// cross-border case). Everything else is opt-in via settings.
const kDefaultCurrencies = ['MYR', 'SGD'];

/// Every currency the user may enable, in a stable display order sourced from
/// the money.dart symbol catalog.
final kCurrencyCatalog = kCurrencySymbols.keys.toList();

/// The user's enabled currency list — the choices shown in the expense form
/// picker and the budget sheet. Persisted via shared_preferences. Never empty.
class CurrencyNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadSaved();
    return kDefaultCurrencies; // until prefs load
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kCurrenciesKey);
    if (saved != null && saved.isNotEmpty) {
      state = _ordered(saved);
    }
  }

  /// Normalizes to catalog order and drops unknown codes.
  List<String> _ordered(List<String> codes) =>
      kCurrencyCatalog.where(codes.contains).toList();

  /// Replaces the enabled set. Ignored if it would leave zero currencies.
  Future<void> setCurrencies(List<String> codes) async {
    final ordered = _ordered(codes);
    if (ordered.isEmpty) return;
    state = ordered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCurrenciesKey, ordered);
  }
}

final enabledCurrenciesProvider =
    NotifierProvider<CurrencyNotifier, List<String>>(CurrencyNotifier.new);
