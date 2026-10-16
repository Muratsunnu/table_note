import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// "Numara" tipinin simgesi ve rengi; tip seçicilerde ve başlıklarda aynıdır.
const codeColumnIcon = Icons.dialpad_rounded;
const codeColumnColor = Colors.blueGrey;

/// Numara sütununun ne olduğunu söyleyen kısa not: ayarı yoktur, yalnızca
/// nasıl davrandığı yazar.
class CodeColumnNote extends StatelessWidget {
  const CodeColumnNote({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(codeColumnIcon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).codeColumnDesc,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
