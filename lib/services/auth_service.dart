import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;
  AuthService._();

  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  /// Ilova ishga tushganda chaqiriladi — anonim foydalanuvchi yaratadi yoki mavjudini qaytaradi
  Future<User?> signInAnonymously() async {
    try {
      if (_auth.currentUser != null) return _auth.currentUser;
      final cred = await _auth.signInAnonymously();
      return cred.user;
    } catch (_) {
      return null;
    }
  }

  /// UID ni kafolatlangan holda qaytaradi — yo'q bo'lsa anonim kiradi
  Future<String?> getUid() async {
    if (_auth.currentUser != null) return _auth.currentUser!.uid;
    final user = await signInAnonymously();
    return user?.uid;
  }
}
