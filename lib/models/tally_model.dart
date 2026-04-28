/// Çetele tablosu durum tanımı
class TallyStatus {
  String code;
  String label;
  int colorValue;

  TallyStatus({
    required this.code,
    required this.label,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'colorValue': colorValue,
  };

  factory TallyStatus.fromJson(Map<String, dynamic> json) => TallyStatus(
    code: json['code'] ?? '',
    label: json['label'] ?? '',
    colorValue: json['colorValue'] ?? 0xFF4CAF50,
  );

  TallyStatus copyWith({String? code, String? label, int? colorValue}) =>
      TallyStatus(
        code: code ?? this.code,
        label: label ?? this.label,
        colorValue: colorValue ?? this.colorValue,
      );
}

/// Çetele tablosundaki bir öğe (satır)
class TallyItemModel {
  String name;
  Map<String, String> entries; // key: "2024-01-15", value: durum kodu

  TallyItemModel({
    required this.name,
    Map<String, String>? entries,
  }) : entries = entries ?? {};

  Map<String, dynamic> toJson() => {
    'name': name,
    'entries': entries,
  };

  factory TallyItemModel.fromJson(Map<String, dynamic> json) => TallyItemModel(
    name: json['name'] ?? '',
    entries: Map<String, String>.from(json['entries'] ?? {}),
  );

  Map<String, int> getSummary(DateTime startDate, DateTime endDate, List<TallyStatus> statuses) {
    final summary = <String, int>{};
    for (final status in statuses) {
      summary[status.code] = 0;
    }
    DateTime current = startDate;
    while (!current.isAfter(endDate)) {
      final key = TallyTableModel.dateKey(current);
      final value = entries[key];
      if (value != null && summary.containsKey(value)) {
        summary[value] = summary[value]! + 1;
      }
      current = current.add(const Duration(days: 1));
    }
    return summary;
  }
}

/// Çetele tablosu ana modeli
class TallyTableModel {
  String tableName;
  DateTime startDate;
  DateTime endDate;
  List<TallyStatus> statuses;
  List<TallyItemModel> items;

  TallyTableModel({
    required this.tableName,
    required this.startDate,
    required this.endDate,
    required this.statuses,
    List<TallyItemModel>? items,
  }) : items = items ?? [];

  int get dayCount => endDate.difference(startDate).inDays + 1;

  List<DateTime> get allDays {
    final days = <DateTime>[];
    DateTime current = startDate;
    while (!current.isAfter(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<String> get statusCodes => statuses.map((s) => s.code).toList();

  TallyStatus? getStatusByCode(String code) {
    try {
      return statuses.firstWhere((s) => s.code == code);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'tableName': tableName,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'statuses': statuses.map((s) => s.toJson()).toList(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory TallyTableModel.fromJson(Map<String, dynamic> json) => TallyTableModel(
    tableName: json['tableName'] ?? '',
    startDate: DateTime.parse(json['startDate']),
    endDate: DateTime.parse(json['endDate']),
    statuses: (json['statuses'] as List).map((s) => TallyStatus.fromJson(s)).toList(),
    items: (json['items'] as List?)?.map((i) => TallyItemModel.fromJson(i)).toList(),
  );
}
