import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Tablo ve çetele PDF'lerinin dizilişi.
///
/// Buraya hazır yazılar gelir: hangi satırın gireceği, sayıların nasıl
/// yazılacağı ve metinlerin dili çağıran tarafta çözülür. Bu dosya yalnızca
/// yerleştirir; böylece ayrı bir iş parçacığında (isolate) çalışabilir ve
/// binlerce satırlık bir tabloda bile uygulama takılmaz.
///
/// Kâğıt hep A4'tür ki dosya yazıcıdan da çıksın. Satırlar sayfalara
/// kendiliğinden bölünür ve sütun başlıkları her sayfada tekrar eder.

enum ReportAlign { start, center, end }

/// Her sayfanın üstünde ve altında yazanlar.
class ReportFrame {
  const ReportFrame({
    required this.title,
    required this.documentTitle,
    this.lines = const [],
    required this.meta,
    required this.footerNote,
    required this.pageLabel,
  });

  /// "Sevkiyat".
  final String title;

  /// Dosyanın kendi adı, PDF okuyucunun başlığında görünür.
  final String documentTitle;

  /// Başlığın altındaki satırlar: arama, tarih aralığı.
  final List<String> lines;

  /// "14 kayıt · 15.10.2026 14:30".
  final String meta;

  /// "Table Note ile hazırlandı".
  final String footerNote;

  /// "Sayfa {n} / {m}".
  final String pageLabel;
}

/// Tablonun altındaki etiket–değer satırı: başlangıç değeri, kalan.
class ReportNote {
  const ReportNote(this.label, this.value, {this.alert = false});

  final String label;
  final String value;

  /// Kalan eksiye düştü: kırmızı yazılır.
  final bool alert;
}

class TableReport {
  const TableReport({
    required this.frame,
    required this.headers,
    required this.aligns,
    required this.rows,
    this.totalRow,
    this.notes = const [],
  });

  final ReportFrame frame;
  final List<String> headers;
  final List<ReportAlign> aligns;

  /// Ekrandaki yazılışıyla hücreler; her satır [headers] kadar.
  final List<List<String>> rows;

  /// Tablonun son satırı: toplamlar. Toplanan sütun yoksa null.
  final List<String>? totalRow;
  final List<ReportNote> notes;
}

class ReportStatus {
  const ReportStatus({
    required this.code,
    required this.label,
    required this.color,
  });

  final String code;
  final String label;
  final int color;
}

class ReportDay {
  const ReportDay({
    required this.number,
    required this.weekday,
    required this.weekend,
    required this.date,
  });

  /// "15".
  final String number;

  /// "Pt".
  final String weekday;
  final bool weekend;

  /// "15.10.2026"; birden çok sayfaya bölünen aralıkların başlığında.
  final String date;
}

class ReportTallyRow {
  const ReportTallyRow(this.name, this.codes);

  final String name;

  /// Gün gün işaretler; boş gün için ''.
  final List<String> codes;
}

class TallyReport {
  const TallyReport({
    required this.frame,
    required this.itemHeader,
    required this.statuses,
    required this.days,
    required this.rows,
    required this.summaryTitle,
    required this.emptyLabel,
    required this.totalLabel,
  });

  final ReportFrame frame;
  final String itemHeader;
  final List<ReportStatus> statuses;
  final List<ReportDay> days;
  final List<ReportTallyRow> rows;
  final String summaryTitle;
  final String emptyLabel;
  final String totalLabel;
}

class ReportFonts {
  const ReportFonts(this.regular, this.bold);

  final Uint8List regular;
  final Uint8List bold;
}

// Renkler yazıcıda da okunur kalacak kadar açık; dolgular mürekkep yemesin.
const _ink = PdfColor.fromInt(0xFF172033);
const _muted = PdfColor.fromInt(0xFF5B6475);
const _brand = PdfColor.fromInt(0xFF2563EB);
const _rule = PdfColor.fromInt(0xFFD5DBE5);
const _headerFill = PdfColor.fromInt(0xFFE8EEFB);
const _zebra = PdfColor.fromInt(0xFFF6F8FB);
const _totalFill = PdfColor.fromInt(0xFFEFF4FF);
const _weekendFill = PdfColor.fromInt(0xFFF1F3F6);
const _alert = PdfColor.fromInt(0xFFC62828);

