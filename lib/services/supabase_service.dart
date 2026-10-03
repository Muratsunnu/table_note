import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseService {
  SupabaseService._();

  static bool _isInitialized = false;
  static String? _initializationError;

  static bool get isAvailable => _isInitialized;
  static String? get initializationError => _initializationError;

  static SupabaseClient? get client =>
      _isInitialized ? Supabase.instance.client : null;

  static Future<void> initialize() async {
    if (!AppConfig.hasSupabaseConfig || _isInitialized) return;

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
      );
      _isInitialized = true;
      _initializationError = null;
    } catch (error) {
      _initializationError = error.toString();
      debugPrint('Supabase başlatılamadı: $error');
    }
  }
}
