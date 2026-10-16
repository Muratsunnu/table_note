import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/config/plan_limits.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/template_provider.dart';
import 'package:table_note/screens/premium_screen.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/premium_features.dart';
import 'package:table_note/widgets/premium_gate.dart';
import 'package:table_note/widgets/quick_table_builder.dart';
import 'package:table_note/widgets/template_management_dialog.dart';

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  _Subscription({this.unlimited = false});

  final bool unlimited;

  @override
  bool get isPremium => unlimited;
  @override
  bool get hasUnlimitedPlan => unlimited;
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

/// Ücretsiz sınırlar oluşturulan şeyin yanında görünür; Premium özellikleri
/// kendi işaretini taşır.
void main() {
  final tr = AppLocalizations(const Locale('tr'));

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool unlimited = false,
    List<Object> providers = const [],
  }) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final subscription = _Subscription(unlimited: unlimited);
    addTearDown(subscription.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscription,
          ),
          for (final provider in providers)
            switch (provider) {
              final TemplateProvider p =>
                ChangeNotifierProvider<TemplateProvider>.value(value: p),
              final TableProvider p =>
                ChangeNotifierProvider<TableProvider>.value(value: p),
              _ => throw ArgumentError(provider),
            },
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('sınır notu', () {
    testWidgets('kalan hakkı yazar', (tester) async {
      await pump(tester, const FreeQuotaNote(used: 3, limit: 5));

      expect(find.text(tr.freeQuotaUsed(3, 5)), findsOneWidget);
    });

    testWidgets('sınır dolunca Premium\'u söyler ve açar', (tester) async {
      await pump(tester, const FreeQuotaNote(used: 5, limit: 5));

      expect(find.text(tr.freeQuotaFull(5)), findsOneWidget);
      await tester.tap(find.text(tr.freeQuotaFull(5)));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets('sınırsız kullanıcıya hiç görünmez', (tester) async {
      await pump(
        tester,
        const FreeQuotaNote(used: 5, limit: 5),
        unlimited: true,
      );

      expect(find.textContaining('5/5'), findsNothing);
    });
  });

  group('Premium özelliği', () {
    testWidgets('kilitliyken mikrofon kalır, köşesine kilit eklenir', (
      tester,
    ) async {
      await pump(
        tester,
        const PremiumFeatureIcon(icon: Icons.mic_rounded, locked: true),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-lock-badge')), findsOneWidget);
    });

    testWidgets('Premium olanda kilit yoktur', (tester) async {
      await pump(
        tester,
        const PremiumFeatureIcon(icon: Icons.mic_rounded, locked: false),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-lock-badge')), findsNothing);
    });

    testWidgets('dokununca ne olduğunu söyler, istenirse Premium\'u açar', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showPremiumFeatureSheet(context, PremiumFeature.voice),
            child: const Text('mikrofon'),
          ),
        ),
      );
      await tester.tap(find.text('mikrofon'));
      await tester.pumpAndSettle();

      expect(find.text(tr.premiumVoiceFeature), findsOneWidget);
      expect(find.text(tr.premiumFeature), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('premium-feature-go')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    });
  });

  testWidgets('şablon sınırı doluysa yeni şablon yerine Premium açılır', (
    tester,
  ) async {
    late TemplateProvider templates;
    late TableProvider tables;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveTemplates([
        for (var i = 0; i < PlanLimits.freeTemplates; i++)
          TemplateModel(
            templateName: 'Şablon $i',
            columns: [ColumnModel(name: 'ad')],
          ),
      ]);
      templates = TemplateProvider();
      tables = TableProvider();
      while (templates.isLoading || !templates.hasTemplates) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    addTearDown(templates.dispose);
    addTearDown(tables.dispose);
    await pump(
      tester,
      const TemplateManagementDialog(),
      providers: [templates, tables],
    );

    expect(
      find.text(tr.freeQuotaFull(PlanLimits.freeTemplates)),
      findsOneWidget,
    );
    await tester.tap(find.text(tr.createNewTemplate).last);
    await tester.pumpAndSettle();

    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(find.byType(QuickTableBuilder), findsNothing);
  });
}
