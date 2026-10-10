import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import '../l10n/app_localizations.dart';
import '../utils/column_balance.dart';
import '../utils/number_display.dart';

class ExportService {
  /// CSV formatında export
  static Future<String> exportToCsv(
    TableModel table, {
    AppLocalizations? loc,
  }) async {
    final StringBuffer csv = StringBuffer();

    // Başlık satırı
    final headers = table.columns
        .map((col) => _escapeCsvField(col.name))
        .join(',');
    csv.writeln(headers);

    // Veri satırları
    for (var row in table.rows) {
      final rowData = row.map((cell) => _escapeCsvField(cell)).join(',');
      csv.writeln(rowData);
    }

    csv.write(balanceCsvLines(table, loc: loc));

    // Dosyayı kaydet
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _sanitizeFileName(table.tableName);
    final file = File('${directory.path}/$fileName.csv');
    await file.writeAsString(csv.toString(), encoding: const Utf8Codec());

    return file.path;
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

  /// PDF formatında export
  static Future<String> exportToPdf(
    TableModel table, {
    required AppLocalizations loc,
    Map<String, double>? columnSums,
  }) async {
    final language = loc.locale.languageCode;
    final pdf = pw.Document();
    final sums = columnSums ?? const <String, double>{};
    final balances = computeColumnBalances(table);

    // Türkçe karakter desteği için font yükle
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final fontDataBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontDataBold);

    // Sayfa boyutuna göre sütun genişliklerini hesapla
    final columnCount = table.columns.length;

    // Verileri sayfalara böl (her sayfada max 25 satır)
    final rowsPerPage = 25;
    final totalPages = (table.rows.length / rowsPerPage).ceil().clamp(1, 999);

    for (int page = 0; page < totalPages; page++) {
      final startRow = page * rowsPerPage;
      final endRow = (startRow + rowsPerPage > table.rows.length)
          ? table.rows.length
          : startRow + rowsPerPage;
      final pageRows = table.rows.sublist(startRow, endRow);
      final isLastPage = page == totalPages - 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Başlık
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      table.tableName,
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      loc.totalNRecords(table.rows.length),
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 15),

                // Tablo
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    columnWidths: _calculateColumnWidths(columnCount),
                    children: [
                      // Başlık satırı
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue100,
                        ),
                        children: table.columns.map((col) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              col.name,
                              style: pw.TextStyle(
                                font: ttfBold,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          );
                        }).toList(),
                      ),
                      // Veri satırları
                      ...pageRows.asMap().entries.map((entry) {
                        final rowIndex = entry.key;
                        final row = entry.value;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: rowIndex % 2 == 0
                                ? PdfColors.white
                                : PdfColors.grey100,
                          ),
                          children: row.asMap().entries.map((cellEntry) {
                            final column = cellEntry.key < table.columns.length
                                ? table.columns[cellEntry.key]
                                : null;
                            // Quantities read the way they do in the app; row
                            // numbers and text are printed exactly as entered.
                            final text =
                                column != null && showsGroupedNumbers(column)
                                ? formatNumericCell(
                                        cellEntry.value,
                                        language: language,
                                      ) ??
                                      cellEntry.value
                                : cellEntry.value;
                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                text,
                                style: pw.TextStyle(font: ttf, fontSize: 9),
                                textAlign: pw.TextAlign.center,
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // Toplamlar (sadece son sayfada)
                if (isLastPage && (sums.isNotEmpty || balances.isNotEmpty))
                  _buildSumsSection(
                    sums,
                    balances,
                    ttf,
                    ttfBold,
                    loc,
                    language,
                  ),

                pw.SizedBox(height: 10),

                // Alt bilgi
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      _getCurrentDateTime(),
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    if (totalPages > 1)
                      pw.Text(
                        loc.pageNofM(page + 1, totalPages),
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    // Dosyayı kaydet
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _sanitizeFileName(table.tableName);
    final file = File('${directory.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Toplamlar bölümünü oluştur
  static pw.Widget _buildSumsSection(
    Map<String, double> sums,
    List<ColumnBalance> balances,
    pw.Font ttf,
    pw.Font ttfBold,
    AppLocalizations loc,
    String language,
  ) {
    pw.Widget chip(String label, double value, {PdfColor? color}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              '$label: ',
              style: pw.TextStyle(font: ttf, fontSize: 9, color: color),
            ),
            pw.Text(
              formatGroupedNumber(value, language),
              style: pw.TextStyle(
                font: ttfBold,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            loc.totalsLabel,
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 20,
            runSpacing: 4,
            children: [
              for (final entry in sums.entries) chip(entry.key, entry.value),
              // Başlangıç değeri olan sütunlar: ne ile başlandı, ne kaldı.
              for (final balance in balances) ...[
                chip(
                  '${balance.name} · ${loc.startingValue}',
                  balance.startingValue,
                ),
                chip(
                  loc.remainingOf(balance.name),
                  balance.remaining,
                  color: balance.isExceeded
                      ? PdfColors.red800
                      : PdfColors.blue800,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============== ÇETELE EXPORT ==============

  /// Çetele tablosunu CSV formatında export
  static Future<String> exportTallyCsv(TallyTableModel table) async {
    final csv = StringBuffer();
    final days = table.allDays;

    // Başlık: Ad, 1/1, 2/1, ..., Durum1(Ç), Durum2(İ), ...
    final headers = <String>['Ad'];
    for (final day in days) {
      headers.add('${day.day}/${day.month}');
    }
    for (final status in table.statuses) {
      headers.add('${status.label} (${status.code})');
    }
    csv.writeln(headers.map((h) => _escapeCsvField(h)).join(','));

    // Satırlar
    for (final item in table.items) {
      final row = <String>[item.name];
      for (final day in days) {
        final key = TallyTableModel.dateKey(day);
        row.add(item.entries[key] ?? '');
      }
      final summary = item.getSummary(
        table.startDate,
        table.endDate,
        table.statuses,
      );
      for (final status in table.statuses) {
        row.add((summary[status.code] ?? 0).toString());
      }
      csv.writeln(row.map((c) => _escapeCsvField(c)).join(','));
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = _sanitizeFileName(table.tableName);
    final file = File('${directory.path}/${fileName}_tally.csv');
    await file.writeAsString(csv.toString(), encoding: const Utf8Codec());
    return file.path;
  }

  /// Çetele tablosunu PDF formatında export
  static Future<String> exportTallyPdf(
    TallyTableModel table, {
    required AppLocalizations loc,
  }) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final fontDataBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontDataBold);

    final days = table.allDays;
    final dateRange =
        '${table.startDate.day}/${table.startDate.month}/${table.startDate.year}'
        ' - ${table.endDate.day}/${table.endDate.month}/${table.endDate.year}';

    // Her sayfada max 20 gün sütunu
    final daysPerPage = 20;
    final totalDayPages = (days.length / daysPerPage).ceil().clamp(1, 999);

    for (int pageIdx = 0; pageIdx < totalDayPages; pageIdx++) {
      final startDay = pageIdx * daysPerPage;
      final endDay = (startDay + daysPerPage > days.length)
          ? days.length
          : startDay + daysPerPage;
      final pageDays = days.sublist(startDay, endDay);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      table.tableName,
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      dateRange,
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: table.statuses
                      .map(
                        (s) => pw.Container(
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Text(
                            '${s.code} = ${s.label}',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue100,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              loc.tallyItemHeader,
                              style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          ...pageDays.map(
                            (day) => pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Text(
                                '${day.day}',
                                style: pw.TextStyle(
                                  font: ttfBold,
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...table.items.asMap().entries.map((entry) {
                        final rowIdx = entry.key;
                        final item = entry.value;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: rowIdx.isEven
                                ? PdfColors.white
                                : PdfColors.grey100,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                item.name,
                                style: pw.TextStyle(font: ttf, fontSize: 8),
                              ),
                            ),
                            ...pageDays.map((day) {
                              final key = TallyTableModel.dateKey(day);
                              final code = item.entries[key] ?? '';
                              return pw.Padding(
                                padding: const pw.EdgeInsets.all(3),
                                child: pw.Text(
                                  code,
                                  style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _getCurrentDateTime(),
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 7,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Son sayfa: Özet tablosu (kimin kaç gün hangi durumda)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${table.tableName} - ${loc.tallySummary}',
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                dateRange,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            loc.tallyItemHeader,
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        ...table.statuses.map(
                          (s) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '${s.label} (${s.code})',
                              style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            loc.tallyEmpty,
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    ...table.items.asMap().entries.map((entry) {
                      final rowIdx = entry.key;
                      final item = entry.value;
                      final summary = item.getSummary(
                        table.startDate,
                        table.endDate,
                        table.statuses,
                      );
                      final filledDays = summary.values.fold<int>(
                        0,
                        (a, b) => a + b,
                      );
                      final emptyDays = table.dayCount - filledDays;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: rowIdx.isEven
                              ? PdfColors.white
                              : PdfColors.grey100,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              item.name,
                              style: pw.TextStyle(font: ttf, fontSize: 10),
                            ),
                          ),
                          ...table.statuses.map(
                            (s) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '${summary[s.code] ?? 0}',
                                style: pw.TextStyle(
                                  font: ttfBold,
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '$emptyDays',
                              style: pw.TextStyle(font: ttf, fontSize: 11),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _getCurrentDateTime(),
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 7,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = _sanitizeFileName(table.tableName);
    final file = File('${directory.path}/${fileName}_tally.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

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

  /// Dosyayı cihaza kaydet (Downloads klasörüne)
  static Future<String?> saveToDownloads(String sourcePath) async {
    try {
      final fileName = sourcePath.split('/').last;

      // Android için Downloads klasörü
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        return null;
      }

      final newPath = '${downloadsDir.path}/$fileName';
      final sourceFile = File(sourcePath);
      await sourceFile.copy(newPath);

      return newPath;
    } catch (e) {
      print('Dosya kaydedilirken hata: $e');
      return null;
    }
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

  /// CSV alanını escape et
  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Dosya adını temizle
  static String _sanitizeFileName(String name) {
    return _convertTurkishChars(
      name,
    ).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
  }

  /// Sütun genişliklerini hesapla
  static Map<int, pw.TableColumnWidth> _calculateColumnWidths(int columnCount) {
    final Map<int, pw.TableColumnWidth> widths = {};
    for (int i = 0; i < columnCount; i++) {
      widths[i] = const pw.FlexColumnWidth(1);
    }
    return widths;
  }

  /// Şu anki tarih ve saati formatla
  static String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
