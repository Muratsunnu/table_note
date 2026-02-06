import '../models/tabel_model.dart';

/// Formül hesaplama servisi
/// Desteklenen işlemler: +, -, *, /, %
/// Formül formatı: {SütunAdı} işlem {SütunAdı} veya {SütunAdı} işlem sayı
/// Yüzde formatı: {SütunAdı}%sayı (örn: {Fiyat}%18 = Fiyatın %18'i)
class FormulaService {
  
  /// Formülü hesapla
  /// [formula] - Hesaplanacak formül (örn: "{Kg}*{Birim Fiyat}")
  /// [rowData] - Satırdaki veriler
  /// [columns] - Sütun tanımları
  /// Returns: Hesaplanan değer veya null (hata durumunda)
  static double? calculate(String? formula, List<String> rowData, List<ColumnModel> columns) {
    // Null veya boş formül kontrolü
    if (formula == null || formula.trim().isEmpty) {
      return null;
    }
    
    try {
      String processedFormula = formula;
      
      // Önce formüldeki sütun referanslarındaki boşlukları temizle
      // {birim fiyatı } → {birim fiyatı}
      // { kilo} → {kilo}
      processedFormula = _cleanFormulaSpaces(processedFormula);
      
      // Sütun referanslarını değerlerle değiştir
      for (int i = 0; i < columns.length; i++) {
        final columnName = columns[i].name.trim(); // Sütun adını da trim'le
        if (columnName.isEmpty) continue;
        
        final placeholder = '{$columnName}';
        
        if (processedFormula.contains(placeholder)) {
          final value = i < rowData.length ? rowData[i] : '0';
          final numValue = double.tryParse(value) ?? 0;
          processedFormula = processedFormula.replaceAll(placeholder, numValue.toString());
        }
      }
      
      // Formülü hesapla
      return _evaluateExpression(processedFormula);
    } catch (e) {
      print('Formül hesaplama hatası: $e');
      return null;
    }
  }
  
  /// Formüldeki sütun referanslarının içindeki gereksiz boşlukları temizle
  /// {birim fiyatı } → {birim fiyatı}
  /// { kilo } → {kilo}
  static String _cleanFormulaSpaces(String formula) {
    // {xxx} pattern'ini bul ve içindeki boşlukları temizle
    final regex = RegExp(r'\{([^}]+)\}');
    return formula.replaceAllMapped(regex, (match) {
      final innerText = match.group(1)!.trim();
      return '{$innerText}';
    });
  }
  
  /// Matematiksel ifadeyi hesapla
  static double? _evaluateExpression(String expression) {
    try {
      // Boşlukları temizle
      expression = expression.replaceAll(' ', '');
      
      // Boş ifade kontrolü
      if (expression.isEmpty) {
        return 0;
      }
      
      // Önce yüzde işlemlerini hesapla
      expression = _processPercentage(expression);
      
      // Parantezleri işle (basit seviye)
      while (expression.contains('(')) {
        final start = expression.lastIndexOf('(');
        final end = expression.indexOf(')', start);
        if (end == -1) break;
        
        final inner = expression.substring(start + 1, end);
        final result = _evaluateSimpleExpression(inner);
        expression = expression.substring(0, start) + result.toString() + expression.substring(end + 1);
      }
      
      return _evaluateSimpleExpression(expression);
    } catch (e) {
      print('İfade hesaplama hatası: $e');
      return null;
    }
  }
  
  /// Yüzde işlemlerini hesapla
  /// Örn: "1000%18" → "180" (1000'in %18'i)
  static String _processPercentage(String expression) {
    final percentRegex = RegExp(r'(\d+\.?\d*)%(\d+\.?\d*)');
    
    while (percentRegex.hasMatch(expression)) {
      expression = expression.replaceAllMapped(percentRegex, (match) {
        final base = double.parse(match.group(1)!);
        final percent = double.parse(match.group(2)!);
        final result = base * percent / 100;
        return result.toString();
      });
    }
    
    return expression;
  }
  
  /// Basit matematiksel ifadeyi hesapla (parantez olmadan)
  static double _evaluateSimpleExpression(String expression) {
    // Sayıları ve operatörleri ayır
    final tokens = _tokenize(expression);
    
    if (tokens.isEmpty) return 0;
    
    // Tek eleman varsa direkt döndür
    if (tokens.length == 1 && tokens[0] is double) {
      return tokens[0] as double;
    }
    
    // Önce çarpma ve bölme
    List<dynamic> processed = [];
    int i = 0;
    
    while (i < tokens.length) {
      if (tokens[i] == '*' || tokens[i] == '/') {
        if (processed.isEmpty || i + 1 >= tokens.length) {
          i++;
          continue;
        }
        
        final left = processed.removeLast() as double;
        final right = tokens[i + 1] as double;
        
        if (tokens[i] == '*') {
          processed.add(left * right);
        } else {
          processed.add(right != 0 ? left / right : 0.0);
        }
        i += 2;
      } else {
        processed.add(tokens[i]);
        i++;
      }
    }
    
    if (processed.isEmpty) return 0;
    
    // Sonra toplama ve çıkarma
    double result = processed[0] as double;
    i = 1;
    
    while (i < processed.length - 1) {
      final op = processed[i] as String;
      final right = processed[i + 1] as double;
      
      if (op == '+') {
        result += right;
      } else if (op == '-') {
        result -= right;
      }
      i += 2;
    }
    
    return result;
  }
  
  /// İfadeyi token'lara ayır
  static List<dynamic> _tokenize(String expression) {
    List<dynamic> tokens = [];
    String currentNumber = '';
    bool isNegative = false;
    
    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];
      
      if (char == '-' && (i == 0 || '+-*/'.contains(expression[i - 1]))) {
        // Negatif sayı başlangıcı
        isNegative = true;
      } else if ('0123456789.'.contains(char)) {
        currentNumber += char;
      } else if ('+-*/'.contains(char)) {
        if (currentNumber.isNotEmpty) {
          double num = double.parse(currentNumber);
          if (isNegative) {
            num = -num;
            isNegative = false;
          }
          tokens.add(num);
          currentNumber = '';
        }
        tokens.add(char);
      }
    }
    
    // Son sayıyı ekle
    if (currentNumber.isNotEmpty) {
      double num = double.parse(currentNumber);
      if (isNegative) {
        num = -num;
      }
      tokens.add(num);
    }
    
    return tokens;
  }
  
  /// Formül geçerli mi kontrol et
  static bool isValidFormula(String formula, List<ColumnModel> columns) {
    try {
      // Sütun referanslarını kontrol et
      final columnPattern = RegExp(r'\{([^}]+)\}');
      final matches = columnPattern.allMatches(formula);
      
      for (final match in matches) {
        final columnName = match.group(1);
        final exists = columns.any((c) => c.name == columnName);
        if (!exists) {
          return false;
        }
      }
      
      // Test hesaplaması yap
      final testData = List.generate(columns.length, (i) => '1');
      final result = calculate(formula, testData, columns);
      
      return result != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Formülde kullanılan sütunları bul
  static List<String> getReferencedColumns(String formula) {
    final columnPattern = RegExp(r'\{([^}]+)\}');
    final matches = columnPattern.allMatches(formula);
    return matches.map((m) => m.group(1)!).toList();
  }
  
  /// Formülü okunabilir formata çevir
  static String formatFormula(String formula) {
    return formula
        .replaceAll('*', ' × ')
        .replaceAll('/', ' ÷ ')
        .replaceAll('+', ' + ')
        .replaceAll('-', ' - ')
        .replaceAll('%', ' % ');
  }
}