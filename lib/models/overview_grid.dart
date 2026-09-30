import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../utils/number_display.dart';
import 'home_widget_snapshot.dart';
import 'tabel_model.dart';
import 'tally_model.dart';

enum OverviewAlign { start, center, end }

/// Genel bakıştaki tek bir hücre. Renk kararları çizim sırasında temaya göre
/// verilir; burada yalnızca durum rengi ([tint]) taşınır.
class OverviewCell {
  final String text;
  final Color? tint;
  final bool strong;
  final OverviewAlign align;

  const OverviewCell(
    this.text, {
    this.tint,
    this.strong = false,
    this.align = OverviewAlign.start,
  });

  static const empty = OverviewCell('');
}

/// Tablonun ya da çetelenin tamamı: başlık, satırlar, isteğe bağlı toplam
/// satırı. Salt okunurdur; düzenleme her zaman normal ekranda yapılır.
class OverviewGrid {
  static const double fontSize = 13;
  static const double headerHeight = 44;
  static const double rowHeight = 36;
  static const double cellPadding = 10;

  /// Dar sütunlarda (çetele günleri) iç boşluk metne yer bırakacak kadar küçülür.
  static double paddingFor(double columnWidth) =>
      math.min(cellPadding, columnWidth * 0.15);

  final String title;
  final List<double> columnWidths;
  final List<OverviewCell> header;
  final List<List<OverviewCell>> rows;
  final List<OverviewCell>? footer;

  /// Soldan kaç sütunun yatay kaydırmada sabit kalacağı.
  final int frozenColumns;

  /// Vurgulanan sütunlar; çetelede bugünün günü.
  final Set<int> highlightedColumns;

  late final List<double> columnOffsets = () {
    final offsets = <double>[0];
    for (final width in columnWidths) {
      offsets.add(offsets.last + width);
    }
    return offsets;
  }();

  OverviewGrid({
    required this.title,
    required this.columnWidths,
    required this.header,
    required this.rows,
    this.footer,
    this.frozenColumns = 0,
    this.highlightedColumns = const {},
  }) : assert(header.length == columnWidths.length),
       assert(frozenColumns >= 0 && frozenColumns <= columnWidths.length);

  int get columnCount => columnWidths.length;
  double get width => columnOffsets.last;
  double get frozenWidth => columnOffsets[frozenColumns];

  /// Gövde satırı sayısı; toplam satırı varsa sona eklenir.
  int get bodyRowCount => rows.length + (footer == null ? 0 : 1);
  double get height => headerHeight + bodyRowCount * rowHeight;
  bool isFooter(int bodyRow) => bodyRow == rows.length && footer != null;
  List<OverviewCell> bodyRow(int index) =>
      index < rows.length ? rows[index] : footer!;
  double bodyRowTop(int index) => headerHeight + index * rowHeight;
}

/// Genişlik tahmini için ölçülen en fazla satır; daha uzun metinler kısalır.
const int _measuredRows = 400;

