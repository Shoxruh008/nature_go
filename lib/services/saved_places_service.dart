import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foydalanuvchining joy ID'lari ro'yxatini (sevimlilar, borgan joylar,
/// bormoqchi bo'lgan joylar) `users/{uid}/{collectionName}` orqali real-time
/// saqlaydigan umumiy servis. Har bir ro'yxat shu klassning alohida
/// instansiyasi bilan ifodalanadi.
class SavedPlacesService extends ChangeNotifier {
  final String collectionName;
  SavedPlacesService(this.collectionName);

  final _db = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _itemsSub;
  String? _boundUid;

  Set<String> _items = {};
  Completer<void> _ready = Completer<void>();

  void _ensureBound() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    _onAuthChanged(FirebaseAuth.instance.currentUser);
  }

  void _onAuthChanged(User? user) {
    final isReal = user != null && !user.isAnonymous;
    final newUid = isReal ? user.uid : null;
    if (newUid == _boundUid) return;

    _boundUid = newUid;
    _itemsSub?.cancel();
    _itemsSub = null;
    _items = {};
    if (!_ready.isCompleted) _ready.complete();
    _ready = Completer<void>();

    if (newUid == null) {
      notifyListeners();
      return;
    }

    _itemsSub = _db
        .collection('users')
        .doc(newUid)
        .collection(collectionName)
        .snapshots()
        .listen((snap) {
      _items = snap.docs.map((d) => d.id).toSet();
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
    });
  }

  Future<void> _ensureLoaded() async {
    _ensureBound();
    if (_boundUid == null) return;
    await _ready.future;
  }

  Future<Set<String>> getAll() async {
    await _ensureLoaded();
    return Set.from(_items);
  }

  Future<bool> isSaved(String placeId) async {
    await _ensureLoaded();
    return _items.contains(placeId);
  }

  bool isSavedSync(String placeId) => _items.contains(placeId);

  Future<bool> toggle(String placeId) async {
    await _ensureLoaded();
    final uid = _boundUid;
    if (uid == null) return false;

    final wasSaved = _items.contains(placeId);
    final docRef =
        _db.collection('users').doc(uid).collection(collectionName).doc(placeId);

    if (wasSaved) {
      await docRef.delete();
    } else {
      await docRef.set({
        'placeId': placeId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
    return !wasSaved;
  }

  Future<void> remove(String placeId) async {
    await _ensureLoaded();
    final uid = _boundUid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(placeId)
        .delete();
  }

  /// Toggle'dan farqli o'laroq, allaqachon saqlangan bo'lsa ham xavfsiz
  /// ravishda qo'shadi (masalan, bir ro'yxatdan ikkinchisiga ko'chirishda).
  Future<void> add(String placeId) async {
    await _ensureLoaded();
    final uid = _boundUid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection(collectionName).doc(placeId).set({
      'placeId': placeId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ilova yangilanishidan oldingi eski (SharedPreferences) lokal ro'yxatni
  /// birinchi muvaffaqiyatli auth'dan so'ng joriy akkountga ko'chiradi.
  Future<void> migrateLegacyLocalIds(String prefsKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(prefsKey) ?? [];
    if (ids.isEmpty) return;

    try {
      final batch = _db.batch();
      final col = _db.collection('users').doc(user.uid).collection(collectionName);
      for (final id in ids) {
        batch.set(col.doc(id), {
          'placeId': id,
          'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      await prefs.remove(prefsKey);
    } catch (e) {
      debugPrint('$collectionName ro\'yxatini ko\'chirishda xatolik: $e');
    }
  }
}

class VisitedPlacesService {
  static final SavedPlacesService instance = SavedPlacesService('visited');
}

class WishlistService {
  static final SavedPlacesService instance = SavedPlacesService('wishlist');
}
