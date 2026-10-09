import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/widgets/add_column_card.dart';

/// Sütun listesinin sonundaki "sıradaki sütun" kartı.
void main() {
  Future<void> pumpCard(WidgetTester tester, VoidCallback? onTap) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [AddColumnCard(onTap: onTap)],
          ),
        ),
      ),
    );
    // Çeviriler bir kare sonra yüklenir.
    await tester.pumpAndSettle();
  }

  testWidgets('dokununca sütun ekler ve satırı boydan boya kaplar', (
    tester,
  ) async {
    var added = 0;
    await pumpCard(tester, () => added++);

    expect(find.text(AppLocalizations(const Locale('tr')).addColumn), findsOne);
    final card = find.byKey(const ValueKey('add-column-card'));
    // Sola yaslı bir sütunun içinde de küçülmez.
    expect(
      tester.getSize(card).width,
      tester.getSize(find.byType(Scaffold)).width,
    );

    await tester.tap(card);
    expect(added, 1);
  });

  testWidgets('kayıt sürerken dokunmak bir şey yapmaz', (tester) async {
    await pumpCard(tester, null);

    await tester.tap(find.byKey(const ValueKey('add-column-card')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
