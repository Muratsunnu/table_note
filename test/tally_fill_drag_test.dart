import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/tally_provider.dart';
import 'package:table_note/screens/tally_screen.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/services/shared_sync_service.dart';

class _NoCloud implements CloudRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TallyTableModel _october() => TallyTableModel(
  tableName: 'Ekim',
  startDate: DateTime(2026, 10, 1),
  endDate: DateTime(2026, 10, 31),
  statuses: [
    TallyStatus(code: 'G', label: 'Geldi', colorValue: 0xFF2E7D32),
    TallyStatus(code: 'İ', label: 'İzinli', colorValue: 0xFFFF9800),
  ],
  items: [
    TallyItemModel(name: 'Ahmet'),
    TallyItemModel(name: 'Mehmet'),
  ],
);

/// Dolu bir gün basılı tutulup kaydırılınca yan günler aynı durumla dolar.
void main() {
  late TableProvider tables;
  late TallyProvider tallies;
  late SharedSyncService sync;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      tables = TableProvider();
      tallies = TallyProvider();
      while (tables.isLoading || tallies.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tallies.createTable(_october());
      // Ahmet 2 Ekim'de izinli.
      await tallies.setCellStatus(0, DateTime(2026, 10, 2), 'İ');
    });
    sync = SharedSyncService(
      tables: tables,
      tallies: tallies,
      repository: _NoCloud(),
    );
    addTearDown(() {
      sync.dispose();
      tables.dispose();
      tallies.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TableProvider>.value(value: tables),
          ChangeNotifierProvider<TallyProvider>.value(value: tallies),
          ChangeNotifierProvider<SharedSyncService>.value(value: sync),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          supportedLocales: [Locale('tr'), Locale('en')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: TallyScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<int> leaveDays() => [
    for (final entry in tallies.currentTable!.items[0].entries.entries)
      if (entry.value == 'İ') int.parse(entry.key.split('-').last),
  ]..sort();

  Future<TestGesture> holdOnLeave(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text('İ')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    return gesture;
  }

  testWidgets('kaydırınca yan günler dolar, tek adımda geri alınır', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('İ'), findsOneWidget);

    final gesture = await holdOnLeave(tester);
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(48, 0));
      await tester.pump();
    }
    // Bırakmadan önce yalnızca önizleme: kayıt henüz değişmedi.
    expect(find.text('İ'), findsNWidgets(4));
    expect(leaveDays(), [2]);
    // Durum seçici artık açılmıyor.
    expect(find.byType(BottomSheet), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(leaveDays(), [2, 3, 4, 5]);

    await tester.runAsync(tallies.undoLastEdit);
    await tester.pump();
    expect(leaveDays(), [2]);
  });

  testWidgets('sola da kaydırılabilir', (tester) async {
    await open(tester);

    final gesture = await holdOnLeave(tester);
    await gesture.moveBy(const Offset(-48, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(leaveDays(), [1, 2]);
  });

  testWidgets('kenarda tutulan parmak tabloyu kaydırıp doldurmayı sürdürür', (
    tester,
  ) async {
    await open(tester);
    final visibleRight = tester.getRect(find.byType(Scrollbar)).right;

    final gesture = await holdOnLeave(tester);
    await gesture.moveTo(
      Offset(visibleRight - 4, tester.getCenter(find.text('İ').first).dy),
    );
    await tester.pump();
    final reached = leaveDays().length;
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    // Ekranda görünen ~12 günün ötesine geçti.
    expect(reached, 1);
    expect(leaveDays().last, greaterThan(14));
  });

  testWidgets('boş gün basılı tutulunca bir şey olmaz; dokunma döndürür', (
    tester,
  ) async {
    await open(tester);
    final emptyCell = Offset(
      tester.getCenter(find.text('İ')).dx,
      tester.getCenter(find.text('Mehmet')).dy,
    );

    final gesture = await tester.startGesture(emptyCell);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(96, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tallies.currentTable!.items[1].entries, isEmpty);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tapAt(emptyCell);
    await tester.pumpAndSettle();
    expect(tallies.currentTable!.items[1].entries.values, ['G']);
  });
}