double _textWidth(String text, {required bool strong}) {
  if (text.isEmpty) return 0;
  var widest = 0.0;
  for (final line in text.split('\n')) {
    final painter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontSize: OverviewGrid.fontSize,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return widest;
}

List<double> _fitWidths(
  List<OverviewCell> header,
  List<List<OverviewCell>> rows,
  List<OverviewCell>? footer, {
  double min = 44,
  double max = 240,
}) {
  final widths = [
    for (final cell in header) _textWidth(cell.text, strong: true),
  ];
  for (final row in [...rows.take(_measuredRows), if (footer != null) footer]) {
    for (var c = 0; c < row.length && c < widths.length; c++) {
      widths[c] = math.max(
        widths[c],
        _textWidth(row[c].text, strong: row[c].strong),
      );
    }
  }
  return [
    for (final width in widths)
      (width + 2 * OverviewGrid.cellPadding).clamp(min, max).toDouble(),
  ];
}

/// Tablonun tamamı, [order] sırasıyla (ekrandaki sıralama, arama hariç).
/// Toplamlar uygulamadaki "Toplamlar" kutusuyla aynı kuralı izler.
OverviewGrid buildTableOverview(
  TableModel table,
  List<int> order, {
  required String language,
}) {
  final tr = language != 'en';
  final columns = table.columns;
  bool summable(ColumnModel column) =>
      !column.isConstant &&
      !column.isAutoNumber &&
      (column.isNumeric || column.isFormula);
  OverviewAlign alignOf(ColumnModel column) =>
      column.isEffectivelyNumeric || column.isAutoNumber
      ? OverviewAlign.end
      : OverviewAlign.start;

  final header = [
    for (final column in columns)
      OverviewCell(column.name, strong: true, align: alignOf(column)),
  ];
  String cellText(List<String> row, int c) {
    final raw = c < row.length ? row[c].trim() : '';
    if (!showsGroupedNumbers(columns[c])) return raw;
    return formatNumericCell(raw, language: language) ?? raw;
  }

  final rows = [
    for (final index in order)
      [
        for (var c = 0; c < columns.length; c++)
          OverviewCell(
            cellText(table.rows[index], c),
            align: alignOf(columns[c]),
          ),
      ],
  ];

  final sums = <int, double>{};
  for (var c = 0; c < columns.length; c++) {
    if (!summable(columns[c])) continue;
    var sum = 0.0;
    for (final row in table.rows) {
      if (c >= row.length) continue;
      final value = double.tryParse(row[c]);
      if (value != null && value.isFinite) sum += value;
    }
    sums[c] = sum;
  }
  final footer = sums.isEmpty
      ? null
      : [
          for (var c = 0; c < columns.length; c++)
            if (sums.containsKey(c))
              OverviewCell(
                // Same grouping as the in-app totals: 47.070 / 47,070.
                HomeWidgetSnapshot.formatNumber(sums[c]!, language),
                strong: true,
                align: OverviewAlign.end,
              )
            else if (c == 0)
              OverviewCell(tr ? 'Toplam' : 'Total', strong: true)
            else
              OverviewCell.empty,
        ];

  return OverviewGrid(
    title: table.tableName,
    columnWidths: _fitWidths(header, rows, footer),
    header: header,
    rows: rows,
    footer: footer,
    frozenColumns: columns.isEmpty ? 0 : 1,
  );
}

const _trWeekdays = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
const _enWeekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/// Çetelenin tamamı: bütün günler ve her öğenin durum sayıları.
/// Sayımlar çetelenin tarih aralığındandır; toplamlarla aynı kural.
OverviewGrid buildTallyOverview(
  TallyTableModel table,
  List<int> order, {
  required String language,
  required String itemHeader,
  DateTime? today,
}) {
  final tr = language != 'en';
  final days = table.allDays;
  final statuses = table.statuses;
  final byCode = {for (final status in statuses) status.code: status};
  const dayStart = 2;
  final countStart = dayStart + days.length;

  final header = [
    const OverviewCell('#', strong: true, align: OverviewAlign.center),
    OverviewCell(itemHeader, strong: true),
    for (final day in days)
      OverviewCell(
        '${day.day}\n${(tr ? _trWeekdays : _enWeekdays)[day.weekday - 1]}',
        strong: true,
        align: OverviewAlign.center,
      ),
    for (final status in statuses)
      OverviewCell(
        status.code,
        tint: Color(status.colorValue),
        strong: true,
        align: OverviewAlign.center,
      ),
  ];

  final totals = {for (final status in statuses) status.code: 0};
  final rows = <List<OverviewCell>>[];
  for (var position = 0; position < order.length; position++) {
    final item = table.items[order[position]];
    final counts = {for (final status in statuses) status.code: 0};
    final dayCells = <OverviewCell>[];
    for (final day in days) {
      final code = item.entries[TallyTableModel.dateKey(day)];
      final status = code == null ? null : byCode[code];
      if (status != null) counts[status.code] = counts[status.code]! + 1;
      dayCells.add(
        code == null
            ? OverviewCell.empty
            : OverviewCell(
                code,
                // A mark whose status was deleted keeps its code, uncoloured.
                tint: status == null ? null : Color(status.colorValue),
                strong: status != null,
                align: OverviewAlign.center,
              ),
      );
    }
    counts.forEach((code, count) => totals[code] = totals[code]! + count);
    rows.add([
      OverviewCell('${position + 1}', align: OverviewAlign.center),
      OverviewCell(item.name.trim()),
      ...dayCells,
      for (final status in statuses)
        OverviewCell(
          HomeWidgetSnapshot.formatNumber(
            counts[status.code]!.toDouble(),
            language,
          ),
          strong: true,
          align: OverviewAlign.center,
        ),
    ]);
  }

  final footer = [
    OverviewCell.empty,
    OverviewCell(tr ? 'Toplam' : 'Total', strong: true),
    for (var i = 0; i < days.length; i++) OverviewCell.empty,
    for (final status in statuses)
      OverviewCell(
        HomeWidgetSnapshot.formatNumber(
          totals[status.code]!.toDouble(),
          language,
        ),
        strong: true,
        align: OverviewAlign.center,
      ),
  ];

  final measured = _fitWidths(header, rows, footer);
  final widths = [
    for (var c = 0; c < measured.length; c++)
      if (c == 0)
        math.max(40.0, measured[c])
      else if (c == 1)
        measured[c].clamp(88.0, 200.0).toDouble()
      else if (c < countStart)
        // Day cells hold a one or two letter code; keep the month compact.
        28.0
      else
        measured[c],
  ];

  final highlighted = <int>{};
  if (today != null) {
    final key = TallyTableModel.dateKey(today);
    final index = days.indexWhere((day) => TallyTableModel.dateKey(day) == key);
    if (index >= 0) highlighted.add(dayStart + index);
  }

  return OverviewGrid(
    title: table.tableName,
    columnWidths: widths,
    header: header,
    rows: rows,
    footer: rows.isEmpty ? null : footer,
    frozenColumns: 2,
    highlightedColumns: highlighted,
  );
}
