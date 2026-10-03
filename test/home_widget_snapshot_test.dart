import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/home_widget_snapshot.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';

Map<String, dynamic> snapshot({
  List<TableModel> tables = const [],
  List<TallyTableModel> tallies = const [],
  String language = 'en',
  Map<String, List<int>> orders = const {},
}) =>
    jsonDecode(
          HomeWidgetSnapshot.encode(
            tables: tables,
            tallies: tallies,
            language: language,
            dark: false,
            orders: orders,
          ),
        )
        as Map<String, dynamic>;

void main() {
  _gridTests();
  _orderTests();

  test(
    'exports summaries and recent entries; ignores invalid and non-finite cells',
    () {
      final data = snapshot(
        tables: [
          TableModel(
            id: 'table-1',
            tableName: 'Trips',
            columns: [
              ColumnModel(name: 'Private note'),
              ColumnModel(name: 'Amount', isNumeric: true),
              ColumnModel(name: 'Formula', columnType: ColumnType.formula),
              ColumnModel(
                name: 'Rate',
                isNumeric: true,
                columnType: ColumnType.constant,
              ),
              ColumnModel(
                name: 'No',
                isNumeric: true,
                columnType: ColumnType.autoNumber,
              ),
            ],
            rows: [
              ['private row contents', '12.5', '25', '99', '1'],
              ['secret', '-2', 'NaN', '99', '2'],
              ['secret', 'Infinity', '5'],
              ['short row'],
            ],
          ),
        ],
      );
      final entry = (data['entries'] as List).single as Map;
      expect(entry['id'], 'table:table-1');
      expect(entry['count'], 4);
      expect(entry['countText'], '4 records');
      final metrics = entry['metrics'] as List;
      expect(metrics.map((metric) => metric['label']), ['Amount', 'Formula']);
      expect(metrics.map((metric) => metric['value']), ['10.5', '30']);
      // Recent entries are shown on the home screen on purpose.
      // Newest first, already in display order.
      final rows = entry['rows'] as List;
      expect(rows.map((row) => row['text']), [
        'short row',
        'secret · Infinity · 5',
        'secret · -2 · NaN',
        'private row contents · 12.5 · 25',
      ]);
      expect(rows[3]['values'], {
        '["Amount",0]': '12.5',
        '["Formula",0]': '25',
      });
      // Non-finite and missing cells carry no value of their own.
      expect(rows[2]['values'], {'["Amount",0]': '-2'});
      expect(rows[1]['values'], {'["Formula",0]': '5'});
      expect(rows[0]['values'], isEmpty);
    },
  );

  test('keeps only the newest entries and clips long cells', () {
    final data = snapshot(
      tables: [
        TableModel(
          id: 'long',
          tableName: 'Long',
          columns: [ColumnModel(name: 'Note')],
          rows: [
            for (var i = 1; i <= 8; i++) ['row $i'],
          ],
        ),
      ],
    );
    final rows = data['entries'][0]['rows'] as List;
    expect(rows.length, HomeWidgetSnapshot.maxRecent);
    expect(rows.first['text'], 'row 8');
    expect(rows.last['text'], 'row 2');
    expect(HomeWidgetSnapshot.clip('abcdef', 4), 'abc…');
    expect(HomeWidgetSnapshot.clip('abcd', 4), 'abcd');
  });

  test('metric IDs survive column reorder and distinguish duplicate names', () {
    Map<String, dynamic> data(List<ColumnModel> columns) => snapshot(
      tables: [
        TableModel(id: 'same', tableName: 'Table', columns: columns, rows: []),
      ],
    );
    final a = ColumnModel(name: 'A', isNumeric: true);
    final b = ColumnModel(name: 'B', isNumeric: true);
    List metrics(Map<String, dynamic> value) =>
        value['entries'][0]['metrics'] as List;
    expect(metrics(data([a, b]))[0]['id'], metrics(data([b, a]))[1]['id']);
    final duplicates = metrics(data([a, a.copyWith()]));
    expect(duplicates[0]['id'], isNot(duplicates[1]['id']));
  });

  test(
    'tally totals include only known statuses in the selected date range',
    () {
      final data = snapshot(
        tallies: [
          TallyTableModel(
            id: 'tally-1',
            tableName: 'Attendance',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 3),
            statuses: [
              TallyStatus(code: 'P', label: 'Present', colorValue: 0),
              TallyStatus(code: 'A', label: 'Absent', colorValue: 0),
            ],
            items: [
              TallyItemModel(
                name: 'Private person',
                entries: {
                  '2026-08-31': 'P',
                  '2026-09-01': 'P',
                  '2026-09-02': 'unknown',
                  '2026-09-03': 'A',
                  '2026-09-04': 'P',
                },
              ),
              TallyItemModel(
                name: 'Another person',
                entries: {'2026-09-01': 'P'},
              ),
            ],
          ),
        ],
      );
      final entry = data['entries'][0];
      expect(entry['id'], 'tally:tally-1');
      expect(entry['count'], 2);
      expect((entry['metrics'] as List).map((m) => m['value']), ['2', '1']);
      // Item names reach the widget, each with its own in-range counts.
      expect((entry['rows'] as List).map((row) => row['text']), [
        'Private person',
        'Another person',
      ]);
      expect(entry['rows'][0]['values'], {'P': '1', 'A': '1'});
      expect(entry['rows'][1]['values'], {'P': '1', 'A': '0'});
      // This range ended long ago, so there is no today view to show.
      expect((entry as Map).containsKey('todayText'), isFalse);
      expect((entry['rows'][0] as Map).containsKey('todayLabel'), isFalse);
    },
  );

  test('tally reports today’s mark when its range covers today', () {
    final today = DateTime.now();
    final data = snapshot(
      language: 'tr',
      tallies: [
        TallyTableModel(
          id: 'tally-today',
          tableName: 'Yoklama',
          startDate: today.subtract(const Duration(days: 2)),
          endDate: today.add(const Duration(days: 2)),
          statuses: [
            TallyStatus(code: 'V', label: 'Var', colorValue: 0xFF2E7D32),
            TallyStatus(code: 'Y', label: 'Yok', colorValue: 0xFFC62828),
          ],
          items: [
            TallyItemModel(
              name: 'Osimhen',
              entries: {TallyTableModel.dateKey(today): 'V'},
            ),
            TallyItemModel(name: 'icardi', entries: {}),
          ],
        ),
      ],
    );
    final entry = data['entries'][0];
    expect(entry['todayText'], 'Bugün · ${HomeWidgetSnapshot.dayText(today)}');
    expect(entry['todayMarked'], '1 / 2 işaretlendi');
    final rows = entry['rows'] as List;
    expect(rows[0]['todayLabel'], 'Var');
    expect(rows[0]['todayColor'], 0xFF2E7D32);
    // An unmarked item shows a dash and stays colourless.
    expect(rows[1]['todayLabel'], '—');
    expect((rows[1] as Map).containsKey('todayColor'), isFalse);
  });

  test(
    'empty and deleted tables are absent rather than reassigned by index',
    () {
      expect(snapshot()['entries'], isEmpty);
      final data = snapshot(
        tables: [
          TableModel(
            id: 'survivor',
            tableName: 'Remaining',
            columns: [],
            rows: [],
          ),
        ],
      );
      expect(data['entries'][0]['id'], 'table:survivor');
      expect(data['entries'][0]['count'], 0);
      expect(data['entries'][0]['metrics'], isEmpty);
    },
  );

  test('formats Turkish/English totals without removing integer zeroes', () {
    expect(HomeWidgetSnapshot.formatNumber(100, 'en'), '100');
    expect(HomeWidgetSnapshot.formatNumber(0, 'tr'), '0');
    expect(HomeWidgetSnapshot.formatNumber(12.50, 'tr'), '12,5');
    expect(HomeWidgetSnapshot.formatNumber(-1.25, 'en'), '-1.25');
    // Thousands are grouped so long totals stay readable.
    expect(HomeWidgetSnapshot.formatNumber(1000, 'tr'), '1.000');
    expect(HomeWidgetSnapshot.formatNumber(47000, 'en'), '47,000');
    expect(HomeWidgetSnapshot.formatNumber(1234567.5, 'tr'), '1.234.567,5');
    expect(HomeWidgetSnapshot.formatNumber(-9876.25, 'en'), '-9,876.25');
    expect(HomeWidgetSnapshot.formatNumber(999, 'tr'), '999');
    expect(HomeWidgetSnapshot.formatNumber(double.infinity, 'en'), '—');
    expect(HomeWidgetSnapshot.formatNumber(double.nan, 'tr'), '—');
    expect(snapshot(language: 'tr')['strings']['add'], '+ Kayıt ekle');
  });

  test(
    'routes only valid widget links, never auth callbacks or other actions',
    () {
      final request = HomeWidgetRequest.parse(
        Uri.parse(
          'com.muratstudio.tablenote://widget/add?kind=tally&id=tally-1&instance=12',
        ),
      )!;
      expect(request.tableId, 'tally-1');
      expect(request.kind, 'tally');
      expect(request.add, isTrue);
      expect(
        HomeWidgetRequest.parse(
          Uri.parse(
            'com.muratstudio.tablenote://widget/open?kind=table&id=table-1',
          ),
        )!.add,
        isFalse,
      );
      for (final link in [
        'com.muratstudio.tablenote://login-callback?code=auth-code',
        'https://widget/add?kind=table&id=table-1',
        'com.muratstudio.tablenote://widget/delete?kind=table&id=table-1',
        'com.muratstudio.tablenote://widget/add?kind=table&id=',
        'com.muratstudio.tablenote://widget/add?kind=other&id=table-1',
        'com.muratstudio.tablenote://widget/open',
      ]) {
        expect(HomeWidgetRequest.parse(Uri.parse(link)), isNull, reason: link);
      }
    },
  );
}

