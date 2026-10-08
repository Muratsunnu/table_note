import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/shared_sync_service.dart';

/// Yalnızca görüntüleme yetkisi olan kişinin karşılaştığı parçalar: kayıt
/// ekleme düğmesinin yerine geçen "Yetki iste" ve bir hücreye dokununca
/// çıkan uyarı. Tablo ve çetele ekranı aynılarını kullanır.

/// Onay sorar, ardından düzenleme yetkisi talebini tablo sahibine gönderir.
Future<void> confirmAndRequestEditAccess(
  BuildContext context, {
  required String tableId,
}) async {
  final loc = AppLocalizations.of(context);
  // Onay penceresi kapanırken çağıran ekran değişmiş olabilir; gerekenler
  // beklemeden önce alınır.
  final sync = context.read<SharedSyncService>();
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(loc.requestEditAccessTitle),
      content: Text(loc.requestEditAccessMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(loc.cancel),
        ),
        FilledButton(
          key: const ValueKey('request-edit-access-confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(loc.sendRequest),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final errorCode = await sync.requestEditAccess(tableId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          errorCode == null
              ? loc.editAccessRequestSent
              : loc.sharedTableError(errorCode),
        ),
      ),
    );
}

/// Kayıt ekleme düğmesinin yerinde duran "Yetki iste". Talep yanıt beklerken
/// bunu söyler ve yeniden basılamaz.
class RequestEditAccessButton extends StatelessWidget {
  const RequestEditAccessButton({super.key, required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final requested = context
        .watch<SharedSyncService>()
        .accessFor(tableId)
        .editRequested;
    return FilledButton.icon(
      key: const ValueKey('request-edit-access'),
      onPressed: requested
          ? null
          : () => confirmAndRequestEditAccess(context, tableId: tableId),
      icon: Icon(
        requested ? Icons.hourglass_top_rounded : Icons.lock_open_rounded,
      ),
      label: Text(requested ? loc.editAccessRequested : loc.requestEditAccess),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Görüntüleyen kişi bir satıra ya da hücreye dokunduğunda: neden bir şey
/// olmadığını söyler ve yetki istemenin yolunu gösterir.
void showViewOnlyNotice(BuildContext context, {required String tableId}) {
  final loc = AppLocalizations.of(context);
  final requested = context
      .read<SharedSyncService>()
      .accessFor(tableId)
      .editRequested;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(requested ? loc.viewOnlyRequested : loc.viewOnlyNotice),
        action: requested
            ? null
            : SnackBarAction(
                label: loc.requestEditAccess,
                onPressed: () {
                  if (context.mounted) {
                    confirmAndRequestEditAccess(context, tableId: tableId);
                  }
                },
              ),
      ),
    );
}
