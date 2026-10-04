import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/onboarding_previews.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await widget.onComplete();
  }

  void _next() {
    if (_currentPage == 2) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final pages = [
      _OnboardingPage(
        icon: Icons.table_chart_rounded,
        preview: const OnboardingTablePreview(),
        color: AppTheme.primaryBlue,
        title: loc.onboardingOrganizeTitle,
        description: loc.onboardingOrganizeDescription,
      ),
      _OnboardingPage(
        icon: Icons.wifi_off_rounded,
        preview: const OnboardingTallyPreview(),
        color: AppTheme.teal,
        title: loc.onboardingOfflineTitle,
        description: loc.onboardingOfflineDescription,
      ),
      _OnboardingPage(
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFF59E0B),
        title: loc.onboardingPremiumTitle,
        description: loc.onboardingPremiumDescription,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _currentPage == 2 ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: _currentPage == 2,
                    child: TextButton(
                      onPressed: _isCompleting ? null : _finish,
                      child: Text(loc.skip),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == _currentPage ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? AppTheme.primaryBlue
                        : Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCompleting ? null : _next,
                  icon: _isCompleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _currentPage == 2
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    _currentPage == 2 ? loc.startUsing : loc.continueLabel,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  /// Verilirse yuvarlak ikonun yerine bu cizim gosterilir. Ornek tablo ve
  /// cetele, uygulamanin ne yaptigini bir cumleden daha hizli anlatiyor.
  final Widget? preview;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (preview != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: preview!,
                  )
                else
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 72, color: color),
                  ),
                const SizedBox(height: 36),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
