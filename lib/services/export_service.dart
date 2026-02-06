import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/tabel_model.dart';

class ExportService {
  
  /// CSV formatında export
  static Future<String> exportToCsv(TableModel table) async {
    final StringBuffer csv = StringBuffer();
    
    // Başlık satırı
    final headers = table.columns.map((col) => _escapeCsvField(col.name)).join(',');
    csv.writeln(headers);
    
    // Veri satırları
    for (var row in table.rows) {
      final rowData = row.map((cell) => _escapeCsvField(cell)).join(',');
      csv.writeln(rowData);
    }
    
    // Dosyayı kaydet
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _sanitizeFileName(table.tableName);
    final file = File('${directory.path}/$fileName.csv');
    await file.writeAsString(csv.toString(), encoding: const Utf8Codec());
    
    return file.path;
  }
  
  /// PDF formatında export
  static Future<String> exportToPdf(TableModel table, {Map<String, double>? columnSums}) async {
    final pdf = pw.Document();
    
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
                      'Toplam: ${table.rows.length} kayit',
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
                              _convertTurkishChars(col.name),
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
                          children: row.map((cell) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                _convertTurkishChars(cell),
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
                if (isLastPage && columnSums != null && columnSums.isNotEmpty)
                  _buildSumsSection(columnSums, ttf, ttfBold),
                
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
                        'Sayfa ${page + 1} / $totalPages',
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
  static pw.Widget _buildSumsSection(Map<String, double> sums, pw.Font ttf, pw.Font ttfBold) {
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
            'TOPLAMLAR',
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
            children: sums.entries.map((entry) {
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
                      '${_convertTurkishChars(entry.key)}: ',
                      style: pw.TextStyle(font: ttf, fontSize: 9),
                    ),
                    pw.Text(
                      _formatNumber(entry.value),
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// Dosyayı paylaş
  static Future<void> shareFile(String filePath, String subject) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: subject,
    );
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
  
  /// Türkçe karakterleri ASCII'ye çevir (font desteklemiyorsa)
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
    return _convertTurkishChars(name)
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_');
  }
  
  /// Sütun genişliklerini hesapla
  static Map<int, pw.TableColumnWidth> _calculateColumnWidths(int columnCount) {
    final Map<int, pw.TableColumnWidth> widths = {};
    for (int i = 0; i < columnCount; i++) {
      widths[i] = const pw.FlexColumnWidth(1);
    }
    return widths;
  }
  
  /// Sayıyı formatla
  static String _formatNumber(double value) {
    if (value == value.truncate()) {
      return value.truncate().toString();
    }
    return value.toStringAsFixed(2);
  }
  
  /// Şu anki tarih ve saati formatla
  static String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}