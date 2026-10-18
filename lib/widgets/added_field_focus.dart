import 'package:flutter/material.dart';
import 'form_field_reveal.dart';

/// Focuses an explicitly added field, never pre-existing/restored form fields.
/// Owns the focus node so removing a row also releases its focus resources.
class AddedFieldFocus extends StatefulWidget {
  const AddedFieldFocus({
    super.key,
    required this.target,
    required this.pendingTarget,
    required this.onFocused,
    required this.builder,
  });

  final Object target;
  final Object? Function() pendingTarget;
  final ValueChanged<Object> onFocused;
  final Widget Function(FocusNode focusNode) builder;

  @override
  State<AddedFieldFocus> createState() => _AddedFieldFocusState();
}

class _AddedFieldFocusState extends State<AddedFieldFocus> {
  final _focusNode = FocusNode();
  final _fieldReveal = FieldRevealController();
  bool _focusQueued = false;

  @override
  void initState() {
    super.initState();
    _queueFocus();
  }

  @override
  void didUpdateWidget(covariant AddedFieldFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _queueFocus();
  }

  void _queueFocus() {
    if (!identical(widget.pendingTarget(), widget.target) || _focusQueued)
      return;
    _focusQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusQueued = false;
      if (!mounted || !identical(widget.pendingTarget(), widget.target)) return;
      _fieldReveal.reveal(_focusNode);
      widget.onFocused(widget.target);
    });
  }

  @override
  void dispose() {
    _fieldReveal.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_focusNode);
}
