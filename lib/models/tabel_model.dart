class ColumnModel {
  String name;
  bool isNumeric;
  List<String> autoFillOptions;

  ColumnModel({
    required this.name,
    this.isNumeric = false,
    this.autoFillOptions = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isNumeric': isNumeric,
      'autoFillOptions': autoFillOptions,
    };
  }

  factory ColumnModel.fromJson(Map<String, dynamic> json) {
    return ColumnModel(
      name: json['name'],
      isNumeric: json['isNumeric'] ?? false,
      autoFillOptions: List<String>.from(json['autoFillOptions'] ?? []),
    );
  }
}

class TableModel {
  List<ColumnModel> columns;
  List<List<String>> rows;
  String tableName;

  TableModel({
    required this.columns,
    required this.rows,
    required this.tableName, required String id, required String name, required DateTime createdAt,
  });

  // Sadece kolay erişim için
  List<String> get columnNames => columns.map((c) => c.name).toList();

  Map<String, dynamic> toJson() {
    return {
      'columns': columns.map((c) => c.toJson()).toList(),
      'rows': rows,
      'tableName': tableName,
    };
  }

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      columns: (json['columns'] as List)
          .map((col) => ColumnModel.fromJson(col))
          .toList(),
      rows: List<List<String>>.from(
        json['rows'].map((row) => List<String>.from(row)),
      ),
      tableName: json['tableName'], id: '', name: '', createdAt:  DateTime.now(),
    );
  }
}

class TemplateModel {
  String templateName;
  List<ColumnModel> columns;

  TemplateModel({
    required this.templateName,
    required this.columns,
  });

  Map<String, dynamic> toJson() {
    return {
      'templateName': templateName,
      'columns': columns.map((c) => c.toJson()).toList(),
    };
  }

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      templateName: json['templateName'],
      columns: (json['columns'] as List)
          .map((col) => ColumnModel.fromJson(col))
          .toList(),
    );
  }
}