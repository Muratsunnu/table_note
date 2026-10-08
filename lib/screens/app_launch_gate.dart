import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'table_screen.dart';

class AppLaunchGate extends StatefulWidget {
  /// Uygulama başlamadan çözülmüşse verilir; yoksa burada çözülür.
  final bool? showOnboarding;

  const AppLaunchGate({super.key, this.showOnboarding});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate> {
  late bool? _showOnboarding = widget.showOnboarding;

  @override
  void initState() {
    super.initState();
    if (_showOnboarding == null) _resolveStartScreen();
  }

  Future<void> _resolveStartScreen() async {
    final shouldShow = await OnboardingService.shouldShow();
    if (mounted) setState(() => _showOnboarding = shouldShow);
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.complete();
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showOnboarding!
          ? OnboardingScreen(onComplete: _completeOnboarding)
          : TableScreen(),
    );
  }
}
