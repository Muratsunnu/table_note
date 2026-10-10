import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/widgets/table_activity_list.dart';

var _nextId = 0;

TableActivityEntry _entry(
  String who,
  String action,
  DateTime at, {
  String? actorId,
  String? column,
  String? from,
  String? to,
}) => TableActivityEntry(
  id: _nextId++,
  actorId: actorId ?? who,
  actorName: who,
  action: action,
  rowId: null,
  columnName: column,
  oldValue: from,
  newValue: to,
  createdAt: at,
);

final _en = AppLocalizations(const Locale('en'));

Widget _app(List<TableActivityEntry> entries) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('tr'), Locale('en')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: SingleChildScrollView(
      child: TableActivityList(
        entries: entries,
        selfActorId: 'me',
        now: DateTime(2026, 10, 9, 13),
      ),
    ),
  ),
);

void main() {
  testWidgets('entries are grouped under one heading per day', (tester) async {
    await tester.pumpWidget(
      _app([
        _entry('Ali', 'left', DateTime(2026, 10, 9, 12, 21)),
        _entry('Ali', 'row_added', DateTime(2026, 10, 9, 8)),
        _entry('Ali', 'joined', DateTime(2026, 10, 8, 3, 28)),
        _entry('Ali', 'row_deleted', DateTime(2026, 10, 3, 9)),
      ]),
    );
    await tester.pumpAndSettle();

    // Aynı günün iki kaydı tek başlık altında; tarih her satırda yinelenmez.
    expect(find.text(_en.today), findsOneWidget);
    expect(find.text(_en.yesterday), findsOneWidget);
    expect(find.textContaining('October 3, 2026'), findsOneWidget);
    expect(find.text(_en.activityLeft), findsOneWidget);
    expect(find.text(_en.activityJoined), findsOneWidget);
  });

  testWidgets('own entries, deleted accounts and unknown kinds are all shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _entry('Murat', 'row_added', DateTime(2026, 10, 9, 9), actorId: 'me'),
        // Hesabını silen kişinin adı kayıttan çıkarılmıştır.
        _entry('', 'row_added', DateTime(2026, 10, 9, 8)),
        // İleride eklenecek bir tür gizlenmez.
        _entry('Ali', 'something_new', DateTime(2026, 10, 9, 7)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text(_en.activityActorSelf), findsOneWidget);
    expect(find.text('Murat'), findsNothing);
    expect(find.text(_en.activityActorDeleted), findsOneWidget);
    expect(find.text('something_new'), findsOneWidget);
  });

  testWidgets('a changed value reads as what, from and to', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app([
        _entry(
          'Ali',
          'row_updated',
          DateTime(2026, 10, 9, 9),
          column: 'kilosu',
          from: '35000',
          to: '40000',
        ),
        _entry(
          'Murat',
          'role_changed',
          DateTime(2026, 10, 9, 8),
          actorId: 'me',
          column: 'Ali',
          from: 'viewer',
          to: 'editor',
        ),
        // Boş bir hücre ilk kez doluyor.
        _entry('Ali', 'mark_changed', DateTime(2026, 10, 9, 7), to: 'Var'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('kilosu: 35000 → 40000'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ali: ${_en.roleViewer} → ${_en.roleEditor}'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('— → Var'), findsOneWidget);
  });
}
