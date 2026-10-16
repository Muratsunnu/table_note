import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/subscription_provider.dart';
import '../screens/premium_screen.dart';
import 'premium_features.dart';

/// Ücretsiz kullanımda bir şeyden kaçının açıldığı: "4/5 ücretsiz". Sınır,
/// liste hâlinde değil, oluşturulan şeyin yanında görünür. Sınırsız
/// kullanıcıda hiç çizilmez; sınır dolunca vurgulanır ve Premium'u açar.
class FreeQuotaNote extends StatelessWidget {
  const FreeQuotaNote({super.key, required this.used, required this.limit});

  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    if (context.watch<SubscriptionProvider>().hasUnlimitedPlan) {
      return const SizedBox.shrink();
    }
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final full = used >= limit;
    final text = Text(
      full ? loc.freeQuotaFull(limit) : loc.freeQuotaUsed(used, limit),
      key: ValueKey('free-quota-$used-$limit'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: full ? FontWeight.w700 : FontWeight.w400,
        color: full ? colors.primary : colors.onSurfaceVariant,
      ),
    );
    if (!full) {
      return Padding(padding: const EdgeInsets.only(top: 6), child: text);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openPremium(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: text,
      ),
    );
  }
}

void openPremium(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const PremiumScreen()),
);

/// Ücretsiz sınır doluysa Premium ekranını açar ve true döner. Oluşturma
/// düğmeleri işe başlamadan bunu sorar: kişi formu doldurup sonunda
/// "oluşturulamadı" hatası görmez.
bool freeLimitReached(
  BuildContext context, {
  required int used,
  required int limit,
}) {
  if (used < limit || context.read<SubscriptionProvider>().hasUnlimitedPlan) {
    return false;
  }
  openPremium(context);
  return true;
}

/// Premium'a ait bir özelliğe dokunan ücretsiz kullanıcıya, özelliğin ne
/// olduğunu ve Premium'da olduğunu tek bakışta söyleyen küçük kâğıt.
Future<void> showPremiumFeatureSheet(
  BuildContext context,
  PremiumFeature feature,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (sheetContext) {
    final loc = AppLocalizations.of(sheetContext);
    final colors = Theme.of(sheetContext).colorScheme;
    // Yan çevrilmiş telefonda kâğıdın yüksekliği azdır; içerik kayar.
    return SingleChildScrollView(
      key: ValueKey('premium-feature-${feature.name}'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: colors.primaryContainer,
              child: Icon(feature.icon, size: 30, color: colors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            feature.label(loc),
            textAlign: TextAlign.center,
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 4),
              Text(
                loc.premiumFeature,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('premium-feature-go'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              Navigator.pop(sheetContext);
              openPremium(context);
            },
            child: Text(loc.goPremium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(loc.notNow),
          ),
        ],
      ),
    );
  },
);

/// Premium'a ait özelliğin düğme ikonu: özelliğin kendi işareti kalır,
/// ücretsiz kullanıcıda köşesine küçük bir kilit eklenir. Yalnızca kilit
/// çizilseydi düğmenin ne işe yaradığı anlaşılmazdı.
class PremiumFeatureIcon extends StatelessWidget {
  const PremiumFeatureIcon({
    super.key,
    required this.icon,
    required this.locked,
  });

  final IconData icon;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (!locked) return Icon(icon);
    return Badge(
      key: const ValueKey('premium-lock-badge'),
      backgroundColor: const Color(0xFFF59E0B),
      padding: const EdgeInsets.all(2),
      offset: const Offset(6, -6),
      label: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
      child: Icon(icon),
    );
  }
}
