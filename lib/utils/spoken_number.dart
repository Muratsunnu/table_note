/// Konuşulan ya da yazıya dökülmüş bir sayıyı rakamla yazar; içinde sayı
/// yoksa null döner.
///
/// Ses tanıma, söylenen sayıyı her zaman rakama çevirmez: "değer yüz" diye
/// yazıp bırakabilir. Çevirdiğinde de dilin alışkanlığıyla yazar: Türkçede
/// otuz beş bin "35.000" olur. Sayısal bir hücreye bunlar olduğu gibi
/// girerse ya yazı kalır ya da 35 diye okunur; ikisi de toplamı sessizce
/// bozar.
///
/// Dönen değer uygulamanın hücrelerde beklediği biçimdedir: yalnızca
/// rakamlar, ondalık ayırıcı olarak nokta, başta isteğe bağlı eksi.
///
/// Örnekler (Türkçe): "yüz" → 100, "iki yüz elli" → 250,
/// "otuz beş bin" → 35000, "35 bin" → 35000, "35.000" → 35000,
/// "on iki virgül beş" → 12.5, "bir buçuk" → 1.5, "eksi on" → -10.
String? parseSpokenNumber(String text, {String languageCode = 'tr'}) {
  final english = languageCode == 'en';
  final tokens = _fold(text)
      // "twenty-five" iki sözcüktür; rakamın önündeki eksi ise işarettir.
      .replaceAllMapped(RegExp(r'([a-z])-([a-z])'), (m) => '${m[1]} ${m[2]}')
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList();

  var index = 0;
  var negative = false;
  // Sayıdan önceki sözcükler ("yaklaşık", "tam") atlanır.
  while (index < tokens.length && !_startsNumber(tokens, index, english)) {
    index++;
  }
  if (index >= tokens.length) return null;
  if (_signs.contains(tokens[index])) {
    negative = true;
    index++;
  }

  var total = 0;
  var current = 0;
  var any = false;
  var previousWasDigits = false;
  var fraction = '';

  // Tam kısım: rakamlar ve sözcükler birlikte ("2 bin 500", "iki yüz elli").
  while (index < tokens.length) {
    final token = tokens[index];
    final digits = _DigitToken.parse(token, english);
    if (digits != null) {
      // Arada çarpan olmadan art arda iki rakam, iki ayrı sayıdır.
      if (previousWasDigits) break;
      if (digits.negative) negative = true;
      current += digits.whole;
      any = true;
      index++;
      if (digits.fraction.isNotEmpty) {
        fraction = digits.fraction;
        break;
      }
      previousWasDigits = true;
      continue;
    }
    previousWasDigits = false;
    final unit = _units[token];
    if (unit != null) {
      current += unit;
      any = true;
      index++;
      continue;
    }
    if (_hundreds.contains(token)) {
      current = (current == 0 ? 1 : current) * 100;
      any = true;
      index++;
      continue;
    }
    final scale = _scales[token];
    if (scale != null) {
      total += (current == 0 ? 1 : current) * _pow10(scale);
      current = 0;
      any = true;
      index++;
      continue;
    }
    // "a hundred", "one hundred and five".
    if (english &&
        token == 'a' &&
        index + 1 < tokens.length &&
        (_hundreds.contains(tokens[index + 1]) ||
            _scales.containsKey(tokens[index + 1]))) {
      index++;
      continue;
    }
    if (any && _fillers.contains(token)) {
      index++;
      continue;
    }
    break;
  }
  var whole = total + current;

  // Tek başına "yarım".
  if (!any && index < tokens.length && _halves.contains(tokens[index])) {
    fraction = '5';
    any = true;
    index++;
  }
  if (!any) return null;

  // Ondalık kısım: "virgül beş", "nokta yirmi beş", "buçuk".
  if (fraction.isEmpty && index < tokens.length) {
    final token = tokens[index];
    if (_halves.contains(token)) {
      fraction = '5';
      index++;
    } else if (_separators.contains(token)) {
      final read = _readFraction(tokens, index + 1, english);
      if (read != null) {
        fraction = read.$1;
        index = read.$2;
      }
    }
  }

  // Ondalıktan sonra gelen çarpan: "bir buçuk milyon", "2,5 bin".
  if (fraction.isNotEmpty && index < tokens.length) {
    final power = _hundreds.contains(tokens[index])
        ? 2
        : _scales[tokens[index]];
    if (power != null) {
      final shifted = fraction.padRight(power, '0');
      whole = int.parse('$whole${shifted.substring(0, power)}');
      fraction = shifted.substring(power);
    }
  }

  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  final sign = negative && (whole != 0 || fraction.isNotEmpty) ? '-' : '';
  return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
}

