import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora_flutter/data/app_database.dart';
import 'package:memora_flutter/l10n/app_localizations.dart';
import 'package:memora_flutter/l10n/app_localizations_en.dart';
import 'package:memora_flutter/l10n/app_localizations_zh.dart';
import 'package:memora_flutter/providers/expense_provider.dart';
import 'package:memora_flutter/providers/memory_provider.dart';
import 'package:memora_flutter/providers/person_provider.dart';
import 'package:memora_flutter/screens/memory/memory_detail_screen.dart';
import 'package:memora_flutter/theme/app_theme.dart';

/// Drives the real 记忆 detail screen over a populated trip, at phone widths, in
/// both languages — the combination that surfaces row overflows.
///
/// Every input is a provider override, so no database is involved. Note the
/// widths here are in test-font glyphs, which are wider than the shipped font;
/// treat a pass as "lays out", not as a pixel-accurate match for the device.
const _memoryId = 'trip-1';

final _memory = Memory(
  id: _memoryId,
  title: '北海道家族旅行',
  type: '旅行',
  description: '冬天的第一场雪，札幌到小樽',
  startDate: DateTime(2026, 2, 10),
  endDate: DateTime(2026, 2, 16),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<Person> _people(int n) => [
      for (int i = 0; i < n; i++)
        Person(
          id: 'p$i',
          name: 'Person $i',
          isSelf: i == 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ];

List<MemoryParticipant> _participants(int n) => [
      for (int i = 0; i < n; i++)
        MemoryParticipant(id: 'mp$i', memoryId: _memoryId, personId: 'p$i'),
    ];

const _locations = [
  MemoryLocation(
      id: 'l0', memoryId: _memoryId, name: '札幌', sortOrder: 0),
  MemoryLocation(
      id: 'l1', memoryId: _memoryId, name: '小樽运河', sortOrder: 1),
];

final _days = [
  ItineraryDay(id: 'd0', memoryId: _memoryId, dayNumber: 1, date: DateTime(2026, 2, 10)),
  ItineraryDay(id: 'd1', memoryId: _memoryId, dayNumber: 2, date: DateTime(2026, 2, 11)),
];

const _stops = <ItineraryStop>[
  ItineraryStop(
      id: 's0',
      dayId: 'd0',
      locationId: 'l0',
      activityText: '到达新千岁机场，取车',
      timeLabel: '09:30',
      orderIndex: 0),
  ItineraryStop(
      id: 's1',
      dayId: 'd1',
      locationId: 'l1',
      activityText: '运河散步',
      timeLabel: '14:00',
      orderIndex: 0),
];

const _category = Category(
  id: 'food',
  name: '餐饮',
  type: 'expense',
  iconName: '🍜',
  isDefault: true,
  sortOrder: 0,
);

final _txns = [
  Transaction(
    id: 't0',
    memoryId: _memoryId,
    type: 'expense',
    categoryId: 'food',
    amount: 1280.50,
    currencyCode: 'MYR',
    exchangeRateToBase: 1,
    txnDate: DateTime(2026, 2, 10),
    splitType: 'split_aa',
    payerPersonId: 'p0',
    note: '晚餐',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

Widget _harness({
  required int participantCount,
  Locale locale = const Locale('zh'),
}) {
  final people = _people(participantCount);
  return ProviderScope(
    overrides: [
      memoryProvider(_memoryId).overrideWith((ref) => Stream.value(_memory)),
      memoryParticipantsProvider(_memoryId)
          .overrideWith((ref) => Stream.value(_participants(participantCount))),
      mediaAssetsProvider(_memoryId)
          .overrideWith((ref) => Stream.value(const <MediaAsset>[])),
      allItineraryStopsProvider(_memoryId)
          .overrideWith((ref) => Stream.value(_stops)),
      itineraryDaysProvider(_memoryId).overrideWith((ref) => Stream.value(_days)),
      itineraryStopsProvider('d0')
          .overrideWith((ref) => Stream.value([_stops[0]])),
      itineraryStopsProvider('d1')
          .overrideWith((ref) => Stream.value([_stops[1]])),
      memoryLocationsProvider(_memoryId)
          .overrideWith((ref) => Stream.value(_locations)),
      transactionsByMemoryProvider(_memoryId)
          .overrideWith((ref) => Stream.value(_txns)),
      memoryBudgetsProvider(_memoryId)
          .overrideWith((ref) => Stream.value(const <MemoryBudget>[])),
      categoriesProvider(null).overrideWith((ref) => Stream.value([_category])),
      personsProvider.overrideWith((ref) => Stream.value(people)),
      mePersonProvider.overrideWith((ref) => Stream.value(people.first)),
      selfPersonStreamProvider.overrideWith((ref) async => people.first),
      for (final p in people)
        personProvider(p.id).overrideWith((ref) => Stream.value(p)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MemoryDetailScreen(id: _memoryId),
    ),
  );
}

void main() {
  /// Pumps at a given logical width. Fixed pumps rather than pumpAndSettle: the
  /// hero runs an animation that never quiesces.
  Future<void> pumpAt(WidgetTester tester, Widget w, double logicalWidth) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(logicalWidth, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  // 360 is the narrowest width the app realistically ships on; 390 is a
  // current-generation phone.
  for (final width in [360.0, 390.0]) {
    for (final locale in [const Locale('zh'), const Locale('en')]) {
      final lang = locale.languageCode;

      testWidgets('overview lays out — ${width.toInt()}dp / $lang',
          (tester) async {
        await pumpAt(
            tester, _harness(participantCount: 10, locale: locale), width);
        expect(tester.takeException(), isNull);
      });

      testWidgets('every tab lays out — ${width.toInt()}dp / $lang',
          (tester) async {
        await pumpAt(
            tester, _harness(participantCount: 10, locale: locale), width);
        final l10n = locale.languageCode == 'en'
            ? const AppLocalizationsEn()
            : const AppLocalizationsZh();
        final labels = [
          l10n.memoryTabItinerary,
          l10n.memoryTabGallery,
          l10n.memoryTabExpenses,
          l10n.memoryTabSettings,
        ];
        for (final label in labels) {
          await tester.tap(find.text(label));
          for (var p = 0; p < 6; p++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
          expect(tester.takeException(), isNull, reason: 'tab "$label"');
        }
      });
    }
  }

  for (final n in [2, 4, 8, 10, 14]) {
    testWidgets('participant strip lays out — $n participants', (tester) async {
      await pumpAt(tester, _harness(participantCount: n), 360);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('avatar stack shows up to 10 faces, then a +N bubble',
      (tester) async {
    await pumpAt(tester, _harness(participantCount: 14), 390);
    // 10 faces rendered; the remaining 4 collapse into one bubble.
    expect(find.text('+4'), findsWidgets);
    expect(find.text('14 人同行'), findsWidgets);
  });
}
