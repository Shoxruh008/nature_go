import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/phone_utils.dart';
import 'favourites_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;
  AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Ro'yxatdan o'tish/kirish jarayoni tugamaguncha `true` bo'ladi. AuthGate
  /// shu vaqtgacha foydalanuvchini Home'ga o'tkazmaydi, shunda xatolar
  /// AuthScreen'da ko'rinadi va yarim tayyor akkaunt qolmaydi.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isRegistered =>
      _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  /// Anonim akkaunt haqiqiyga `link` qilinganda `authStateChanges` ishlamaydi,
  /// shuning uchun `userChanges` tinglanadi.
  Stream<User?> userChanges() => _auth.userChanges();

  /// Joriy foydalanuvchi UID'i. Anonim akkaunt yaratmaydi.
  Future<String?> getUid() async => _auth.currentUser?.uid;

  /// Ommaviy joylarda (sharhlar) ko'rsatiladigan niqoblangan nom.
  String publicDisplayName() {
    final phone = phoneFromAuthEmail(_auth.currentUser?.email);
    return phone != null ? maskPhone(phone) : 'Foydalanuvchi';
  }

  Future<void> registerWithPhone(String rawPhone, String password) async {
    final phone = normalizeUzPhone(rawPhone);
    if (password.length < 6) {
      throw Exception('Parol kamida 6 belgidan iborat bo\'lishi kerak');
    }
    final email = emailForPhone(phone);

    busy.value = true;
    try {
      User? user;
      var linked = false;
      try {
        final current = _auth.currentUser;
        if (current != null && current.isAnonymous) {
          // Eski (anonim) akkauntni saqlab qolamiz: avvalgi sharh va qo'shilgan
          // joylar shu UID bilan bog'liq.
          final cred = await current.linkWithCredential(
            EmailAuthProvider.credential(email: email, password: password),
          );
          user = cred.user;
          linked = true;
        } else {
          final cred = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          user = cred.user;
        }
      } on FirebaseAuthException catch (e) {
        throw Exception(_mapAuthError(e));
      }
      if (user == null) {
        throw Exception('Ro\'yxatdan o\'tishda xatolik yuz berdi');
      }

      try {
        await _writeUserDoc(user.uid, phone, password);
      } catch (e) {
        debugPrint('users/{uid} yozilmadi: $e');
        await _rollbackRegistration(user, linked: linked);
        throw Exception(
            'Ma\'lumotlarni saqlab bo\'lmadi. Internetni tekshirib, qayta urinib ko\'ring');
      }
      await FavouritesService.instance
          .migrateLegacyLocalIds('favourite_place_ids');
    } finally {
      busy.value = false;
    }
  }

  Future<void> loginWithPhone(String rawPhone, String password) async {
    final phone = normalizeUzPhone(rawPhone);
    final email = emailForPhone(phone);

    busy.value = true;
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await FavouritesService.instance
          .migrateLegacyLocalIds('favourite_place_ids');
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } finally {
      busy.value = false;
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Oflayn rejimda `set()` server tasdig'ini kutib osilib qolmasligi uchun
  /// vaqt chegarasi bor; muvaffaqiyatsiz bo'lsa qayta uriniladi.
  Future<void> _writeUserDoc(String uid, String phone, String password) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _db.collection('users').doc(uid).set({
          'phone': phone,
          'password': password,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('users hujjatini yozib bo\'lmadi');
  }

  /// `users/{uid}` yozilmagan bo'lsa yarim tayyor akkauntni qoldirmaymiz.
  Future<void> _rollbackRegistration(User user, {required bool linked}) async {
    try {
      if (linked) {
        await user.unlink(EmailAuthProvider.PROVIDER_ID);
      } else {
        await user.delete();
      }
    } catch (e) {
      debugPrint('Rollback bajarilmadi: $e');
      if (!linked) await _auth.signOut();
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
      case 'credential-already-in-use':
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
