import 'package:flutter/material.dart';

/// Shared heading for normal and tally tables; selection belongs in the drawer.
class TableSectionHeader extends StatelessWidget {
  const TableSectionHeader({
    super.key,
    required this.title,
    required this.summary,
    required this.actions,
    this.detail,
    this.titleTrailing,
    this.compact = false,
  });

  final String title;
  final String summary;
  final String? detail;
  final List<Widget> actions;

  /// Basligin hemen yanina giren kucuk gosterge. Kendi satirini isteyen bir
  /// serit yerine buraya konuldugu icin tabloyu asagi itmez.
  final Widget? titleTrailing;

  /// Yüksekliği dar ekranda her şey tek satıra iner.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            // Düğmeler sağ kenarda kalsın diye yazılar kendi satırında.
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    flex: 3,
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (titleTrailing != null) ...[
                    const SizedBox(width: 8),
                    titleTrailing!,
                  ],
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 2,
                    child: Text(
                      detail == null ? summary : '$summary  •  $detail',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Uzun tablo adi gostergeyi disari itmesin.
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: 8),
                      titleTrailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
