import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/widgets/share_file_sheet.dart';

final _en = AppLocalizations(const Locale('en'));

void main() {
  late List<String> created;
  late List<String> shared;
  late List<String> saved;
  late bool shareCompletes;
  Object? createFailure;

  setUp(() {
    created = [];
    shared = [];
    saved = [];
    shareCompletes = true;
    createFailure = null;
  });

  ShareFileFormat format(String label) => ShareFileFormat(
    label: label,
    description: '$label description',
    icon: Icons.description_rounded,
    color: Colors.green,
    create: () async {
      if (createFailure != null) throw createFailure!;
      created.add(label);
      return '/tmp/seferler.${label.toLowerCase()}';
    },
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => ShareFileSheet(
                    name: 'seferler',
                    summary: '3 records',
                    icon: Icons.table_chart_rounded,
                    formats: [format('PDF'), format('CSV')],
                    shareFile: (path, subject, {origin}) async {
                      shared.add('$subject -> $path');
                      return shareCompletes;
                    },
                    saveFile: (path) async {
                      saved.add(path);
                      return '/downloads/${path.split('/').last}';
                    },
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a format shares it straight away', (tester) async {
    await open(tester);
    expect(find.text(_en.shareAsFile), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('share-file-PDF')));
    await tester.pumpAndSettle();

    // Ayrı bir "paylaş" adımı yok: dosya oluşur ve paylaşım açılır.
    expect(created, ['PDF']);
    expect(shared, ['seferler - PDF -> /tmp/seferler.pdf']);
    expect(saved, isEmpty);
    // Gönderildi; kâğıdın işi bitti.
    expect(find.byType(ShareFileSheet), findsNothing);
  });

  testWidgets('a dismissed share window leaves the sheet open', (tester) async {
    shareCompletes = false;
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('share-file-CSV')));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    // Başka bir tür ya da cihaza kaydetme seçilebilsin.
    expect(find.byType(ShareFileSheet), findsOneWidget);
  });

  testWidgets('saving to the device is still one tap away', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('save-file-CSV')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(created, ['CSV']);
    expect(saved, ['/tmp/seferler.csv']);
    expect(shared, isEmpty);
    expect(find.text(_en.fileSaved('seferler.csv')), findsOneWidget);
    // Bildirim kendiliğinden kalkar.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a file that cannot be created is reported, not shared', (
    tester,
  ) async {
    createFailure = StateError('disk dolu');
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('share-file-PDF')));
    await tester.pumpAndSettle();

    expect(shared, isEmpty);
    expect(find.text(_en.exportFailed), findsOneWidget);
    expect(find.byType(ShareFileSheet), findsOneWidget);
  });
}
