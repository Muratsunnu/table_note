import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/account_screen.dart';

/// Auth links may arrive while a table, dialog, or onboarding is open.
class AuthCallbackRouter extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const AuthCallbackRouter({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  State<AuthCallbackRouter> createState() => _AuthCallbackRouterState();
}

class _AuthCallbackRouterState extends State<AuthCallbackRouter> {
  bool _routeOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (_routeOpen || (!auth.recoveryNeedsScreen && !auth.callbackFailed))
      return;
    _routeOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null ||
          (!auth.recoveryNeedsScreen && !auth.callbackFailed)) {
        _routeOpen = false;
        return;
      }
      await navigator.push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/auth-callback'),
          builder: (_) => const AccountScreen(),
        ),
      );
      if (!mounted) return;
      _routeOpen = false;
      if (auth.callbackFailed) auth.clearFeedback();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
