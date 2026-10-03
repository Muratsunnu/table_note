import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Yapiyi yalnizca paylasan kisi degistirebilir.
///
/// Katilan kisinin yaptigi yapi degisikligi buluta gitmez; gitseydi de iki
/// kisinin es zamanli sutun degisikligini birlestirmek gerekirdi. Daha
/// kotusu: sutun sayisi iki tarafta farklilasinca satir birlestirmeleri
/// yanlis uzunlukta satirlar yazmaya baslar. Bu yuzden duzenleyici hic
/// acilmaz, sadece gizlenmis bir dugme degil.
class SharedStructureLocked extends StatelessWidget {
  const SharedStructureLocked({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(loc.sharedStructureLockedTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 52, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                loc.sharedStructureLocked,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
