import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'favourites_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;
  AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  static const _emailDomain = 'naturego.uz';

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isRegistered =>
      _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> signInAnonymously() async {
    try {
      if (_auth.currentUser != null) return _auth.currentUser;
      final cred = await _auth.signInAnonymously();
      return cred.user;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUid() async {
    if (_auth.currentUser != null) return _auth.currentUser!.uid;
    final user = await signInAnonymously();
    return user?.uid;
  }

  /// "90 123 45 67", "+998901234567", "998901234567", "0901234567" kabi
  /// kiritilgan raqamlarni "+998901234567" ko'rinishiga keltiradi.
  String normalizePhone(String raw) {
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

  String _emailForPhone(String normalizedPhone) {
    final digits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    return '$digits@$_emailDomain';
  }

  Future<void> registerWithPhone(String rawPhone, String password) async {
    final phone = normalizePhone(rawPhone);
    if (password.length < 6) {
      throw Exception('Parol kamida 6 belgidan iborat bo\'lishi kerak');
    }
    final email = _emailForPhone(phone);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw Exception('Ro\'yxatdan o\'tishda xatolik yuz berdi');
      }
      await _db.collection('users').doc(user.uid).set({
        'phone': phone,
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FavouritesService.instance.migrateLegacyLocalIds('favourite_place_ids');
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    }
  }

  Future<void> loginWithPhone(String rawPhone, String password) async {
    final phone = normalizePhone(rawPhone);
    final email = _emailForPhone(phone);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await FavouritesService.instance.migrateLegacyLocalIds('favourite_place_ids');
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await signInAnonymously();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu raqam allaqachon ro\'yxatdan o\'tgan. Kirish qismidan foydalaning';
      case 'weak-password':
        return 'Parol juda oddiy (kamida 6 belgi kerak)';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Raqam yoki parol noto\'g\'ri';
      case 'invalid-email':
        return 'Telefon raqami noto\'g\'ri';
      case 'network-request-failed':
        return 'Internet aloqasi yo\'q. Qayta urinib ko\'ring';
      case 'too-many-requests':
        return 'Juda ko\'p urinish. Birozdan so\'ng qayta urinib ko\'ring';
      default:
        return e.message ?? 'Noma\'lum xatolik yuz berdi';
    }
  }
}
