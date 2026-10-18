import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/tally_provider.dart';
import 'package:table_note/screens/premium_screen.dart';
import 'package:table_note/widgets/table_drawer.dart';

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  _Subscription({required this.premium});

  final bool premium;

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

/// Premium'u olmayan kişi, tablolar arasında geçerken Premium'u görür.
void main() {
  final tr = AppLocalizations(const Locale('tr'));
  const banner = ValueKey('drawer-premium');

  Future<void> openDrawer(WidgetTester tester, {required bool premium}) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final subscription = _Subscription(premium: premium);
    final tables = TableProvider();
    final tallies = TallyProvider();
    addTearDown(subscription.dispose);
    addTearDown(tables.dispose);
    addTearDown(tallies.dispose);
    final scaffold = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscription,
          ),
          ChangeNotifierProvider<TableProvider>.value(value: tables),
          ChangeNotifierProvider<TallyProvider>.value(value: tallies),
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
          home: Scaffold(key: scaffold, drawer: const TableDrawer()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scaffold.currentState!.openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('Premium yoksa kısa tanıtım görünür ve Premium ekranını açar', (
    tester,
  ) async {
    await openDrawer(tester, premium: false);

    expect(find.byKey(banner), findsOneWidget);
    expect(find.text(tr.goPremium), findsOneWidget);
    expect(find.text(tr.premiumDescription), findsOneWidget);

    await tester.tap(find.byKey(banner));
    await tester.pumpAndSettle();

    expect(find.byType(TableDrawer), findsNothing);
    expect(find.byType(PremiumScreen), findsOneWidget);
  });

  testWidgets('Premium olan kişiye gösterilmez', (tester) async {
    await openDrawer(tester, premium: true);

    expect(find.byType(TableDrawer), findsOneWidget);
    expect(find.byKey(banner), findsNothing);
  });
}
