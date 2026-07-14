import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/utils/money.dart';

void main() {
  group('roundHalfUp', () {
    test('rounds decimal midpoints up (four-five-round-up)', () {
      expect(roundHalfUp(1.005), 1.01);
      expect(roundHalfUp(33.335), 33.34);
      expect(roundHalfUp(2.345), 2.35);
      expect(roundHalfUp(0.005), 0.01);
    });

    test('rounds below-midpoint down', () {
      expect(roundHalfUp(1.004), 1.00);
      expect(roundHalfUp(33.334), 33.33);
      expect(roundHalfUp(2.344), 2.34);
    });

    test('leaves already-2dp values untouched', () {
      expect(roundHalfUp(50.00), 50.00);
      expect(roundHalfUp(70.00), 70.00);
      expect(roundHalfUp(25.00), 25.00);
    });

    test('handles repeating divisions used by AA split', () {
      // 200 / 3 = 66.6666...  -> 66.67
      expect(roundHalfUp(200 / 3), 66.67);
      // 100 / 3 = 33.3333...  -> 33.33
      expect(roundHalfUp(100 / 3), 33.33);
      // 350 / 5 = 70 exactly
      expect(roundHalfUp(350 / 5), 70.00);
    });

    test('supports custom decimal places', () {
      expect(roundHalfUp(1.2345, 3), 1.235);
      expect(roundHalfUp(1.2344, 3), 1.234);
      expect(roundHalfUp(12.5, 0), 13);
    });

    test('is symmetric for negatives (ties away from zero)', () {
      expect(roundHalfUp(-1.005), -1.01);
      expect(roundHalfUp(-33.335), -33.34);
    });

    test('passes through zero and non-finite values', () {
      expect(roundHalfUp(0), 0);
      expect(roundHalfUp(double.nan).isNaN, isTrue);
      expect(roundHalfUp(double.infinity), double.infinity);
    });
  });

  group('normalizeCurrency', () {
    test('uppercases and trims', () {
      expect(normalizeCurrency('myr'), 'MYR');
      expect(normalizeCurrency('  sgd '), 'SGD');
    });
  });

  group('currencySymbol', () {
    test('maps known codes', () {
      expect(currencySymbol('MYR'), 'RM');
      expect(currencySymbol('sgd'), r'S$');
      expect(currencySymbol('USD'), r'$');
    });

    test('falls back to the normalized code for unknown currencies', () {
      expect(currencySymbol('krw'), 'KRW');
    });
  });

  group('formatMoney', () {
    test('formats with grouping and 2dp, rounding half-up', () {
      expect(formatMoney(1234.5), '1,234.50');
      expect(formatMoney(1.005), '1.01');
      expect(formatMoney(0), '0.00');
    });

    test('formatMoneyWithSymbol prefixes the symbol', () {
      expect(formatMoneyWithSymbol(12.5, 'MYR'), 'RM 12.50');
      expect(formatMoneyWithSymbol(95, 'sgd'), r'S$ 95.00');
    });
  });
}
