import 'package:flutter/foundation.dart';

import 'app_localizations.dart';

/// Iki dilin ayni anahtarlari tasidigini testin dogrulayabilmesi icin.
/// Eksik anahtar hata vermez, sessizce genel hata metnine duser; bu yuzden
/// eksikligi ancak bir test yakalar.
@visibleForTesting
Map<String, Map<String, String>> get authStrings => const {
  'tr': _authTr,
  'en': _authEn,
};

extension AuthLocalizations on AppLocalizations {
  String authText(String key) =>
      (locale.languageCode == 'en' ? _authEn : _authTr)[key] ??
      (locale.languageCode == 'en' ? _authEn : _authTr)['failed']!;

  String authError(String code) => authText(switch (code) {
    'invalid_credentials' => 'credentials',
    'email_not_confirmed' => 'unconfirmed',
    'email_exists' || 'user_already_exists' => 'accountExists',
    'weak_password' => 'weakPassword',
    'same_password' => 'samePassword',
    'current_password_required' ||
    'current_password_mismatch' => 'currentPasswordError',
    'reauthentication_needed' ||
    'reauthentication_not_valid' => 'reauthenticate',
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' ||
    'over_sms_send_rate_limit' => 'rateLimit',
    'email_address_invalid' || 'validation_failed' => 'checkFields',
    'email_address_not_authorized' ||
    'email_provider_disabled' ||
    'signup_disabled' ||
    'provider_disabled' ||
    'service_unavailable' => 'unavailable',
    'otp_expired' ||
    'flow_state_expired' ||
    'flow_state_not_found' ||
    'bad_code_verifier' ||
    'callback_failed' => 'invalidLink',
    'session_not_found' ||
    'session_expired' ||
    'refresh_token_not_found' => 'sessionExpired',
    'network' => 'network',
    'apple_unavailable' => 'appleUnavailable',
    'apple_failed' => 'appleFailed',
    'oauth_launch_failed' => 'googleFailed',
    'delete_failed' => 'deleteFailed',
    _ => 'failed',
  });
}

