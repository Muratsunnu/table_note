import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dialoglar dahil her rotanın üzerinde görünen kısa işlem bildirimi.
class AppFeedback {
  AppFeedback._();

  static OverlayEntry? _activeEntry;
  static Timer? _timer;

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.error_outline_rounded,
      color: AppTheme.error,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline_rounded,
      color: AppTheme.successForeground,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color color,
  }) {
    _timer?.cancel();
    _activeEntry?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(overlayContext).bottom + 24,
        child: SafeArea(
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: color,
              elevation: 12,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 4), () {
      if (_activeEntry == entry) {
        entry.remove();
        _activeEntry = null;
      }
    });
  }
}
