// Sütun tipi enum
enum ColumnType {
  normal,     // Manuel giriş
  constant,   // Sabit değer (varsayılan gelir, değiştirilebilir)
  formula,    // Formül (otomatik hesaplanır)
  date,       // Tarih (bugünün tarihi otomatik gelir, değiştirilebilir)
  time,       // Saat (şu anki saat otomatik gelir, değiştirilebilir)
  autoNumber, // Otomatik sıra numarası
}

class ColumnModel {
  String name;
  bool isNumeric;
  List<String> autoFillOptions;
  
  // Yeni alanlar
  ColumnType columnType;
  double? constantValue;  // Sabit değer (columnType=constant ise)
  String? formula;        // Formül (columnType=formula ise)
                          // Örn: "{Kg}*{Birim Fiyat}" veya "{Fiyat}%18"

  ColumnModel({
    required this.name,
    this.isNumeric = false,
    this.autoFillOptions = const [],
    this.columnType = ColumnType.normal,
    this.constantValue,
    this.formula,
  });

  // Sütun tipi kontrolü
  bool get isNormal => columnType == ColumnType.normal;
  bool get isConstant => columnType == ColumnType.constant;
  bool get isFormula => columnType == ColumnType.formula;
  bool get isDate => columnType == ColumnType.date;
  bool get isTime => columnType == ColumnType.time;
  bool get isAutoNumber => columnType == ColumnType.autoNumber;
  
  // Formül sütunu her zaman sayısaldır
  bool get isEffectivelyNumeric => isNumeric || isFormula || isConstant;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isNumeric': isNumeric,
      'autoFillOptions': autoFillOptions,
      'columnType': columnType.index,
      'constantValue': constantValue,
      'formula': formula,
    };
  }

  factory ColumnModel.fromJson(Map<String, dynamic> json) {
    return ColumnModel(
      name: json['name'],
      isNumeric: json['isNumeric'] ?? false,
      autoFillOptions: List<String>.from(json['autoFillOptions'] ?? []),
      columnType: ColumnType.values[json['columnType'] ?? 0],
      constantValue: json['constantValue']?.toDouble(),
      formula: json['formula'],
    );
  }
  
  // Kopyalama metodu
  ColumnModel copyWith({
    String? name,
    bool? isNumeric,
    List<String>? autoFillOptions,
    ColumnType? columnType,
    double? constantValue,
    String? formula,
  }) {
    return ColumnModel(
      name: name ?? this.name,
      isNumeric: isNumeric ?? this.isNumeric,
      autoFillOptions: autoFillOptions ?? List.from(this.autoFillOptions),
      columnType: columnType ?? this.columnType,
      constantValue: constantValue ?? this.constantValue,
      formula: formula ?? this.formula,
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
    required this.tableName,
    required String id,
    required String name,
    required DateTime createdAt,
  });

  // Kolay erişim
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
      tableName: json['tableName'],
      id: '',
      name: '',
      createdAt: DateTime.now(),
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