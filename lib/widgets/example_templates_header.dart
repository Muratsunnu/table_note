import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Şablon listelerinde hazır örneklerin başladığı yer.
class ExampleTemplatesHeader extends StatelessWidget {
  const ExampleTemplatesHeader({super.key, this.firstInList = false});

  /// Üstünde kullanıcının kendi şablonu yoksa boşluk bırakılmaz.
  final bool firstInList;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('example-templates-header'),
      padding: EdgeInsets.fromLTRB(4, firstInList ? 0 : 20, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.exampleTemplates,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            loc.exampleTemplatesHint,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
