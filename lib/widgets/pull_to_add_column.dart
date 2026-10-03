import 'package:flutter/material.dart';
import 'form_field_reveal.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Reveals the same pull-up affordance used by the table creation form.
class PullToAddColumn extends StatefulWidget {
  const PullToAddColumn({super.key, required this.child, required this.onAdd});

  final Widget child;
  final VoidCallback onAdd;

  @override
  State<PullToAddColumn> createState() => _PullToAddColumnState();
}

class _PullToAddColumnState extends State<PullToAddColumn> {
  static const double _threshold = 72;
  static const double _maximum = 96;
  double _distance = 0;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.metrics.extentAfter <= 0 &&
        notification.overscroll > 0) {
      final next = (_distance + notification.overscroll).clamp(0.0, _maximum);
      if (next >= _threshold && _distance < _threshold) {
        HapticFeedback.selectionClick();
      }
      setState(() => _distance = next);
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        _distance > 0 &&
        (notification.scrollDelta ?? 0) < 0) {
      setState(() {
        _distance = (_distance + notification.scrollDelta!).clamp(
          0.0,
          _maximum,
        );
      });
    } else if (notification is ScrollEndNotification ||
        notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
      if (_distance > 0) {
        final shouldAdd = _distance >= _threshold;
        setState(() => _distance = 0);
        if (shouldAdd) widget.onAdd();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = _distance == 0 && !reducedMotion
        ? const Duration(milliseconds: 160)
        : Duration.zero;
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: FormFocusScrollView(
                primary: false,
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: widget.child,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: duration,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: 0,
            height: _distance,
            child: IgnorePointer(
              child: ColoredBox(
                color: colors.primary,
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: (_distance / _threshold).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSlide(
                        duration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 120),
                        offset: _distance >= _threshold
                            ? const Offset(0, -0.12)
                            : Offset.zero,
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: colors.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).addColumn,
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
