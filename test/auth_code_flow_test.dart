import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_note/providers/auth_provider.dart';

/// E-postayla gelen 6 haneli kodun doğrulanması: istek gerçek Supabase
/// istemcisinden geçer, yalnızca ağ sahtedir.

String _jwt() {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return [
    part({'alg': 'HS256', 'typ': 'JWT'}),
    part({'sub': 'user-1', 'exp': 4102444800, 'role': 'authenticated'}),
    'signature',
  ].join('.');
}

http.Response _session() => http.Response(
  jsonEncode({
    'access_token': _jwt(),
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh',
    'user': {
      'id': 'user-1',
      'aud': 'authenticated',
      'email': 'test@example.com',
      'app_metadata': {'provider': 'email'},
      'user_metadata': <String, Object>{},
      'created_at': '2026-10-01T00:00:00Z',
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _wrongCode() => http.Response(
  jsonEncode({
    'code': 403,
    'error_code': 'otp_expired',
    'msg': 'Token has expired or is invalid',
  }),
  403,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<Map<String, dynamic>> requests;
  late http.Response Function() respond;
  late SupabaseClient client;
  late AuthProvider auth;
  late List<bool> screenRequests;

  setUp(() {
    requests = [];
    respond = _session;
    client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/verify')) {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return respond();
      }),
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    auth = AuthProvider(client: client);
    screenRequests = [];
    auth.addListener(() => screenRequests.add(auth.recoveryNeedsScreen));
  });

  tearDown(() async {
    auth.dispose();
    await client.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('kayıt kodu adresi doğrular ve oturumu açar', () async {
    expect(await auth.verifySignupCode(' test@example.com ', '123456'), isTrue);
    await settle();

    expect(requests.single, containsPair('type', 'signup'));
    expect(requests.single, containsPair('email', 'test@example.com'));
    expect(requests.single, containsPair('token', '123456'));
    expect(auth.hasAccount, isTrue);
    expect(auth.isRecovering, isFalse);
    expect(auth.errorMessage, isNull);
  });

  test(
    'sıfırlama kodu yeni şifre adımını ekranı yeniden açmadan başlatır',
    () async {
      expect(
        await auth.verifyRecoveryCode('test@example.com', '123456'),
        isTrue,
      );
      await settle();

      expect(requests.single, containsPair('type', 'recovery'));
      expect(auth.isRecovering, isTrue);
      // Kod hesap ekranında yazıldı; yönlendirici ikinci bir ekran açmamalı.
      expect(screenRequests, isNot(contains(true)));
    },
  );

  test('yanlış ya da süresi dolmuş kod anlaşılır bir hata verir', () async {
    respond = _wrongCode;

    expect(
      await auth.verifyRecoveryCode('test@example.com', '000000'),
      isFalse,
    );
    await settle();

    expect(auth.errorMessage, 'code_invalid');
    expect(auth.isRecovering, isFalse);
    expect(auth.isSignedIn, isFalse);

    // Başarısız deneme sonraki bağlantılı sıfırlamayı gizlememeli.
    respond = _session;
    await client.auth.verifyOTP(
      email: 'test@example.com',
      token: '123456',
      type: OtpType.recovery,
    );
    await settle();
    expect(auth.recoveryNeedsScreen, isTrue);
  });

  test(
    'eski e-postadaki bağlantıyla başlayan sıfırlama hesap ekranını açtırır',
    () async {
      // Bağlantı uygulamayı açtığında oturum sağlayıcının dışında kurulur.
      await client.auth.verifyOTP(
        email: 'test@example.com',
        token: '123456',
        type: OtpType.recovery,
      );
      await settle();

      expect(auth.isRecovering, isTrue);
      expect(auth.recoveryNeedsScreen, isTrue);
    },
  );
}
