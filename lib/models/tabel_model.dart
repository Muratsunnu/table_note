class TableModel {
  List<String> columns;
  List<List<String>> rows;
  String tableName;

  TableModel({
    required this.columns,
    required this.rows,
    required this.tableName,
  });

  Map<String, dynamic> toJson() {
    return {
      'columns': columns,
      'rows': rows,
      'tableName': tableName,
    };
  }

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      columns: List<String>.from(json['columns']),
      rows: List<List<String>>.from(
        json['rows'].map((row) => List<String>.from(row)),
      ),
      tableName: json['tableName'],
    );
  }
}
