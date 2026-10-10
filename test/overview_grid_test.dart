import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/overview_grid.dart';
import 'package:table_note/utils/number_display.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/widgets/grid_overview_screen.dart';

TableModel _trips() => TableModel(
  id: 'trips',
  tableName: 'seferler',
  columns: [
    ColumnModel(
      name: 'sıra',
      isNumeric: true,
      columnType: ColumnType.autoNumber,
    ),
    ColumnModel(name: 'nereden'),
    ColumnModel(name: 'kilosu', isNumeric: true),
    ColumnModel(
      name: 'birim',
      isNumeric: true,
      columnType: ColumnType.constant,
    ),
  ],
  rows: [
    ['1', 'konya', '35000', '5'],
    ['2', 'ızmır', '12000', '5'],
    ['3', 'karaman'],
  ],
);

TallyTableModel _attendance() => TallyTableModel(
  tableName: 'Yoklama',
  startDate: DateTime(2026, 9, 1),
  endDate: DateTime(2026, 9, 3),
  statuses: [
    TallyStatus(code: 'V', label: 'Var', colorValue: 0xFF2E7D32),
    TallyStatus(code: 'Y', label: 'Yok', colorValue: 0xFFC62828),
  ],
  items: [
    TallyItemModel(
      name: 'muslera',
      entries: {
        '2026-09-01': 'V',
        '2026-09-02': 'Y',
        '2026-09-03': 'V',
        // Outside the range: never counted, never drawn.
        '2026-08-31': 'Y',
      },
    ),
    TallyItemModel(
      name: 'icardi',
      // "X" belonged to a status that has since been deleted.
      entries: {'2026-09-01': 'Y', '2026-09-02': 'X'},
    ),
  ],
);

List<String> _texts(List<OverviewCell> cells) =>
    cells.map((cell) => cell.text).toList();

