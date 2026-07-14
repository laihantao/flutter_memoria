import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/utils/split_math.dart';

void main() {
  const roster = ['me', 'a', 'b', 'c', 'd'];

  group('computeSharerIds', () {
    test('everyone shares when nobody is excluded', () {
      final s = computeSharerIds(
          rosterIds: roster, excludedIds: {}, payerId: 'me');
      expect(s, roster.toSet());
    });

    test('excluded people are removed', () {
      final s = computeSharerIds(
          rosterIds: roster, excludedIds: {'c'}, payerId: 'me');
      expect(s, {'me', 'a', 'b', 'd'});
    });

    test('payer is force-included even if passed in the exclude set', () {
      // Defensive: UI prevents this, but the math must never drop the payer.
      final s = computeSharerIds(
          rosterIds: roster, excludedIds: {'a', 'me'}, payerId: 'me');
      expect(s.contains('me'), isTrue);
      expect(s.contains('a'), isFalse);
    });

    test('ignores a payer not in the roster', () {
      final s = computeSharerIds(
          rosterIds: roster, excludedIds: {}, payerId: 'ghost');
      expect(s, roster.toSet());
    });
  });

  group('perHeadShare', () {
    test('divides equally and rounds half-up', () {
      expect(perHeadShare(200, 4), 50.0);
      expect(perHeadShare(100, 4), 25.0);
      expect(perHeadShare(350, 5), 70.0);
      expect(perHeadShare(200, 5), 40.0);
      expect(perHeadShare(100, 3), 33.33);
      expect(perHeadShare(200, 3), 66.67);
    });

    test('returns 0 for no sharers', () {
      expect(perHeadShare(100, 0), 0);
    });
  });

  group('reconstructExcluded', () {
    test('is the roster minus the persisted sharers (round-trip)', () {
      final excluded =
          reconstructExcluded(rosterIds: roster, sharerIds: {'me', 'a', 'b', 'd'});
      expect(excluded, {'c'});
    });

    test('empty when everyone shared', () {
      final excluded = reconstructExcluded(
          rosterIds: roster, sharerIds: roster.toSet());
      expect(excluded, isEmpty);
    });

    test('round-trips with computeSharerIds', () {
      const excludedIn = {'b', 'd'};
      final sharers = computeSharerIds(
          rosterIds: roster, excludedIds: excludedIn, payerId: 'me');
      final excludedOut =
          reconstructExcluded(rosterIds: roster, sharerIds: sharers);
      expect(excludedOut, excludedIn);
    });
  });
}
