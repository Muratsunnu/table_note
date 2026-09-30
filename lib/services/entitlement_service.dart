import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class Entitlement {
  final bool isPremium;
  final DateTime? validUntil;

  const Entitlement({required this.isPremium, this.validUntil});
}

class EntitlementService {
  static const _validUntilKey = 'premium_valid_until';

  Future<Entitlement> loadCached() async {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null) return const Entitlement(isPremium: false);
    final preferences = await SharedPreferences.getInstance();
    // Never reuse the old, account-independent cache for a different user.
    final rawDate = preferences.getString('${_validUntilKey}_$userId');
    final validUntil = rawDate == null ? null : DateTime.tryParse(rawDate);
    return Entitlement(
      isPremium: validUntil?.isAfter(DateTime.now().toUtc()) ?? false,
      validUntil: validUntil,
    );
  }

  Future<Entitlement> refresh() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return loadCached();

    final response = await client
        .from('subscriptions')
        .select('status, expires_at')
        .eq('user_id', user.id)
        .maybeSingle();
    final validUntil = response == null
        ? null
        : DateTime.tryParse(response['expires_at']?.toString() ?? '');
    final status = response?['status']?.toString();
    final isPremium =
        (status == 'active' ||
            status == 'trialing' ||
            status == 'grace_period') &&
        (validUntil?.isAfter(DateTime.now().toUtc()) ?? false);
    await _cache(user.id, isPremium ? validUntil : null);
    return Entitlement(isPremium: isPremium, validUntil: validUntil);
  }

  Future<Entitlement> verifyPurchase({
    required String productId,
    required String verificationData,
    required String source,
  }) async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Satın alma doğrulaması için giriş yapılmalı.');
    }
    final userId = client.auth.currentUser!.id;

    final response = await client.functions.invoke(
      'verify-google-play-purchase',
      body: {
        'productId': productId,
        'verificationData': verificationData,
        'source': source,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Satın alma sunucuda doğrulanamadı.');
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final validUntil = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    final isPremium =
        data['isPremium'] == true &&
        (validUntil?.isAfter(DateTime.now().toUtc()) ?? false);
    await _cache(userId, isPremium ? validUntil : null);
    return Entitlement(isPremium: isPremium, validUntil: validUntil);
  }

  Future<void> _cache(String userId, DateTime? validUntil) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '${_validUntilKey}_$userId';
    if (validUntil == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, validUntil.toUtc().toIso8601String());
    }
  }
}
