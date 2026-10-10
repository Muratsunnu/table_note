import '../models/tabel_model.dart';
import '../utils/spoken_number.dart';

/// Konuşmadan çıkarılan hücre değerleri.
class VoiceRowResult {
  const VoiceRowResult(this.values, this.unreadNumbers);

  /// Sütun sırasına göre doldurulacak değerler.
  final Map<int, String> values;

  /// Sayısal olduğu halde söylenenin sayıya çevrilemediği sütunlar. Bunlara
  /// değer yazılmaz: sayısal bir hücreye yazı girerse toplam sessizce bozulur.
  final Set<int> unreadNumbers;
}

class VoiceRowParser {
  const VoiceRowParser();

  VoiceRowResult parse(
    String transcript,
    List<ColumnModel> columns, {
    String languageCode = 'tr',
  }) {
    final text = _normalize(transcript, trim: false);
    final matches = <_ColumnMatch>[];
    for (var index = 0; index < columns.length; index++) {
      if (!columns[index].isNormal) continue;
      for (final marker in _markers(columns[index])) {
        final match = RegExp(
          '(?:^| )${RegExp.escape(marker)}(?: |\$)',
        ).firstMatch(text);
        if (match != null) {
          matches.add(_ColumnMatch(index, match.start, match.end));
          break;
        }
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    final values = <int, String>{};
    final unreadNumbers = <int>{};
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : text.length;
      var value = transcript
          .substring(match.end, end)
          .trim()
          .replaceAll(RegExp(r'^[,.: -]+|[,.: -]+$'), '');
      if (columns[match.columnIndex].isNumeric) {
        // Ses tanıma sayıyı sözcükle ("yüz") ya da dilin alışkanlığıyla
        // ("35.000") yazabilir; hücreye yalnızca rakam girer.
        final number = parseSpokenNumber(value, languageCode: languageCode);
        if (number == null) {
          if (value.isNotEmpty) unreadNumbers.add(match.columnIndex);
          continue;
        }
        value = number;
      }
      if (value.isNotEmpty) values[match.columnIndex] = value;
    }
    return VoiceRowResult(values, unreadNumbers);
  }

  List<String> _markers(ColumnModel column) {
    final name = _normalize(column.name);
    final markers = <String>{name};
    if (_containsAny(name, ['nereden', 'cikis', 'yukleme yeri'])) {
      markers.addAll(['nereden', 'cikis', 'yukleme yeri']);
    }
    if (_containsAny(name, ['nereye', 'varis', 'teslim yeri'])) {
      markers.addAll(['nereye', 'varis', 'teslim yeri']);
    }
    if (_containsAny(name, ['yuk', 'mal', 'urun', 'malzeme'])) {
      markers.addAll(['yuk', 'mal', 'urun', 'malzeme']);
    }
    if (_containsAny(name, ['ton', 'kilo', 'agirlik', 'miktar'])) {
      markers.addAll(['ton', 'kilo', 'agirlik', 'miktar']);
    }
    if (_containsAny(name, ['ucret', 'fiyat', 'tutar'])) {
      markers.addAll(['ucret', 'fiyat', 'tutar']);
    }
    return markers.where((marker) => marker.isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  bool _containsAny(String value, List<String> candidates) =>
      candidates.any(value.contains);

  String _normalize(String value, {bool trim = true}) {
    final normalized = value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9.,:-]'), ' ');
    return trim ? normalized.trim() : normalized;
  }
}

class _ColumnMatch {
  final int columnIndex;
  final int start;
  final int end;

  const _ColumnMatch(this.columnIndex, this.start, this.end);
}