const _brandName = 'Table Note';

/// Hata ayıklama derlemesinde sayfa sınırı denetlenir; uzun bir tablo
/// yanlışlıkla "çok sayfa" sayılmasın.
const _maxPages = 5000;

pw.ThemeData _theme(ReportFonts fonts) => pw.ThemeData.withFont(
  base: pw.Font.ttf(ByteData.sublistView(fonts.regular)),
  bold: pw.Font.ttf(ByteData.sublistView(fonts.bold)),
);

pw.Document _document(ReportFrame frame) => pw.Document(
  title: frame.documentTitle,
  author: _brandName,
  creator: _brandName,
  producer: _brandName,
);

pw.TextAlign _textAlign(ReportAlign align) => switch (align) {
  ReportAlign.start => pw.TextAlign.left,
  ReportAlign.center => pw.TextAlign.center,
  ReportAlign.end => pw.TextAlign.right,
};

/// Bir yazının kabaca kaç punto yer kaplayacağı. Roboto'da ortalama harf
/// yarım em kadardır; sütunların payını ve kâğıdın yönünü seçmeye yeter.
double _estimateWidth(String text, double size, {bool bold = false}) {
  var longest = 0;
  for (final line in text.split('\n')) {
    longest = math.max(longest, line.runes.length);
  }
  return longest * size * (bold ? 0.58 : 0.53);
}

/// İlk sayfada büyük başlık, sonrakilerde tek satırlık hatırlatma.
pw.Widget _header(pw.Context context, ReportFrame frame) {
  final brand = pw.Text(
    _brandName,
    style: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: context.pageNumber == 1 ? 10 : 8,
      color: _brand,
    ),
  );
  if (context.pageNumber > 1) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              [frame.title, ...frame.lines].join(' · '),
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
          brand,
        ],
      ),
    );
  }
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.8)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                frame.title,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 17,
                  color: _ink,
                ),
              ),
              for (final line in frame.lines) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  line,
                  style: const pw.TextStyle(fontSize: 10, color: _ink),
                ),
              ],
              pw.SizedBox(height: 3),
              pw.Text(
                frame.meta,
                style: const pw.TextStyle(fontSize: 8.5, color: _muted),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        brand,
      ],
    ),
  );
}

pw.Widget _footer(pw.Context context, ReportFrame frame) {
  const style = pw.TextStyle(fontSize: 7.5, color: _muted);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(frame.footerNote, style: style),
        if (context.pagesCount > 1)
          pw.Text(
            frame.pageLabel
                .replaceAll('{n}', '${context.pageNumber}')
                .replaceAll('{m}', '${context.pagesCount}'),
            style: style,
          ),
      ],
    ),
  );
}

pw.Widget _cell(
  String text, {
  ReportAlign align = ReportAlign.start,
  bool bold = false,
  double size = 9,
  PdfColor? color,
  pw.EdgeInsets padding = const pw.EdgeInsets.symmetric(
    horizontal: 5,
    vertical: 4,
  ),
}) => pw.Padding(
  padding: padding,
  child: pw.Text(
    text,
    textAlign: _textAlign(align),
    // Tek bir satır sayfadan uzun olursa bölünemez; çok uzun bir not
    // kırpılır ama dosya yine oluşur.
    maxLines: 30,
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? _ink,
    ),
  ),
);

pw.Widget _notes(List<ReportNote> notes) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 14),
  child: pw.Table(
    tableWidth: pw.TableWidth.min,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
    ),
    children: [
      for (final note in notes)
        pw.TableRow(
          children: [
            _cell(note.label, color: _muted),
            pw.SizedBox(width: 24),
            _cell(
              note.value,
              align: ReportAlign.end,
              bold: true,
              color: note.alert ? _alert : null,
            ),
          ],
        ),
    ],
  ),
);

