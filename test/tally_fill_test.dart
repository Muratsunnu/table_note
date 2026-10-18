import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/utils/tally_fill.dart';

void main() {
  test('parmağın altındaki gün şeridin dışına taşmaz', () {
    expect(tallyDayAt(0, dayWidth: 48, dayCount: 31), 0);
    expect(tallyDayAt(47.9, dayWidth: 48, dayCount: 31), 0);
    expect(tallyDayAt(48, dayWidth: 48, dayCount: 31), 1);
    expect(tallyDayAt(-30, dayWidth: 48, dayCount: 31), 0);
    expect(tallyDayAt(5000, dayWidth: 48, dayCount: 31), 30);
  });

  test('kenara yaklaştıkça tablo hızlanır, ortada durur', () {
    expect(tallyAutoScrollStep(150, 300), 0);
    final nearRight = tallyAutoScrollStep(280, 300);
    final atRight = tallyAutoScrollStep(300, 300);
    expect(nearRight, greaterThan(0));
    expect(atRight, greaterThan(nearRight));
    // Parmak şeridin dışına taşsa da en hızlıda kalır.
    expect(tallyAutoScrollStep(400, 300), atRight);
    expect(tallyAutoScrollStep(10, 300), lessThan(0));
    expect(tallyAutoScrollStep(-50, 300), -atRight);
  });

  test('doldurma her iki yöne uzar, başlanan gün önizlenmez', () {
    final fill = TallyFill(itemIndex: 2, anchor: 5, code: 'İ');
    expect(fill.isEmpty, isTrue);

    fill.current = 8;
    expect((fill.first, fill.last), (5, 8));
    expect(fill.previews(2, 5), isFalse);
    expect(fill.previews(2, 7), isTrue);
    expect(fill.previews(1, 7), isFalse);
    expect(fill.previews(2, 9), isFalse);

    fill.current = 3;
    expect((fill.first, fill.last), (3, 5));
    expect(fill.previews(2, 3), isTrue);
    expect(fill.isEmpty, isFalse);
  });
}
