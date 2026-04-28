import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/table_provider.dart';
import 'providers/template_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/tally_provider.dart';
import 'screens/table_screen.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TableProvider()),
        ChangeNotifierProvider(create: (context) => TemplateProvider()),
        ChangeNotifierProvider(create: (context) => TallyProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
      ],
      child: const TableNoteApp(),
    ),
  );
}

class TableNoteApp extends StatelessWidget {
  const TableNoteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: 'Table Note',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr', 'TR'),
            Locale('en', 'US'),
          ],
          locale: localeProvider.locale,
          theme: AppTheme.theme,
          home: TableScreen(),
        );
      },
    );
  }
}
