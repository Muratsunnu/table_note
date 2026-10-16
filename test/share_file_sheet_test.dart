import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/widgets/premium_features.dart';
import 'package:table_note/widgets/share_file_sheet.dart';

final _en = AppLocalizations(const Locale('en'));

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  _Subscription(this.premium);

  bool premium;

  @override
  bool get isPremium => premium;
  @override
  bool get hasUnlimitedPlan => premium;
  @override
  bool get isLoading => false;
  @override
  bool get requiresSignIn => false;
  @override
  bool get isVerifying => false;
  @override
  bool get hasPendingPurchase => false;
  @override
  bool get showsSamplePlans => false;
  @override
  DateTime? get validUntil => null;
  @override
  PurchaseProblem? get problem => null;
  @override
  List<PlanOffer> get plans => const [];
  @override
  PlanOffer? plan(PlanPeriod period) => null;
  @override
  bool takePurchaseCompleted() => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<String> created;
  late List<ExportChoice> choices;
  late List<String> shared;
  late bool shareCompletes;
  Object? createFailure;

  setUp(() {
    created = [];
    choices = [];
    shared = [];
    shareCompletes = true;
    createFailure = null;
  });

  ShareFileFormat format(String label) => ShareFileFormat(
    label: label,
    description: '$label description',
    icon: Icons.description_rounded,
    color: Colors.green,
    create: (choice) async {
      if (createFailure != null) throw createFailure!;
      created.add(label);
      choices.add(choice);
      return '/tmp/seferler.${label.toLowerCase()}';
    },
  );

  // "Konya" iki kayıtta geçer, başka hiçbir şey tutmaz.
  ShareMatch? match(String query) {
    final text = query.trim();
    if (text.isEmpty) return null;
    if (text.toLowerCase() == 'kayseri') {
      return ShareMatch(
        7,
        preview: [for (var i = 1; i <= ShareMatch.previewLimit; i++) 'K$i'],
      );
    }
    return text.toLowerCase() == 'konya'
        ? const ShareMatch(2, preview: ['42 A · Konya', '42 C · Konya'])
        : const ShareMatch(0);
  }

  Future<void> open(
    WidgetTester tester, {
    bool premium = false,
    bool searchable = false,
    String initialQuery = '',
    DateTimeRange? period,
  }) async {
    final subscription = _Subscription(premium);
    addTearDown(subscription.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: subscription,
        child: MaterialApp(
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
                    isScrollControlled: true,
                    builder: (_) => ShareFileSheet(
                      name: 'seferler',
                      summary: '3 records',
                      icon: Icons.table_chart_rounded,
                      formats: [format('PDF'), format('CSV')],
                      total: 3,
                      match: searchable ? match : null,
                      initialQuery: initialQuery,
                      searchHint: 'Search',
                      period: period,
                      shareFile: (path, subject, {origin}) async {
                        shared.add('$subject -> $path');
                        return shareCompletes;
                      },
                    ),
                  ),
                  child: const Text('open'),
                ),
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
    // Gönderildi; kâğıdın işi bitti.
    expect(find.byType(ShareFileSheet), findsNothing);
  });

  testWidgets('a dismissed share window leaves the sheet open', (tester) async {
    shareCompletes = false;
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('share-file-CSV')));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    // Başka bir tür seçilebilsin.
    expect(find.byType(ShareFileSheet), findsOneWidget);
  });

  testWidgets('every format shows a share sign, not a download', (
    tester,
  ) async {
    await open(tester);

    // Kaydetmek de paylaşım penceresinden yapılır; ayrı düğme yok.
    expect(find.byIcon(Icons.adaptive.share), findsNWidgets(2));
    expect(find.byIcon(Icons.save_alt_rounded), findsNothing);
    expect(find.byType(IconButton), findsNothing);
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

  group('iki adım', () {
    final query = find.byKey(const ValueKey('export-query'));
    final next = find.byKey(const ValueKey('export-continue'));

    testWidgets('arama verilmezse seçim sorulmaz, tamamı gider', (
      tester,
    ) async {
      await open(tester, premium: true);

      expect(find.text(_en.exportWhat), findsNothing);
      await tester.tap(find.byKey(const ValueKey('share-file-PDF')));
      await tester.pumpAndSettle();
      expect(choices.single.filtered, isFalse);
    });

    testWidgets('önce ne gönderileceği seçilir, dosya türleri sonra gelir', (
      tester,
    ) async {
      await open(tester, premium: true, searchable: true);

      expect(find.byKey(const ValueKey('export-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('export-some')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-file-PDF')), findsNothing);
    });

    testWidgets('tamamı: doğrudan paylaşıma geçer', (tester) async {
      await open(tester, premium: true, searchable: true);

      await tester.tap(find.byKey(const ValueKey('export-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('export-summary')), findsOneWidget);
      expect(find.text(_en.exportAll), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('share-file-PDF')));
      await tester.pumpAndSettle();
      expect(choices.single.filtered, isFalse);
    });

    testWidgets('bir kısmı: aranır, bulunanlar görülür, devam edilir', (
      tester,
    ) async {
      await open(tester, premium: true, searchable: true);

      await tester.tap(find.byKey(const ValueKey('export-some')));
      await tester.pumpAndSettle();
      // Bir şey bulunmadan devam edilemez.
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      await tester.enterText(query, 'Konya');
      await tester.pump();
      expect(find.text('42 A · Konya'), findsOneWidget);
      expect(find.text('42 C · Konya'), findsOneWidget);

      await tester.tap(next);
      await tester.pumpAndSettle();
      // Paylaşım adımında neyin gideceği yazar.
      expect(find.textContaining('Konya · ${_en.nRecords(2)}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-file-PDF')));
      await tester.pumpAndSettle();
      expect(choices.single.filtered, isTrue);
      expect(choices.single.query, 'Konya');
    });

    testWidgets('fazlası sayıyla söylenir', (tester) async {
      await open(tester, premium: true, searchable: true);

      await tester.tap(find.byKey(const ValueKey('export-some')));
      await tester.pumpAndSettle();
      await tester.enterText(query, 'Kayseri');
      await tester.pump();
      expect(find.text('K5'), findsOneWidget);
      expect(find.text(_en.exportMore(2)), findsOneWidget);
    });

    testWidgets('kayıtlar çıkınca arama kutusu odağını kaybetmez', (
      tester,
    ) async {
      await open(tester, premium: true, searchable: true);

      await tester.tap(find.byKey(const ValueKey('export-some')));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: query,
        matching: find.byType(EditableText),
      );
      final focus = tester.widget<EditableText>(field).focusNode;
      expect(focus.hasFocus, isTrue);

      tester.testTextInput.enterText('K');
      await tester.pump();
      expect(find.byKey(const ValueKey('export-preview')), findsNothing);
      tester.testTextInput.enterText('Konya');
      await tester.pump();
      expect(find.byKey(const ValueKey('export-preview')), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      tester.testTextInput.enterText('Konyaa');
      await tester.pump();
      expect(find.byKey(const ValueKey('export-preview')), findsNothing);
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('tutmayan arama söylenir', (tester) async {
      await open(tester, premium: true, searchable: true);

      await tester.tap(find.byKey(const ValueKey('export-some')));
      await tester.pumpAndSettle();
      await tester.enterText(query, 'Van');
      await tester.pump();
      expect(find.text(_en.noMatchingRecord('Van')), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
    });

    testWidgets('ekrandaki arama kutuya dolu gelir', (tester) async {
      await open(
        tester,
        premium: true,
        searchable: true,
        initialQuery: 'Konya',
      );

      await tester.tap(find.byKey(const ValueKey('export-some')));
      await tester.pumpAndSettle();
      expect(find.text('42 A · Konya'), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
    });

    testWidgets('"Değiştir" ve geri ok seçime döner', (tester) async {
      await open(tester, premium: true, searchable: true);

      await tester.tap(find.byKey(const ValueKey('export-some')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('export-all')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('export-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-change')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('export-some')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-file-PDF')), findsNothing);
    });

    testWidgets('ücretsizde kilitli görünür: dokununca Premium anlatılır', (
      tester,
    ) async {
      await open(tester, searchable: true, initialQuery: 'Konya');

      expect(find.byKey(const ValueKey('premium-lock-badge')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('export-some')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('premium-feature-${PremiumFeature.export.name}')),
        findsOneWidget,
      );
      await tester.tap(find.text(_en.notNow));
      await tester.pumpAndSettle();
      expect(query, findsNothing);

      // Tamamı gönderilir.
      await tester.tap(find.byKey(const ValueKey('export-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-file-PDF')));
      await tester.pumpAndSettle();
      expect(choices.single.filtered, isFalse);
    });
  });

  group('çetelede günler', () {
    final october = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
    );

    testWidgets('ücretsizde bütün aralık gider, günler kilitli', (
      tester,
    ) async {
      await open(tester, period: october);

      await tester.tap(find.byKey(const ValueKey('export-dates')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('premium-feature-${PremiumFeature.export.name}')),
        findsOneWidget,
      );
      await tester.tap(find.text(_en.notNow));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('share-file-PDF')));
      await tester.pumpAndSettle();
      expect(choices.single.range, isNull);
    });

    testWidgets('Premium\'da günler seçilir', (tester) async {
      await open(tester, premium: true, period: october);

      await tester.tap(find.byKey(const ValueKey('export-dates')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });
  });
}
