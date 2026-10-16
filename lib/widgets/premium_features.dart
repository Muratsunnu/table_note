import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Premium'un açtığı özellikler. Premium ekranı ile satın alma sonrası
/// karşılama aynı listeyi aynı sırayla gösterir; yeni bir özellik buraya
/// eklenince iki yerde de görünür.
enum PremiumFeature { voice, cloud, share, export, csv, unlimited, tally }

extension PremiumFeatureInfo on PremiumFeature {
  IconData get icon => switch (this) {
    PremiumFeature.voice => Icons.mic_rounded,
    PremiumFeature.cloud => Icons.cloud_done_rounded,
    PremiumFeature.share => Icons.group_add_rounded,
    PremiumFeature.export => Icons.filter_alt_rounded,
    PremiumFeature.csv => Icons.upload_file_rounded,
    PremiumFeature.unlimited => Icons.all_inclusive_rounded,
    PremiumFeature.tally => Icons.grid_view_rounded,
  };

  String label(AppLocalizations loc) => switch (this) {
    PremiumFeature.voice => loc.premiumVoiceFeature,
    PremiumFeature.cloud => loc.premiumCloudFeature,
    PremiumFeature.share => loc.premiumShareFeature,
    PremiumFeature.export => loc.premiumExportFeature,
    PremiumFeature.csv => loc.premiumImportFeature,
    PremiumFeature.unlimited => loc.premiumUnlimitedFeature,
    PremiumFeature.tally => loc.premiumTallyFeature,
  };
}
