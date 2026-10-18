import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_note/providers/auth_provider.dart';

User _user(String id, {bool anonymous = false}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-01T00:00:00Z',
  isAnonymous: anonymous,
);

void main() {
  // Kodla katılınan tablolardaki üyelik misafir kimliğine aittir. Bu kural
  // yanlış ateşlerse kullanıcının ortak tabloları boş yere kopar; hiç
  // ateşlemezse erişemediği tablolar kalıcı hatada kalır.
  group('replacesGuest', () {
    final guest = _user('g', anonymous: true);
    final account = _user('a');

    test('misafirin yerine hesap gelince tetiklenir', () {
      expect(AuthProvider.replacesGuest(guest, account), isTrue);
    });

    test('oturum yokken giriş yapmak bir şey koparmaz', () {
      expect(AuthProvider.replacesGuest(null, account), isFalse);
    });

    test('misafirin çıkış yapması ayrı bir durumdur', () {
      expect(AuthProvider.replacesGuest(guest, null), isFalse);
    });

    test('aynı misafirin yenilenen oturumu kimliği değiştirmez', () {
      expect(
        AuthProvider.replacesGuest(guest, _user('g', anonymous: true)),
        isFalse,
      );
    });

    test('misafir kalıcı hesaba dönüşürse kimlik aynı kalır, erişim de', () {
      expect(AuthProvider.replacesGuest(guest, _user('g')), isFalse);
    });

    test('hesaptan hesaba geçiş misafirle ilgili değildir', () {
      expect(AuthProvider.replacesGuest(account, _user('b')), isFalse);
    });
  });

  test('hasAccount misafir oturumunu hesap saymaz', () {
    final auth = AuthProvider();
    addTearDown(auth.dispose);
    expect(auth.isSignedIn, isFalse);
    expect(auth.hasAccount, isFalse);
  });
}
