import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';
import 'form_draft_guard.dart';

class AppFormScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final String cancelLabel;
  final String primaryLabel;
  final IconData primaryIcon;
  final Future<void> Function() onPrimary;
  final bool isSaving;
  final bool isRestoring;

  const AppFormScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
    required this.cancelLabel,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.isSaving = false,
    this.isRestoring = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return FormDraftGuard(
      isSaving: isSaving || isRestoring,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          toolbarHeight: 64 * scale.clamp(1.0, 2.0),
          leading: IconButton(
            onPressed: isSaving ? null : () => Navigator.maybePop(context),
            tooltip: cancelLabel,
            icon: const Icon(Icons.close_rounded),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: isRestoring
                ? const Center(child: CircularProgressIndicator())
                : child,
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Material(
            color: colors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cancel = TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.maybePop(context),
                      child: Text(cancelLabel),
                    );
                    final primary = FilledButton.icon(
                      onPressed: isSaving || isRestoring ? null : onPrimary,
                      icon: isSaving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(primaryIcon),
                      label: Text(
                        isSaving ? loc.savingProgress : primaryLabel,
                        textAlign: TextAlign.center,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    );
                    if (constraints.maxWidth / scale < 280) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [primary, cancel],
                      );
                    }
                    return Row(
                      children: [
                        Flexible(child: cancel),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: primary),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
