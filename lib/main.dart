import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/table_provider.dart';
import 'providers/template_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/tally_provider.dart';
import 'providers/tally_template_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/backup_reminder_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/app_launch_gate.dart';
import 'services/onboarding_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'widgets/auth_callback_router.dart';
import 'widgets/launch_intro.dart';
import 'services/home_widget_service.dart';
import 'services/shared_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  final themeProvider = await ThemeProvider.load();
  // Sağlayıcılar veriye dokunmadan önce: önceki sürümden kalan veri var mı?
  final legacyUnlimited = await StorageService.resolveLegacyUnlimited();
  // Açılış ekranı kapanınca ilk kare doğrudan gerçek ekran olsun.
  final showOnboarding = await OnboardingService.shouldShow();
  // Yeni kullanıcı telefonunun diliyle, eski kullanıcı alıştığı dille açar.
  final localeProvider = await LocaleProvider.load(newUser: showOnboarding);

  runApp(
    TableNoteRoot(
      themeProvider: themeProvider,
      localeProvider: localeProvider,
      legacyUnlimited: legacyUnlimited,
      showOnboarding: showOnboarding,
      // Ana ekran widget'ından gelen kişi hemen kayıt eklemek ister;
      // açılış animasyonu onu bekletmez.
      playIntro: !await _launchedFromWidget(),
    ),
  );
}

Future<bool> _launchedFromWidget() async {
  try {
    final link = await AppLinks().getInitialLink();
    return link?.host == 'widget';
  } catch (_) {
    return false;
  }
}

class TableNoteRoot extends StatelessWidget {
  final ThemeProvider themeProvider;

  /// Açılışta önceden belirlenmiş dil; verilmezse kayıtlı dil sonradan okunur.
  final LocaleProvider? localeProvider;

  /// Ücretsiz sınırlar gelmeden önceki sürümden gelen kullanıcı.
  final bool legacyUnlimited;

  /// Açılışta önceden çözülmüşse başlangıç ekranı beklemeden gösterilir.
  final bool? showOnboarding;

  /// Açılış animasyonu oynatılsın mı. Yalnızca gerçek açılışta açıktır.
  final bool playIntro;

  const TableNoteRoot({
    super.key,
    required this.themeProvider,
    this.localeProvider,
    this.legacyUnlimited = false,
    this.showOnboarding,
    this.playIntro = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TableProvider()),
        ChangeNotifierProvider(create: (context) => TemplateProvider()),
        ChangeNotifierProvider(create: (context) => TallyProvider()),
        ChangeNotifierProvider(create: (context) => TallyTemplateProvider()),
        if (localeProvider != null)
          ChangeNotifierProvider.value(value: localeProvider!)
        else
          ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (context) => BackupReminderProvider()),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => HomeWidgetService(
            context.read<TableProvider>(),
            context.read<TallyProvider>(),
            context.read<LocaleProvider>(),
            context.read<ThemeProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => AuthProvider(
            onSharedAccessLost: ({required ownedToo}) {
              context.read<TableProvider>().clearSharedState(
                joinedOnly: !ownedToo,
              );
              context.read<TallyProvider>().clearSharedState(
                joinedOnly: !ownedToo,
              );
            },
          ),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => SharedSyncService(
            tables: context.read<TableProvider>(),
            tallies: context.read<TallyProvider>(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SubscriptionProvider>(
          create: (context) => SubscriptionProvider(
            context.read<AuthProvider>(),
            legacyUnlimited: legacyUnlimited,
          ),
          update: (context, auth, subscription) {
            subscription!.updateAuth(auth);
            return subscription;
          },
        ),
      ],
      child: TableNoteApp(showOnboarding: showOnboarding, playIntro: playIntro),
    );
  }
}

class TableNoteApp extends StatefulWidget {
  final bool? showOnboarding;
  final bool playIntro;

  const TableNoteApp({super.key, this.showOnboarding, this.playIntro = false});

  @override
  State<TableNoteApp> createState() => _TableNoteAppState();
}

class _TableNoteAppState extends State<TableNoteApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _widgetObserver = HomeWidgetNavigationObserver(() {
    if (mounted) context.read<HomeWidgetService>().navigationChanged();
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, ThemeProvider>(
      builder: (context, localeProvider, themeProvider, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          navigatorObservers: [_widgetObserver],
          title: 'Table Note',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
          locale: localeProvider.locale,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return LaunchIntro(
              enabled: widget.playIntro,
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: isDark
                        ? Brightness.light
                        : Brightness.dark,
                    statusBarBrightness: isDark
                        ? Brightness.dark
                        : Brightness.light,
                    systemNavigationBarColor: theme.colorScheme.surface,
                    systemNavigationBarDividerColor: Colors.transparent,
                    systemNavigationBarIconBrightness: isDark
                        ? Brightness.light
                        : Brightness.dark,
                    systemNavigationBarContrastEnforced: false,
                  ),
                  child: AuthCallbackRouter(
                    navigatorKey: _navigatorKey,
                    child: child ?? const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
          home: AppLaunchGate(showOnboarding: widget.showOnboarding),
        );
      },
    );
  }
}
