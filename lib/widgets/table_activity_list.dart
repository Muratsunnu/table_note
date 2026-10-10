import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/cloud_repository.dart';
import '../theme/app_theme.dart';
import 'ledger.dart';

/// Ortak tablonun değişiklik geçmişi: kim, ne zaman, ne yaptı.
///
/// Kayıtlar güne göre gruplanır ve her gün, uygulamadaki öteki formlarla aynı
/// dilde bir tablo olarak çizilir: solda saat sütunu, sağda olay. Olayın türü
/// renkli bir simgeyle ayrılır ki uzun bir listede katılan, ayrılan, silen
/// bir bakışta bulunabilsin. Bir değerin değiştiği kayıtlarda eski değer
/// üstü çizili, yenisi koyu yazılır.
class TableActivityList extends StatelessWidget {
  const TableActivityList({
    super.key,
    required this.entries,
    required this.selfActorId,
    this.now,
  });

  /// Yeniden eskiye sıralı kayıtlar.
  final List<TableActivityEntry> entries;

  /// Geçmişe bakan kişinin kimliği; kendi kayıtları "Sen" diye yazılır.
  final String? selfActorId;

  /// "Bugün" ve "Dün" başlıklarının neye göre hesaplanacağı.
  @visibleForTesting
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(now ?? DateTime.now());

    // Kayıtlar zaten sıralı; ardışık aynı günler tek başlık altında toplanır.
    final days = <(DateTime, List<TableActivityEntry>)>[];
    for (final entry in entries) {
      final day = DateUtils.dateOnly(entry.createdAt);
      if (days.isEmpty || days.last.$1 != day) {
        days.add((day, [entry]));
      } else {
        days.last.$2.add(entry);
      }
    }

    String dayLabel(DateTime day) {
      final distance = today.difference(day).inDays;
      if (distance == 0) return loc.today;
      if (distance == 1) return loc.yesterday;
      return MaterialLocalizations.of(context).formatFullDate(day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (day, dayEntries) in days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
            child: Semantics(
              header: true,
              child: Text(
                dayLabel(day),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          LedgerCard(
            children: [
              for (final entry in dayEntries)
                _ActivityRow(
                  entry: entry,
                  isSelf: entry.actorId != null && entry.actorId == selfActorId,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Olay türünün simgesi ve rengi.
({IconData icon, Color color}) _look(String action) => switch (action) {
  'joined' => (
    icon: Icons.person_add_alt_1_rounded,
    color: AppTheme.primaryBlue,
  ),
  'left' => (icon: Icons.logout_rounded, color: AppTheme.textSecondary),
  'row_added' ||
  'item_added' => (icon: Icons.add_rounded, color: AppTheme.success),
  'row_updated' ||
  'item_renamed' => (icon: Icons.edit_rounded, color: AppTheme.warning),
  'row_deleted' ||
  'item_deleted' => (icon: Icons.delete_outline_rounded, color: AppTheme.error),
  'mark_changed' => (icon: Icons.check_rounded, color: AppTheme.teal),
  'columns_changed' => (
    icon: Icons.view_column_outlined,
    color: AppTheme.formula,
  ),
  'table_replaced' => (icon: Icons.restore_rounded, color: AppTheme.formula),
  'role_changed' => (icon: Icons.key_rounded, color: AppTheme.teal),
  'edit_requested' => (icon: Icons.lock_open_rounded, color: AppTheme.warning),
  _ => (icon: Icons.history_rounded, color: AppTheme.textSecondary),
};

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.isSelf});

  final TableActivityEntry entry;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final look = _look(entry.action);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(entry.createdAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final actor = isSelf
        ? loc.activityActorSelf
        // Hesabını silen kişinin adı kayıttan çıkarılır.
        : entry.actorName.trim().isEmpty
        ? loc.activityActorDeleted
        : entry.actorName;
    // Saat sütunu büyük yazı ayarında genişler; 12 saatlik biçim de sığar.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 66 * scale,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 15, 6, 12),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.tintedSurface(context, look.color),
                      ),
                      child: Icon(
                        look.icon,
                        size: 16,
                        color: AppTheme.readableAccent(context, look.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            // Kendi kayıtların ötekilerden ayrılsın.
                            color: isSelf ? colors.primary : colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        _detail(context, loc),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, AppLocalizations loc) {
    final colors = Theme.of(context).colorScheme;
    final plain = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: colors.onSurface,
    );
    Widget phrase(String text) => Text(text, style: plain);
    return switch (entry.action) {
      'joined' => phrase(loc.activityJoined),
      'left' => phrase(loc.activityLeft),
      'row_added' => phrase(loc.activityRowAdded),
      'row_deleted' => phrase(loc.activityRowDeleted),
      'item_added' => phrase(loc.activityItemAdded),
      'item_deleted' => phrase(loc.activityItemDeleted),
      'columns_changed' => phrase(loc.activityColumnsChanged),
      'table_replaced' => phrase(loc.activityTableReplaced),
      'edit_requested' => phrase(loc.activityEditRequested),
      'row_updated' || 'mark_changed' => _Change(
        label: entry.columnName,
        from: entry.oldValue,
        to: entry.newValue,
      ),
      'item_renamed' => _Change(from: entry.oldValue, to: entry.newValue),
      'role_changed' => _Change(
        label: entry.columnName,
        from: loc.roleLabel(entry.oldValue),
        to: loc.roleLabel(entry.newValue),
      ),
      // Tanınmayan bir tür gizlenmez; ham haliyle de olsa görünür.
      _ => phrase(entry.action),
    };
  }
}

/// Bir değerin değişimi: neyin, hangi değerden hangi değere.
class _Change extends StatelessWidget {
  const _Change({this.label, required this.from, required this.to});

  final String? label;
  final String? from;
  final String? to;

  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final hasLabel = label != null && label!.trim().isNotEmpty;
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 14, height: 1.35, color: colors.onSurface),
        children: [
          if (hasLabel)
            TextSpan(
              text: '${label!.trim()}  ',
              style: TextStyle(color: muted),
            ),
          TextSpan(
            text: _orDash(from),
            // Önceki değer boşsa üstü çizilecek bir şey de yoktur.
            style: from == null || from!.trim().isEmpty
                ? TextStyle(color: muted)
                : TextStyle(
                    color: muted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: muted,
                  ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.arrow_forward_rounded, size: 14, color: muted),
            ),
          ),
          TextSpan(
            text: _orDash(to),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      // Ekran okuyucu oku "sağ ok" diye değil, cümle gibi okusun.
      semanticsLabel:
          '${hasLabel ? '${label!.trim()}: ' : ''}${_orDash(from)} → ${_orDash(to)}',
    );
  }
}
