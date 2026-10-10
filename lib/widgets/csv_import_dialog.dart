import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/tabel_model.dart';
import '../providers/table_provider.dart';
import '../services/csv_import_service.dart';

class CsvImportDialog extends StatefulWidget {
  const CsvImportDialog({super.key});

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<CsvImportDialog> {
  final _service = CsvImportService();
  TableModel? _preview;
  bool _loading = false;
  String? _error;

  Future<void> _pick() async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      if (file.bytes == null) {
        if (!mounted) return;
        throw StateError(AppLocalizations.of(context).fileCouldNotBeRead);
      }
      _preview = _service.parse(
        file.bytes!,
        file.name,
        fallbackTableName: loc.csvImportedTable,
      );
    } catch (error) {
      _error = switch (error) {
        CsvImportException(code: 'empty_or_too_large') =>
          loc.csvEmptyOrTooLarge,
        CsvImportException(code: 'header_missing') => loc.csvHeaderMissing,
        CsvImportException(code: 'too_many_rows') => loc.csvTooManyRows,
        _ => loc.csvInvalid,
      };
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final table = _preview;
    if (table == null) return;
    final success = await context.read<TableProvider>().importCloudTable(
      table,
      overwrite: false,
    );
    if (mounted && success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final table = _preview;
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.importCsv),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width * .9,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (table == null)
                    Text(loc.csvImportDescription)
                  else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.table_chart_rounded),
                      title: Text(table.tableName),
                      subtitle: Text(
                        loc.recordsAndColumns(
                          table.rows.length,
                          table.columns.length,
                        ),
                      ),
                    ),
                    const Divider(),
                    SizedBox(
                      height: 220,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: table.columns
                                .map(
                                  (column) =>
                                      DataColumn(label: Text(column.name)),
                                )
                                .toList(),
                            rows: table.rows.take(5).map((row) {
                              return DataRow(
                                cells: row
                                    .map((value) => DataCell(Text(value)))
                                    .toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pick,
          icon: const Icon(Icons.folder_open_rounded),
          label: Text(table == null ? loc.selectFile : loc.selectAnotherFile),
        ),
        if (table != null)
          FilledButton(onPressed: _import, child: Text(loc.importCsv)),
      ],
    );
  }
}
