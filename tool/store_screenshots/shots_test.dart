// Mağaza ekran görüntülerinin ham ekranlarını üretir: uygulamanın gerçek
// ekranları, örnek veriyle. Tek başına çalıştırılmaz; generate.sh çağırır.
//
//   tool/store_screenshots/generate.sh
//
// `flutter test` bu dosyayı kendiliğinden çalıştırmaz (test/ altında değil).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show ProductDetails;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:table_note/main.dart';
import 'package:table_note/models/plan_offer.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/auth_provider.dart';
import 'package:table_note/providers/locale_provider.dart';
import 'package:table_note/providers/subscription_provider.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/theme_provider.dart';
import 'package:table_note/screens/app_launch_gate.dart';
import 'package:table_note/screens/cloud_backup_screen.dart';
import 'package:table_note/screens/premium_screen.dart';
import 'package:table_note/services/cloud_repository.dart';
import 'package:table_note/services/storage_service.dart';
import 'package:table_note/widgets/share_table_sheet.dart';
import 'package:table_note/widgets/template_management_dialog.dart';
import 'package:table_note/widgets/voice_add_row_dialog.dart';

const out = String.fromEnvironment('SHOT_DIR');
const lang = String.fromEnvironment('SHOT_LANG', defaultValue: 'tr');
const fonts = String.fromEnvironment('SHOT_FONTS');
const tr = lang == 'tr';

/// Hangi mağazanın görseli: `play` (1080x1920), `iphone` (1320x2868) ya da
/// `ipad` (2064x2752). Ekranın mantıksal boyutu ve ölçeği, kartın görselde
/// tutacağı yere göre seçilir (Play'de 1080 genişlikte 792 piksel).
const device = String.fromEnvironment('SHOT_DEVICE', defaultValue: 'play');
const apple = device != 'play';
const ratio = device == 'iphone'
    ? 2.42
    : device == 'ipad'
    ? 2.07
    : 2.2;
const logical = device == 'iphone'
    ? Size(400, 930)
    : device == 'ipad'
    ? Size(820, 1040)
    : Size(360, 680);
const shotKey = ValueKey('store-shot');
const userId = 'demo-user';

TableModel expenses() => TableModel(
  id: 'demo-table',
  tableName: tr ? 'Dükkân açılışı' : 'Shop opening',
  columns: [
    ColumnModel(name: tr ? 'kalem' : 'item'),
    ColumnModel(name: tr ? 'tarih' : 'date', columnType: ColumnType.date),
    ColumnModel(
      name: tr ? 'tutar' : 'cost',
      isNumeric: true,
      startingValue: 100000,
    ),
  ],
  rows: [
    [tr ? 'Kira depozitosu' : 'Rent deposit', '01.10.2026', '18000'],
    [tr ? 'Tezgâh' : 'Counter', '02.10.2026', '9500'],
    [tr ? 'Raf sistemi' : 'Shelving', '02.10.2026', '7200'],
    [tr ? 'Tabela' : 'Signboard', '05.10.2026', '4800'],
    [tr ? 'Kasa ve yazıcı' : 'Till and printer', '06.10.2026', '6350'],
    [tr ? 'Boya badana' : 'Paint job', '08.10.2026', '3900'],
    [tr ? 'İlk mal alımı' : 'First stock', '09.10.2026', '12400'],
  ],
);

TallyTableModel attendance() {
  const marks = [
    'GGGGGYGGG',
    'GGÇGGGGGG',
    'GYGGGGÇGG',
    'GGGGGGGGG',
    'ÇGGGYGGGG',
    'GGGGGGGYG',
    'GGGÇGGGGG',
    'GGGGGGGGÇ',
  ];
  const names = tr
      ? ['Ayşe', 'Mehmet', 'Zeynep', 'Can', 'Elif', 'Burak', 'Deniz', 'Emre']
      : ['Emma', 'Liam', 'Olivia', 'Noah', 'Ava', 'Lucas', 'Mia', 'Ethan'];
  const codes = tr
      ? {'G': 'GEL', 'Ç': 'GEÇ', 'Y': 'YOK'}
      : {'G': 'IN', 'Ç': 'LATE', 'Y': 'OUT'};
  return TallyTableModel(
    id: 'demo-tally',
    tableName: tr ? 'Ekim yoklaması' : 'Attendance',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 31),
    statuses: [
      TallyStatus(
        code: codes['G']!,
        label: tr ? 'Geldi' : 'Present',
        colorValue: 0xFF4CAF50,
      ),
      TallyStatus(
        code: codes['Ç']!,
        label: tr ? 'Geç kaldı' : 'Late',
        colorValue: 0xFFFF9800,
      ),
      TallyStatus(
        code: codes['Y']!,
        label: tr ? 'Gelmedi' : 'Absent',
        colorValue: 0xFFEF5350,
      ),
    ],
    items: [
      for (var i = 0; i < names.length; i++)
        TallyItemModel(
          name: names[i],
          entries: {
            for (var d = 0; d < marks[i].length; d++)
              TallyTableModel.dateKey(DateTime(2026, 10, d + 1)):
                  codes[marks[i][d]]!,
          },
        ),
    ],
  );
}