/// Tablonun PDF'i.
Future<Uint8List> buildTablePdf(TableReport report, ReportFonts fonts) {
  const margin = 32.0;
  final columns = report.headers.length;

  // Her sütunun doğal genişliği: başlığı, en uzun hücresi ve toplamı.
  final natural = List<double>.generate(columns, (index) {
    var width = _estimateWidth(report.headers[index], 9, bold: true);
    for (final row in report.rows) {
      width = math.max(width, _estimateWidth(row[index], 9));
    }
    final total = report.totalRow?[index];
    if (total != null) {
      width = math.max(width, _estimateWidth(total, 9, bold: true));
    }
    return (width + 10).clamp(28.0, 240.0);
  });
  final needed = natural.fold<double>(0, (sum, width) => sum + width);
  // Sığıyorsa dikey kâğıt, sığmıyorsa yatay.
  final format = needed <= PdfPageFormat.a4.width - 2 * margin
      ? PdfPageFormat.a4
      : PdfPageFormat.a4.landscape;

  final document = _document(report.frame);
  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(margin, 30, margin, 24),
        theme: _theme(fonts),
      ),
      maxPages: _maxPages,
      header: (context) => _header(context, report.frame),
      footer: (context) => _footer(context, report.frame),
      build: (context) => [
        pw.Table(
          columnWidths: {
            for (var index = 0; index < columns; index++)
              index: pw.FlexColumnWidth(natural[index]),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
            verticalInside: pw.BorderSide(color: _rule, width: 0.5),
            bottom: pw.BorderSide(color: _rule, width: 0.5),
          ),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _headerFill),
              children: [
                for (var index = 0; index < columns; index++)
                  _cell(
                    report.headers[index],
                    align: report.aligns[index],
                    bold: true,
                  ),
              ],
            ),
            for (var row = 0; row < report.rows.length; row++)
              pw.TableRow(
                decoration: row.isOdd
                    ? const pw.BoxDecoration(color: _zebra)
                    : null,
                children: [
                  for (var index = 0; index < columns; index++)
                    _cell(report.rows[row][index], align: report.aligns[index]),
                ],
              ),
            if (report.totalRow case final total?)
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: _totalFill,
                  border: pw.Border(
                    top: pw.BorderSide(color: _brand, width: 1),
                  ),
                ),
                children: [
                  for (var index = 0; index < columns; index++)
                    _cell(
                      total[index],
                      align: report.aligns[index],
                      bold: true,
                    ),
                ],
              ),
          ],
        ),
        if (report.notes.isNotEmpty) _notes(report.notes),
      ],
    ),
  );
  return document.save();
}

PdfColor _tint(int argb, double amount) {
  final color = PdfColor.fromInt(argb);
  double mix(double channel) => 1 - (1 - channel) * amount;
  return PdfColor(mix(color.red), mix(color.green), mix(color.blue));
}

/// Çetelenin PDF'i: gün gün işaretler, ardından kişi başına sayımlar.
Future<Uint8List> buildTallyPdf(TallyReport report, ReportFonts fonts) {
  const margin = 28.0;
  final format = PdfPageFormat.a4.landscape;
  final width = format.width - 2 * margin;
  final statusByCode = {
    for (final status in report.statuses) status.code: status,
  };

  // Bir sayfada en çok 31 gün: bir ay tek parça görünür.
  const daysPerBlock = 31;
  var nameWidth = _estimateWidth(report.itemHeader, 8, bold: true);
  for (final row in report.rows) {
    nameWidth = math.max(nameWidth, _estimateWidth(row.name, 8));
  }
  nameWidth = (nameWidth + 10).clamp(70.0, 150.0);
  final dayWidth = math.min((width - nameWidth) / daysPerBlock, 26.0);

  List<pw.Widget> dayBlock(int start, int end, bool titled) {
    final days = report.days.sublist(start, end);
    return [
      // Başlık ya da sütun başları sayfanın dibinde yalnız kalmasın.
      pw.NewPage(freeSpace: 90),
      if (titled)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, top: 6),
          child: pw.Text(
            '${days.first.date} – ${days.last.date}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ),
      pw.Table(
        tableWidth: pw.TableWidth.min,
        columnWidths: {
          0: pw.FixedColumnWidth(nameWidth),
          for (var index = 0; index < days.length; index++)
            index + 1: pw.FixedColumnWidth(dayWidth),
        },
        border: pw.TableBorder.all(color: _rule, width: 0.5),
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _headerFill),
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _cell(report.itemHeader, bold: true, size: 8),
              for (final day in days)
                pw.Container(
                  color: day.weekend ? _rule : null,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        day.number,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      pw.Text(
                        day.weekday,
                        style: const pw.TextStyle(fontSize: 6, color: _muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          for (final row in report.rows)
            pw.TableRow(
              verticalAlignment: pw.TableCellVerticalAlignment.full,
              children: [
                _cell(row.name, size: 8),
                for (var index = start; index < end; index++)
                  _dayMark(
                    row.codes[index],
                    statusByCode[row.codes[index]],
                    report.days[index].weekend,
                  ),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 10),
    ];
  }

  final multiple = report.days.length > daysPerBlock;
  final blocks = <pw.Widget>[
    for (var start = 0; start < report.days.length; start += daysPerBlock)
      ...dayBlock(
        start,
        math.min(start + daysPerBlock, report.days.length),
        multiple,
      ),
  ];

  final document = _document(report.frame);
  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(margin),
        theme: _theme(fonts),
      ),
      maxPages: _maxPages,
      header: (context) => _header(context, report.frame),
      footer: (context) => _footer(context, report.frame),
      build: (context) => [
        _legend(report.statuses),
        ...blocks,
        ..._tallySummary(report),
      ],
    ),
  );
  return document.save();
}

pw.Widget _dayMark(String code, ReportStatus? status, bool weekend) {
  return pw.Container(
    alignment: pw.Alignment.center,
    color: status != null
        ? _tint(status.color, 0.28)
        : weekend
        ? _weekendFill
        : null,
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Text(
      code,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
    ),
  );
}

pw.Widget _legend(List<ReportStatus> statuses) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Wrap(
    spacing: 14,
    runSpacing: 4,
    children: [
      for (final status in statuses)
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 14,
              height: 11,
              alignment: pw.Alignment.center,
              color: _tint(status.color, 0.28),
              child: pw.Text(
                status.code,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text(status.label, style: const pw.TextStyle(fontSize: 8.5)),
          ],
        ),
    ],
  ),
);

