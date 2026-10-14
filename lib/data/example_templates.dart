import '../models/tabel_model.dart';

/// Uygulamayla birlikte gelen hazır örnekler. Kullanıcının kendi şablonları
/// gibi kullanılır: dokunulur, ad verilir, tablo açılır. Cihaza yazılmazlar;
/// bu yüzden ücretsiz şablon sınırına sayılmaz, silinmez ve uygulamanın
/// diliyle birlikte değişirler.
List<TemplateModel> exampleTemplates(String languageCode) {
  final tr = languageCode != 'en';
  ColumnModel text(String a, String b) => ColumnModel(name: tr ? a : b);
  ColumnModel number(String a, String b) =>
      ColumnModel(name: tr ? a : b, isNumeric: true);
  ColumnModel date(String a, String b) =>
      ColumnModel(name: tr ? a : b, columnType: ColumnType.date);
  TemplateModel example(String id, String a, String b, List<ColumnModel> c) =>
      TemplateModel(id: 'example-$id', templateName: tr ? a : b, columns: c);

  return [
    example('income', 'Gelir gider', 'Income and expenses', [
      date('tarih', 'date'),
      text('açıklama', 'note'),
      number('gelir', 'income'),
      number('gider', 'expense'),
    ]),
    example('debts', 'Borç alacak', 'Money owed', [
      text('kişi', 'person'),
      date('tarih', 'date'),
      number('verilen', 'lent'),
      number('alınan', 'received'),
    ]),
    example('sales', 'Satış kaydı', 'Sales log', [
      date('tarih', 'date'),
      text('müşteri', 'customer'),
      text('ürün', 'product'),
      number('adet', 'qty'),
      number('birim fiyat', 'unit price'),
      ColumnModel(
        name: tr ? 'tutar' : 'total',
        columnType: ColumnType.formula,
        formula: tr ? '{adet}*{birim fiyat}' : '{qty}*{unit price}',
      ),
    ]),
    example('stock', 'Stok sayımı', 'Stock count', [
      text('ürün', 'product'),
      text('raf', 'shelf'),
      number('adet', 'count'),
    ]),
    example('deliveries', 'Sevkiyat', 'Deliveries', [
      date('tarih', 'date'),
      text('plaka', 'plate'),
      text('yükleme', 'pickup'),
      number('kilo', 'weight'),
      number('navlun', 'freight'),
    ]),
    example('customers', 'Müşteri listesi', 'Customer list', [
      ColumnModel(name: tr ? 'sıra' : 'no', columnType: ColumnType.autoNumber),
      text('ad soyad', 'name'),
      text('telefon', 'phone'),
      text('not', 'note'),
    ]),
    example('todo', 'Yapılacaklar', 'To-do list', [
      text('iş', 'task'),
      date('tarih', 'date'),
      text('durum', 'status'),
    ]),
  ];
}