const _authTr = {
  'login': 'Giriş yap',
  'register': 'Hesap oluştur',
  'name': 'Ad soyad',
  'email': 'E-posta',
  'password': 'Şifre',
  'newPassword': 'Yeni şifre',
  'currentPassword': 'Mevcut şifre',
  'confirmPassword': 'Şifreyi tekrar yaz',
  'passwordHint': 'En az 6 karakter',
  'showPassword': 'Şifreyi göster',
  'hidePassword': 'Şifreyi gizle',
  'forgot': 'Şifremi unuttum',
  'resetTitle': 'Şifreni sıfırla',
  'resetHelp':
      'Hesabının e-posta adresini yaz. Şifre sıfırlama bağlantısını bu adrese göndereceğiz.',
  'sendReset': 'Sıfırlama bağlantısı gönder',
  'backToLogin': 'Girişe dön',
  'or': 'veya',
  'google': 'Google ile devam et',
  'apple': 'Apple ile devam et',
  'accountPurpose': 'Yedekleme, paylaşım ve Premium hesabına bağlıdır.',
  'accountOptional': 'Tablolarını hesap açmadan da kullanabilirsin.',
  'emailHint': 'ornek@eposta.com',
  'confirmShort': 'Tekrar',
  'codeShort': 'Kod',
  'guestNotice':
      'Misafir olarak katıldığın tablolar var. Giriş yapınca misafir erişimin kapanır; bu tablolara kodla yeniden katılman gerekir. Kopyaları cihazında kalır.',
  'backToAccount': 'Hesaba dön',
  'signOutHint': 'Tabloların bu cihazda kalır.',
  'deleteAccount': 'Hesabı sil',
  'deleteHint': 'Hesabın ve buluttaki her şey kalıcı olarak silinir.',
  'deleteTitle': 'Hesabın kalıcı olarak silinsin mi?',
  'deleteCloud':
      'Buluttaki yedeklerin ve paylaştığın tablolar silinir. Katılanlar bu tablolara artık erişemez.',
  'deleteLocal': 'Bu cihazdaki tabloların ve çetelelerin silinmez.',
  'deleteSubscription':
      'Premium aboneliğin varsa kendiliğinden iptal olmaz. Ücretlendirmeyi durdurmak için {store} aboneliklerinden iptal et.',
  'deleteConfirmWord': 'SİL',
  'deleteConfirmLabel': 'Onaylamak için {word} yaz',
  'deleteConfirm': 'Hesabımı kalıcı olarak sil',
  'deleteFailed': 'Hesap silinemedi. Bağlantını kontrol edip yeniden dene.',
  'account_deleted': 'Hesabın silindi. Tabloların bu cihazda duruyor.',
  'verifyTitle': 'E-postanı doğrula',
  'verifyHelp':
      'E-postandaki bağlantıya dokun, sonra buraya dönüp devam et. Bağlantı başka bir cihazda hata verse de doğrulama tamamlanır.',
  'verifiedContinue': 'Doğruladım, devam et',
  'resend': 'Doğrulama e-postasını yeniden gönder',
  'changePassword': 'Şifreyi değiştir',
  'savePassword': 'Yeni şifreyi kaydet',
  'recoveryHelp': 'Hesabın için yeni bir şifre belirle.',
  'reauthenticate':
      'Güvenliğin için e-posta doğrulaması gerekiyor. Kod gönderip gelen kodu aşağıya yaz.',
  'sendCode': 'Doğrulama kodu gönder',
  'code': 'E-posta doğrulama kodu',
  'cancelRecovery': 'Vazgeç ve çıkış yap',
  'signOut': 'Bu cihazdan çıkış yap',
  'requiredName': 'Adını yaz.',
  'invalidEmail': 'Geçerli bir e-posta adresi yaz.',
  'requiredPassword': 'Şifreni yaz.',
  'weakPassword': 'Şifre en az 6 karakter olmalı.',
  'passwordMismatch': 'Şifreler aynı değil.',
  'credentials': 'E-posta veya şifre hatalı.',
  'unconfirmed': 'Giriş yapmadan önce e-posta adresini doğrula.',
  'accountExists':
      'Bu e-posta ile giriş yapmayı veya şifreni sıfırlamayı dene.',
  'samePassword': 'Yeni şifren mevcut şifrenden farklı olmalı.',
  'currentPasswordError': 'Mevcut şifreni kontrol edip yeniden dene.',
  'rateLimit': 'Çok sık istek gönderdin. Biraz bekleyip yeniden dene.',
  'checkFields': 'Girdiğin bilgileri kontrol edip yeniden dene.',
  'unavailable':
      'Bu giriş hizmeti şu anda kullanılamıyor. Daha sonra yeniden dene.',
  'invalidLink':
      'Bağlantı geçersiz veya süresi dolmuş. Yeni bir bağlantı iste ve isteği gönderdiğin cihazda aç.',
  'sessionExpired': 'Oturumun sona erdi. Yeniden giriş yap.',
  'network': 'Bağlantı kurulamadı. İnternetini kontrol edip yeniden dene.',
  'appleUnavailable': 'Apple ile giriş bu cihazda kullanılamıyor.',
  'appleFailed': 'Apple ile giriş tamamlanamadı. Yeniden dene.',
  'googleFailed': 'Google giriş ekranı açılamadı. Yeniden dene.',
  'failed': 'İşlem tamamlanamadı. Bağlantını kontrol edip yeniden dene.',
  'confirmation_sent':
      'Adresin kayıt için uygunsa doğrulama e-postası gönderildi. Gelen kutunu ve gereksiz posta klasörünü kontrol et.',
  'recovery_sent':
      'Bu adresle bir hesap varsa şifre sıfırlama bağlantısı gönderildi. Bağlantıyı bu cihazda aç.',
  'reauthentication_sent': 'Doğrulama kodu e-posta adresine gönderildi.',
  'password_updated': 'Şifren güncellendi.',
  'oauth_continue':
      'Google ekranında girişini tamamla. İptal ettiysen yeniden deneyebilirsin.',
  'profile_name_not_saved': 'Giriş yapıldı ancak adın kaydedilemedi.',
  'wait': '{seconds} sn sonra yeniden gönderebilirsin.',
};