List<TemplateModel> templates() => [
  TemplateModel(
    templateName: tr ? 'Gider takibi' : 'Expense log',
    columns: [
      ColumnModel(name: tr ? 'kalem' : 'item'),
      ColumnModel(name: tr ? 'tarih' : 'date', columnType: ColumnType.date),
      ColumnModel(name: tr ? 'tutar' : 'cost', isNumeric: true),
    ],
  ),
  TemplateModel(
    templateName: tr ? 'Sevkiyat' : 'Deliveries',
    columns: [
      ColumnModel(name: tr ? 'plaka' : 'plate'),
      ColumnModel(name: tr ? 'yükleme' : 'pickup'),
      ColumnModel(name: tr ? 'kilo' : 'weight', isNumeric: true),
      ColumnModel(name: tr ? 'navlun' : 'freight', isNumeric: true),
    ],
  ),
  TemplateModel(
    templateName: tr ? 'Stok sayımı' : 'Stock count',
    columns: [
      ColumnModel(name: tr ? 'ürün' : 'product'),
      ColumnModel(name: tr ? 'raf' : 'shelf'),
      ColumnModel(name: tr ? 'adet' : 'count', isNumeric: true),
    ],
  ),
  TemplateModel(
    templateName: tr ? 'Aidat' : 'Dues',
    columns: [
      ColumnModel(name: tr ? 'daire' : 'flat'),
      ColumnModel(name: tr ? 'ay' : 'month'),
      ColumnModel(name: tr ? 'ödenen' : 'paid', isNumeric: true),
    ],
  ),
];

/// Hesabı olan, Premium'lu bir kullanıcı: bulut ekranları bu hâlde çizilir.
class _Auth extends AuthProvider {
  @override
  bool get isAvailable => true;
  @override
  bool get isSignedIn => true;
  @override
  bool get isAnonymous => false;
  @override
  User? get user => const User(
    id: userId,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-01T00:00:00Z',
  );
}

/// Tablosunu paylaşıma açmış kullanıcı. Uygulamadaki sağlayıcı işaretlenmez:
/// o zaman eşitleme servisi gerçek sunucuyu arardı.
class _OwnedTables extends TableProvider {
  @override
  bool isSharedOwner(String tableId) => true;
}

class _Subscription extends ChangeNotifier implements SubscriptionProvider {
  @override
  bool get isPremium => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Satın alma ekranı için: Premium'u olmayan, hesabı açık kullanıcı. Fiyatlar
/// mağazadaki gibi; App Store incelemesine konan görsel bundan üretilir.
class _Paywall extends ChangeNotifier implements SubscriptionProvider {
  static PlanOffer _offer(
    PlanPeriod period,
    String price,
    double raw,
    int? trial,
  ) => PlanOffer(
    period: period,
    product: ProductDetails(
      id: period.name,
      title: period.name,
      description: '',
      price: price,
      rawPrice: raw,
      currencyCode: tr ? 'TRY' : 'USD',
    ),
    price: price,
    rawPrice: raw,
    trialDays: trial,
  );

