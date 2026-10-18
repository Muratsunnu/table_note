import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/l10n/app_localizations.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/table_provider.dart';
import 'package:table_note/providers/tally_provider.dart';
import 'package:table_note/services/export_service.dart';
import 'package:table_note/services/pdf_report.dart';
import 'package:table_note/utils/row_preview.dart';

final _tr = AppLocalizations(const Locale('tr'));
final _now = DateTime(2026, 10, 15, 14, 30);

/// Sevkiyat: Konya iki satırda, navlunun başlangıç değeri var.
TableModel _trips() => TableModel(
  tableName: 'Sevkiyat',
  columns: [
    ColumnModel(name: 'plaka'),
    ColumnModel(name: 'yükleme'),
    ColumnModel(name: 'navlun', isNumeric: true, startingValue: 50000),
  ],
  rows: [
    ['42 A 1', 'Konya', '12000'],
    ['06 B 2', 'Ankara', '9000'],
    ['42 C 3', 'Konya', '8500'],
  ],
);

TallyTableModel _tally() => TallyTableModel(
  tableName: 'Puantaj',
  startDate: DateTime(2026, 10, 1),
  endDate: DateTime(2026, 10, 31),
  statuses: [
    TallyStatus(code: 'Ç', label: 'Çalıştı', colorValue: 0xFF4CAF50),
    TallyStatus(code: 'İ', label: 'İzinli', colorValue: 0xFFFF9800),
  ],
  items: [
    TallyItemModel(
      name: 'Ahmet',
      entries: {'2026-10-01': 'Ç', '2026-10-02': 'İ', '2026-10-20': 'Ç'},
    ),
    TallyItemModel(name: 'Mehmet', entries: {'2026-10-01': 'Ç'}),
  ],
);