const _authEn = {
  'login': 'Sign in',
  'register': 'Create account',
  'name': 'Full name',
  'email': 'Email',
  'password': 'Password',
  'newPassword': 'New password',
  'currentPassword': 'Current password',
  'confirmPassword': 'Confirm password',
  'passwordHint': 'At least 6 characters',
  'showPassword': 'Show password',
  'hidePassword': 'Hide password',
  'forgot': 'Forgot password?',
  'resetTitle': 'Reset your password',
  'resetHelp':
      'Enter your account email. We will send a password reset link to this address.',
  'sendReset': 'Send reset link',
  'backToLogin': 'Back to sign in',
  'or': 'or',
  'google': 'Continue with Google',
  'apple': 'Continue with Apple',
  'accountPurpose': 'Backup, sharing and Premium are tied to your account.',
  'accountOptional': 'You can keep using your tables without one.',
  'emailHint': 'name@example.com',
  'confirmShort': 'Repeat',
  'codeShort': 'Code',
  'guestNotice':
      'You have joined tables as a guest. Signing in ends your guest access, so you will need to rejoin those tables with their codes. Their copies stay on this device.',
  'backToAccount': 'Back to account',
  'signOutHint': 'Your tables stay on this device.',
  'deleteAccount': 'Delete account',
  'deleteHint': 'Permanently deletes your account and everything in the cloud.',
  'deleteTitle': 'Permanently delete your account?',
  'deleteCloud':
      'Your cloud backups and the tables you share are deleted. People who joined lose access to them.',
  'deleteLocal': 'Tables and tallies on this device are not deleted.',
  'deleteSubscription':
      'A Premium subscription is not cancelled automatically. To stop being charged, cancel it in your {store} subscriptions.',
  'deleteConfirmWord': 'DELETE',
  'deleteConfirmLabel': 'Type {word} to confirm',
  'deleteConfirm': 'Permanently delete my account',
  'deleteFailed':
      'Could not delete the account. Check your connection and try again.',
  'account_deleted':
      'Your account was deleted. Your tables are still on this device.',
  'verifyTitle': 'Verify your email',
  'verifyHelp':
      'Tap the link in your email, then come back here and continue. Even if the link shows an error on another device, your email is still verified.',
  'verifiedContinue': 'I have verified, continue',
  'resend': 'Resend verification email',
  'changePassword': 'Change password',
  'savePassword': 'Save new password',
  'recoveryHelp': 'Choose a new password for your account.',
  'reauthenticate':
      'For your security, email verification is required. Request a code and enter it below.',
  'sendCode': 'Send verification code',
  'code': 'Email verification code',
  'cancelRecovery': 'Cancel and sign out',
  'signOut': 'Sign out on this device',
  'requiredName': 'Enter your name.',
  'invalidEmail': 'Enter a valid email address.',
  'requiredPassword': 'Enter your password.',
  'weakPassword': 'Use at least 6 characters.',
  'passwordMismatch': 'The passwords do not match.',
  'credentials': 'Incorrect email or password.',
  'unconfirmed': 'Verify your email address before signing in.',
  'accountExists': 'Try signing in with this email or resetting your password.',
  'samePassword': 'Your new password must differ from your current password.',
  'currentPasswordError': 'Check your current password and try again.',
  'rateLimit': 'Too many requests. Please wait before trying again.',
  'checkFields': 'Check the information you entered and try again.',
  'unavailable':
      'This sign-in service is currently unavailable. Please try again later.',
  'invalidLink':
      'This link is invalid or expired. Request a new link and open it on the device that requested it.',
  'sessionExpired': 'Your session has expired. Please sign in again.',
  'network': 'Could not connect. Check your internet connection and try again.',
  'appleUnavailable': 'Sign in with Apple is unavailable on this device.',
  'appleFailed': 'Could not complete Apple sign-in. Please try again.',
  'googleFailed': 'Could not open Google sign-in. Please try again.',
  'failed':
      'Could not complete the action. Check your connection and try again.',
  'confirmation_sent':
      'If the address is eligible for registration, a verification email has been sent. Check your inbox and spam folder.',
  'recovery_sent':
      'If an account exists for this address, a reset link has been sent. Open it on this device.',
  'reauthentication_sent': 'A verification code has been sent to your email.',
  'password_updated': 'Your password has been updated.',
  'oauth_continue':
      'Complete sign-in in the Google window. If you canceled, you can try again.',
  'profile_name_not_saved':
      'You are signed in, but your name could not be saved.',
  'wait': 'You can send again in {seconds} s.',
};
