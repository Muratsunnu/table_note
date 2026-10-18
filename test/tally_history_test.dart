import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/providers/tally_provider.dart';

TallyTableModel _tally() => TallyTableModel(
  tableName: 'Yoklama',
  startDate: DateTime(2026, 9, 1),
  endDate: DateTime(2026, 9, 10),
  statuses: [
    TallyStatus(code: 'V', label: 'Var', colorValue: 0xFF2E7D32),
    TallyStatus(code: 'Y', label: 'Yok', colorValue: 0xFFC62828),
  ],
  items: [
    TallyItemModel(name: 'icardi'),
    TallyItemModel(name: 'Osimhen'),
  ],
);

Future<TallyProvider> _seeded() async {
  SharedPreferences.setMockInitialValues({});
  final provider = TallyProvider();
  while (provider.isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(await provider.createTable(_tally()), isTrue);
  return provider;
}

final _day = DateTime(2026, 9, 2);
const _key = '2026-09-02';

String? _mark(TallyProvider provider, int item) =>
    provider.currentTable!.items[item].entries[_key];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('geri alınan işaret ileri alınca geri gelir', () async {
    final provider = await _seeded();
    expect(provider.canUndo, isFalse);
    expect(provider.canRedo, isFalse);

    await provider.setCellStatus(0, _day, 'V');
    expect(_mark(provider, 0), 'V');
    expect(provider.canUndo, isTrue);
    // Nothing has been taken back yet, so there is nothing to replay.
    expect(provider.canRedo, isFalse);

    await provider.undoLastEdit();
    expect(_mark(provider, 0), isNull);
    expect(provider.canRedo, isTrue);

    await provider.redoLastEdit();
    expect(_mark(provider, 0), 'V');
    expect(provider.canRedo, isFalse);
    expect(provider.canUndo, isTrue);
  });

  test('art arda birkaç adım ileri geri gidilebilir', () async {
    final provider = await _seeded();
    await provider.setCellStatus(0, _day, 'V');
    await provider.setCellStatus(0, _day, 'Y');

    await provider.undoLastEdit();
    expect(_mark(provider, 0), 'V');
    await provider.undoLastEdit();
    expect(_mark(provider, 0), isNull);
    expect(provider.canUndo, isFalse);

    await provider.redoLastEdit();
    expect(_mark(provider, 0), 'V');
    await provider.redoLastEdit();
    expect(_mark(provider, 0), 'Y');
    expect(provider.canRedo, isFalse);
  });

  test(
    'geri aldıktan sonra yeni işaret, ileri almayı geçersiz kılar',
    () async {
      final provider = await _seeded();
      await provider.setCellStatus(0, _day, 'V');
      await provider.undoLastEdit();
      expect(provider.canRedo, isTrue);

      // The user chose a different future; the old one is no longer reachable.
      await provider.setCellStatus(1, _day, 'Y');
      expect(provider.canRedo, isFalse);
      expect(_mark(provider, 0), isNull);
      expect(_mark(provider, 1), 'Y');
    },
  );

  test('toplu işaretleme tek adımda geri ve ileri alınır', () async {
    final provider = await _seeded();
    await provider.setBulkStatus(
      itemIndices: [0, 1],
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      statusCode: 'V',
    );
    expect(provider.currentTable!.items[0].entries.length, 3);
    expect(provider.currentTable!.items[1].entries.length, 3);

    await provider.undoLastEdit();
    expect(provider.currentTable!.items[0].entries, isEmpty);
    expect(provider.currentTable!.items[1].entries, isEmpty);

    await provider.redoLastEdit();
    expect(_mark(provider, 0), 'V');
    expect(_mark(provider, 1), 'V');
    expect(provider.currentTable!.items[0].entries.length, 3);
  });

  test('başka çeteleye geçince geçmiş sıfırlanır', () async {
    final provider = await _seeded();
    await provider.setCellStatus(0, _day, 'V');
    await provider.undoLastEdit();
    expect(provider.canRedo, isTrue);

    expect(
      await provider.createTable(
        TallyTableModel(
          tableName: 'İkinci',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 10),
          statuses: [TallyStatus(code: 'V', label: 'Var', colorValue: 1)],
          items: [TallyItemModel(name: 'Ali')],
        ),
        // The free plan allows one tally; history is a premium-agnostic concern.
        isPremium: true,
      ),
      isTrue,
    );
    provider.changeTable(0);
    // History belongs to the tally that was open; it must not leak across.
    expect(provider.canUndo, isFalse);
    expect(provider.canRedo, isFalse);
  });
}
