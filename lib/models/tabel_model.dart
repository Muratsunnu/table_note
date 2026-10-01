import '../utils/id_generator.dart';

// Sütun tipi enum
enum ColumnType {
  normal, // Manuel giriş
  constant, // Sabit değer (varsayılan gelir, değiştirilebilir)
  formula, // Formül (otomatik hesaplanır)
  date, // Tarih (bugünün tarihi otomatik gelir, değiştirilebilir)
  time, // Saat (şu anki saat otomatik gelir, değiştirilebilir)
  autoNumber, // Otomatik sıra numarası
}

class ColumnModel {
  String name;
  bool isNumeric;
  List<String> autoFillOptions;

  // Yeni alanlar
  ColumnType columnType;
  double? constantValue; // Sabit değer (columnType=constant ise)
  String? formula; // Formül (columnType=formula ise)
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
    final rawType = json['columnType'];
    final typeIndex = rawType is int ? rawType : int.tryParse('$rawType') ?? 0;
    final safeTypeIndex = typeIndex >= 0 && typeIndex < ColumnType.values.length
        ? typeIndex
        : 0;
    return ColumnModel(
      name: json['name']?.toString() ?? '',
      isNumeric: json['isNumeric'] ?? false,
      autoFillOptions: List<String>.from(json['autoFillOptions'] ?? []),
      columnType: ColumnType.values[safeTypeIndex],
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
  final String id;
  List<ColumnModel> columns;
  List<List<String>> rows;
  String tableName;
  final DateTime createdAt;
  DateTime updatedAt;

  /// One stable identity per row, in the same order as [rows]. Two people
  /// editing the same table need to agree on which row is which, and the
  /// activity log needs something to point at, so a row keeps its id for
  /// life — through sorting, reordering and other rows being deleted.
  ///
  /// Never assign to this or to [rows] directly; go through the mutators
  /// below so the two can never fall out of step.
  List<String> rowIds;

  TableModel({
    String? id,
    required this.columns,
    required this.rows,
    required this.tableName,
    List<String>? rowIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id?.isNotEmpty == true ? id! : IdGenerator.uuidV4(),
       rowIds = _alignIds(rowIds, rows.length),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  /// Saves written before rows had identities, and any payload whose ids do
  /// not line up with its rows, are given fresh ones rather than rejected.
  static List<String> _alignIds(List<String>? ids, int rowCount) {
    final aligned = <String>[
      for (final id in ids ?? const <String>[])
        if (id.trim().isNotEmpty) id.trim(),
    ];
    if (aligned.length > rowCount)
      aligned.removeRange(rowCount, aligned.length);
    while (aligned.length < rowCount) {
      aligned.add(IdGenerator.uuidV4());
    }
    // A duplicate id would make two rows indistinguishable to the merge.
    final seen = <String>{};
    for (var i = 0; i < aligned.length; i++) {
      if (!seen.add(aligned[i])) aligned[i] = IdGenerator.uuidV4();
    }
    return aligned;
  }

  /// The id of the row at [index], or null when there is no such row.
  /// Bir sira sutununun bir sonraki degeri: var olanlarin en buyugu + 1.
  ///
  /// Satir SAYISI + 1 degil. Silinen satirin numarasi geri gelmedigi icin
  /// o hesap cakisma uretiyordu: 5 satirlik tablodan 2'yi silip yeni kayit
  /// eklemek yeniden 5 veriyordu. Ortak tabloda ayni hata iki kat agir;
  /// karsi tarafin ekledigi satiri henuz gormeyen kullanici da ayni
  /// numarayi uretirdi.
  int nextAutoNumber(int columnIndex) {
    var highest = 0;
    for (final row in rows) {
      if (columnIndex < 0 || columnIndex >= row.length) continue;
      final value = int.tryParse(row[columnIndex].trim());
      if (value != null && value > highest) highest = value;
    }
    return highest + 1;
  }

  String? rowIdAt(int index) =>
      index >= 0 && index < rowIds.length ? rowIds[index] : null;

  int indexOfRowId(String rowId) => rowIds.indexOf(rowId);

  void appendRow(List<String> values, {String? rowId}) {
    rows.add(List<String>.from(values));
    rowIds.add(
      rowId?.trim().isNotEmpty == true ? rowId!.trim() : IdGenerator.uuidV4(),
    );
  }

  /// Replaces a row's values while it keeps its identity.
  void replaceRow(int index, List<String> values) {
    if (index < 0 || index >= rows.length) return;
    rows[index] = List<String>.from(values);
  }

  void removeRowAt(int index) {
    if (index < 0 || index >= rows.length) return;
    rows.removeAt(index);
    if (index < rowIds.length) rowIds.removeAt(index);
  }

  /// Reorders or rewrites every row at once. [ids] keeps the identities of
  /// rows that survived; anything missing gets a new one.
  void setRows(List<List<String>> newRows, {List<String>? ids}) {
    rows = [for (final row in newRows) List<String>.from(row)];
    rowIds = _alignIds(ids, rows.length);
  }

  // Kolay erişim
  List<String> get columnNames => columns.map((c) => c.name).toList();

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'columns': columns.map((c) => c.toJson()).toList(),
      'rows': rows,
      'rowIds': rowIds,
      'tableName': tableName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TableModel.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return TableModel(
      columns: (json['columns'] as List)
          .map((col) => ColumnModel.fromJson(Map<String, dynamic>.from(col)))
          .toList(),
      rows: List<List<String>>.from(
        json['rows'].map((row) => List<String>.from(row)),
      ),
      tableName: json['tableName']?.toString() ?? '',
      id: json['id']?.toString(),
      rowIds: json['rowIds'] == null
          ? null
          : List<String>.from(
              (json['rowIds'] as List).map((id) => id.toString()),
            ),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

class TemplateModel {
  final String id;
  String templateName;
  List<ColumnModel> columns;
  final DateTime createdAt;
  DateTime updatedAt;

  TemplateModel({
    String? id,
    required this.templateName,
    required this.columns,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id?.isNotEmpty == true ? id! : IdGenerator.uuidV4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateName': templateName,
      'columns': columns.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return TemplateModel(
      id: json['id']?.toString(),
      templateName: json['templateName']?.toString() ?? '',
      columns: (json['columns'] as List)
          .map((col) => ColumnModel.fromJson(Map<String, dynamic>.from(col)))
          .toList(),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}
