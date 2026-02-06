import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({Key? key}) : super(key: key);

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool _isExporting = false;
  String? _exportedFilePath;
  String? _exportFormat;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TableProvider>(context, listen: false);
    final table = provider.currentTable!;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.download_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Çıktı Al',
              style: TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tablo bilgisi
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.tableName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${table.rows.length} kayıt • ${table.columns.length} sütun',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Export seçenekleri
            if (_exportedFilePath == null) ...[
              const Text(
                'Format Seçin:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              // CSV seçeneği
              _buildFormatOption(
                icon: Icons.description,
                title: 'CSV',
                subtitle: 'Excel ve diğer uygulamalarda açılabilir',
                color: Colors.green,
                onTap: () => _export('csv'),
              ),

              const SizedBox(height: 10),

              // PDF seçeneği
              _buildFormatOption(
                icon: Icons.picture_as_pdf,
                title: 'PDF',
                subtitle: 'Yazdırılabilir profesyonel rapor',
                color: Colors.red,
                onTap: () => _export('pdf'),
              ),
            ],

            // Export başarılı
            if (_exportedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 48),
                    const SizedBox(height: 12),
                    Text(
                      '${_exportFormat!.toUpperCase()} dosyası oluşturuldu!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Paylaş butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share),
                        label: const Text('Paylaş (WhatsApp, Mail, vb.)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Kaydet butonu
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saveToDevice,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Cihaza Kaydet'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Başka format seç
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _exportedFilePath = null;
                          _exportFormat = null;
                        });
                      },
                      child: const Text('Başka format seç'),
                    ),
                  ],
                ),
              ),
            ],

            // Loading
            if (_isExporting)
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Dosya oluşturuluyor...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_exportedFilePath != null ? 'Kapat' : 'İptal'),
        ),
      ],
    );
  }

  Widget _buildFormatOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isExporting ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(String format) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final provider = Provider.of<TableProvider>(context, listen: false);
      final table = provider.currentTable!;
      final columnSums = provider.calculateFilteredColumnSums();

      String filePath;
      if (format == 'csv') {
        filePath = await ExportService.exportToCsv(table);
      } else {
        filePath = await ExportService.exportToPdf(table, columnSums: columnSums);
      }

      setState(() {
        _exportedFilePath = filePath;
        _exportFormat = format;
        _isExporting = false;
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _share() async {
    if (_exportedFilePath != null) {
      final provider = Provider.of<TableProvider>(context, listen: false);
      await ExportService.shareFile(
        _exportedFilePath!,
        '${provider.currentTable!.tableName} - Tablo Verisi',
      );
    }
  }

  Future<void> _saveToDevice() async {
    if (_exportedFilePath != null) {
      final savedPath = await ExportService.saveToDownloads(_exportedFilePath!);
      
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Dosya kaydedildi: ${savedPath.split('/').last}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya kaydedilemedi. Depolama izni gerekebilir.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}