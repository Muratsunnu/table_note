import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/overview_grid.dart' show weekdayShort;
import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import '../utils/column_balance.dart';
import '../utils/column_sums.dart';
import '../utils/number_display.dart';
import 'pdf_report.dart';

/// Dosyaya ne yazılacağı: tablonun (çetelenin) tamamı ya da aramayla
/// seçilmiş kısmı.
class ExportSelection {
  const ExportSelection({
    required this.order,
    this.search,
    this.searchTerm,
    this.from,
    this.to,
  });

  /// Dosyaya girecek satırlar (çetelede öğeler), ekrandaki sırayla.
  final List<int> order;

  /// Aramanın dosyanın başlığında yazılacak hâli: "yükleme: Konya".
  /// Tamamı yazılıyorsa null.
  final String? search;

  /// Dosya adına eklenecek söz: "Konya".
  final String? searchTerm;

  /// Çetelede yazılacak günler; null ise çetelenin kendi aralığı.
  final DateTime? from;
  final DateTime? to;

  bool get isFiltered => search != null;
}

class ExportService {
  /// Her dosyanın adı bununla başlar: gönderilen dosya uygulamayı da tanıtır.
  static const appName = 'Table Note';

  static Future<String> exportToCsv(
    TableModel table, {
    required AppLocalizations loc,
    ExportSelection? selection,
  }) async {
    final file = await _exportFile(
      fileBaseName(table.tableName, tag: selection?.searchTerm),
      'csv',
    );
    await file.writeAsString(
      tableCsv(table, loc: loc, selection: selection),
      encoding: const Utf8Codec(),
    );
    return file.path;
  }

  /// Tablonun CSV metni. Arama sonucunda başlangıç değeri ve kalan yazılmaz:
  /// ikisi de tablonun tamamına aittir, bir kısmının yanında yanıltır.
  @visibleForTesting
  static String tableCsv(
    TableModel table, {
    AppLocalizations? loc,
    ExportSelection? selection,
  }) {
    final csv = StringBuffer();
    csv.writeln(
      table.columns.map((col) => _escapeCsvField(col.name)).join(','),
    );
    for (final row in _selectedRows(table, selection)) {
      csv.writeln(row.map(_escapeCsvField).join(','));
    }
    if (selection?.isFiltered != true) {
      csv.write(balanceCsvLines(table, loc: loc));
    }
    return csv.toString();
  }

  /// Başlangıç değeri olan sütunların özeti: toplam, başlangıç değeri ve
  /// kalan. Satırlardan boş bir satırla ayrılır; başlangıç değeri yoksa boş
  /// döner ve dosya eskisiyle aynı kalır. Sayılar ayraçsız yazılır ki tablo
  /// programları sayı olarak okusun.
  static String balanceCsvLines(TableModel table, {AppLocalizations? loc}) {
    final balances = computeColumnBalances(table);
    if (balances.isEmpty) return '';
    String number(double value) => value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    final out = StringBuffer()..writeln();
    for (final balance in balances) {
      void line(String label, double value) => out.writeln(
        '${_escapeCsvField('$label (${balance.name})')},${number(value)}',
      );
      line(loc?.totalLabel ?? 'Toplam', balance.total);
      line(loc?.startingValue ?? 'Başlangıç değeri', balance.startingValue);
      line(loc?.remaining ?? 'Kalan', balance.remaining);
    }
    return out.toString();
  }

