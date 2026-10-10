import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_note/providers/backup_reminder_provider.dart';

/// Elle yedeklemenin hatırlatma kuralları: 3 günden sonra satır, 7 günden
/// sonra kart; "sonra" denince kart ertesi güne kalır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const user = 'user-1';
  late DateTime now;
  late BackupReminderProvider reminder;

  Future<void> start({Map<String, Object> saved = const {}}) async {
    SharedPreferences.setMockInitialValues(saved);
    now = DateTime(2026, 10, 10, 9);
    reminder = BackupReminderProvider(now: () => now);
    addTearDown(reminder.dispose);
    await Future<void>.delayed(Duration.zero);
  }

  /// Son yedek [days] gün önce alınmış, tablolar az önce değişmiş.
  Future<BackupStatus> statusAfter(int days) async {
    await reminder.markBackedUp(
      user,
      at: now.subtract(Duration(days: days, minutes: 1)),
    );
    return reminder.statusFor(userId: user, canBackUp: true, latestChange: now);
  }

  test('ilk üç gün hiçbir şey göstermez', () async {
    await start();
    expect((await statusAfter(0)).nudge, BackupNudge.none);
    expect((await statusAfter(2)).nudge, BackupNudge.none);
  });

  test('üç günden sonra satır, yedi günden sonra kart', () async {
    await start();

    final third = await statusAfter(3);
    expect(third.nudge, BackupNudge.line);
    expect(third.days, 3);
    expect((await statusAfter(6)).nudge, BackupNudge.line);

    final seventh = await statusAfter(7);
    expect(seventh.nudge, BackupNudge.card);
    expect(seventh.days, 7);
    expect((await statusAfter(30)).nudge, BackupNudge.card);
  });

  test('"sonra" kartı o gün gizler, ertesi gün yeniden getirir', () async {
    await start();
    expect((await statusAfter(8)).nudge, BackupNudge.card);

    await reminder.snooze();
    BackupStatus current() =>
        reminder.statusFor(userId: user, canBackUp: true, latestChange: now);
    // Kart gider, sessiz satır kalır.
    expect(current().nudge, BackupNudge.line);

    // Aynı gün, saatler sonra: hâlâ gizli.
    now = DateTime(2026, 10, 10, 23, 30);
    expect(current().nudge, BackupNudge.line);

    // Ertesi sabah: kart geri gelir, gün sayısı da ilerlemiştir.
    now = DateTime(2026, 10, 11, 8);
    expect(current().nudge, BackupNudge.card);
    expect(current().days, 8);
  });

  test('yedekleyince hatırlatma kalkar', () async {
    await start();
    expect((await statusAfter(9)).nudge, BackupNudge.card);

    await reminder.markBackedUp(user);

    expect(
      reminder
          .statusFor(userId: user, canBackUp: true, latestChange: now)
          .nudge,
      BackupNudge.none,
    );
    expect(reminder.daysSinceBackup(user), 0);
  });

  test('son yedekten sonra bir şey değişmediyse hatırlatmaz', () async {
    await start();
    await reminder.markBackedUp(
      user,
      at: now.subtract(const Duration(days: 20)),
    );

    final status = reminder.statusFor(
      userId: user,
      canBackUp: true,
      // Tablolara en son yedekten önce dokunulmuş.
      latestChange: now.subtract(const Duration(days: 25)),
    );

    expect(status.nudge, BackupNudge.none);
  });

  test('hiç yedek almamış kişiye kart çıkar, gün sayısı yoktur', () async {
    await start();

    final status = reminder.statusFor(
      userId: user,
      canBackUp: true,
      latestChange: now,
    );

    expect(status.nudge, BackupNudge.card);
    expect(status.days, isNull);
  });

  test('yedekleyemeyen kişiye ya da boş cihazda hatırlatmaz', () async {
    await start();

    // Premium'u ya da hesabı yok.
    expect(
      reminder
          .statusFor(userId: user, canBackUp: false, latestChange: now)
          .nudge,
      BackupNudge.none,
    );
    // Yedeklenecek tablo yok.
    expect(
      reminder
          .statusFor(userId: user, canBackUp: true, latestChange: null)
          .nudge,
      BackupNudge.none,
    );
  });

  test('yedek zamanı hesaba özeldir ve saklanır', () async {
    await start();
    await reminder.markBackedUp(user);
    await reminder.snooze();

    expect(reminder.lastBackup('user-2'), isNull);

    // Uygulama yeniden açıldı.
    final reopened = BackupReminderProvider(now: () => now);
    addTearDown(reopened.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(reopened.daysSinceBackup(user), 0);
    expect(reopened.lastBackup('user-2'), isNull);
  });

  test(
    'buluttaki daha yeni yedek esas alınır, daha eskisi yok sayılır',
    () async {
      await start();
      await reminder.markBackedUp(
        user,
        at: now.subtract(const Duration(days: 10)),
      );

      await reminder.syncFromCloud(user, now.subtract(const Duration(days: 2)));
      expect(reminder.daysSinceBackup(user), 2);

      await reminder.syncFromCloud(
        user,
        now.subtract(const Duration(days: 30)),
      );
      expect(reminder.daysSinceBackup(user), 2);
    },
  );
}