/// Ayırıcıdan sonraki basamaklar. "sıfır beş" → "05", "yirmi beş" → "25".
(String, int)? _readFraction(List<String> tokens, int start, bool english) {
  final buffer = StringBuffer();
  var index = start;
  while (index < tokens.length) {
    final token = tokens[index];
    if (_zeros.contains(token)) {
      buffer.write('0');
      index++;
      continue;
    }
    final digits = _DigitToken.parse(token, english);
    if (digits != null && digits.fraction.isEmpty) {
      buffer.write(digits.raw);
      index++;
      break;
    }
    // Sözcükle söylenen basamaklar: "yirmi beş", "yüz yirmi beş".
    var value = 0;
    var any = false;
    while (index < tokens.length) {
      final unit = _units[tokens[index]];
      if (unit != null && unit != 0) {
        value += unit;
      } else if (_hundreds.contains(tokens[index])) {
        value = (value == 0 ? 1 : value) * 100;
      } else {
        break;
      }
      any = true;
      index++;
    }
    if (any) buffer.write(value);
    break;
  }
  return buffer.isEmpty ? null : (buffer.toString(), index);
}

bool _startsNumber(List<String> tokens, int index, bool english) {
  final token = tokens[index];
  if (_DigitToken.parse(token, english) != null) return true;
  if (_units.containsKey(token) ||
      _hundreds.contains(token) ||
      _scales.containsKey(token) ||
      _halves.contains(token)) {
    return true;
  }
  if (english && token == 'a' && index + 1 < tokens.length) {
    return _hundreds.contains(tokens[index + 1]) ||
        _scales.containsKey(tokens[index + 1]);
  }
  // İşaret ancak ardından sayı geliyorsa sayının başıdır.
  return _signs.contains(token) &&
      index + 1 < tokens.length &&
      !_signs.contains(tokens[index + 1]) &&
      _startsNumber(tokens, index + 1, english);
}

int _pow10(int power) {
  var value = 1;
  for (var i = 0; i < power; i++) {
    value *= 10;
  }
  return value;
}

/// Türkçe harfleri sadeleştirir ve sayıyla ilgisi olmayan işaretleri atar.
/// "İki" de "ıkı" da "iki" olur; sözlükler bu yazımla tutulur.
String _fold(String value) => value
    .toLowerCase()
    .replaceAll('̇', '')
    .replaceAll('ı', 'i')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[^a-z0-9.,-]'), ' ');

/// Rakamla yazılmış bir parça: "35", "35.000", "12,5", "100tl".
class _DigitToken {
  const _DigitToken(this.whole, this.fraction, this.raw, this.negative);

  final int whole;
  final String fraction;

  /// Ayırıcısız rakamlar; ondalık basamak olarak okunurken baştaki sıfır
  /// kaybolmasın diye saklanır ("05").
  final String raw;
  final bool negative;

  static _DigitToken? parse(String token, bool english) {
    final match = RegExp(r'^(-)?(\d[\d.,]*\d|\d)').firstMatch(token);
    if (match == null) return null;
    final negative = match.group(1) != null;
    final body = match.group(2)!;
    // Binlik ayırıcı dile göre değişir: Türkçede nokta, İngilizcede virgül.
    final thousands = english ? ',' : '.';
    final decimal = english ? '.' : ',';
    final grouped = RegExp(
      '^\\d{1,3}(?:${RegExp.escape(thousands)}\\d{3})+'
      '(?:${RegExp.escape(decimal)}(\\d+))?\$',
    ).firstMatch(body);
    if (grouped != null) {
      final whole = body.split(decimal).first.replaceAll(thousands, '');
      return _DigitToken(
        int.parse(whole),
        grouped.group(1) ?? '',
        whole,
        negative,
      );
    }
    final plain = RegExp(r'^(\d+)(?:[.,](\d+))?$').firstMatch(body);
    if (plain == null) return null;
    return _DigitToken(
      int.parse(plain.group(1)!),
      plain.group(2) ?? '',
      plain.group(1)!,
      negative,
    );
  }
}

const _signs = {'eksi', 'minus', '-'};
const _zeros = {'sifir', 'zero', 'oh', '0'};
const _halves = {'bucuk', 'yarim', 'half'};
const _separators = {'virgul', 'nokta', 'point', 'comma'};
const _fillers = {'ve', 'and'};
const _hundreds = {'yuz', 'hundred'};

/// Çarpan sözcükleri ve onun kaçıncı kuvveti oldukları.
const _scales = {
  'bin': 3,
  'milyon': 6,
  'milyar': 9,
  'thousand': 3,
  'million': 6,
  'billion': 9,
};

const _units = {
  'sifir': 0,
  'bir': 1,
  'iki': 2,
  'uc': 3,
  'dort': 4,
  'bes': 5,
  'alti': 6,
  'yedi': 7,
  'sekiz': 8,
  'dokuz': 9,
  'on': 10,
  'yirmi': 20,
  'otuz': 30,
  'kirk': 40,
  'elli': 50,
  'altmis': 60,
  'yetmis': 70,
  'seksen': 80,
  'doksan': 90,
  'zero': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};
