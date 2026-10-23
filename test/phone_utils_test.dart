import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/utils/phone_utils.dart';

void main() {
  group('normalizeUzPhone', () {
    test("turli ko'rinishlarni +998XXXXXXXXX ga keltiradi", () {
      for (final raw in [
        '90 123 45 67',
        '901234567',
        '+998901234567',
        '998 90 123 45 67',
        '0901234567',
        '(90) 123-45-67',
      ]) {
        expect(normalizeUzPhone(raw), '+998901234567', reason: raw);
      }
    });

    test("noto'g'ri uzunlikda FormatException tashlaydi", () {
      for (final raw in ['', '123', '90123456', '9012345678', '+99890123']) {
        expect(() => normalizeUzPhone(raw), throwsFormatException,
            reason: raw);
      }
    });
  });

  group('emailForPhone / phoneFromAuthEmail', () {
    test('bir-birining teskarisi', () {
      final email = emailForPhone('+998901234567');
      expect(email, '998901234567@naturego.uz');
      expect(phoneFromAuthEmail(email), '+998901234567');
    });

    test("begona yoki noto'g'ri emailda null qaytaradi", () {
      expect(phoneFromAuthEmail(null), isNull);
      expect(phoneFromAuthEmail('user@gmail.com'), isNull);
      expect(phoneFromAuthEmail('abc@naturego.uz'), isNull);
    });
  });

  group('maskPhone', () {
    test("o'rtadagi raqamlarni yashiradi", () {
      expect(maskPhone('+998901234567'), '+998 90 *** ** 67');
    });

    test("noto'g'ri uzunlikdagi qiymatni o'zgartirmaydi", () {
      expect(maskPhone('123'), '123');
    });
  });

  group('PhoneGroupFormatter', () {
    TextEditingValue format(String text) => PhoneGroupFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

    test('2-3-2-2 guruhlaydi', () {
      expect(format('901234567').text, '90 123 45 67');
      expect(format('9012').text, '90 12');
      expect(format('90').text, '90');
    });

    test("kursorni oxiriga qo'yadi", () {
      final v = format('901234567');
      expect(v.selection.baseOffset, v.text.length);
    });
  });
}
