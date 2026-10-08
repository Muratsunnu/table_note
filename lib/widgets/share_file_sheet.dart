import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';
import 'ledger.dart';

/// Paylaşılabilecek bir dosya türü ve onu üreten işlem.
class ShareFileFormat {
  const ShareFileFormat({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.create,
  });

  /// "PDF", "CSV".
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  /// Dosyayı oluşturur ve yolunu döner.
  final Future<String> Function() create;
}

/// Tabloyu ya da çeteleyi dosya olarak paylaşma kâğıdı.
///
/// Eskiden üst çubukta bir indirme düğmesi vardı: tür seçilir, dosya
/// oluşturulur, sonra ayrı bir adımda "paylaş" ya da "cihaza kaydet"
/// denirdi. Çoğu kişi dosyayı cihazına indirmek değil birine göndermek
/// istiyor; bu yüzden türe dokunmak doğrudan paylaşım penceresini açar.
/// Cihaza kaydetmek satırın sonundaki küçük düğmede durur.
class ShareFileSheet extends StatefulWidget {
  const ShareFileSheet({
    super.key,
    required this.name,
    required this.summary,
    required this.icon,
    required this.formats,
    this.shareFile = ExportService.shareFile,
    this.saveFile = ExportService.saveToDownloads,
  });

  final String name;

  /// Adın altındaki tek satır: kaç kayıt, kaç sütun.
  final String summary;
  final IconData icon;
  final List<ShareFileFormat> formats;

  @visibleForTesting
  final Future<bool> Function(String path, String subject, {Rect? origin})
  shareFile;

  @visibleForTesting
  final Future<String?> Function(String path) saveFile;

  static Future<void> show(
    BuildContext context, {
    required String name,
    required String summary,
    required IconData icon,
    required List<ShareFileFormat> formats,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ShareFileSheet(
      name: name,
      summary: summary,
      icon: icon,
      formats: formats,
    ),
  );

  @override
  State<ShareFileSheet> createState() => _ShareFileSheetState();
}

class _ShareFileSheetState extends State<ShareFileSheet> {
  /// Dosyası hazırlanan tür; hazırlık sürerken öteki satırlar bekler.
  ShareFileFormat? _working;
  bool _failed = false;

  Future<String?> _create(ShareFileFormat format) async {
    setState(() {
      _working = format;
      _failed = false;
    });
    try {
      return await format.create();
    } catch (error) {
      debugPrint('Dosya oluşturulamadı: $error');
      if (mounted) setState(() => _failed = true);
      return null;
    }
  }

  Future<void> _share(ShareFileFormat format, BuildContext rowContext) async {
    // iPad'de paylaşım penceresi bir noktaya bağlanmak zorunda; konum,
    // dosya hazırlanırken satır yerinden oynamadan önce alınır.
    final box = rowContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final navigator = Navigator.of(context);
    final path = await _create(format);
    if (path == null) {
      if (mounted) setState(() => _working = null);
      return;
    }
    var shared = false;
    try {
      shared = await widget.shareFile(
        path,
        '${widget.name} - ${format.label}',
        origin: origin,
      );
    } catch (error) {
      debugPrint('Paylaşım açılamadı: $error');
      if (mounted) setState(() => _failed = true);
    }
    if (!mounted) return;
    setState(() => _working = null);
    // Gönderildiyse kâğıdın işi bitti. Paylaşım penceresi kapatıldıysa
    // kâğıt açık kalır: başka bir tür ya da cihaza kaydetme seçilebilir.
    if (shared) navigator.pop();
  }

  Future<void> _save(ShareFileFormat format) async {
    final loc = AppLocalizations.of(context);
    final path = await _create(format);
    if (path == null) {
      if (mounted) setState(() => _working = null);
      return;
    }
    final saved = await widget.saveFile(path);
    if (!mounted) return;
    setState(() => _working = null);
    if (saved == null) {
      AppFeedback.showError(context, loc.fileSaveFailed);
    } else {
      AppFeedback.showSuccess(context, loc.fileSaved(saved.split('/').last));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final busy = _working != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      widget.summary,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Semantics(
              header: true,
              child: Text(
                loc.shareAsFile,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          LedgerCard(
            children: [
              for (final format in widget.formats)
                _FormatRow(
                  key: ValueKey('share-file-${format.label}'),
                  format: format,
                  working: identical(_working, format),
                  enabled: !busy,
                  onShare: (rowContext) => _share(format, rowContext),
                  onSave: () => _save(format),
                ),
            ],
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                loc.exportFailed,
                style: TextStyle(color: colors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bir dosya türü: satıra dokunmak paylaşır, sondaki düğme cihaza kaydeder.
class _FormatRow extends StatelessWidget {
  const _FormatRow({
    super.key,
    required this.format,
    required this.working,
    required this.enabled,
    required this.onShare,
    required this.onSave,
  });

  final ShareFileFormat format;
  final bool working;
  final bool enabled;
  final void Function(BuildContext rowContext) onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? () => onShare(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tintedSurface(context, format.color),
              ),
              child: working
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.readableAccent(context, format.color),
                      ),
                    )
                  : Icon(
                      format.icon,
                      size: 20,
                      color: AppTheme.readableAccent(context, format.color),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.label,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    working ? loc.creatingFile : format.description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('save-file-${format.label}'),
              tooltip: loc.saveToDevice,
              onPressed: enabled ? onSave : null,
              icon: const Icon(Icons.save_alt_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
