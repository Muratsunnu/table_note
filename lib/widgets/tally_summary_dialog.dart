import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/tally_provider.dart';
import '../theme/app_theme.dart';

class TallySummaryDialog extends StatelessWidget {
  final int itemIndex;
  const TallySummaryDialog({Key? key, required this.itemIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Consumer<TallyProvider>(
      builder: (context, provider, _) {
        final table = provider.currentTable;
        if (table == null || itemIndex >= table.items.length) {
          return AlertDialog(
            title: Text(loc.tallySummary),
            content: Text(loc.error),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.close))],
          );
        }

        final item = table.items[itemIndex];
        final summary = provider.getItemSummary(itemIndex);
        final totalDays = table.dayCount;
        final filledDays = summary.values.fold<int>(0, (a, b) => a + b);
        final emptyDays = totalDays - filledDays;

        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(item.name, style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tarih aralığı
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${table.startDate.day}/${table.startDate.month}/${table.startDate.year}'
                        ' - ${table.endDate.day}/${table.endDate.month}/${table.endDate.year}'
                        '  ($totalDays ${loc.tallyDays})',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Durum istatistikleri
                ...table.statuses.map((status) {
                  final count = summary[status.code] ?? 0;
                  final percentage = totalDays > 0 ? (count / totalDays * 100) : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(status.colorValue).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(status.colorValue).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: Color(status.colorValue), borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text(status.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(status.label, style: TextStyle(fontWeight: FontWeight.w600, color: Color(status.colorValue))),
                              const SizedBox(height: 4),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation(Color(status.colorValue)),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(status.colorValue))),
                            Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Color(status.colorValue))),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                // Boş günler
                if (emptyDays > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(loc.tallyEmpty, style: const TextStyle(color: AppTheme.textSecondary))),
                        Text('$emptyDays', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.close)),
          ],
        );
      },
    );
  }
}
