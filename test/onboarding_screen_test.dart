import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/screens/onboarding_screen.dart';
import 'package:table_note/widgets/onboarding_previews.dart';

void main() {
  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('tanıtım dört sayfadır ve sesle kaydı anlatır ($locale)', (
      tester,
    ) async {
      final loc = AppLocalizations(locale);
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OnboardingScreen(onComplete: () async => completed++),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> next() async {
        await tester.tap(find.text(loc.continueLabel));
        await tester.pumpAndSettle();
      }

      expect(find.text(loc.onboardingOrganizeTitle), findsOneWidget);
      await next();
      expect(find.text(loc.onboardingOfflineTitle), findsOneWidget);
      await next();
      // Üçüncü sayfa: sesle kayıt, Premium'a özel olduğu da yazar.
      expect(find.text(loc.onboardingVoiceTitle), findsOneWidget);
      expect(find.byType(OnboardingVoicePreview), findsOneWidget);
      expect(find.text(loc.premium), findsOneWidget);
      await next();
      expect(find.text(loc.onboardingPremiumTitle), findsOneWidget);

      // Son sayfada "İleri" yerine başlama düğmesi durur.
      expect(find.text(loc.continueLabel), findsNothing);
      expect(completed, 0);
      await tester.tap(find.text(loc.startUsing));
      await tester.pump();
      expect(completed, 1);
    });
  }
}