  @override
  final List<PlanOffer> plans = [
    _offer(PlanPeriod.yearly, tr ? '₺199,99' : r'$3.99', tr ? 199.99 : 3.99, 7),
    _offer(
      PlanPeriod.monthly,
      tr ? '₺29,99' : r'$0.99',
      tr ? 29.99 : 0.99,
      null,
    ),
  ];
  @override
  PlanOffer? plan(PlanPeriod period) =>
      plans.where((offer) => offer.period == period).firstOrNull;
  @override
  bool get isPremium => false;
  @override
  bool get isLoading => false;
  @override
  bool get isVerifying => false;
  @override
  bool get hasPendingPurchase => false;
  @override
  bool get requiresSignIn => false;
  @override
  bool get showsSamplePlans => false;
  @override
  PurchaseProblem? get problem => null;
  @override
  String? get errorMessage => null;
  @override
  DateTime? get validUntil => null;
  @override
  bool takePurchaseCompleted() => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements CloudRepository {
  @override
  Future<String?> sharedTableJoinCode(String tableId) async => '463404';

  @override
  Future<List<SharedTableMember>> sharedTableMembers(String tableId) async => [
    SharedTableMember(
      userId: 'member-1',
      displayName: tr ? 'Zeynep' : 'Olivia',
      role: 'viewer',
      joinedAt: DateTime(2026, 10, 8),
      editRequestOpen: true,
    ),
  ];

  @override
  Future<List<CloudEntry>> list() async {
    CloudEntry entry(String id, String kind, String name) => CloudEntry(
      id: id,
      ownerId: userId,
      kind: kind,
      name: name,
      payload: const {},
      updatedAt: DateTime.now(),
      revision: 1,
      collaborationEnabled: false,
    );
    return [
      entry('1', 'table', tr ? 'Dükkân açılışı' : 'Shop opening'),
      entry('2', 'tally', tr ? 'Ekim yoklaması' : 'Attendance'),
      entry('3', 'table', tr ? 'Sevkiyat' : 'Deliveries'),
      entry('4', 'table', tr ? 'Stok sayımı' : 'Stock count'),
      entry('5', 'tally', tr ? 'Nöbet çizelgesi' : 'Duty roster'),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Temada ailesi yazılmayan stiller telefonda sistemin Roboto'suyla çizilir;
/// test motorunda sistem yazı tipi yoktur, aile burada açıkça verilir.
ThemeData withRoboto(ThemeData theme) {
  TextStyle? family(TextStyle? style) => style?.copyWith(fontFamily: 'Roboto');
  ButtonStyle? button(ButtonStyle? style) => style?.textStyle == null
      ? style
      : style!.copyWith(
          textStyle: WidgetStateProperty.resolveWith(
            (states) => family(style.textStyle!.resolve(states)),
          ),
        );
  final labels = theme.navigationBarTheme.labelTextStyle;
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: family(theme.appBarTheme.titleTextStyle),
      toolbarTextStyle: family(theme.appBarTheme.toolbarTextStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: button(theme.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: button(theme.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: button(theme.textButtonTheme.style),
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      titleTextStyle: family(theme.dialogTheme.titleTextStyle),
      contentTextStyle: family(theme.dialogTheme.contentTextStyle),
    ),
    navigationBarTheme: theme.navigationBarTheme.copyWith(
      labelTextStyle: labels == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => family(labels.resolve(states)),
            ),
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: family(theme.chipTheme.labelStyle),
    ),
    snackBarTheme: theme.snackBarTheme.copyWith(
      contentTextStyle: family(theme.snackBarTheme.contentTextStyle),
    ),
  );
}

PageRoute<void> themed(Widget screen) => PageRouteBuilder<void>(
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) =>
      Theme(data: withRoboto(Theme.of(context)), child: screen),
);

/// Bulut ekranları hesabı ve Premium'u olan kullanıcıyla çizilir.
Widget signedIn(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
    ChangeNotifierProvider<SubscriptionProvider>(
      create: (_) => _Subscription(),
    ),
  ],
  child: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    // App Store satın alma eklentisi test ortamında yok; iOS görünümünde
    // uygulama mağazaya bağlanmaya çalışır. Mağaza kapalıymış gibi cevap
    // verilir: ürün yok, ödeme yapılamaz.
    const codec = StandardMessageCodec();
    const storeKit = 'dev.flutter.pigeon.in_app_purchase_storekit.';
    final replies = <String, Object?>{
      'InAppPurchase2API.canMakePayments': false,
      'InAppPurchaseAPI.canMakePayments': false,
      'InAppPurchaseAPI.supportsStoreKit': true,
      'InAppPurchase2API.products': <Object?>[],
      'InAppPurchase2API.transactions': <Object?>[],
      'InAppPurchase2API.unfinishedTransactions': <Object?>[],
      'InAppPurchaseAPI.transactions': <Object?>[],
      'InAppPurchase2API.startListeningToTransactions': null,
      'InAppPurchase2API.stopListeningToTransactions': null,
      'InAppPurchaseAPI.startObservingPaymentQueue': null,
      'InAppPurchaseAPI.stopObservingPaymentQueue': null,
      'InAppPurchaseAPI.registerPaymentQueueDelegate': null,
    };
    replies.forEach((name, value) {
      messenger.setMockMessageHandler(
        '$storeKit$name',
        (_) async => codec.encodeMessage(<Object?>[value]),
      );
    });
    Future<ByteData> read(String path) async => ByteData.view(
      Uint8List.fromList(await File(path).readAsBytes()).buffer,
    );
    await (FontLoader('Roboto')
          ..addFont(read('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(read('assets/fonts/Roboto-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(read('$fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> open(WidgetTester tester, {required int tab}) async {
    tester.view.devicePixelRatio = ratio;
    tester.view.physicalSize = logical * ratio;
    addTearDown(tester.view.reset);
    // Bu dosya da bir testtir; yalnızca test/ klasörünün dışında durur.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'onboarding_completed_v1': true,
      'last_active_tab': tab,
    });
    await tester.runAsync(() async {
      await StorageService.saveTables([expenses()]);
      await StorageService.saveTallyTables([attendance()]);
      await StorageService.saveTemplates(templates());
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: TableNoteRoot(
          themeProvider: ThemeProvider(),
          localeProvider: LocaleProvider(
            initial: tr ? const Locale('tr', 'TR') : const Locale('en', 'US'),
          ),
          showOnboarding: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushReplacement(themed(const AppLaunchGate(showOnboarding: false)));
    await tester.pumpAndSettle();
  }

  BuildContext screen(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  /// Gerçek zamanlı işleri (dosya, sahte ağ) bekler, sonra ekranı oturtur.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shotKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// Gölgeler testte kapalıdır; mağaza görseli için gerçekteki gibi açılır.
  void shadowed(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      // App Store görselleri uygulamanın iOS'taki hâlini gösterir: paylaş
      // simgesi, ortalanmış başlık.
      if (apple) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  shadowed('tablo', (tester) async {
    await open(tester, tab: 0);
    await shot(tester, 'tablo');
  });

  shadowed('çetele', (tester) async {
    await open(tester, tab: 1);
    await shot(tester, 'cetele');
  });

  shadowed('sesle kayıt', (tester) async {
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'has_permission':
        case 'initialize':
        case 'listen':
          return true;
        case 'locales':
          return ['tr_TR:Türkçe', 'en_US:English'];
      }
      return null;
    });
    Future<void> fromPlatform(String method, Object? arguments) =>
        messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, arguments)),
          (_) {},
        );

    await open(tester, tab: 0);
    Navigator.of(screen(tester)).push(themed(const VoiceAddRowDialog()));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('voice-mic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await fromPlatform('notifyStatus', 'listening');
    await fromPlatform(
      'textRecognition',
      jsonEncode({
        'alternates': [
          {
            'recognizedWords': tr
                ? 'kalem vitrin camı tutar beş bin altı yüz'
                : 'item shop window cost five thousand six hundred',
            'confidence': 0.92,
          },
        ],
        'resultType': 0,
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'ses');

    await fromPlatform('notifyStatus', 'done');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 60));
  });

  shadowed('ortak tablo', (tester) async {
    await open(tester, tab: 0);
    final tables = _OwnedTables();
    addTearDown(tables.dispose);
    await tester.runAsync(() async {
      while (tables.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    showModalBottomSheet<void>(
      context: screen(tester),
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider<TableProvider>.value(
        value: tables,
        child: signedIn(
          ShareTableSheet(
            tableId: 'demo-table',
            isTally: false,
            repository: _Repository(),
          ),
        ),
      ),
    );
    await settle(tester);
    await shot(tester, 'paylasim');
  });

  // Paylaş penceresinde yalnızca bir kısmı: aranır, bulunanlar görünür.
  shadowed('dosya paylaşma', (tester) async {
    await open(tester, tab: 0);
    await tester.tap(find.byIcon(Icons.adaptive.share_rounded).first);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('export-some')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('export-query')),
      tr ? 'tarih: 02.10' : 'date: 02.10',
    );
    await settle(tester);
    await shot(tester, 'dosya');
  });

  shadowed('şablonlar', (tester) async {
    await open(tester, tab: 0);
    Navigator.of(screen(tester)).push(themed(const TemplateManagementDialog()));
    await settle(tester);
    await shot(tester, 'sablon');
  });

  shadowed('yedekleme', (tester) async {
    await open(tester, tab: 0);
    Navigator.of(
      screen(tester),
    ).push(themed(signedIn(CloudBackupScreen(repository: _Repository()))));
    await settle(tester);
    await shot(tester, 'yedek');
  });

  // App Store incelemesi abonelik başına satın alma ekranının görüntüsünü
  // ister; iPhone 6.9 inç ölçüsünde (1320x2868) çizilir.
  if (apple) {
    shadowed('satın alma', (tester) async {
      await open(tester, tab: 0);
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1320, 2868);
      Navigator.of(screen(tester)).push(
        themed(
          ChangeNotifierProvider<SubscriptionProvider>(
            create: (_) => _Paywall(),
            child: const PremiumScreen(),
          ),
        ),
      );
      await settle(tester);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(shotKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/premium.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
