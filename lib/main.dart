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
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/app_launch_gate.dart';
import 'services/onboarding_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'widgets/auth_callback_router.dart';
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

  runApp(
    TableNoteRoot(
      themeProvider: themeProvider,
      legacyUnlimited: legacyUnlimited,
      showOnboarding: showOnboarding,
    ),
  );
}

class TableNoteRoot extends StatelessWidget {
  final ThemeProvider themeProvider;

  /// Ücretsiz sınırlar gelmeden önceki sürümden gelen kullanıcı.
  final bool legacyUnlimited;

  /// Açılışta önceden çözülmüşse başlangıç ekranı beklemeden gösterilir.
  final bool? showOnboarding;

  const TableNoteRoot({
    super.key,
    required this.themeProvider,
    this.legacyUnlimited = false,
    this.showOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TableProvider()),
        ChangeNotifierProvider(create: (context) => TemplateProvider()),
        ChangeNotifierProvider(create: (context) => TallyProvider()),
        ChangeNotifierProvider(create: (context) => TallyTemplateProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
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
      child: TableNoteApp(showOnboarding: showOnboarding),
    );
  }
}

class TableNoteApp extends StatefulWidget {
  final bool? showOnboarding;

  const TableNoteApp({super.key, this.showOnboarding});

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
            return ColoredBox(
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
            );
          },
          home: AppLaunchGate(showOnboarding: widget.showOnboarding),
        );
      },
    );
  }
}
