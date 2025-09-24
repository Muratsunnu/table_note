import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';

class ColumnSumsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        if (!provider.hasTables) return SizedBox();
        
        final sums = provider.calculateColumnSums();
        
        if (sums.isEmpty) return SizedBox();
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate, color: Colors.green[700], size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Sütun Toplamları',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: sums.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${entry.value.toStringAsFixed(2)}'),
                    backgroundColor: Colors.green[100],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}