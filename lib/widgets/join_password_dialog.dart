import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Katılım şifresini sorar. Vazgeçilirse null döner; boş bırakılıp
/// kaydedilirse boş metin döner ve bu, şifrenin kaldırılması demektir.
Future<String?> showJoinPasswordDialog(BuildContext context) {
  final loc = AppLocalizations.of(context);
  // Denetleyici değil düz değişken: showDialog, kapanma animasyonu bitmeden
  // döner. Denetleyiciyi döner dönmez dispose etmek, hâlâ ağaçta duran
  // TextField yüzünden '_dependents.isEmpty' iddiasını patlatıyordu.
  var typed = '';
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(loc.joinPassword),
      content: TextField(
        autofocus: true,
        onChanged: (text) => typed = text,
        onSubmitted: (text) => Navigator.pop(dialogContext, text),
        decoration: InputDecoration(
          labelText: loc.joinPasswordOptional,
          // İpucu tek satıra sığmayıp ortasından kesiliyordu.
          helperText: loc.joinPasswordHint,
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, typed),
          child: Text(loc.save),
        ),
      ],
    ),
  );
}
