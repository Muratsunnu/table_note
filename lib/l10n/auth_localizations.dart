import 'app_localizations.dart';

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
  'offlineHelp':
      'Hesap yalnızca çevrimiçi özellikler için gerekir. Tablolarını giriş yapmadan kullanabilirsin.',
  'verifyTitle': 'E-postanı doğrula',
  'verifyHelp':
      'E-postandaki doğrulama bağlantısını bu cihazda aç. Gelen kutusu ve gereksiz posta klasörünü kontrol et.',
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
      'Adresin kayıt için uygunsa doğrulama e-postası gönderildi. Gelen kutunu kontrol et.',
  'recovery_sent':
      'Bu adresle bir hesap varsa şifre sıfırlama bağlantısı gönderildi. Bağlantıyı bu cihazda aç.',
  'reauthentication_sent': 'Doğrulama kodu e-posta adresine gönderildi.',
  'password_updated': 'Şifren güncellendi.',
  'oauth_continue':
      'Google ekranında girişini tamamla. İptal ettiysen yeniden deneyebilirsin.',
  'profile_name_not_saved': 'Giriş yapıldı ancak adın kaydedilemedi.',
  'wait': 'Yeniden göndermek için bekle',
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
  'offlineHelp':
      'An account is only needed for online features. You can use your tables without signing in.',
  'verifyTitle': 'Verify your email',
  'verifyHelp':
      'Open the verification link in your email on this device. Check your inbox and spam folder.',
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
      'If the address is eligible for registration, a verification email has been sent. Check your inbox.',
  'recovery_sent':
      'If an account exists for this address, a reset link has been sent. Open it on this device.',
  'reauthentication_sent': 'A verification code has been sent to your email.',
  'password_updated': 'Your password has been updated.',
  'oauth_continue':
      'Complete sign-in in the Google window. If you canceled, you can try again.',
  'profile_name_not_saved':
      'You are signed in, but your name could not be saved.',
  'wait': 'Wait before sending again',
};
