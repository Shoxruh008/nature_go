import 'package:flutter/services.dart';

const _authEmailDomain = 'naturego.uz';

/// "90 123 45 67", "+998901234567", "998901234567", "0901234567" kabi
/// kiritilgan raqamlarni "+998901234567" ko'rinishiga keltiradi.
/// Noto'g'ri uzunlikda [FormatException] tashlaydi.
String normalizeUzPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('998')) {
    digits = digits.substring(3);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length != 9) {
    throw const FormatException(
        'Telefon raqami noto\'g\'ri. Masalan: 90 123 45 67');
  }
  return '+998$digits';
}

/// Telefon raqamdan Firebase Auth uchun ichki email hosil qiladi.
String emailForPhone(String normalizedPhone) {
  final digits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
  return '$digits@$_authEmailDomain';
}

/// [emailForPhone] teskarisi: ichki emaildan "+998..." raqamni qaytaradi.
String? phoneFromAuthEmail(String? email) {
  if (email == null || !email.endsWith('@$_authEmailDomain')) return null;
  final digits = email.split('@').first;
  if (!RegExp(r'^998\d{9}$').hasMatch(digits)) return null;
  return '+$digits';
}

/// "+998901234567" -> "+998 90 *** ** 67" (ommaviy joylarda ko'rsatish uchun).
String maskPhone(String normalizedPhone) {
  final digits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 12) return normalizedPhone;
  return '+998 ${digits.substring(3, 5)} *** ** ${digits.substring(10)}';
}

/// "90 123 45 67" ko'rinishida guruhlab yozadi (2-3-2-2).
class PhoneGroupFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 4 || i == 6) {
        if (i != digits.length - 1) buffer.write(' ');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
