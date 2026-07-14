import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/screens/memory/memory_expenses_tab.dart';

/// Simulates a formatter applied to an incremental edit.
TextEditingValue _apply(String oldText, String newText) =>
    MoneyInputFormatter().formatEditUpdate(
      TextEditingValue(text: oldText),
      TextEditingValue(text: newText),
    );

void main() {
  group('MoneyInputFormatter', () {
    test('accepts digits', () {
      expect(_apply('12', '123').text, '123');
    });

    test('accepts a single decimal point with up to 2 places', () {
      expect(_apply('12', '12.').text, '12.');
      expect(_apply('12.', '12.5').text, '12.5');
      expect(_apply('12.5', '12.59').text, '12.59');
    });

    test('rejects letters (keeps old value)', () {
      expect(_apply('12', '12a').text, '12');
      expect(_apply('', 'a').text, '');
    });

    test('rejects a third decimal place', () {
      expect(_apply('12.59', '12.599').text, '12.59');
    });

    test('rejects a second decimal point', () {
      expect(_apply('12.5', '12.5.').text, '12.5');
    });

    test('allows clearing to empty', () {
      expect(_apply('12', '').text, '');
    });
  });
}
