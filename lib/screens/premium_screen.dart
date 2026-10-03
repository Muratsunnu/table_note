import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

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
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primaryBlue, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    subscription.localizedPrice ?? loc.plannedAnnualPrice,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.sevenDayTrial,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: subscription.isLoading
                          ? null
                          : () async {
                              if (subscription.requiresSignIn) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AccountScreen(),
                                  ),
                                );
                                return;
                              }
                              await subscription.startPurchase();
                            },
                      child: Text(
                        subscription.isLoading
                            ? loc.billingPreparing
                            : subscription.requiresSignIn
                            ? loc.signInToSubscribe
                            : loc.startFreeTrial,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
}
