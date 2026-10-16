import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/supabase_service.dart';

/// Buluttaki kimlik degisip bu cihazdaki ortak tablolarin baglantisi
/// koptugunda cagrilir. [ownedToo] false ise yalnizca katilinanlar koptu.
typedef SharedAccessLost = void Function({required bool ownedToo});

/// Stores codes rather than server messages so feedback follows the app locale.
class AuthProvider extends ChangeNotifier {
  final SupabaseClient? _client;
  final SharedAccessLost? _onSharedAccessLost;
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  bool _isLoading = false;
  bool _disposed = false;
  bool _isRecovering = false;
  // Şifre sıfırlama hesap ekranında kodla başladıysa ekran zaten açıktır.
  bool _recoveryInPlace = false;
  bool _needsReauthentication = false;
  bool _callbackFailed = false;
  String? _errorMessage;
  String? _notice;
  DateTime? _nextEmailAt;

  AuthProvider({SupabaseClient? client, SharedAccessLost? onSharedAccessLost})
    : _client = client ?? SupabaseService.client,
      _onSharedAccessLost = onSharedAccessLost {
    _user = _client?.auth.currentUser;
    _authSubscription = _client?.auth.onAuthStateChange.listen(
      (state) {
        if (_disposed) return;
        final previous = _user;
        _user = state.session?.user;
        // Google girisi tarayicidan dondugunde oturum buradan degisir;
        // e-posta ve Apple girisi de ayni olayi uretir. Tek kontrol noktasi.
        if (replacesGuest(previous, _user)) {
          _onSharedAccessLost?.call(ownedToo: false);
        }
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _isRecovering = true;
          _errorMessage = null;
          _notice = null;
        } else if (state.event == AuthChangeEvent.signedOut) {
          _isRecovering = false;
          _recoveryInPlace = false;
          _needsReauthentication = false;
        } else if (state.event == AuthChangeEvent.signedIn) {
          _errorMessage = null;
          _notice = null;
          _callbackFailed = false;
        }
        _notify();
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed) return;
        _errorMessage = _errorCode(error);
        _callbackFailed =
            error is AuthPKCEGrantCodeExchangeError ||
            {
              'otp_expired',
              'flow_state_expired',
              'flow_state_not_found',
              'bad_code_verifier',
            }.contains(_errorMessage);
        _notify();
      },
    );
  }

  bool get isAvailable => _client != null;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  bool get isRecovering => _isRecovering;

  /// Şifre sıfırlama için hesap ekranının açılması gerekiyor mu? Eski bir
  /// e-postadaki bağlantıyla başlayan sıfırlamada evet; ekranda kod yazılarak
  /// başlayanda ekran zaten açıktır, ikincisi açılmaz.
  bool get recoveryNeedsScreen => isRecovering && !_recoveryInPlace;
  bool get callbackFailed => _callbackFailed;
  bool get needsReauthentication => _needsReauthentication;
  bool get supportsApple =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get hasEmailIdentity =>
      _user?.identities?.any((identity) => identity.provider == 'email') ??
      false;
  User? get user => _user;
  String? get email => _user?.email;
  String? get displayName {
    final value = _user?.userMetadata?['full_name'];
    return value is String ? value : null;
  }

  String? get errorMessage => _errorMessage;
  String? get notice => _notice;
  int get emailCooldownSeconds {
    final milliseconds =
        _nextEmailAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void clearFeedback() {
    _errorMessage = null;
    _notice = null;
    _callbackFailed = false;
    _notify();
  }

  /// Oturum yoksa sessizce anonim bir tane acar. Tabloya katilan kisi bunu
  /// hic gormez: ne form, ne e-posta, ne dogrulama. Zaten oturum varsa —
  /// gercek hesap ya da daha onceki anonim oturum — dokunmaz.
  ///
  /// Kimlik cihaza baglidir: uygulama silinirse geri gelmez.
  Future<bool> ensureAnonymousSession() async {
    if (_client == null) return false;
    if (_client.auth.currentUser != null) return true;
    return _run(() async {
      await _client.auth.signInAnonymously();
    });
  }

  /// Gercek bir kimligi olmayan, yalnizca katilmak icin acilmis oturum.
  bool get isAnonymous => _user?.isAnonymous ?? false;

  /// Gercek bir hesabi olan kullanici.
  ///
  /// [isSignedIn] bunu soylemez: kodla tabloya katilmak icin sessizce acilan
  /// misafir oturumu da "giris yapmis" sayilir. Hesap ekrani, satin alma ve
  /// bulut yedekleme "oturum var mi" diye degil "hesap var mi" diye
  /// sormali; yoksa misafire cikis dugmesi gosterilir ya da abonelik,
  /// uygulama silinince kaybolan bir kimlige baglanir.
  bool get hasAccount => isSignedIn && !isAnonymous;

  /// Misafir oturumunun yerini baska bir hesap mi aldi?
  ///
  /// Kodla katilinan tablolardaki uyelik misafir kimligine aittir. Kullanici
  /// sonradan giris yaparsa o kimlik geri gelmez; katildigi tablolar bu
  /// cihazda sahipsiz kalir ve temizlenmeleri gerekir.
  @visibleForTesting
  static bool replacesGuest(User? before, User? after) =>
      before != null &&
      before.isAnonymous &&
      after != null &&
      !after.isAnonymous &&
      after.id != before.id;

  Future<bool> signInWithEmail(String email, String password) => _run(() async {
    await _client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  });

  Future<bool> signUp(String name, String email, String password) =>
      _run(() async {
        final response = await _client!.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': name.trim()},
          emailRedirectTo: AppConfig.authRedirectUrl,
        );
        if (response.session == null) {
          _notice = 'confirmation_sent';
          _markEmailSent();
        }
      });

  /// Kayıt e-postasındaki 6 haneli kodla adresi doğrular ve oturumu açar.
  /// Kod, e-posta hangi cihazda okunursa okunsun çalışır.
  Future<bool> verifySignupCode(String email, String code) =>
      _verifyCode(email, code, OtpType.signup);

  /// Şifre sıfırlama e-postasındaki kodla oturumu açar; ardından yeni şifre
  /// sorulur ([isRecovering]).
  Future<bool> verifyRecoveryCode(String email, String code) =>
      _verifyCode(email, code, OtpType.recovery);

  Future<bool> _verifyCode(String email, String code, OtpType type) =>
      _run(() async {
        final recovery = type == OtpType.recovery;
        // Oturum olayı çağrı dönmeden gelir; bayrak ondan önce kurulur.
        if (recovery) _recoveryInPlace = true;
        var verified = false;
        try {
          await _client!.auth.verifyOTP(
            email: email.trim(),
            token: code.trim(),
            type: type,
          );
          verified = true;
        } on AuthException catch (error) {
          // Sunucu yanlış kodla süresi dolmuş kodu ayırmaz.
          if (error.code == 'otp_expired') {
            throw const AuthException('Invalid code', code: 'code_invalid');
          }
          rethrow;
        } finally {
          if (recovery && !verified) _recoveryInPlace = false;
        }
      });

  Future<bool> resendConfirmation(String email) => _run(() async {
    _checkEmailCooldown();
    await _client!.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: AppConfig.authRedirectUrl,
    );
    _markEmailSent();
    _notice = 'confirmation_sent';
  });

  Future<bool> requestPasswordReset(String email) => _run(() async {
    _checkEmailCooldown();
    await _client!.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.authRedirectUrl,
    );
    _markEmailSent();
    // Avoid disclosing whether an address is registered.
    _notice = 'recovery_sent';
  });

  Future<bool> sendReauthenticationCode() => _run(() async {
    _checkEmailCooldown();
    await _client!.auth.reauthenticate();
    _markEmailSent();
    _needsReauthentication = true;
    _notice = 'reauthentication_sent';
  });

  Future<bool> updatePassword(
    String password, {
    String? currentPassword,
    String? nonce,
  }) => _run(() async {
    await _client!.auth.updateUser(
      UserAttributes(
        password: password,
        currentPassword: _isRecovering ? null : currentPassword,
        nonce: nonce?.trim().isEmpty == true ? null : nonce?.trim(),
      ),
    );
    _isRecovering = false;
    _recoveryInPlace = false;
    _needsReauthentication = false;
    _notice = 'password_updated';
  });

  Future<bool> signInWithGoogle() => _run(() async {
    final started = await _client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.authRedirectUrl,
    );
    if (!started) {
      throw const AuthException('Launch failed', code: 'oauth_launch_failed');
    }
    _notice = 'oauth_continue';
  });

  Future<bool> signInWithApple() => _run(() async {
    if (!supportsApple || !await SignInWithApple.isAvailable()) {
      throw const AuthException(
        'Unsupported platform',
        code: 'apple_unavailable',
      );
    }
    final rawNonce = _client!.auth.generateRawNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    final token = credential.identityToken;
    if (token == null) {
      throw const AuthException('Missing token', code: 'apple_failed');
    }
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: token,
      nonce: rawNonce,
    );
    // Apple supplies the name only on first consent; do not overwrite it later.
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (name.isNotEmpty && response.user != null) {
      try {
        await _client.auth.updateUser(
          UserAttributes(data: {'full_name': name}),
        );
        // The profile insert trigger ran before the metadata update.
        await _client
            .from('profiles')
            .update({'display_name': name})
            .eq('id', response.user!.id);
      } catch (_) {
        _notice = 'profile_name_not_saved';
      }
    }
  });

  /// Hesabi ve buluttaki her seyi kalici olarak siler.
  ///
  /// Sunucudaki kullanici silindikten sonra yerel oturum da birakilir;
  /// sunucuya sorulsa artik var olmayan bir kullanici icin hata donerdi.
  Future<bool> deleteAccount() => _run(() async {
    try {
      await _client!.rpc('delete_my_account');
    } on PostgrestException {
      throw const AuthException('Delete failed', code: 'delete_failed');
    }
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Hesap zaten silindi; yerel temizlik basarisiz olsa da kullaniciya
      // "silinemedi" demek yanlis olurdu.
    }
    _user = null;
    _isRecovering = false;
    _recoveryInPlace = false;
    _needsReauthentication = false;
    _notice = 'account_deleted';
    _onSharedAccessLost?.call(ownedToo: true);
  });

  Future<bool> signOut() => _run(() async {
    await _client!.auth.signOut(scope: SignOutScope.local);
    _user = null;
    _isRecovering = false;
    _recoveryInPlace = false;
    _needsReauthentication = false;
  });

  void _checkEmailCooldown() {
    if (emailCooldownSeconds > 0) {
      throw const AuthException(
        'Wait before retrying',
        code: 'over_email_send_rate_limit',
      );
    }
  }

  void _markEmailSent() =>
      _nextEmailAt = DateTime.now().add(const Duration(seconds: 60));

  Future<bool> _run(Future<void> Function() operation) async {
    if (_isLoading || _disposed) return false;
    _errorMessage = null;
    _notice = null;
    if (_client == null) {
      _errorMessage = 'service_unavailable';
      _notify();
      return false;
    }
    _isLoading = true;
    _notify();
    try {
      await operation();
      _user = _client.auth.currentUser;
      return true;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled) {
        _errorMessage = 'apple_failed';
      }
      return false;
    } catch (error) {
      _errorMessage = _errorCode(error);
      if (_errorMessage == 'reauthentication_needed' ||
          _errorMessage == 'reauthentication_not_valid') {
        _needsReauthentication = true;
      }
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  String _errorCode(Object error) {
    if (error is AuthRetryableFetchException || error is TimeoutException) {
      return 'network';
    }
    if (error is AuthPKCEGrantCodeExchangeError) return 'callback_failed';
    if (error is AuthException) {
      if (error.statusCode == '429') return 'over_request_rate_limit';
      return error.code ?? 'auth_failed';
    }
    return 'auth_failed';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
