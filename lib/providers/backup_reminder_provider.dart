import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/storage_service.dart';

/// Yedekleme hatırlatmasının ne kadar öne çıkacağı.
enum BackupNudge {
  /// Hatırlatılacak bir şey yok.
  none,

  /// Başlığın altında küçük "Son yedekleme: 3 gün önce" satırı.
  line,

  /// Ekranın üstünde "şimdi yedekle / sonra" kartı.
  card,
}

@immutable
class BackupStatus {
  const BackupStatus(this.nudge, [this.days]);

  static const none = BackupStatus(BackupNudge.none);

  final BackupNudge nudge;

  /// Son yedekten bu yana geçen gün; hiç yedek alınmadıysa null.
  final int? days;
}

/// Elle yedeklemeyi hatırlatan durum: hesabın son yedeği ne zaman alındı ve
/// hatırlatmaya bugün "sonra" dendi mi.
///
/// Yedekleme bilerek elle yapılır; burası yalnızca hatırlatır. Kural:
/// 3 günden sonra küçük bir satır, 7 günden sonra kart. Karta "sonra"
/// denirse o gün bir daha çıkmaz, ertesi gün yeniden gelir.
class BackupReminderProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  BackupReminderProvider({DateTime Function()? now})
    : _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  static const int lineAfterDays = 3;
  static const int cardAfterDays = 7;

  final DateTime Function() _now;
  final Map<String, DateTime> _lastBackups = {};
  String? _snoozedDay;
  bool _loaded = false;
  bool _disposed = false;

  Future<void> _load() async {
    final backups = await StorageService.loadLastBackups();
    final snoozed = await StorageService.loadBackupSnoozeDay();
    if (_disposed) return;
    // Yükleme sürerken alınmış bir yedek eskisiyle ezilmez.
    for (final entry in backups.entries) {
      _lastBackups.putIfAbsent(entry.key, () => entry.value);
    }
    _snoozedDay ??= snoozed;
    _loaded = true;
    notifyListeners();
  }

  DateTime? lastBackup(String? userId) =>
      userId == null ? null : _lastBackups[userId];

  /// Son yedekten bu yana geçen tam gün; hiç yedek yoksa null.
  int? daysSinceBackup(String? userId) {
    final last = lastBackup(userId);
    return last == null ? null : _now().difference(last).inDays;
  }

  static String _dayKey(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  bool get _snoozedToday => _snoozedDay == _dayKey(_now());

  /// Bu hesap için şu an ne gösterilmeli.
  ///
  /// [canBackUp]: giriş yapmış ve yedekleme hakkı olan kullanıcı.
  /// [latestChange]: yedeklenecek tablo ve çetelelerdeki en son değişiklik;
  /// hiç yoksa null. Son yedekten sonra bir şey değişmediyse hatırlatılmaz.
  BackupStatus statusFor({
    required String? userId,
    required bool canBackUp,
    required DateTime? latestChange,
  }) {
    if (!_loaded || !canBackUp || userId == null || latestChange == null) {
      return BackupStatus.none;
    }
    final last = _lastBackups[userId];
    if (last != null && !latestChange.isAfter(last)) return BackupStatus.none;

    final days = daysSinceBackup(userId);
    if (days == null || days >= cardAfterDays) {
      // "Sonra" denmişse o gün kart yerine sessiz satır kalır.
      return BackupStatus(
        _snoozedToday ? BackupNudge.line : BackupNudge.card,
        days,
      );
    }
    return days >= lineAfterDays
        ? BackupStatus(BackupNudge.line, days)
        : BackupStatus.none;
  }

  /// "Sonra": kart bugün bir daha çıkmaz, yarın yeniden gelir.
  Future<void> snooze() async {
    _snoozedDay = _dayKey(_now());
    notifyListeners();
    await StorageService.saveBackupSnoozeDay(_snoozedDay);
  }

  /// Elle yedekleme tamamlandı.
  Future<void> markBackedUp(String userId, {DateTime? at}) async {
    _lastBackups[userId] = at ?? _now();
    notifyListeners();
    await StorageService.saveLastBackups(_lastBackups);
  }

  /// Buluttaki en yeni yedek daha yeniyse onu esas alır: yedek başka bir
  /// cihazdan alınmış ya da uygulama yeniden kurulmuş olabilir.
  Future<void> syncFromCloud(String userId, DateTime newest) async {
    final known = _lastBackups[userId];
    if (known != null && !newest.isAfter(known)) return;
    await markBackedUp(userId, at: newest);
  }

  /// Yalnızca geliştirme derlemesinde: hatırlatmaları denemek için son
  /// yedeği [days] gün geriye alır; null verilirse yedek kaydını siler.
  Future<void> debugSetDaysSinceBackup(String userId, int? days) async {
    if (!kDebugMode) return;
    if (days == null) {
      _lastBackups.remove(userId);
    } else {
      _lastBackups[userId] = _now().subtract(Duration(days: days));
    }
    _snoozedDay = null;
    notifyListeners();
    await StorageService.saveLastBackups(_lastBackups);
    await StorageService.saveBackupSnoozeDay(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama günlerce arka planda kalmış olabilir; gün değiştiyse
    // hatırlatmalar yeniden hesaplanır.
    if (state == AppLifecycleState.resumed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
