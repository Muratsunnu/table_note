import 'package:flutter/material.dart';

/// Prevents a second edit or route dismissal while a form is being committed.
/// Draft persistence belongs to the form's [FormDraftStore] snapshots.
class FormDraftGuard extends StatelessWidget {
  const FormDraftGuard({
    super.key,
    required this.isSaving,
    required this.child,
  });

  final bool isSaving;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !isSaving,
    child: ExcludeFocus(
      excluding: isSaving,
      child: AbsorbPointer(absorbing: isSaving, child: child),
    ),
  );
}
