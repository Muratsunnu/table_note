import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/widgets/launch_intro.dart';

/// Açılış animasyonu uygulamanın üstünde bir perdedir: oynarken dokunuşları
/// tutar, bitince tamamen kalkar.
void main() {
  const curtain = ValueKey('launch-intro');
  late int taps;

  Future<void> pumpApp(
    WidgetTester tester, {
    bool enabled = true,
    bool reduceMotion = false,
  }) async {
    taps = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          useInheritedMediaQuery: true,
          builder: (context, child) =>
              LaunchIntro(enabled: enabled, child: child!),
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Kayıt Ekle'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('animasyon oynar, bitince perde kalkar', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(curtain), findsOneWidget);

    // Perde kapalıyken arkadaki düğmeye dokunulamaz.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Kayıt Ekle'), warnIfMissed: false);
    expect(taps, 0);

    await tester.pumpAndSettle();
    expect(find.byKey(curtain), findsNothing);

    await tester.tap(find.text('Kayıt Ekle'));
    expect(taps, 1);
  });

  testWidgets('uygulama perdenin arkasında baştan kuruludur', (tester) async {
    await pumpApp(tester);

    // Animasyon yüklemeyi bekletmez; yalnızca üstünü örter.
    expect(find.text('Kayıt Ekle'), findsOneWidget);
  });

  testWidgets('kapalıyken perde hiç çizilmez', (tester) async {
    await pumpApp(tester, enabled: false);

    expect(find.byKey(curtain), findsNothing);
    await tester.tap(find.text('Kayıt Ekle'));
    expect(taps, 1);
  });

  testWidgets('hareketi azalt açıkken animasyon oynatılmaz', (tester) async {
    await pumpApp(tester, reduceMotion: true);
    await tester.pump();

    expect(find.byKey(curtain), findsNothing);
    await tester.tap(find.text('Kayıt Ekle'));
    expect(taps, 1);
  });
}