  static Future<String> exportToPdf(
    TableModel table, {
    required AppLocalizations loc,
    ExportSelection? selection,
  }) async {
    final bytes = await renderInBackground(
      buildTablePdf,
      tableReport(table, loc: loc, selection: selection),
      await _loadFonts(),
    );
    final file = await _exportFile(
      fileBaseName(table.tableName, tag: selection?.searchTerm),
      'pdf',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Tablonun PDF'te yazılacak hâli: hücreler ekrandaki gibi ayraçlı,
  /// en altta seçilen satırların toplamı.
  @visibleForTesting
  static TableReport tableReport(
    TableModel table, {
    required AppLocalizations loc,
    ExportSelection? selection,
    DateTime? now,
  }) {
    final language = loc.locale.languageCode;
    final columns = table.columns;
    final rows = _selectedRows(table, selection);

    String cell(List<String> row, int index) {
      final raw = index < row.length ? row[index] : '';
      // Miktarlar uygulamadaki gibi okunur; sıra numarası ve metin yazıldığı
      // gibi kalır.
      return showsGroupedNumbers(columns[index])
          ? formatNumericCell(raw, language: language) ?? raw
          : raw;
    }

    final totals = columnTotals(table, rows);
    final notes = <ReportNote>[];
    List<String>? totalRow;
    if (totals.any((total) => total != null)) {
      // "Toplam" yazısı toplanmayan ilk sütuna oturur; her sütun toplanıyorsa
      // toplamlar tablonun altına ayrı ayrı yazılır.
      final labelColumn = columns.indexWhere((column) => !column.isSummed);
      if (labelColumn >= 0) {
        totalRow = [
          for (var index = 0; index < columns.length; index++)
            if (totals[index] case final total?)
              formatGroupedNumber(total, language)
            else if (index == labelColumn)
              loc.totalLabel
            else
              '',
        ];
      } else {
        for (var index = 0; index < columns.length; index++) {
          notes.add(
            ReportNote(
              '${loc.totalLabel} · ${columns[index].name}',
              formatGroupedNumber(totals[index]!, language),
            ),
          );
        }
      }
    }
    // Başlangıç değeri ve kalan tablonun tamamına aittir; arama sonucunda
    // yazılmaz.
    if (selection?.isFiltered != true) {
      for (final balance in computeColumnBalances(table)) {
        notes.add(
          ReportNote(
            '${balance.name} · ${loc.startingValue}',
            formatGroupedNumber(balance.startingValue, language),
          ),
        );
        notes.add(
          ReportNote(
            loc.remainingOf(balance.name),
            formatGroupedNumber(balance.remaining, language),
            alert: balance.isExceeded,
          ),
        );
      }
    }

    return TableReport(
      frame: _frame(
        loc,
        title: table.tableName,
        tag: selection?.searchTerm,
        lines: [
          if (selection?.search case final search?)
            loc.exportSearchLine(search),
        ],
        count: rows.length,
        now: now,
      ),
      headers: [for (final column in columns) column.name],
      aligns: [for (final column in columns) _align(column)],
      rows: [
        for (final row in rows)
          [
            for (var index = 0; index < columns.length; index++)
              cell(row, index),
          ],
      ],
      totalRow: totalRow,
      notes: notes,
    );
  }

  // ============== ÇETELE EXPORT ==============

  static Future<String> exportTallyCsv(
    TallyTableModel table, {
    required AppLocalizations loc,
    ExportSelection? selection,
  }) async {
    final file = await _exportFile(
      fileBaseName(table.tableName, tag: selection?.searchTerm),
      'csv',
    );
    await file.writeAsString(
      tallyCsv(table, loc: loc, selection: selection),
      encoding: const Utf8Codec(),
    );
    return file.path;
  }

  /// Çetelenin CSV metni: gün gün işaretler ve her durumdan kaç gün.
  @visibleForTesting
  static String tallyCsv(
    TallyTableModel table, {
    required AppLocalizations loc,
    ExportSelection? selection,
  }) {
    final csv = StringBuffer();
    final days = _tallyDays(table, selection);
    final headers = <String>[
      loc.tallyItemHeader,
      for (final day in days) '${day.day}/${day.month}',
      for (final status in table.statuses) '${status.label} (${status.code})',
    ];
    csv.writeln(headers.map(_escapeCsvField).join(','));

    for (final item in _selectedItems(table, selection)) {
      final summary = item.getSummary(days.first, days.last, table.statuses);
      final row = <String>[
        item.name,
        for (final day in days)
          item.entries[TallyTableModel.dateKey(day)] ?? '',
        for (final status in table.statuses) '${summary[status.code] ?? 0}',
      ];
      csv.writeln(row.map(_escapeCsvField).join(','));
    }
    return csv.toString();
  }

  static Future<String> exportTallyPdf(
    TallyTableModel table, {
    required AppLocalizations loc,
    ExportSelection? selection,
  }) async {
    final bytes = await renderInBackground(
      buildTallyPdf,
      tallyReport(table, loc: loc, selection: selection),
      await _loadFonts(),
    );
    final file = await _exportFile(
      fileBaseName(table.tableName, tag: selection?.searchTerm),
      'pdf',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @visibleForTesting
  static TallyReport tallyReport(
    TallyTableModel table, {
    required AppLocalizations loc,
    ExportSelection? selection,
    DateTime? now,
  }) {
    final language = loc.locale.languageCode;
    final days = _tallyDays(table, selection);
    final items = _selectedItems(table, selection);
    return TallyReport(
      frame: _frame(
        loc,
        title: table.tableName,
        tag: selection?.searchTerm,
        lines: [
          '${_date(days.first)} – ${_date(days.last)}',
          if (selection?.search case final search?)
            loc.exportSearchLine(search),
        ],
        count: items.length,
        now: now,
      ),
      itemHeader: loc.tallyItemHeader,
      statuses: [
        for (final status in table.statuses)
          ReportStatus(
            code: status.code,
            label: status.label,
            color: status.colorValue,
          ),
      ],
      days: [
        for (final day in days)
          ReportDay(
            number: '${day.day}',
            weekday: weekdayShort(day, language),
            weekend: day.weekday >= DateTime.saturday,
            date: _date(day),
          ),
      ],
      rows: [
        for (final item in items)
          ReportTallyRow(item.name.trim(), [
            for (final day in days)
              item.entries[TallyTableModel.dateKey(day)] ?? '',
          ]),
      ],
      summaryTitle: loc.tallySummary,
      emptyLabel: loc.tallyEmpty,
      totalLabel: loc.totalLabel,
    );
  }

  /// PDF ayrı bir iş parçacığında dizilir: uzun tabloda ekran donmasın.
  ///
  /// Bilerek async değildir: async bir metodun içinde kurulan kapanış, o
  /// metodun gönderilemeyen değişkenlerini de yanında taşıyabilir.
  @visibleForTesting
  static Future<Uint8List> renderInBackground<T>(
    Future<Uint8List> Function(T report, ReportFonts fonts) build,
    T report,
    ReportFonts fonts,
  ) => Isolate.run(() => build(report, fonts));

  /// Dosyayı sistemin paylaşım penceresiyle paylaşır.
  ///
  /// Kullanıcı pencereyi bir yere göndermeden kapattıysa false döner.
  /// Android çoğu zaman sonucu bildirmez; bildirilmeyen sonuç gönderilmiş
  /// sayılır. [origin], iPad'de pencerenin bağlanacağı yerdir; orada bu
  /// olmadan paylaşım açılmaz.
  static Future<bool> shareFile(
    String filePath,
    String subject, {
    Rect? origin,
  }) async {
    final result = await Share.shareXFiles(
      [XFile(filePath)],
      subject: subject,
      sharePositionOrigin: origin,
    );
    return result.status != ShareResultStatus.dismissed;
  }

  /// Uzantısız dosya adı: "Table Note - Sevkiyat - Konya". Dosya kime
  /// giderse gitsin uygulamanın adını taşır.
  @visibleForTesting
  static String fileBaseName(String name, {String? tag}) {
    final parts = [
      appName,
      for (final part in [name, tag ?? ''])
        if (part.trim().isNotEmpty) part.trim(),
    ];
    final base = _convertTurkishChars(parts.join(' - '))
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    // Çok uzun adlar bazı sistemlerde kesilir ya da reddedilir.
    final runes = base.runes;
    return runes.length <= 100
        ? base
        : String.fromCharCodes(runes.take(100)).trim();
  }

  // ============== YARDIMCILAR ==============

  static List<List<String>> _selectedRows(
    TableModel table,
    ExportSelection? selection,
  ) {
    if (selection == null) return table.rows;
    return [
      for (final index in selection.order)
        if (index >= 0 && index < table.rows.length) table.rows[index],
    ];
  }

  static List<TallyItemModel> _selectedItems(
    TallyTableModel table,
    ExportSelection? selection,
  ) {
    if (selection == null) return table.items;
    return [
      for (final index in selection.order)
        if (index >= 0 && index < table.items.length) table.items[index],
    ];
  }

  /// Yazılacak günler: istenen aralığın çetele aralığına düşen kısmı.
  static List<DateTime> _tallyDays(
    TallyTableModel table,
    ExportSelection? selection,
  ) {
    DateTime dayOf(DateTime value) =>
        DateTime(value.year, value.month, value.day);
    final start = dayOf(table.startDate);
    final end = dayOf(table.endDate);
    var from = dayOf(selection?.from ?? start);
    var to = dayOf(selection?.to ?? end);
    if (from.isBefore(start)) from = start;
    if (to.isAfter(end)) to = end;
    if (to.isBefore(from)) {
      from = start;
      to = end.isBefore(start) ? start : end;
    }
    // Saat değişimi olan günlerde de doğru gün gelsin diye takvimle sayılır.
    return [
      for (
        var day = from;
        !day.isAfter(to);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        day,
    ];
  }

  static ReportFrame _frame(
    AppLocalizations loc, {
    required String title,
    String? tag,
    List<String> lines = const [],
    required int count,
    DateTime? now,
  }) => ReportFrame(
    title: title,
    documentTitle: [
      appName,
      title,
      if (tag != null && tag.trim().isNotEmpty) tag.trim(),
    ].join(' - '),
    lines: lines,
    meta: '${loc.nRecords(count)} · ${_dateTime(now ?? DateTime.now())}',
    footerNote: loc.madeWithTableNote,
    pageLabel: loc.pageNofMTemplate,
  );

  static ReportAlign _align(ColumnModel column) {
    if (showsGroupedNumbers(column) || column.isAutoNumber) {
      return ReportAlign.end;
    }
    if (column.isDate || column.isTime) return ReportAlign.center;
    return ReportAlign.start;
  }

  static ReportFonts? _fonts;

  static Future<ReportFonts> _loadFonts() async {
    // Gömülü Roboto bütün Türkçe harfleri taşır.
    Future<Uint8List> load(String asset) async {
      final data = await rootBundle.load(asset);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }

    return _fonts ??= ReportFonts(
      await load('assets/fonts/Roboto-Regular.ttf'),
      await load('assets/fonts/Roboto-Bold.ttf'),
    );
  }

  /// Dosyalar geçici klasöre yazılır: paylaşıldıktan sonra cihazda yer
  /// tutmasınlar, sistem gerektiğinde temizler.
  static Future<File> _exportFile(String baseName, String extension) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/exports',
    );
    await directory.create(recursive: true);
    return File('${directory.path}/$baseName.$extension');
  }

  /// Türkçe karakterleri ASCII'ye çevirir. Yalnızca dosya adları için; gömülü
  /// Roboto bütün Türkçe harfleri taşıdığı için PDF metni olduğu gibi yazılır.
  static String _convertTurkishChars(String text) {
    return text
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _date(DateTime value) =>
      '${_two(value.day)}.${_two(value.month)}.${value.year}';

  static String _dateTime(DateTime value) =>
      '${_date(value)} ${_two(value.hour)}:${_two(value.minute)}';
}
