import 'package:flutter_test/flutter_test.dart';
import 'package:sos_pet/user_profile.dart';

void main() {
  group('normalizePhoneNumber', () {
    test('adds the Brazilian country code to local numbers', () {
      expect(normalizePhoneNumber('(11) 99999-9999'), '+5511999999999');
    });

    test('preserves a valid international number', () {
      expect(normalizePhoneNumber('+1 202 555 0123'), '+12025550123');
    });

    test('rejects invalid phone numbers', () {
      expect(normalizePhoneNumber('123'), isNull);
      expect(normalizePhoneNumber(''), isNull);
    });
  });
}
