import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Money helpers — single source of truth for rounding, currency symbols, and
/// display formatting across the expense/split/PDF features.
///
/// Rounding is **round-half-up (四舍五入)** to [decimals] places. This is a
/// display/aggregation convenience, NOT a strict financial ledger: rounded
/// per-cell values are not guaranteed to reconcile to the cent.

const Map<String, String> kCurrencySymbols = {
  'MYR': 'RM',
  'SGD': r'S$',
  'USD': r'$',
  'EUR': '€',
  'CNY': '¥',
  'GBP': '£',
  'JPY': '¥',
  'THB': '฿',
  'HKD': r'HK$',
  'TWD': r'NT$',
};

/// Normalizes a currency code for storage and grouping (uppercase, trimmed).
/// Falls back to the raw input when empty.
String normalizeCurrency(String code) {
  final c = code.trim().toUpperCase();
  return c.isEmpty ? code : c;
}

/// Returns a display symbol for [code], or the normalized code itself when the
/// currency is unknown (so e.g. "KRW" still renders sensibly).
String currencySymbol(String code) {
  final c = normalizeCurrency(code);
  return kCurrencySymbols[c] ?? c;
}

/// Rounds [value] to [decimals] places using round-half-up semantics
/// (ties round away from zero, matching everyday 四舍五入 expectations).
///
/// A magnitude-relative epsilon corrects binary floating-point
/// under-representation so decimal midpoints round up as a human would expect
/// (e.g. `1.005 -> 1.01`, `33.335 -> 33.34`), rather than down due to the fact
/// that 1.005 is actually stored as ~1.00499999999999989.
double roundHalfUp(double value, [int decimals = 2]) {
  if (value.isNaN || value.isInfinite) return value;
  if (value == 0) return 0;
  final factor = math.pow(10, decimals).toDouble();
  final scaled = value.abs() * factor;
  // Nudge up by an epsilon scaled to magnitude to counter FP error.
  final corrected = scaled + (scaled + 1) * 1e-9;
  final rounded = (corrected + 0.5).floorToDouble();
  final result = rounded / factor;
  return value < 0 ? -result : result;
}

final NumberFormat _moneyFmt = NumberFormat('#,##0.00');

/// Formats [amount] as a grouped 2-decimal string (no currency), rounded
/// half-up first. e.g. `1234.5 -> "1,234.50"`.
String formatMoney(double amount) => _moneyFmt.format(roundHalfUp(amount));

/// Formats [amount] with the [code]'s symbol, e.g. `("MYR", 12.5) -> "RM 12.50"`.
String formatMoneyWithSymbol(double amount, String code) =>
    '${currencySymbol(code)} ${formatMoney(amount)}';
