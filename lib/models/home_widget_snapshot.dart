import 'dart:convert';

import 'package:flutter/painting.dart';

import '../theme/app_theme.dart';
import '../utils/number_display.dart';
import 'tabel_model.dart';
import 'tally_model.dart';

/// A read-only summary plus the most recent entries, never auth tokens or the
/// primary database. Recent entries are visible on the home screen by design.
class HomeWidgetSnapshot {
  /// How many recent entries travel per table. Keeps the shared payload small.
  /// The large widget draws a grid, so it wants a few more than a list did.
  static const int maxRecent = 7;
  static const int _cellLimit = 24;
  static const int _lineLimit = 56;

  /// A widget column is narrow; grid cells are clipped harder than list lines.
  static const int _gridCellLimit = 14;

  /// Columns sent per table. The widget drops the rightmost ones when the
  /// family is too narrow, and appends the selected number column itself.
  static const int maxGridColumns = 3;

  /// Days sent per tally, ending at today when the range covers it.
  static const int maxGridDays = 4;

  static String encode({
    required List<TableModel> tables,
    required List<TallyTableModel> tallies,
    required String language,
    required bool dark,

    /// On-screen order per table or tally id, for the ones the user sorted.
    /// Missing means unsorted, and each kind keeps its own default order.
    Map<String, List<int>> orders = const {},

    /// The app's own colours, so the widget draws the same table it does.
    /// Empty means the widget keeps its built-in fallback palette.
    Map<String, int> palette = const {},
  }) {
    final tr = language != 'en';
    final entries = <Map<String, Object>>[];
    void add({
      required String kind,
      required String id,
      required String name,
      required int count,
      required List<Map<String, Object>> metrics,
      required List<Map<String, Object>> recent,
      required List<Map<String, Object>> columns,
      List<String>? footer,
      Map<String, Object>? extra,
    }) {
      final countValue = formatNumber(count.toDouble(), language);
      entries.add({
        if (extra != null) ...extra,
        'rows': recent,
        'columns': columns,
        if (footer != null) 'footer': footer,
        'id': '$kind:$id',
        'kind': kind,
        'tableId': id,
        'name': name,
        'count': count,
        'countValue': countValue,
        'countText': tr
            ? '$countValue ${kind == 'table' ? 'kayıt' : 'öğe'}'
            : '$countValue ${kind == 'table' ? 'records' : 'items'}',
        'typeText': tr
            ? (kind == 'table' ? 'Tablo' : 'Çetele')
            : (kind == 'table' ? 'Table' : 'Tally'),
        'metrics': metrics,
      });
    }

    for (final table in tables) {
      final metrics = <Map<String, Object>>[];
      // Use name + occurrence, not position: reordering columns keeps a selection.
      final occurrences = <String, int>{};
      final metricColumn = <String, int>{};
      for (var i = 0; i < table.columns.length; i++) {
        final column = table.columns[i];
        final occurrence = occurrences.update(
          column.name,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        if (column.isConstant ||
            column.isAutoNumber ||
            (!column.isNumeric && !column.isFormula)) {
          continue;
        }
        var total = 0.0;
        for (final row in table.rows) {
          if (i >= row.length) continue;
          final value = double.tryParse(row[i]);
          if (value != null && value.isFinite) total += value;
        }
        final id = jsonEncode([column.name, occurrence]);
        metricColumn[id] = i;
        metrics.add({
          'id': id,
          'label': column.name,
          'value': formatNumber(total, language),
        });
      }
      // The widget draws these as a real grid, so it gets the user's own column
      // order. Row numbers are left out: the widget has too little width to
      // spend on a counter.
      final shown = <int>[];
      for (var i = 0; i < table.columns.length; i++) {
        if (table.columns[i].isAutoNumber) continue;
        shown.add(i);
        if (shown.length == maxGridColumns) break;
      }
      final columns = [
        for (final i in shown)
          <String, Object>{
            'label': clip(table.columns[i].name.trim(), _gridCellLimit),
            'numeric': showsGroupedNumbers(table.columns[i]),
            // Lets the widget tell whether the chosen total is already a column.
            for (final entry in metricColumn.entries)
              if (entry.value == i) 'metricId': entry.key,
          },
      ];

      final recent = <Map<String, Object>>[];
      // A sorted table is read from the top, exactly as it looks in the app.
      // An unsorted one is newest first: the last thing entered matters most.
      final order =
          orders[table.id]?.take(maxRecent).toList() ??
          [
            for (
              var r = table.rows.length - 1;
              r >= _firstRecent(table.rows.length);
              r--
            )
              r,
          ];
      for (final r in order) {
        if (r < 0 || r >= table.rows.length) continue;
        final row = table.rows[r];
        // The leading filled cells read like the table's own row.
        final parts = <String>[];
        for (var i = 0; i < table.columns.length && parts.length < 3; i++) {
          if (table.columns[i].isAutoNumber || i >= row.length) continue;
          final cell = row[i].trim();
          if (cell.isEmpty) continue;
          parts.add(clip(cell, _cellLimit));
        }
        final values = <String, String>{};
        for (final entry in metricColumn.entries) {
          if (entry.value >= row.length) continue;
          final value = double.tryParse(row[entry.value]);
          if (value == null || !value.isFinite) continue;
          values[entry.key] = formatNumber(value, language);
        }
        recent.add({
          'text': clip(parts.join(' · '), _lineLimit),
          'values': values,
          'cells': [
            for (final i in shown)
              _gridCell(table.columns[i], row, i, language),
          ],
        });
      }

      // Same rule as the app's totals box, so the two never disagree.
      final totals = {
        for (final metric in metrics)
          metricColumn[metric['id']]!: metric['value'] as String,
      };
      final footer = totals.keys.any(shown.contains)
          ? [
              for (final i in shown)
                totals[i] ??
                    (i == shown.first ? (tr ? 'Toplam' : 'Total') : ''),
            ]
          : null;

      add(
        kind: 'table',
        id: table.id,
        name: table.tableName,
        count: table.rows.length,
        metrics: metrics,
        recent: recent,
        columns: columns,
        footer: footer,
      );
    }
    for (final table in tallies) {
      final totals = {for (final status in table.statuses) status.code: 0};
      final start = TallyTableModel.dateKey(table.startDate);
      final end = TallyTableModel.dateKey(table.endDate);
      for (final item in table.items) {
        for (final entry in item.entries.entries) {
          if (entry.key.compareTo(start) >= 0 &&
              entry.key.compareTo(end) <= 0 &&
              totals.containsKey(entry.value)) {
            totals[entry.value] = totals[entry.value]! + 1;
          }
        }
      }
      // A tally is a roster, not a timeline: show it in its own order, and when
      // today falls inside the range show today's mark instead of a bare count.
      final now = DateTime.now();
      final todayKey = TallyTableModel.dateKey(now);
      final todayInRange =
          todayKey.compareTo(start) >= 0 && todayKey.compareTo(end) <= 0;
      final byCode = {for (final status in table.statuses) status.code: status};
      var marked = 0;
      if (todayInRange) {
        for (final item in table.items) {
          if (byCode.containsKey(item.entries[todayKey])) marked++;
        }
      }
      // The days the widget draws: the last few of the range, ending on today
      // when today falls inside it. A roster is read from the newest day back.
      final days = <DateTime>[];
      {
        var anchor = DateTime(now.year, now.month, now.day);
        if (todayKey.compareTo(end) > 0) anchor = table.endDate;
        if (todayKey.compareTo(start) < 0) {
          anchor = table.startDate.add(const Duration(days: maxGridDays - 1));
        }
        for (var d = maxGridDays - 1; d >= 0; d--) {
          final day = anchor.subtract(Duration(days: d));
          final key = TallyTableModel.dateKey(day);
          if (key.compareTo(start) < 0 || key.compareTo(end) > 0) continue;
          days.add(day);
        }
      }
      final columns = [
        <String, Object>{'label': tr ? 'Kayıt' : 'Item', 'numeric': false},
        for (final day in days)
          <String, Object>{'label': '${day.day}', 'numeric': false},
      ];
      final todayColumn = todayInRange
          ? days.indexWhere((day) => TallyTableModel.dateKey(day) == todayKey)
          : -1;

      final recent = <Map<String, Object>>[];
      final itemOrder =
          orders[table.id] ??
          List<int>.generate(table.items.length, (index) => index);
      for (final i in itemOrder.take(maxRecent)) {
        if (i < 0 || i >= table.items.length) continue;
        final item = table.items[i];
        final counts = {for (final status in table.statuses) status.code: 0};
        for (final entry in item.entries.entries) {
          if (entry.key.compareTo(start) >= 0 &&
              entry.key.compareTo(end) <= 0 &&
              counts.containsKey(entry.value)) {
            counts[entry.value] = counts[entry.value]! + 1;
          }
        }
        final marks = [
          for (final day in days)
            byCode[item.entries[TallyTableModel.dateKey(day)]],
        ];
        final row = <String, Object>{
          'text': clip(item.name.trim(), _lineLimit),
          'values': {
            for (final status in table.statuses)
              status.code: formatNumber(
                counts[status.code]!.toDouble(),
                language,
              ),
          },
          'cells': [
            clip(item.name.trim(), _gridCellLimit),
            for (final status in marks) status?.code ?? '',
          ],
          // Aligned with the cells; the name column is never tinted.
          'colors': <Object?>[
            null,
            for (final status in marks) status?.colorValue,
          ],
          // The tint the app writes the code in; the raw colour above still
          // paints the cell behind it, exactly as the tally screen does.
          'inks': <Object?>[
            null,
            for (final status in marks)
              if (status == null)
                null
              else
                AppTheme.readableInk(
                  Color(status.colorValue),
                  dark: dark,
                ).toARGB32(),
          ],
        };
        if (todayInRange) {
          final status = byCode[item.entries[todayKey]];
          row['todayLabel'] = status == null
              ? '—'
              : clip(status.label.trim(), _cellLimit);
          if (status != null) row['todayColor'] = status.colorValue;
        }
        recent.add(row);
      }
      add(
        kind: 'tally',
        id: table.id,
        name: table.tableName,
        count: table.items.length,
        metrics: [
          for (final status in table.statuses)
            <String, Object>{
              'id': status.code,
              'label': status.label,
              'value': formatNumber(totals[status.code]!.toDouble(), language),
            },
        ],
        recent: recent,
        columns: columns,
        extra: todayInRange
            ? {
                'todayText': tr
                    ? 'Bugün · ${dayText(now)}'
                    : 'Today · ${dayText(now)}',
                'todayMarked': tr
                    ? '${formatNumber(marked.toDouble(), language)} / '
                          '${formatNumber(table.items.length.toDouble(), language)} işaretlendi'
                    : '${formatNumber(marked.toDouble(), language)} of '
                          '${formatNumber(table.items.length.toDouble(), language)} marked',
                if (todayColumn >= 0) 'todayColumn': todayColumn + 1,
              }
            : null,
      );
    }
    return jsonEncode({
      'version': 1,
      'language': tr ? 'tr' : 'en',
      'dark': dark,
      'palette': palette,
      'entries': entries,
      'strings': {
        'choose': tr ? 'Tablo veya çetele seç' : 'Choose a table or tally',
        'empty': tr
            ? 'Önce uygulamada bir tablo oluştur.'
            : 'Create a table in the app first.',
        'missing': tr
            ? 'Seçim artık mevcut değil. Widget’ı düzenle.'
            : 'Selection no longer exists. Edit the widget.',
        'add': tr ? '+ Kayıt ekle' : '+ Add record',
        'addItem': tr ? '+ Öğe ekle' : '+ Add item',
        'open': tr ? 'Uygulamayı aç' : 'Open app',
        'edit': tr ? 'Widget’ı düzenle' : 'Edit widget',
        'countOnly': tr ? 'Yalnızca kayıt sayısı' : 'Record count only',
        'total': tr ? 'Toplam' : 'Total',
        'save': tr ? 'Kaydet' : 'Save',
      },
    });
  }

  /// One grid cell, formatted the way the app's own table draws it.
  static String _gridCell(
    ColumnModel column,
    List<String> row,
    int index,
    String language,
  ) {
    final raw = index < row.length ? row[index].trim() : '';
    if (!showsGroupedNumbers(column)) return clip(raw, _gridCellLimit);
    return clip(
      formatNumericCell(raw, language: language) ?? raw,
      _gridCellLimit,
    );
  }

  /// Day stamp in the same shape the app's tables use: 15.09.2026.
  static String dayText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';

  /// Index of the first entry that still fits in [maxRecent].
  static int _firstRecent(int length) =>
      length > maxRecent ? length - maxRecent : 0;

  /// Shortens without splitting a surrogate pair, so emoji survive intact.
  static String clip(String value, int max) {
    if (value.length <= max) return value;
    var end = max - 1;
    final unit = value.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end -= 1;
    return '${value.substring(0, end)}…';
  }

  static String formatNumber(double value, String language) =>
      formatGroupedNumber(value, language);
}

class HomeWidgetRequest {
  final String kind;
  final String tableId;
  final bool add;
  const HomeWidgetRequest({
    required this.kind,
    required this.tableId,
    required this.add,
  });

  static HomeWidgetRequest? parse(Uri uri) {
    if (uri.scheme != 'com.muratstudio.tablenote' ||
        uri.host != 'widget' ||
        !{'/open', '/add'}.contains(uri.path)) {
      return null;
    }
    final kind = uri.queryParameters['kind'];
    final id = uri.queryParameters['id'];
    if (!{'table', 'tally'}.contains(kind) ||
        id == null ||
        id.isEmpty ||
        id.length > 128) {
      return null;
    }
    return HomeWidgetRequest(kind: kind!, tableId: id, add: uri.path == '/add');
  }
}