void _gridTests() {
  test('tablo widget için sütun sütun hücre gönderir', () {
    final data = snapshot(
      language: 'tr',
      tables: [
        TableModel(
          id: 't1',
          tableName: 'seferler',
          columns: [
            ColumnModel(
              name: 'sıra',
              isNumeric: true,
              columnType: ColumnType.autoNumber,
            ),
            ColumnModel(name: 'nereden'),
            ColumnModel(name: 'nereye'),
            ColumnModel(name: 'malzeme'),
            ColumnModel(name: 'kilosu', isNumeric: true),
          ],
          rows: [
            ['1', 'konya', 'ankara', 'pmt', '35000'],
            ['2', 'izmir', '', '', '12000'],
          ],
        ),
      ],
    );
    final entry = data['entries'][0];

    // Row numbers are dropped, then the user's own column order is kept.
    expect(entry['columns'].map((c) => c['label']), [
      'nereden',
      'nereye',
      'malzeme',
    ]);
    expect(entry['columns'].map((c) => c['numeric']), [false, false, false]);

    final rows = entry['rows'] as List;
    // Newest first, exactly as the list and the overview draw it.
    expect(rows[0]['cells'], ['izmir', '', '']);
    expect(rows[1]['cells'], ['konya', 'ankara', 'pmt']);
    // "kilosu" did not fit; the widget appends it from `values` when chosen.
    expect(rows[1]['values'].values, contains('35.000'));
    // No total lands in these three columns, so there is no totals row.
    expect(entry.containsKey('footer'), isFalse);
  });

  test('sayı sütunu görünüyorsa hücreler ayraçlı ve toplam satırı gelir', () {
    final data = snapshot(
      language: 'tr',
      tables: [
        TableModel(
          id: 't2',
          tableName: 'kasa',
          columns: [
            ColumnModel(name: 'kalem'),
            ColumnModel(name: 'tutar', isNumeric: true),
          ],
          rows: [
            ['kira', '35000'],
            ['fatura', '12000'],
          ],
        ),
      ],
    );
    final entry = data['entries'][0];
    expect(entry['columns'].map((c) => c['numeric']), [false, true]);
    expect(entry['columns'][1]['metricId'], isNotNull);
    expect((entry['rows'] as List)[0]['cells'], ['fatura', '12.000']);
    expect(entry['footer'], ['Toplam', '47.000']);
  });

  test('çetele son günleri sütun olarak gönderir, bugün işaretli', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 5));
    final data = snapshot(
      language: 'tr',
      tallies: [
        TallyTableModel(
          id: 'c1',
          tableName: 'yoklama',
          startDate: start,
          endDate: today.add(const Duration(days: 2)),
          statuses: [
            TallyStatus(code: 'V', label: 'Var', colorValue: 0xFF2E7D32),
            TallyStatus(code: 'Y', label: 'Yok', colorValue: 0xFFC62828),
          ],
          items: [
            TallyItemModel(
              name: 'Murat',
              entries: {TallyTableModel.dateKey(today): 'V'},
            ),
            TallyItemModel(name: 'Ali'),
          ],
        ),
      ],
    );
    final entry = data['entries'][0];
    final columns = entry['columns'] as List;
    // Name column plus the last days of the range, ending on today.
    expect(columns.first['label'], 'Kayıt');
    expect(columns.length, HomeWidgetSnapshot.maxGridDays + 1);
    expect(columns.last['label'], '${today.day}');
    expect(entry['todayColumn'], columns.length - 1);

    final rows = entry['rows'] as List;
    expect(rows[0]['cells'].first, 'Murat');
    expect(rows[0]['cells'].last, 'V');
    expect(rows[0]['colors'].last, 0xFF2E7D32);
    // An unmarked item keeps its place with empty, uncoloured cells.
    expect(rows[1]['cells'].last, '');
    expect(rows[1]['colors'].last, isNull);
  });
}

