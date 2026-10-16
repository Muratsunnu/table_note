import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/tally_provider.dart';

class TallyOverallSummaryDialog extends StatelessWidget {
  const TallyOverallSummaryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TallyProvider>();
    final table = provider.currentTable!;
    final summary = provider.getOverallSummary();
    final totalCells = table.items.length * table.dayCount;
    final filled = summary.values.fold<int>(0, (sum, count) => sum + count);
    final empty = totalCells - filled;
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.overallSummary),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width * .86,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${table.items.length} ${loc.tallyItems} · ${table.dayCount} ${loc.tallyDays}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ...table.statuses.map((status) {
                final count = summary[status.code] ?? 0;
                final percentage = totalCells == 0 ? 0.0 : count / totalCells;
                final color = Color(status.colorValue);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count · %${(percentage * 100).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 7,
                          backgroundColor: color.withValues(alpha: .12),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(loc.tallyEmpty)),
                    Text(
                      '$empty',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.close),
        ),
      ],
    );
  }
}