/// Kişi başına her durumdan kaç gün; birden çok kişi varsa en altta toplam.
/// İşareti silinmiş bir duruma ait günler boş sayılır, uygulamadaki gibi.
List<pw.Widget> _tallySummary(TallyReport report) {
  final statuses = report.statuses;
  final column = {
    for (var index = 0; index < statuses.length; index++)
      statuses[index].code: index,
  };
  final totals = List<int>.filled(statuses.length + 1, 0);
  final rows = <pw.TableRow>[];
  for (var position = 0; position < report.rows.length; position++) {
    final row = report.rows[position];
    final counts = List<int>.filled(statuses.length + 1, 0);
    for (final code in row.codes) {
      if (column[code] case final index?) counts[index]++;
    }
    final filled = counts.fold<int>(0, (sum, count) => sum + count);
    counts[statuses.length] = report.days.length - filled;
    for (var index = 0; index < counts.length; index++) {
      totals[index] += counts[index];
    }
    rows.add(
      pw.TableRow(
        decoration: position.isOdd
            ? const pw.BoxDecoration(color: _zebra)
            : null,
        children: [
          _cell(row.name),
          for (final count in counts)
            _cell('$count', align: ReportAlign.center, bold: true),
        ],
      ),
    );
  }

  return [
    pw.NewPage(freeSpace: 90),
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
      child: pw.Text(
        report.summaryTitle,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ),
    pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        for (var index = 1; index <= statuses.length + 1; index++)
          index: const pw.FlexColumnWidth(1),
      },
      border: pw.TableBorder.all(color: _rule, width: 0.5),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _headerFill),
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [
            _cell(report.itemHeader, bold: true),
            for (final status in statuses)
              pw.Container(
                color: _tint(status.color, 0.28),
                child: _cell(
                  '${status.label} (${status.code})',
                  align: ReportAlign.center,
                  bold: true,
                  size: 8.5,
                ),
              ),
            _cell(
              report.emptyLabel,
              align: ReportAlign.center,
              bold: true,
              size: 8.5,
            ),
          ],
        ),
        ...rows,
        if (report.rows.length > 1)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: _totalFill,
              border: pw.Border(top: pw.BorderSide(color: _brand, width: 1)),
            ),
            children: [
              _cell(report.totalLabel, bold: true),
              for (final total in totals)
                _cell('$total', align: ReportAlign.center, bold: true),
            ],
          ),
      ],
    ),
  ];
}