void main() {
  group('tablo genel bakışı', () {
    test('verilen sırayı izler, tüm hücreleri içerir', () {
      final grid = buildTableOverview(_trips(), [1, 2, 0], language: 'tr');
      expect(_texts(grid.header), ['sıra', 'nereden', 'kilosu', 'birim']);
      expect(grid.rows.map((row) => row[1].text), [
        'ızmır',
        'karaman',
        'konya',
      ]);
      // A short row is padded with empty cells rather than dropped.
      expect(_texts(grid.rows[1]), ['3', 'karaman', '', '']);
      expect(grid.frozenColumns, 1);
    });

    test('toplam satırı uygulamadaki kuralla ve binlik ayraçla', () {
      final tr = buildTableOverview(_trips(), [0, 1, 2], language: 'tr');
      // Row numbers and constants are not totalled, as in "Toplamlar".
      expect(_texts(tr.footer!), ['Toplam', '', '47.000', '']);
      final en = buildTableOverview(_trips(), [0, 1, 2], language: 'en');
      expect(_texts(en.footer!), ['Total', '', '47,000', '']);
    });

    test('sayı hücrelerine binlik ayracı gelir, sıra ve metne gelmez', () {
      final grid = buildTableOverview(_trips(), [0, 1], language: 'tr');
      // kilosu: 35000 → 35.000. sıra ("1") is a number, not a quantity.
      expect(_texts(grid.rows[0]), ['1', 'konya', '35.000', '5']);
      expect(_texts(grid.rows[1]), ['2', 'ızmır', '12.000', '5']);

      final text = buildTableOverview(
        TableModel(
          tableName: 'kodlar',
          columns: [ColumnModel(name: 'posta kodu')],
          rows: [
            ['34000'],
          ],
        ),
        [0],
        language: 'tr',
      );
      expect(text.rows[0][0].text, '34000');
    });

    test('düz sayı olmayan hücreler olduğu gibi kalır', () {
      expect(formatNumericCell('12000', language: 'tr'), '12.000');
      expect(formatNumericCell('12000', language: 'en'), '12,000');
      expect(formatNumericCell('999', language: 'tr'), '999');
      // Decimals keep every digit the user typed; no rounding.
      expect(formatNumericCell('1234567.5', language: 'tr'), '1.234.567,5');
      expect(formatNumericCell('12,345', language: 'tr'), '12,345');
      expect(formatNumericCell('-9876.25', language: 'en'), '-9,876.25');
      // Anything that is not a plain number is left alone.
      expect(formatNumericCell('12 kg', language: 'tr'), isNull);
      expect(formatNumericCell('12.000,5', language: 'tr'), isNull);
      expect(formatNumericCell('', language: 'tr'), isNull);
      expect(formatNumericCell('1e5', language: 'tr'), isNull);
    });

    test('sayısal sütunlar sağa, metin sola yaslanır', () {
      final grid = buildTableOverview(_trips(), [0], language: 'tr');
      expect(grid.rows[0].map((cell) => cell.align), [
        OverviewAlign.end,
        OverviewAlign.start,
        OverviewAlign.end,
        OverviewAlign.end,
      ]);
    });

    test('toplanacak sütun yoksa toplam satırı da yok', () {
      final grid = buildTableOverview(
        TableModel(
          tableName: 'notlar',
          columns: [ColumnModel(name: 'not')],
          rows: [
            ['a'],
          ],
        ),
        [0],
        language: 'tr',
      );
      expect(grid.footer, isNull);
      expect(grid.bodyRowCount, 1);
    });
  });

  group('çetele genel bakışı', () {
    test('bütün günler ve durum sayıları sütun olarak gelir', () {
      final grid = buildTallyOverview(
        _attendance(),
        [0, 1],
        language: 'tr',
        itemHeader: 'Kayıt',
      );
      expect(_texts(grid.header), [
        '#',
        'Kayıt',
        '1\nSa',
        '2\nÇa',
        '3\nPe',
        'V',
        'Y',
      ]);
      expect(_texts(grid.rows[0]), ['1', 'muslera', 'V', 'Y', 'V', '2', '1']);
      expect(grid.frozenColumns, 2);
    });

    test('silinmiş durum kodu görünür ama renksiz ve sayılmaz', () {
      final grid = buildTallyOverview(
        _attendance(),
        [0, 1],
        language: 'tr',
        itemHeader: 'Kayıt',
      );
      final icardi = grid.rows[1];
      expect(icardi[2].tint, const Color(0xFFC62828));
      expect(icardi[3].text, 'X');
      expect(icardi[3].tint, isNull);
      expect(_texts(icardi).sublist(5), ['0', '1']);
    });

    test('toplam satırı durumları, # sütunu görünen sırayı gösterir', () {
      final grid = buildTallyOverview(
        _attendance(),
        [1, 0],
        language: 'en',
        itemHeader: 'Item',
      );
      expect(grid.rows.map((row) => row[1].text), ['icardi', 'muslera']);
      expect(grid.rows.map((row) => row[0].text), ['1', '2']);
      expect(_texts(grid.footer!), ['', 'Total', '', '', '', '2', '2']);
      expect(grid.header[2].text, '1\nTu');
    });

    test('bugün aralıktaysa o gün vurgulanır', () {
      final grid = buildTallyOverview(
        _attendance(),
        [0],
        language: 'tr',
        itemHeader: 'Kayıt',
        today: DateTime(2026, 9, 2, 15, 30),
      );
      expect(grid.highlightedColumns, {3});
      final outside = buildTallyOverview(
        _attendance(),
        [0],
        language: 'tr',
        itemHeader: 'Kayıt',
        today: DateTime(2026, 10, 1),
      );
      expect(outside.highlightedColumns, isEmpty);
    });
  });

  group('yakınlaştırma hesapları', () {
    test('açılış ölçeği tamamını sığdırır ama küçüğü büyütmez', () {
      expect(
        OverviewViewport.fitScale(const Size(400, 800), const Size(1600, 400)),
        0.25,
      );
      expect(
        OverviewViewport.fitScale(const Size(400, 800), const Size(200, 100)),
        1,
      );
    });

    test('yakınlaşınca dokunulan nokta yerinde kalır', () {
      const viewport = Size(400, 800);
      const content = Size(2000, 3000);
      final start = OverviewViewport.matrix(0.2, Offset.zero);
      const focal = Offset(100, 200);
      final zoomed = OverviewViewport.zoomAt(
        focal,
        start,
        1.0,
        viewport,
        content,
      );
      expect(OverviewViewport.scaleOf(zoomed), 1.0);
      // The content point under the finger (500, 1000) is still under it.
      expect(OverviewViewport.translationOf(zoomed), const Offset(-400, -800));
    });

    test('kenarlar görünümün dışına kaçmaz', () {
      const viewport = Size(400, 800);
      const content = Size(1000, 500);
      expect(
        OverviewViewport.clampTranslation(
          const Offset(50, -900),
          1,
          viewport,
          content,
        ),
        const Offset(0, 0),
      );
      expect(
        OverviewViewport.clampTranslation(
          const Offset(-5000, 0),
          1,
          viewport,
          content,
        ),
        const Offset(-600, 0),
      );
    });

    test('iki parmak hareketi parmakların altındaki noktayı taşır', () {
      const viewport = Size(400, 800);
      const content = Size(2000, 3000);
      final start = OverviewViewport.matrix(0.5, const Offset(-100, -200));
      // The content point under the fingers at the start: (400, 600).
      final moved = OverviewViewport.gesture(
        start: start,
        startFocal: const Offset(100, 100),
        focal: const Offset(150, 120),
        scaleChange: 2,
        viewport: viewport,
        content: content,
      );
      expect(OverviewViewport.scaleOf(moved), 1.0);
      expect(OverviewViewport.translationOf(moved), const Offset(-250, -480));
    });

    test(
      'iki parmak hareketi ölçeği sığdırma ile üst sınır arasında tutar',
      () {
        const viewport = Size(400, 800);
        const content = Size(2000, 3000);
        final fit = OverviewViewport.fitScale(viewport, content);
        final start = OverviewViewport.matrix(1, Offset.zero);
        double scaled(double change) => OverviewViewport.scaleOf(
          OverviewViewport.gesture(
            start: start,
            startFocal: Offset.zero,
            focal: Offset.zero,
            scaleChange: change,
            viewport: viewport,
            content: content,
          ),
        );
        expect(scaled(0.01), fit);
        expect(scaled(100), OverviewViewport.maxScale(viewport, content));
      },
    );

    test('yan çevirme ipucu yalnızca gerçekten büyütecekse çıkar', () {
      const portrait = Size(400, 740);
      // A month-wide roster with a few rows: far larger when turned.
      expect(
        OverviewViewport.suggestsLandscape(portrait, const Size(1100, 330)),
        isTrue,
      );
      // Wide and tall: turning the phone would only shrink it.
      expect(
        OverviewViewport.suggestsLandscape(portrait, const Size(1100, 1500)),
        isFalse,
      );
      // Narrow tables already fit.
      expect(
        OverviewViewport.suggestsLandscape(portrait, const Size(300, 200)),
        isFalse,
      );
      // Already sideways.
      expect(
        OverviewViewport.suggestsLandscape(
          const Size(740, 400),
          const Size(1100, 330),
        ),
        isFalse,
      );
    });

    test(
      'sabit sütun ve başlık ekranı kaplayacak kadar büyüyünce bırakılır',
      () {
        const viewport = Size(400, 800);
        // "#" + name: 150 wide. Pinned while it leaves most of the screen free.
        expect(OverviewViewport.pinsColumns(150, 1, viewport), isTrue);
        expect(OverviewViewport.pinsColumns(150, 1.2, viewport), isTrue);
        // Four times larger it would cover the whole phone: let it scroll.
        expect(OverviewViewport.pinsColumns(150, 4, viewport), isFalse);
        expect(OverviewViewport.pinsColumns(0, 1, viewport), isFalse);
        expect(OverviewViewport.pinsHeader(44, 1, viewport), isTrue);
        expect(OverviewViewport.pinsHeader(44, 6, viewport), isFalse);
      },
    );

    test('sabit başlık ve sütun ekrandan çıkmaz', () {
      expect(
        OverviewViewport.stickyOrigin(const Offset(-300, -120)),
        Offset.zero,
      );
      expect(
        OverviewViewport.stickyOrigin(const Offset(20, 40)),
        const Offset(20, 40),
      );
    });
  });
}
