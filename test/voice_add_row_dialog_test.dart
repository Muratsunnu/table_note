import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/l10n/ux_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/widgets/voice_add_row_dialog.dart';

final _en = AppLocalizations(const Locale('en'));

void main() {
  late TableProvider tables;

  Future<void> seed(WidgetTester tester, {bool withDraft = false}) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      tables = TableProvider();
      while (tables.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tables.createTable('seferler', [
        ColumnModel(name: 'nereden'),
        ColumnModel(name: 'kilosu', isNumeric: true),
      ]);
      if (withDraft) {
        final table = tables.currentTable!;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'form_draft_v1_voice_row_${table.id}',
          jsonEncode({
            'schema': jsonEncode(
              table.columns.map((column) => column.toJson()).toList(),
            ),
            'values': ['Konya', '35000'],
            'transcript': 'nereden konya kilosu otuz beş bin',
          }),
        );
      }
    });
    addTearDown(tables.dispose);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TableProvider>.value(
        value: tables,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const VoiceAddRowDialog(),
        ),
      ),
    );
    // Taslak cihazdan gerçek zamanlı okunur.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  String cell(WidgetTester tester, int index) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(ValueKey('voice-field-$index')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('before speaking there is one thing to do: tap the microphone', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);

    expect(find.byKey(const ValueKey('voice-mic')), findsOneWidget);
    expect(find.text(_en.tapToSpeak), findsOneWidget);
    // Konuşulmadan önce boş bir "algılanan konuşma" kutusu yer tutmaz.
    expect(find.byKey(const ValueKey('voice-transcript')), findsNothing);
    // Eklenecek satır yine de görünür ve elle doldurulabilir.
    expect(find.text('nereden'), findsOneWidget);
    expect(find.text('kilosu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('what was heard stays visible and correcting it refills cells', (
    tester,
  ) async {
    await seed(tester, withDraft: true);
    await open(tester);

    final transcript = find.byKey(const ValueKey('voice-transcript'));
    expect(transcript, findsOneWidget);
    expect(find.text('nereden konya kilosu otuz beş bin'), findsOneWidget);
    expect(cell(tester, 0), 'Konya');
    expect(cell(tester, 1), '35000');

    // Yanlış duyulan yer metinde düzeltilince hücre de düzelir.
    await tester.enterText(transcript, 'nereden konya kilosu 500');
    await tester.pump();
    expect(cell(tester, 1), '500');

    // Sözcükle yazılan sayı hücreye rakam olarak girer.
    await tester.enterText(transcript, 'nereden konya kilosu yüz elli');
    await tester.pump();
    expect(cell(tester, 1), '150');

    // Sayıya çevrilemeyen söz hücreyi bozmaz; ne olduğu satırda yazar.
    await tester.enterText(transcript, 'nereden konya kilosu bilmiyorum');
    await tester.pump();
    expect(cell(tester, 1), '150');
    expect(find.text(_en.voiceNumberUnread), findsOneWidget);

    // Taslağın gecikmeli kaydı bitmeden test kapanmasın.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a numeric cell holding text cannot be saved', (tester) async {
    // Bu düzeltmeden önce kaydedilmiş bir taslakta "yüz" yazılı kalmış
    // olabilir. Sayısal hücredeki yazıyı toplam sıfır sayar ve kimse fark
    // etmez; kayıt buna izin vermez.
    await seed(tester, withDraft: true);
    await tester.runAsync(() async {
      final table = tables.currentTable!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'form_draft_v1_voice_row_${table.id}',
        jsonEncode({
          'schema': jsonEncode(
            table.columns.map((column) => column.toJson()).toList(),
          ),
          'values': ['Konya', 'yüz'],
          'transcript': '',
        }),
      );
    });
    await open(tester);
    expect(cell(tester, 1), 'yüz');

    await tester.tap(find.text(_en.confirmAndAdd));
    await tester.pumpAndSettle();
    expect(find.text(_en.numberOnly), findsOneWidget);
    expect(tables.currentTable!.rows, isEmpty);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
  });
}
