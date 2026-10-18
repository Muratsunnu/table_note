import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/shared_tally_operation.dart';

void main() {
  test('aynı öğeye art arda dokunmak tek işlem bırakır', () {
    final pending = PendingTallyChanges();
    pending.recordMark('oge-1', '2026-10-01', value: 'v', base: null);
    pending.recordMark('oge-1', '2026-10-02', value: 'y', base: null);
    expect(pending.length, 1);
    expect(pending.operations.single.days, {
      '2026-10-01': 'v',
      '2026-10-02': 'y',
    });
  });

  test('temel ilk dokunuşta donar, sonraki dokunuşlar ezmez', () {
    final pending = PendingTallyChanges();
    // Kayıtta "v" vardı; kullanıcı önce "y" yaptı, sonra fikir değiştirip
    // işareti kaldırdı. Sunucuya gidecek temel yine "v" olmalı -- kendi ara
    // adımımız "kayıttaki değer" sanılırsa çakışma gözden kaçar.
    pending.recordMark('oge-1', '2026-10-01', value: 'y', base: 'v');
    pending.recordMark('oge-1', '2026-10-01', value: null, base: 'y');
    final operation = pending.operations.single;
    expect(operation.days['2026-10-01'], isNull);
    expect(operation.dayBase['2026-10-01'], 'v');
  });

  test('yerelde oluşturulup yerelde silinen öğe kuyruktan tamamen düşer', () {
    final pending = PendingTallyChanges();
    pending.recordCreate('oge-1', 'Ahmet');
    pending.recordMark('oge-1', '2026-10-01', value: 'v', base: null);
    pending.recordDelete('oge-1');
    expect(pending.isEmpty, isTrue);
  });

  test('buluttaki öğenin silinmesi işlem olarak kalır', () {
    final pending = PendingTallyChanges();
    pending.recordMark('oge-1', '2026-10-01', value: 'v', base: null);
    pending.recordDelete('oge-1');
    expect(pending.operations.single.isDelete, isTrue);
  });

  test('ad değişikliği gün işaretlerini korur', () {
    final pending = PendingTallyChanges();
    pending.recordMark('oge-1', '2026-10-01', value: 'v', base: null);
    pending.recordRename('oge-1', 'Mehmet', base: 'Ahmet');
    final operation = pending.operations.single;
    expect(operation.name, 'Mehmet');
    expect(operation.nameBase, 'Ahmet');
    expect(operation.days, {'2026-10-01': 'v'});
  });

  test('"benimki kalsın" temeli sunucunun haliyle değiştirir', () {
    final pending = PendingTallyChanges();
    pending.recordMark('oge-1', '2026-10-01', value: 'y', base: 'v');
    pending.rebase('oge-1', {'2026-10-01': 'g', '2026-10-02': 'v'}, 'Ahmet');
    final operation = pending.operations.single;
    // Yalnızca göndereceğimiz günün temeli gerekiyor.
    expect(operation.dayBase, {'2026-10-01': 'g'});
    expect(operation.days, {'2026-10-01': 'y'});
  });

  test('sunucuda silinmiş öğe yeniden yeni öğe olur', () {
    final pending = PendingTallyChanges();
    pending.recordMark('oge-1', '2026-10-01', value: 'y', base: 'v');
    pending.rebase('oge-1', null, null);
    final operation = pending.operations.single;
    expect(operation.isNew, isTrue);
    expect(operation.dayBase, isEmpty);
  });

  test('kaydedilip geri okunan kuyruk aynı kalır', () {
    final pending = PendingTallyChanges();
    pending.recordCreate('oge-1', 'Ahmet');
    pending.recordMark('oge-1', '2026-10-01', value: 'v', base: null);
    pending.recordMark('oge-2', '2026-10-02', value: null, base: 'y');
    final restored = PendingTallyChanges.fromJson(pending.toJson());
    expect(restored.length, 2);
    expect(
      restored.operations.firstWhere((o) => o.itemId == 'oge-1').isNew,
      isTrue,
    );
    final second = restored.operations.firstWhere((o) => o.itemId == 'oge-2');
    expect(second.days['2026-10-02'], isNull);
    expect(second.dayBase['2026-10-02'], 'y');
  });
}
