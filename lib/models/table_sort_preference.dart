import 'tabel_model.dart';

/// Bir tablonun kalıcı sıralama tercihi. Tablo verisinin parçası değildir;
/// sıralamak tabloyu "değişmiş" saymaz ve bulutla senkronlanmaz.
///
/// Sütun konumuyla değil adıyla tanınır; aynı adı taşıyan sütunlar arasında
/// kaçıncı olduğu da tutulur. Böylece sütunlar yer değiştirince sıralama doğru
/// sütunda kalır, sütun silinince ya da adı değişince yanlış sütuna kaymaz.
class TableSortPreference {
  final String column;
  final int occurrence;
  final bool ascending;

  const TableSortPreference({
    required this.column,
    required this.occurrence,
    required this.ascending,
  });

  factory TableSortPreference.forColumn(
    List<ColumnModel> columns,
    int index, {
    required bool ascending,
  }) {
    final name = columns[index].name;
    var occurrence = 0;
    for (var i = 0; i < index; i++) {
      if (columns[i].name == name) occurrence++;
    }
    return TableSortPreference(
      column: name,
      occurrence: occurrence,
      ascending: ascending,
    );
  }

  /// Sütunun bugünkü konumu; sütun artık yoksa null.
  int? resolve(List<ColumnModel> columns) {
    var seen = 0;
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].name != column) continue;
      if (seen == occurrence) return i;
      seen++;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'column': column,
    'occurrence': occurrence,
    'ascending': ascending,
  };

  /// Bozuk ya da eski biçimdeki kayıtlar yok sayılır.
  static TableSortPreference? fromJson(Object? json) {
    if (json is! Map) return null;
    final column = json['column'];
    final occurrence = json['occurrence'];
    final ascending = json['ascending'];
    if (column is! String || occurrence is! int || ascending is! bool) {
      return null;
    }
    if (occurrence < 0) return null;
    return TableSortPreference(
      column: column,
      occurrence: occurrence,
      ascending: ascending,
    );
  }
}
