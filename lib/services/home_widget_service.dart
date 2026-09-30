import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/home_widget_snapshot.dart';
import '../providers/table_provider.dart';
import '../providers/tally_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class HomeWidgetService extends ChangeNotifier with WidgetsBindingObserver {
  static const channel = MethodChannel('com.muratstudio.tablenote/home_widget');
  final TableProvider tables;
  final TallyProvider tallies;
  final LocaleProvider locale;
  final ThemeProvider theme;
  StreamSubscription<Uri>? _links;
  Timer? _timer;
  bool _disposed = false;
  bool _publishing = false;
  bool _dirty = false;
  String? _lastPublished;
  String? _lastUri;
  DateTime? _lastUriAt;
  HomeWidgetRequest? pending;
  String? syncError;

  HomeWidgetService(this.tables, this.tallies, this.locale, this.theme) {
    for (final source in [tables, tallies, locale, theme]) {
      source.addListener(_schedulePublish);
    }
    WidgetsBinding.instance.addObserver(this);
    if (supported) _initialize();
  }

  bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform);

  Future<void> _initialize() async {
    final links = AppLinks();
    _links = links.uriLinkStream.listen(_accept, onError: (Object _) {});
    try {
      final uri = await links.getInitialLink();
      if (!_disposed && uri != null) _accept(uri);
    } on MissingPluginException {
      // Desktop, static tests or a host that has not been rebuilt yet.
    } on PlatformException {
      // A failed initial link does not prevent normal app use.
    }
    _schedulePublish();
  }

  void _accept(Uri uri) {
    if (_disposed) return;
    final request = HomeWidgetRequest.parse(uri);
    if (request == null) return;
    final now = DateTime.now();
    if (_lastUri == uri.toString() &&
        _lastUriAt != null &&
        now.difference(_lastUriAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastUri = uri.toString();
    _lastUriAt = now;
    pending = request;
    notifyListeners();
  }

  void consume(HomeWidgetRequest request) {
    if (identical(pending, request)) pending = null;
  }

  void navigationChanged() {
    if (!_disposed && pending != null) notifyListeners();
  }

  void _schedulePublish() {
    if (_disposed || !supported) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), publish);
  }

  Future<void> publish() async {
    if (_disposed || !supported || tables.isLoading || tallies.isLoading) {
      return;
    }
    if (_publishing) {
      _dirty = true;
      return;
    }
    _publishing = true;
    try {
      final data = HomeWidgetSnapshot.encode(
        tables: tables.tables,
        tallies: tallies.tables,
        language: locale.locale.languageCode,
        dark: theme.isDarkMode,
        palette: AppTheme.widgetPalette(
          theme.isDarkMode ? AppTheme.darkTheme : AppTheme.theme,
        ),
        // So the widget's rows never contradict the order shown on screen.
        orders: {
          for (final table in tables.tables)
            if (tables.sortedOrderFor(table) case final order?) table.id: order,
          for (final tally in tallies.tables)
            if (tallies.sortedOrderFor(tally) case final order?)
              tally.id: order,
        },
      );
      if (data != _lastPublished) {
        await channel.invokeMethod<void>('publish', data);
        _lastPublished = data;
      }
      if (syncError != null) {
        syncError = null;
        if (!_disposed) notifyListeners();
      }
    } on MissingPluginException {
      syncError = 'not_installed';
      if (!_disposed) notifyListeners();
    } on PlatformException catch (error) {
      syncError = error.code;
      if (!_disposed) notifyListeners();
    } finally {
      _publishing = false;
      if (_dirty) {
        _dirty = false;
        _schedulePublish();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedulePublish();
      navigationChanged();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _links?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final source in [tables, tallies, locale, theme]) {
      source.removeListener(_schedulePublish);
    }
    super.dispose();
  }
}

/// A widget tap waits for an open form/route to close, preserving unsaved input.
class HomeWidgetNavigationObserver extends NavigatorObserver {
  final VoidCallback onChanged;
  HomeWidgetNavigationObserver(this.onChanged);
  void _changed() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _changed();
}
