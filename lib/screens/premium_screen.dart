import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/plan_offer.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ledger.dart';
import 'account_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  /// Seçili paket. Yıllık öndedir: hem ucuzu hem de denemesi olanı.
  PlanPeriod _selected = PlanPeriod.yearly;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final subscription = context.watch<SubscriptionProvider>();
    final isPremium = subscription.isPremium;
    final features = [
      (Icons.mic_rounded, loc.premiumVoiceFeature),
      (Icons.cloud_done_rounded, loc.premiumCloudFeature),
      (Icons.ios_share_rounded, loc.premiumShareFeature),
      (Icons.upload_file_rounded, loc.premiumImportFeature),
      (Icons.all_inclusive_rounded, loc.premiumUnlimitedFeature),
      (Icons.grid_view_rounded, loc.premiumTallyFeature),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(loc.premium)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF172554), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFBBF24),
                  size: 58,
                ),
                const SizedBox(height: 12),
                Text(
                  isPremium ? loc.premiumActive : loc.unlockPremium,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPremium
                      ? loc.premiumActiveDescription
                      : loc.premiumDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.cardDecorationFor(context),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(feature.$1, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature.$2,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.success,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 10),
            ..._purchase(context, subscription),
            TextButton(
              onPressed: subscription.isLoading || subscription.requiresSignIn
                  ? null
                  : subscription.restorePurchases,
              child: Text(loc.restorePurchases),
            ),
            if (subscription.errorMessage != null)
              Text(
                loc.purchaseCouldNotBeVerified,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ] else ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: subscription.isLoading
                  ? null
                  : subscription.restorePurchases,
              icon: const Icon(Icons.restore_rounded),
              label: Text(loc.restorePurchases),
            ),
          ],
        ],
      ),
    );
  }

  /// Paket seçimi ve satın alma. Fiyatlar ve deneme süresi mağazadan gelir;
  /// mağazaya ulaşılamıyorsa uygulama kendi başına fiyat yazmaz.
  List<Widget> _purchase(
    BuildContext context,
    SubscriptionProvider subscription,
  ) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final plans = subscription.plans;

    if (plans.isEmpty) {
      return [
        if (subscription.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Text(
            loc.priceUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('plans-retry'),
            onPressed: subscription.reloadPlans,
            child: Text(loc.retry),
          ),
        ],
      ];
    }

    final selected = subscription.plan(_selected) ?? plans.first;
    final yearly = subscription.plan(PlanPeriod.yearly);
    final monthly = subscription.plan(PlanPeriod.monthly);
    // İndirim de mağazanın iki fiyatından hesaplanır.
    final saving = yearly == null || monthly == null
        ? null
        : yearlySavingPercent(
            yearly: yearly.rawPrice,
            monthly: monthly.rawPrice,
          );
    String unit(PlanOffer plan) =>
        plan.period == PlanPeriod.yearly ? loc.perYear : loc.perMonth;

    return [
      LedgerCard(
        children: [
          for (final plan in plans)
            _PlanRow(
              key: ValueKey('plan-${plan.period.name}'),
              title: plan.period == PlanPeriod.yearly
                  ? loc.planYearly
                  : loc.planMonthly,
              price: '${plan.price} / ${unit(plan)}',
              badges: [
                if (plan.trialDays != null) loc.trialBadge(plan.trialDays!),
                if (plan.period == PlanPeriod.yearly && saving != null)
                  loc.savingBadge(saving),
              ],
              selected: identical(plan, selected),
              onTap: subscription.isLoading
                  ? null
                  : () => setState(() => _selected = plan.period),
            ),
        ],
      ),
      const SizedBox(height: 14),
      FilledButton(
        key: const ValueKey('plan-buy'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: subscription.isLoading
            ? null
            : () async {
                if (subscription.requiresSignIn) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountScreen()),
                  );
                  return;
                }
                await subscription.startPurchase(selected);
              },
        child: Text(
          subscription.isLoading
              ? loc.billingPreparing
              : subscription.requiresSignIn
              ? loc.signInToSubscribe
              : selected.trialDays != null
              ? loc.startTrial(selected.trialDays!)
              : loc.subscribeNow,
        ),
      ),
      const SizedBox(height: 10),
      // Ne zaman, ne kadar ücretleneceği düğmenin hemen altında yazar.
      Text(
        selected.trialDays != null
            ? loc.trialTerms(
                selected.trialDays!,
                selected.price,
                unit(selected),
              )
            : loc.renewalTerms(selected.price, unit(selected)),
        key: const ValueKey('plan-terms'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.4,
          color: colors.onSurfaceVariant,
        ),
      ),
    ];
  }
}

/// Seçilebilir bir paket satırı: adı, mağazadaki fiyatı ve varsa deneme ile
/// indirim etiketleri.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    super.key,
    required this.title,
    required this.price,
    required this.badges,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;
  final List<String> badges;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(11, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.tintedSurface(context, colors.primary)
                : colors.surface.withValues(alpha: 0),
            // Seçili satırın işareti, formlardaki etkin satırla aynı.
            border: Border(
              left: BorderSide(
                width: 3,
                color: selected ? colors.primary : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final badge in badges)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.tintedSurface(
                                  context,
                                  AppTheme.success,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.readableAccent(
                                    context,
                                    AppTheme.success,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                price,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
