import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:table_note/main.dart';
import 'package:table_note/providers/theme_provider.dart';

void main() {
  testWidgets('uygulama sağlayıcılarıyla açılır', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed_v1': true});

    await tester.pumpWidget(TableNoteRoot(themeProvider: ThemeProvider()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    // Material 3 NavigationBar, not the legacy BottomNavigationBar.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('Table Note'), findsWidgets);
  });

  testWidgets('yeni kullanıcıya ilk açılış tanıtımını gösterir', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(TableNoteRoot(themeProvider: ThemeProvider()));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Kayıtlarını Düzenle'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
  });
}
