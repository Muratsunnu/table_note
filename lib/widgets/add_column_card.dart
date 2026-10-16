import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Sütun listesinin sonunda duran boş "sıradaki sütun" kartı. Yeni sütunun
/// nereye geleceğini gösterir; dokununca ekler.
class AddColumnCard extends StatelessWidget {
  const AddColumnCard({super.key, required this.onTap});

  /// Null ise kart soluk durur ve dokunulmaz (örneğin kayıt sürerken).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final ink = onTap == null
        ? colors.onSurfaceVariant.withValues(alpha: 0.5)
        : colors.primary;
    const radius = BorderRadius.all(Radius.circular(12));

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: loc.addColumn,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('add-column-card'),
        borderRadius: radius,
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: _DashedBorder(
            color: onTap == null
                ? colors.outlineVariant
                : Color.lerp(colors.outline, colors.primary, 0.5)!,
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 20, color: ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    loc.addColumn,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
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

/// Kesik çizgili yuvarlak köşeli çerçeve: "burası henüz boş" der.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 1.5;
    const dash = 6.0;
    const gap = 5.0;
    final shape = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      const Radius.circular(12),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in (Path()..addRRect(shape)).computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash + gap) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}
