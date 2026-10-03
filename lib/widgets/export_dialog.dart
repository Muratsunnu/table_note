import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_feedback.dart';

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
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.download_rounded,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).exportTitle,
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
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.table_chart_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.tableName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).recordsAndColumns(
                            table.rows.length,
                            table.columns.length,
                          ),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
              Text(
                AppLocalizations.of(context).selectFormat,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),

              // CSV seçeneği
              _buildFormatOption(
                icon: Icons.description,
                title: 'CSV',
                subtitle: AppLocalizations.of(context).csvDesc,
                color: Colors.green,
                onTap: () => _export('csv'),
              ),

              const SizedBox(height: 10),

              // PDF seçeneği
              _buildFormatOption(
                icon: Icons.picture_as_pdf,
                title: 'PDF',
                subtitle: AppLocalizations.of(context).pdfDesc,
                color: Colors.red,
                onTap: () => _export('pdf'),
              ),
            ],

            // Export başarılı
            if (_exportedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.tintedSurface(context, Colors.green),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.readableAccent(context, Colors.green),
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).fileCreated(_exportFormat!.toUpperCase()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.readableAccent(context, Colors.green),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Paylaş butonu
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share),
                        label: Text(AppLocalizations.of(context).shareWhatsApp),
                        style: FilledButton.styleFrom(
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
                        label: Text(AppLocalizations.of(context).saveToDevice),
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
                      child: Text(
                        AppLocalizations.of(context).selectAnotherFormat,
                      ),
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
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).creatingFile,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
          child: Text(
            _exportedFilePath != null
                ? AppLocalizations.of(context).close
                : AppLocalizations.of(context).cancel,
          ),
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
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
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
        filePath = await ExportService.exportToPdf(
          table,
          loc: AppLocalizations.of(context),
          columnSums: columnSums,
        );
      }

      setState(() {
        _exportedFilePath = filePath;
        _exportFormat = format;
        _isExporting = false;
      });
    } catch (_) {
      setState(() {
        _isExporting = false;
      });

      AppFeedback.showError(context, AppLocalizations.of(context).exportFailed);
    }
  }

  Future<void> _share() async {
    if (_exportedFilePath != null) {
      final provider = Provider.of<TableProvider>(context, listen: false);
      await ExportService.shareFile(
        _exportedFilePath!,
        '${provider.currentTable!.tableName} - ${AppLocalizations.of(context).tableData}',
      );
    }
  }

  Future<void> _saveToDevice() async {
    if (_exportedFilePath != null) {
      final savedPath = await ExportService.saveToDownloads(_exportedFilePath!);

      if (savedPath != null) {
        AppFeedback.showSuccess(
          context,
          AppLocalizations.of(context).fileSaved(savedPath.split('/').last),
        );
      } else {
        AppFeedback.showError(
          context,
          AppLocalizations.of(context).fileSaveFailed,
        );
      }
    }
  }
}
