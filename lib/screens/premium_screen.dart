import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/plan_offer.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ledger.dart';
import '../utils/store_links.dart';
import 'account_screen.dart';
import 'premium_welcome_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  /// Seçili paket. Yıllık öndedir: hem ucuzu hem de denemesi olanı.
  PlanPeriod _selected = PlanPeriod.yearly;

  // Girişten sonra hesabın aboneliğine bakılırken düğme bekler.
  bool _continuing = false;

  SubscriptionProvider? _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final subscription = context.read<SubscriptionProvider>();
    if (!identical(subscription, _subscription)) {
      _subscription?.removeListener(_onSubscriptionChanged);
      _subscription = subscription..addListener(_onSubscriptionChanged);
    }
  }

  @override
  void dispose() {
    _subscription?.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  /// Satın alma doğrulandığı an bu ekran yerini karşılama ekranına bırakır.
  void _onSubscriptionChanged() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (!_subscription!.takePurchaseCompleted()) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PremiumWelcomeScreen()),
    );
  }

  Future<void> _manageSubscription() async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    if (await openSubscriptionSettings()) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(loc.manageSubscriptionFailed(subscriptionStoreName)),
        ),
      );
  }

  /// Hesabı olmayan kişi önce giriş yapar; giriş bitince kaldığı yerden,
  /// mağazanın satın alma penceresinden devam eder. Geri dönüp düğmeye bir
  /// kez daha basması gerekmez.
  Future<void> _buy(SubscriptionProvider subscription) async {
    if (subscription.requiresSignIn) {
      final signedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AccountScreen(closeOnSignIn: true),
        ),
      );
      if (signedIn != true || !mounted) return;
      // Girilen hesabın aboneliği zaten olabilir; öyleyse yeniden satın
      // aldırılmaz.
      setState(() => _continuing = true);
      try {
        await subscription.refreshEntitlement();
      } finally {
        if (mounted) setState(() => _continuing = false);
      }
      if (!mounted || subscription.isPremium) return;
    }
    final plan = subscription.plan(_selected) ?? subscription.plans.firstOrNull;
    if (plan != null) await subscription.startPurchase(plan);
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                  size: 44,
                ),
                const SizedBox(height: 8),
                Text(
                  isPremium ? loc.premiumActive : loc.unlockPremium,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
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
          // Premium'u olan kişi: ne zamana kadar geçerli ve nereden yönetilir.
          if (isPremium) ...[
            const SizedBox(height: 16),
            LedgerCard(
              children: [
                if (subscription.validUntil case final validUntil?)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Text(
                      loc.premiumValidUntil(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(validUntil.toLocal()),
                      ),
                      key: const ValueKey('premium-valid-until'),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                InkWell(
                  key: const ValueKey('manage-subscription'),
                  onTap: _manageSubscription,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 20,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.manageSubscription,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Tek kart, sıkı satırlar: fiyat ve düğme aşağıda kaybolmasın.
          LedgerCard(
            children: [
              for (final feature in features)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(feature.$1, size: 20, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature.$2,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: AppTheme.success,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (!isPremium) ...[
            const SizedBox(height: 16),
            ..._purchase(context, subscription),
            TextButton(
              onPressed: subscription.isLoading || subscription.requiresSignIn
                  ? null
                  : subscription.restorePurchases,
              child: Text(loc.restorePurchases),
            ),
            if (subscription.problem case final problem?)
              Text(
                switch (problem) {
                  PurchaseProblem.network => loc.purchaseNoConnection,
                  PurchaseProblem.verification => loc.purchaseNotVerified,
                  PurchaseProblem.other => loc.purchaseFailed,
                },
                key: const ValueKey('purchase-problem'),
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
    final store = defaultTargetPlatform == TargetPlatform.iOS
        ? 'App Store'
        : 'Google Play';
    final trialDays = selected.trialDays;
    final small = TextStyle(
      fontSize: 12.5,
      height: 1.4,
      color: colors.onSurfaceVariant,
    );

    return [
      if (subscription.showsSamplePlans) ...[
        const LedgerNote(
          'Geliştirici önizlemesi: fiyatlar örnek, mağazadan gelmiyor; '
          'satın alma düğmesi bir şey yapmaz.',
        ),
        const SizedBox(height: 10),
      ],
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
      // Ne zaman, ne kadar ücretleneceği düğmeden önce satır satır yazar.
      if (trialDays != null) ...[
        LedgerCard(
          key: const ValueKey('plan-terms'),
          children: [
            _TermRow(label: loc.trialTodayLabel, text: loc.trialTodayText),
            _TermRow(
              label: loc.trialChargeLabel(trialDays),
              text: loc.trialChargeText(selected.price, unit(selected)),
            ),
            _TermRow(
              label: loc.trialCancelLabel,
              text: loc.trialCancelText(store),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (subscription.requiresSignIn) ...[
        Text(
          loc.signInToSubscribeHint,
          textAlign: TextAlign.center,
          style: small,
        ),
        const SizedBox(height: 8),
      ],
      // Onayı geciken ödeme: kişi beklediğini bilsin, yeniden denemesin.
      if (subscription.hasPendingPurchase) ...[
        LedgerNote(loc.purchasePending),
        const SizedBox(height: 10),
      ],
      FilledButton(
        key: const ValueKey('plan-buy'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        // Mağaza ödemeyi aldıktan sonra sunucu doğrulayana kadar düğme bekler;
        // yoksa "bir şey olmadı" sanılıp yeniden basılır.
        onPressed:
            subscription.isLoading ||
                _continuing ||
                subscription.isVerifying ||
                subscription.hasPendingPurchase
            ? null
            : () => _buy(subscription),
        child: subscription.isVerifying
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(loc.verifyingPurchase)),
                ],
              )
            : Text(
                subscription.isLoading || _continuing
                    ? loc.billingPreparing
                    : subscription.requiresSignIn
                    ? loc.signInToSubscribe
                    : trialDays != null
                    ? loc.startTrial(trialDays)
                    : loc.subscribeNow,
              ),
      ),
      const SizedBox(height: 10),
      if (trialDays == null) ...[
        Text(
          loc.renewalTerms(selected.price, unit(selected), store),
          key: const ValueKey('plan-terms'),
          textAlign: TextAlign.center,
          style: small,
        ),
        const SizedBox(height: 6),
      ],
      Text(loc.premiumKeepsData, textAlign: TextAlign.center, style: small),
    ];
  }
}

/// Deneme koşullarının bir satırı: solda ne zaman, sağda ne olacağı.
class _TermRow extends StatelessWidget {
  const _TermRow({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
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
