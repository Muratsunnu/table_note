import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/overview_grid.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/widgets/grid_overview_screen.dart';

/// A month-long roster: far wider and taller than a phone screen.
OverviewGrid _monthGrid() {
  final start = DateTime(2026, 9, 1);
  final table = TallyTableModel(
    tableName: 'Eylül yoklaması',
    startDate: start,
    endDate: DateTime(2026, 9, 30),
    statuses: [
      TallyStatus(code: 'V', label: 'Var', colorValue: 0xFF2E7D32),
      TallyStatus(code: 'Y', label: 'Yok', colorValue: 0xFFC62828),
    ],
    items: [
      for (var i = 0; i < 40; i++)
        TallyItemModel(
          name: 'Öğrenci ${i + 1}',
          entries: {
            for (var d = 0; d < 30; d += 1 + i % 3)
              TallyTableModel.dateKey(start.add(Duration(days: d))): d.isEven
                  ? 'V'
                  : 'Y',
          },
        ),
    ],
  );
  return buildTallyOverview(
    table,
    List<int>.generate(40, (i) => i),
    language: 'tr',
    itemHeader: 'Kayıt',
    today: DateTime(2026, 9, 17),
  );
}

final _canvas = find.byKey(GridOverviewScreen.canvasKey);

Future<TransformationController> _open(
  WidgetTester tester,
  OverviewGrid grid,
) async {
  final controller = TransformationController();
  addTearDown(controller.dispose);
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: GridOverviewScreen(grid: grid, controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

double _fit(WidgetTester tester, OverviewGrid grid) =>
    OverviewViewport.fitScale(
      tester.getSize(_canvas),
      Size(grid.width, grid.height),
    );

void main() {
  testWidgets('açılışta çetelenin tamamı ekrana sığar', (tester) async {
    final grid = _monthGrid();
    final controller = await _open(tester, grid);
    final fit = _fit(tester, grid);
    expect(fit, lessThan(1));
    expect(OverviewViewport.scaleOf(controller.value), closeTo(fit, 1e-9));
    expect(OverviewViewport.translationOf(controller.value), Offset.zero);
    expect(find.text('Eylül yoklaması'), findsOneWidget);
  });

  testWidgets('çift dokunuş yakınlaşır, ikincisi tamamına döner', (
    tester,
  ) async {
    final grid = _monthGrid();
    final controller = await _open(tester, grid);
    final fit = _fit(tester, grid);
    final viewer = _canvas;

    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    expect(OverviewViewport.scaleOf(controller.value), greaterThan(fit * 2));

    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    expect(OverviewViewport.scaleOf(controller.value), closeTo(fit, 1e-6));
  });

  testWidgets('yakınlaşıp kaydırınca sabit katman sorunsuz çizilir', (
    tester,
  ) async {
    final grid = _monthGrid();
    final controller = await _open(tester, grid);
    final viewer = _canvas;

    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    await tester.drag(viewer, const Offset(-250, -400));
    await tester.pumpAndSettle();

    final moved = OverviewViewport.translationOf(controller.value);
    // Scrolled past both the header row and the pinned columns.
    expect(moved.dx, lessThan(0));
    expect(moved.dy, lessThan(0));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Tamamını sığdır'));
    await tester.pumpAndSettle();
    expect(
      OverviewViewport.scaleOf(controller.value),
      closeTo(_fit(tester, grid), 1e-6),
    );
    expect(OverviewViewport.translationOf(controller.value), Offset.zero);
  });

  testWidgets('geniş ama kısa çetelede yan çevirme ipucu çıkar', (
    tester,
  ) async {
    final start = DateTime(2026, 9, 1);
    final wide = buildTallyOverview(
      TallyTableModel(
        tableName: 'kısa',
        startDate: start,
        endDate: DateTime(2026, 9, 30),
        statuses: [TallyStatus(code: 'V', label: 'Var', colorValue: 0)],
        items: [for (var i = 0; i < 5; i++) TallyItemModel(name: 'Kişi $i')],
      ),
      [0, 1, 2, 3, 4],
      language: 'tr',
      itemHeader: 'Kayıt',
    );
    await _open(tester, wide);
    const hint = 'Daha büyük görmek için telefonu yan çevir';
    expect(find.text(hint), findsOneWidget);

    // Advice for the first look only: any pinch or drag puts it away.
    await tester.drag(_canvas, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
  });

  testWidgets('geniş ama kısa çetelede art arda yakınlaştırmalar birikir', (
    tester,
  ) async {
    // Wider than the screen but far shorter: the shape that used to stall
    // pinch zoom at roughly four times the fitted scale.
    final start = DateTime(2026, 9, 1);
    final grid = buildTallyOverview(
      TallyTableModel(
        tableName: 'kısa',
        startDate: start,
        endDate: DateTime(2026, 9, 30),
        statuses: [TallyStatus(code: 'Y', label: 'Y', colorValue: 0)],
        items: [for (var i = 0; i < 7; i++) TallyItemModel(name: 'Kişi $i')],
      ),
      List.generate(7, (i) => i),
      language: 'tr',
      itemHeader: 'Kayıt',
    );
    final controller = await _open(tester, grid);
    final center = tester.getTopLeft(_canvas) + const Offset(200, 100);

    Future<void> pinch(double from, double to) async {
      final a = await tester.startGesture(center - Offset(from / 2, 0));
      final b = await tester.startGesture(center + Offset(from / 2, 0));
      await tester.pump(const Duration(milliseconds: 20));
      for (var i = 1; i <= 10; i++) {
        final d = from + (to - from) * i / 10;
        await a.moveTo(center - Offset(d / 2, 0));
        await b.moveTo(center + Offset(d / 2, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    }

    await pinch(60, 240);
    final first = OverviewViewport.scaleOf(controller.value);
    await pinch(60, 240);
    final second = OverviewViewport.scaleOf(controller.value);
    expect(second, greaterThan(first * 2.5));
    expect(second, lessThanOrEqualTo(4.0));
  });

  testWidgets('hem geniş hem uzun çetelede ipucu çıkmaz', (tester) async {
    await _open(tester, _monthGrid());
    expect(
      find.text('Daha büyük görmek için telefonu yan çevir'),
      findsNothing,
    );
  });

  testWidgets('küçük bir tablo büyütülmeden gösterilir', (tester) async {
    final grid = OverviewGrid(
      title: 'küçük',
      columnWidths: const [80, 80],
      header: const [OverviewCell('a'), OverviewCell('b')],
      rows: const [
        [OverviewCell('1'), OverviewCell('2')],
      ],
      frozenColumns: 1,
    );
    final controller = await _open(tester, grid);
    expect(OverviewViewport.scaleOf(controller.value), 1);
  });
}
