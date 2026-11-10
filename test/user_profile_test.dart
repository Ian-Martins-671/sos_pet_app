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

  group('normalizeCnpj', () {
    test('validates and normalizes a formatted numeric CNPJ', () {
      expect(normalizeCnpj('11.222.333/0001-81'), '11222333000181');
    });

    test('supports alphanumeric CNPJ and uppercase normalization', () {
      expect(normalizeCnpj('12.abc.345/01de-35'), '12ABC34501DE35');
    });

    test(
      'rejects invalid check digits, repeated values, and wrong lengths',
      () {
        expect(normalizeCnpj('11.222.333/0001-80'), isNull);
        expect(normalizeCnpj('00.000.000/0000-00'), isNull);
        expect(normalizeCnpj('123'), isNull);
      },
    );
  });
}