void _orderTests() {
  TableModel _trips() => TableModel(
    id: 't-order',
    tableName: 'seferler',
    columns: [
      ColumnModel(name: 'nereden'),
      ColumnModel(name: 'kilosu', isNumeric: true),
    ],
    rows: [
      ['konya', '35000'],
      ['ankara', '9'],
      ['izmir', '120'],
    ],
  );

  test('sıralama yoksa en yeni kayıt üstte kalır', () {
    final entry = snapshot(language: 'tr', tables: [_trips()])['entries'][0];
    expect((entry['rows'] as List).map((row) => row['cells'][0]), [
      'izmir',
      'ankara',
      'konya',
    ]);
  });

  test('tablo sıralıysa widget ekrandaki sırayı gösterir', () {
    final entry = snapshot(
      language: 'tr',
      tables: [_trips()],
      // "kilosu" artan: ankara(9), izmir(120), konya(35000).
      orders: {
        't-order': [1, 2, 0],
      },
    )['entries'][0];
    expect((entry['rows'] as List).map((row) => row['cells'][0]), [
      'ankara',
      'izmir',
      'konya',
    ]);
    // Totals cover the whole table, not just the rows that travelled.
    expect(entry['footer'], ['Toplam', '35.129']);
  });

  test('çetele sıralıysa öğeler o sırayla gider', () {
    final start = DateTime(2026, 9, 1);
    final entry = snapshot(
      language: 'tr',
      tallies: [
        TallyTableModel(
          id: 'c-order',
          tableName: 'yoklama',
          startDate: start,
          endDate: DateTime(2026, 9, 3),
          statuses: [TallyStatus(code: 'V', label: 'Var', colorValue: 1)],
          items: [
            TallyItemModel(name: 'Zeynep'),
            TallyItemModel(name: 'Ali'),
          ],
        ),
      ],
      orders: {
        'c-order': [1, 0],
      },
    )['entries'][0];
    expect((entry['rows'] as List).map((row) => row['cells'][0]), [
      'Ali',
      'Zeynep',
    ]);
  });

  test('geçersiz sıra indeksleri sessizce atlanır', () {
    final entry = snapshot(
      language: 'tr',
      tables: [_trips()],
      // A row deleted between sorting and publishing must not crash the widget.
      orders: {
        't-order': [2, 9, -1, 0],
      },
    )['entries'][0];
    expect((entry['rows'] as List).map((row) => row['cells'][0]), [
      'izmir',
      'konya',
    ]);
  });
}
