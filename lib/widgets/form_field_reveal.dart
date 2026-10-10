import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

/// Leaves enough scroll space to bring even the last input near the top.
class FormFocusScrollView extends StatefulWidget {
  const FormFocusScrollView({
    super.key,
    required this.child,
    this.controller,
    this.physics,
    this.primary,
    this.padding = EdgeInsets.zero,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  final Widget child;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool? primary;
  final EdgeInsetsGeometry padding;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  State<FormFocusScrollView> createState() => _FormFocusScrollViewState();
}

class _FormFocusScrollViewState extends State<FormFocusScrollView> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => _hasFocus = value),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: widget.controller,
          physics: widget.physics,
          primary: widget.primary,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          padding: widget.padding.add(
            EdgeInsets.only(
              bottom: _hasFocus && constraints.hasBoundedHeight
                  ? constraints.maxHeight * 0.8
                  : 0,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Briefly follows keyboard layout changes for an explicit focus request.
/// Stops after settling, losing focus, or a user drag; it never pins the form.
class FieldRevealController with WidgetsBindingObserver {
  FocusNode? _focus;
  Timer? _settleTimer;
  Timer? _deadline;
  int _generation = 0;

  void reveal(FocusNode focus) {
    _stop();
    _focus = focus;
    WidgetsBinding.instance.addObserver(this);
    focus.requestFocus();
    _queueReveal();
    _settleTimer = Timer(const Duration(milliseconds: 350), _finish);
    _deadline = Timer(const Duration(seconds: 1), _finish);
  }

  @override
  void didChangeMetrics() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 120), _finish);
  }

  void _queueReveal({bool finish = false}) {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation) return;
      final focus = _focus;
      final context = focus?.context;
      if (context == null || !context.mounted || !focus!.hasFocus) {
        _stop();
        return;
      }
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null &&
          scrollable.position.userScrollDirection != ScrollDirection.idle) {
        _stop();
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      if (finish) _stop();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _finish() => _queueReveal(finish: true);

  void _stop() {
    _generation++;
    _settleTimer?.cancel();
    _deadline?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _focus = null;
  }

  void dispose() => _stop();
}
