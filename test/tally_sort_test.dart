import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/models/tally_sort_preference.dart';
import 'package:table_note/providers/tally_provider.dart';
import 'package:table_note/services/storage_service.dart';

/// Manual order: icardi, Osimhen, ışık, Çağlar.
///
/// icardi has three "Y" marks outside the range. If they were counted, icardi
/// (4) would outrank Osimhen (2); counted correctly Osimhen leads with 2 vs 1.
TallyTableModel _tally() => TallyTableModel(
  tableName: 'Yoklama',
  startDate: DateTime(2026, 9, 1),
  endDate: DateTime(2026, 9, 10),
  statuses: [
    TallyStatus(code: 'V', label: 'Var', colorValue: 0xFF2E7D32),
    TallyStatus(code: 'Y', label: 'Yok', colorValue: 0xFFC62828),
  ],
  items: [
    TallyItemModel(
      name: 'icardi',
      entries: {
        '2026-09-01': 'V',
        '2026-09-02': 'V',
        '2026-09-03': 'Y',
        '2026-08-20': 'Y',
        '2026-08-21': 'Y',
        '2026-08-22': 'Y',
      },
    ),
    TallyItemModel(
      name: 'Osimhen',
      entries: {'2026-09-01': 'Y', '2026-09-02': 'Y'},
    ),
    TallyItemModel(name: 'ışık', entries: {'2026-09-01': 'V'}),
    TallyItemModel(name: 'Çağlar'),
  ],
);

Future<TallyProvider> _ready() async {
  final provider = TallyProvider();
  while (provider.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return provider;
}

Future<TallyProvider> _seeded() async {
  SharedPreferences.setMockInitialValues({});
  final provider = await _ready();
  expect(await provider.createTable(_tally()), isTrue);
  return provider;
}

/// The fire-and-forget save must reach storage before a "cold start".
Future<void> _waitForSaved(
  String id,
  bool Function(TallySortPreference?) done,
) async {
  for (var i = 0; i < 200; i++) {
    if (done((await StorageService.loadTallySorts())[id])) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('sort preference never reached storage');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('varsayılan görünüm elle belirlenen sırayı korur', () async {
    final provider = await _seeded();
    expect(provider.isSorted, isFalse);
    expect(provider.filteredItemIndices, [0, 1, 2, 3]);
  });

  test('ad başlığı Türkçe alfabeyle artan → azalan → kapalı döner', () async {
    final provider = await _seeded();

    provider.toggleNameSort();
    // ç comes after c, ı comes after h and before i.
    expect(provider.filteredItemIndices, [3, 2, 0, 1]);

    provider.toggleNameSort();
    expect(provider.filteredItemIndices, [1, 0, 2, 3]);

    provider.toggleNameSort();
    expect(provider.isSorted, isFalse);
    expect(provider.filteredItemIndices, [0, 1, 2, 3]);
  });

  test('durum sayısı yalnızca tarih aralığı içinden sayılır', () async {
    final provider = await _seeded();

    provider.setSort(const TallySortPreference.byStatus('Y', ascending: false));
    expect(provider.filteredItemIndices, [1, 0, 2, 3]);

    provider.setSort(const TallySortPreference.byStatus('Y', ascending: true));
    // ışık and Çağlar tie at zero and keep their manual order.
    expect(provider.filteredItemIndices, [2, 3, 0, 1]);

    provider.setSort(const TallySortPreference.byStatus('V', ascending: false));
    expect(provider.filteredItemIndices, [0, 2, 1, 3]);
  });

  test('arama ile sıralama birlikte çalışır', () async {
    final provider = await _seeded();
    provider.setItemSearchQuery('i');
    // "ışık" has a dotless ı, so it does not match "i".
    expect(provider.filteredItemIndices, [0, 1]);

    provider.setSort(const TallySortPreference.byStatus('Y', ascending: false));
    expect(provider.filteredItemIndices, [1, 0]);
  });

  test('genel bakış sırası aramadan bağımsızdır', () async {
    final provider = await _seeded();
    provider.setItemSearchQuery('i');
    provider.setSort(const TallySortPreference.byStatus('Y', ascending: false));
    expect(provider.filteredItemIndices, [1, 0]);
    // The whole-tally view always shows every item, in the on-screen order.
    expect(provider.sortedItemIndices, [1, 0, 2, 3]);
  });

  test('silinmiş bir duruma bağlı sıralama yok sayılır', () async {
    final provider = await _seeded();
    provider.setSort(const TallySortPreference.byStatus('X', ascending: false));
    expect(provider.currentSort, isNull);
    expect(provider.filteredItemIndices, [0, 1, 2, 3]);
  });

  test('elle sıralamak otomatik sıralamayı kaldırır, kalıcı olarak', () async {
    final provider = await _seeded();
    final id = provider.currentTable!.id;
    provider.toggleNameSort();
    await _waitForSaved(id, (saved) => saved != null);

    await provider.reorderItem(0, 2);
    expect(provider.isSorted, isFalse);
    expect(provider.currentTable!.items.map((item) => item.name), [
      'Osimhen',
      'icardi',
      'ışık',
      'Çağlar',
    ]);
    await _waitForSaved(id, (saved) => saved == null);
  });

  test('sıralama uygulama yeniden açılınca geri gelir', () async {
    final provider = await _seeded();
    final id = provider.currentTable!.id;
    provider.setSort(const TallySortPreference.byStatus('Y', ascending: false));
    await _waitForSaved(id, (saved) => saved?.statusCode == 'Y');

    final reopened = await _ready();
    expect(reopened.currentTable!.id, id);
    expect(
      reopened.currentSort,
      const TallySortPreference.byStatus('Y', ascending: false),
    );
    expect(reopened.filteredItemIndices, [1, 0, 2, 3]);
  });

  test('tercih JSON gidiş-dönüşü korunur, bozuk kayıtlar reddedilir', () {
    for (final preference in const [
      TallySortPreference.byName(ascending: true),
      TallySortPreference.byStatus('Y', ascending: false),
    ]) {
      expect(TallySortPreference.fromJson(preference.toJson()), preference);
    }
    expect(TallySortPreference.fromJson(null), isNull);
    expect(TallySortPreference.fromJson({'by': 'name'}), isNull);
    expect(
      TallySortPreference.fromJson({'by': 'status', 'ascending': true}),
      isNull,
    );
    expect(
      TallySortPreference.fromJson({'by': 'color', 'ascending': true}),
      isNull,
    );
  });

  test('tüm verileri temizlemek çetele sıralamalarını da siler', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveTallySorts({
      'a': const TallySortPreference.byName(ascending: true),
    });
    expect(await StorageService.loadTallySorts(), isNotEmpty);
    await StorageService.clearAllData();
    expect(await StorageService.loadTallySorts(), isEmpty);
  });
}
