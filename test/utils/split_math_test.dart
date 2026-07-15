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

  group('buildShares', () {
    Map<String, double> build(String mode,
            {String? payer = 'me', Set<String> excluded = const {}}) =>
        buildShares(
          splitType: mode,
          amount: 300,
          payerId: payer,
          rosterIds: roster,
          excludedIds: excluded,
        );

    test('个人: the payer alone bears the full amount', () {
      expect(build('personal'), {'me': 300.0});
    });

    test('请客: the treater alone bears the full amount', () {
      expect(build('treat', payer: 'a'), {'a': 300.0});
    });

    test('个人 and 请客 differ only in who the payer is', () {
      // The bearer IS the payer in both — this is what makes them settle to
      // zero downstream with no mode-specific branch.
      expect(build('personal', payer: 'a'), build('treat', payer: 'a'));
    });

    test('AA: spreads evenly over the roster minus the excluded', () {
      final s = build('split_aa', excluded: {'c', 'd'});
      expect(s.keys.toSet(), {'me', 'a', 'b'});
      expect(s.values.every((v) => v == 100.0), isTrue);
    });

    test('AA: the payer always shares', () {
      final s = build('split_aa', payer: 'a', excluded: {'a'});
      expect(s.containsKey('a'), isTrue);
    });

    test('AA excludes nobody by default — everyone gets a share', () {
      expect(build('split_aa').keys.toSet(), roster.toSet());
    });

    test('empty without a payer, in every mode', () {
      for (final m in ['personal', 'split_aa', 'treat']) {
        expect(build(m, payer: null), isEmpty, reason: m);
      }
    });

    test('AA over an empty roster is empty, not a divide-by-zero', () {
      final s = buildShares(
        splitType: 'split_aa',
        amount: 300,
        payerId: null,
        rosterIds: const [],
        excludedIds: const {},
      );
      expect(s, isEmpty);
    });
  });

  group('shareTypeFor', () {
    test('AA is an equal share, the single-bearer modes are full', () {
      expect(shareTypeFor('split_aa'), kShareEqual);
      expect(shareTypeFor('personal'), kShareFull);
      expect(shareTypeFor('treat'), kShareFull);
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