void main() {
  group('dosya adı', () {
    test('uygulamanın adıyla başlar, aranan söz sona eklenir', () {
      expect(ExportService.fileBaseName('Sevkiyat'), 'Table Note - Sevkiyat');
      expect(
        ExportService.fileBaseName('Sevkiyat', tag: 'Konya'),
        'Table Note - Sevkiyat - Konya',
      );
    });

    test('dosya adına yazılamayan işaretler ayıklanır', () {
      expect(
        ExportService.fileBaseName('Müşteri: listesi/2026', tag: '  '),
        'Table Note - Musteri_ listesi_2026',
      );
      expect(
        ExportService.fileBaseName('a' * 300).runes.length,
        lessThanOrEqualTo(100),
      );
    });
  });

  group('tablo', () {
    test('arama sonucu: yalnızca bulunanlar ve onların toplamı', () {
      final report = ExportService.tableReport(
        _trips(),
        loc: _tr,
        now: _now,
        selection: const ExportSelection(
          order: [2, 0],
          search: 'yükleme: Konya',
          searchTerm: 'Konya',
        ),
      );

      // Ekrandaki sırayla, sayılar ayraçlı.
      expect(report.rows, [
        ['42 C 3', 'Konya', '8.500'],
        ['42 A 1', 'Konya', '12.000'],
      ]);
      expect(report.totalRow, ['Toplam', '', '20.500']);
      expect(report.frame.lines, ['Arama: yükleme: Konya']);
      expect(report.frame.meta, '2 kayıt · 15.10.2026 14:30');
      expect(report.frame.documentTitle, 'Table Note - Sevkiyat - Konya');
      // Başlangıç değeri tablonun tamamına ait; burada yanıltır.
      expect(report.notes, isEmpty);
    });

    test('tamamı: toplamın altında başlangıç değeri ve kalan', () {
      final report = ExportService.tableReport(
        _trips(),
        loc: _tr,
        now: _now,
        selection: const ExportSelection(order: [0, 1, 2]),
      );

      expect(report.rows, hasLength(3));
      expect(report.totalRow, ['Toplam', '', '29.500']);
      expect(report.frame.lines, isEmpty);
      expect(report.notes.map((note) => '${note.label}=${note.value}'), [
        'navlun · Başlangıç değeri=50.000',
        'navlun · kalan=20.500',
      ]);
    });

    test('her sütun toplanıyorsa toplamlar tablonun altına yazılır', () {
      final table = TableModel(
        tableName: 'Kilo',
        columns: [ColumnModel(name: 'kilo', isNumeric: true)],
        rows: [
          ['10'],
          ['5'],
        ],
      );
      final report = ExportService.tableReport(table, loc: _tr, now: _now);

      expect(report.totalRow, isNull);
      expect(report.notes.single.label, 'Toplam · kilo');
      expect(report.notes.single.value, '15');
    });

    test('CSV de aynı seçime uyar', () {
      final filtered = ExportService.tableCsv(
        _trips(),
        loc: _tr,
        selection: const ExportSelection(
          order: [0, 2],
          search: 'yükleme: Konya',
        ),
      );
      expect(
        filtered,
        'plaka,yükleme,navlun\n42 A 1,Konya,12000\n42 C 3,Konya,8500\n',
      );

      final whole = ExportService.tableCsv(_trips(), loc: _tr);
      expect(whole, contains('06 B 2,Ankara,9000'));
      expect(whole, contains('Kalan (navlun),20500'));
    });
  });

  group('çetele', () {
    test('seçilen kişi ve günler', () {
      final report = ExportService.tallyReport(
        _tally(),
        loc: _tr,
        now: _now,
        selection: ExportSelection(
          order: const [0],
          search: 'Ahmet',
          searchTerm: 'Ahmet',
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 15),
        ),
      );

      expect(report.rows.single.name, 'Ahmet');
      expect(report.days, hasLength(15));
      expect(report.rows.single.codes.take(3), ['Ç', 'İ', '']);
      expect(report.frame.lines, ['01.10.2026 – 15.10.2026', 'Arama: Ahmet']);
      // 1 Ekim 2026 perşembedir; 3'ü cumartesi.
      expect(report.days.first.weekday, 'Pe');
      expect(report.days[2].weekend, isTrue);
    });

    test('çetelenin dışına taşan aralık çeteleye kırpılır', () {
      final report = ExportService.tallyReport(
        _tally(),
        loc: _tr,
        selection: ExportSelection(
          order: const [0, 1],
          from: DateTime(2026, 9, 20),
          to: DateTime(2026, 12, 1),
        ),
      );

      expect(report.days, hasLength(31));
      expect(report.days.first.date, '01.10.2026');
      expect(report.days.last.date, '31.10.2026');
    });

    test('CSV yalnızca seçilen günleri sayar', () {
      final csv = ExportService.tallyCsv(
        _tally(),
        loc: _tr,
        selection: ExportSelection(
          order: const [0],
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 2),
        ),
      );
      expect(csv, 'Kayıt,1/10,2/10,Çalıştı (Ç),İzinli (İ)\nAhmet,Ç,İ,1,1\n');
    });
  });

  group('PDF', () {
    final fonts = ReportFonts(
      File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
      File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync(),
    );

    test('uzun bir tablo sayfalara bölünür', () async {
      final table = _trips()
        ..rows.addAll([
          for (var i = 0; i < 400; i++) ['34 X $i', 'İzmir', '$i'],
        ]);
      final bytes = await buildTablePdf(
        ExportService.tableReport(table, loc: _tr, now: _now),
        fonts,
      );
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('arka planda dizilir', () async {
      final bytes = await ExportService.renderInBackground(
        buildTablePdf,
        ExportService.tableReport(_trips(), loc: _tr, now: _now),
        fonts,
      );
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('iki aylık çetele oluşur', () async {
      final tally = _tally()..endDate = DateTime(2026, 11, 30);
      final bytes = await buildTallyPdf(
        ExportService.tallyReport(tally, loc: _tr, now: _now),
        fonts,
      );
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    });
  });

  test(
    'kâğıttaki arama ekrandakini değiştirmez, yazıldığı gibi geçer',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tables = TableProvider();
      addTearDown(tables.dispose);
      while (tables.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tables.createTable('Sevkiyat', [
        ColumnModel(name: 'plaka'),
        ColumnModel(name: 'yükleme'),
      ]);
      for (final city in ['Konya', 'İzmir', 'Konya']) {
        await tables.addRow(['42 A', city]);
      }

      expect(tables.queryRows('  '), isNull);

      // "İ" küçülünce iki harf olur; sözün yeri yine doğru bulunmalı.
      final izmir = tables.queryRows('YÜKLEME: İzmir')!;
      expect(izmir.rows, [1]);
      expect(izmir.label, 'yükleme: İzmir');
      expect(izmir.term, 'İzmir');
      expect(izmir.columns, ['yükleme']);

      final konya = tables.queryRows('konya')!;
      expect(konya.rows, [0, 2]);
      expect(konya.columns, isEmpty);
      expect(tables.isFiltering, isFalse);

      // Birden çok koşul: başlığa hepsi, dosya adına sözler.
      final both = tables.queryRows('yükleme: Konya, plaka: 42')!;
      expect(both.rows, [0, 2]);
      expect(both.label, 'yükleme: Konya, plaka: 42');
      expect(both.term, 'Konya - 42');
    },
  );

  test('çetelede kişi aranır', () async {
    SharedPreferences.setMockInitialValues({});
    final tallies = TallyProvider();
    addTearDown(tallies.dispose);
    while (tallies.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await tallies.createTable(_tally());

    expect(tallies.queryItems(''), isNull);
    final found = tallies.queryItems(' ahm ')!;
    expect(found.items, [0]);
    expect(found.term, 'ahm');
    expect(tallies.filteredItemIndices, [0, 1]);
  });

  test('kâğıttaki önizleme satırı ekrandaki gibi okunur', () {
    final table = TableModel(
      tableName: 'Sevkiyat',
      columns: [
        ColumnModel(name: 'sıra', columnType: ColumnType.autoNumber),
        ColumnModel(name: 'plaka'),
        ColumnModel(name: 'kilo', isNumeric: true),
        ColumnModel(name: 'not'),
      ],
      rows: [],
    );
    expect(
      rowPreview(table, ['3', '42 A', '12000', ''], 'tr'),
      '42 A · 12.000',
    );
    // İpucu sıra numarasıyla değil, bir yazı sütunuyla örnek verir.
    expect(searchExampleColumn(table.columns)?.name, 'plaka');
  });

  group('görüntüleyen', () {
    test('yalnızca görüntüleyen katılımcı dosya alamaz', () async {
      SharedPreferences.setMockInitialValues({});
      final tables = TableProvider();
      final tallies = TallyProvider();
      addTearDown(tables.dispose);
      addTearDown(tallies.dispose);
      while (tables.isLoading || tallies.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tables.createTable('seferler', [ColumnModel(name: 'nereden')]);
      await tallies.createTable(_tally());
      final tableId = tables.currentTable!.id;
      final tallyId = tallies.currentTable!.id;

      expect(tables.canExportCurrent, isTrue);
      expect(tallies.canExportCurrent, isTrue);

      for (final role in ['owner', 'editor']) {
        await tables.setSharedRole(tableId, role);
        await tallies.setSharedRole(tallyId, role);
        expect(tables.canExportCurrent, isTrue, reason: role);
        expect(tallies.canExportCurrent, isTrue, reason: role);
      }

      await tables.setSharedRole(tableId, 'viewer');
      await tallies.setSharedRole(tallyId, 'viewer');
      expect(tables.canExportCurrent, isFalse);
      expect(tallies.canExportCurrent, isFalse);
    });
  });
}
