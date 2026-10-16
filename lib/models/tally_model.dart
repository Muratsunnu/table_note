import '../utils/id_generator.dart';

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
  final String id;
  String name;
  Map<String, String> entries; // key: "2024-01-15", value: durum kodu

  TallyItemModel({String? id, required this.name, Map<String, String>? entries})
    : id = id?.isNotEmpty == true ? id! : IdGenerator.uuidV4(),
      entries = entries ?? {};

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'entries': entries};

  factory TallyItemModel.fromJson(Map<String, dynamic> json) => TallyItemModel(
    id: json['id']?.toString(),
    name: json['name'] ?? '',
    entries: Map<String, String>.from(json['entries'] ?? {}),
  );

  Map<String, int> getSummary(
    DateTime startDate,
    DateTime endDate,
    List<TallyStatus> statuses,
  ) {
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
  final String id;
  String tableName;
  DateTime startDate;
  DateTime endDate;
  List<TallyStatus> statuses;
  List<TallyItemModel> items;
  final DateTime createdAt;
  DateTime updatedAt;

  TallyTableModel({
    String? id,
    required this.tableName,
    required this.startDate,
    required this.endDate,
    required this.statuses,
    List<TallyItemModel>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id?.isNotEmpty == true ? id! : IdGenerator.uuidV4(),
       items = items ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

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
    'id': id,
    'tableName': tableName,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'statuses': statuses.map((s) => s.toJson()).toList(),
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TallyTableModel.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return TallyTableModel(
      id: json['id']?.toString(),
      tableName: json['tableName'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      statuses: (json['statuses'] as List)
          .map((s) => TallyStatus.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      items: (json['items'] as List?)
          ?.map((i) => TallyItemModel.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

/// Çetele şablonu — durumlar ve öğe adları (giriş verisi yok)
class TallyTemplateModel {
  final String id;
  String templateName;
  List<TallyStatus> statuses;
  List<String> itemNames;
  final DateTime createdAt;
  DateTime updatedAt;

  TallyTemplateModel({
    String? id,
    required this.templateName,
    required this.statuses,
    List<String>? itemNames,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id?.isNotEmpty == true ? id! : IdGenerator.uuidV4(),
       itemNames = itemNames ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'templateName': templateName,
    'statuses': statuses.map((s) => s.toJson()).toList(),
    'itemNames': itemNames,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TallyTemplateModel.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return TallyTemplateModel(
      id: json['id']?.toString(),
      templateName: json['templateName'] ?? '',
      statuses: (json['statuses'] as List? ?? [])
          .map((s) => TallyStatus.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      itemNames: List<String>.from(json['itemNames'] ?? const []),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}
