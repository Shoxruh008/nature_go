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
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  /// [db] va [auth] faqat testlarda almashtirish uchun.
  SavedPlacesService(
    this.collectionName, {
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _dbOverride = db,
        _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Oflayn rejimda `set()/delete()` serverdan tasdiq kelguncha tugamaydi.
  /// Lokal yozuv esa darhol qo'llanadi va ulanganda yuboriladi, shuning uchun
  /// shu vaqtdan keyin kutishni to'xtatamiz.
  static const _writeTimeout = Duration(seconds: 4);
  static const _loadTimeout = Duration(seconds: 8);

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _itemsSub;
  String? _boundUid;

  Set<String> _items = {};

  /// Joy ID -> saqlangan sana (`visitedAt`, bo'lmasa `addedAt`).
  Map<String, DateTime> _dates = {};
  Completer<void> _ready = Completer<void>();
  bool _loadFailed = false;

  /// Oxirgi yuklash urinishi xato bilan tugagan bo'lsa `true`.
  bool get loadFailed => _loadFailed;

  void _ensureBound() {
    // `userChanges`: anonim akkaunt haqiqiyga link qilinganda ham ishlaydi.
    _authSub ??= _auth.userChanges().listen(_onAuthChanged);
    _onAuthChanged(_auth.currentUser);
  }

  void _onAuthChanged(User? user) {
    final isReal = user != null && !user.isAnonymous;
    final newUid = isReal ? user.uid : null;
    if (newUid == _boundUid) return;

    _boundUid = newUid;
    _itemsSub?.cancel();
    _itemsSub = null;
    _items = {};
    _dates = {};
    _loadFailed = false;
    if (!_ready.isCompleted) _ready.complete();
    _ready = Completer<void>();

    if (newUid == null) {
      notifyListeners();
      return;
    }
    _subscribe(newUid);
  }

  void _subscribe(String uid) {
    _itemsSub = _db
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .snapshots()
        .listen((snap) {
      _items = snap.docs.map((d) => d.id).toSet();
      _dates = {
        for (final d in snap.docs)
          if (_readDate(d.data()) != null) d.id: _readDate(d.data())!,
      };
      _loadFailed = false;
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
    }, onError: (Object e) {
      // Masalan, rules ruxsat bermasa. Oqim shu yerda tugaydi, shuning uchun
      // keyingi so'rovda qayta ulanamiz (`_ensureLoaded`).
      debugPrint('$collectionName ro\'yxatini o\'qib bo\'lmadi: $e');
      _itemsSub?.cancel();
      _itemsSub = null;
      _loadFailed = true;
      if (!_ready.isCompleted) _ready.complete();
      notifyListeners();
    });
  }

  Future<void> _ensureLoaded() async {
    _ensureBound();
    final uid = _boundUid;
    if (uid == null) return;
    if (_itemsSub == null) {
      _ready = Completer<void>();
      _subscribe(uid);
    }
    await _ready.future.timeout(_loadTimeout, onTimeout: () {});
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid, String placeId) =>
      _db.collection('users').doc(uid).collection(collectionName).doc(placeId);

  Map<String, dynamic> _payload(String placeId, {DateTime? visitedAt}) => {
        'placeId': placeId,
        'addedAt': FieldValue.serverTimestamp(),
        if (visitedAt != null) 'visitedAt': Timestamp.fromDate(visitedAt),
      };

  static DateTime? _readDate(Map<String, dynamic> data) {
    final value = data['visitedAt'] ?? data['addedAt'];
    return value is Timestamp ? value.toDate() : null;
  }

  Future<void> _commit(Future<void> write) async {
    try {
      await write.timeout(_writeTimeout);
    } on TimeoutException {
      // Oflayn: yozuv lokal saqlandi, ulanganda serverga yuboriladi.
    }
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

  /// Joy shu ro'yxatga qo'shilgan (borgan joylar uchun: tashrif qilingan) sana.
  DateTime? dateOf(String placeId) => _dates[placeId];

  /// [visitedAt] faqat qo'shishda ishlatiladi (masalan, borgan joylar uchun).
  Future<bool> toggle(String placeId, {DateTime? visitedAt}) async {
    await _ensureLoaded();
    final uid = _boundUid;
    if (uid == null) return false;

    final wasSaved = _items.contains(placeId);
    final ref = _doc(uid, placeId);
    await _commit(wasSaved
        ? ref.delete()
        : ref.set(_payload(placeId, visitedAt: visitedAt)));
    return !wasSaved;
  }

  /// Saqlangan joyning sanasini o'zgartiradi (tashrif sanasini tahrirlash).
  Future<void> setVisitDate(String placeId, DateTime visitedAt) async {
    await _ensureLoaded();
    final uid = _boundUid;
    if (uid == null) return;
    await _commit(_doc(uid, placeId)
        .update({'visitedAt': Timestamp.fromDate(visitedAt)}));
  }

  Future<void> remove(String placeId) async {
    await _ensureLoaded();
    final uid = _boundUid;
    if (uid == null) return;
    await _commit(_doc(uid, placeId).delete());
  }

  /// Joyni shu ro'yxatdan [target] ro'yxatiga bitta batch'da ko'chiradi:
  /// ikkalasi birga bajariladi yoki hech biri.
  Future<void> moveTo(
    SavedPlacesService target,
    String placeId, {
    DateTime? visitedAt,
  }) async {
    await _ensureLoaded();
    final uid = _boundUid;
    if (uid == null) return;

    final batch = _db.batch()
      ..delete(_doc(uid, placeId))
      ..set(target._doc(uid, placeId),
          target._payload(placeId, visitedAt: visitedAt));
    await _commit(batch.commit());
  }

  /// Ilova yangilanishidan oldingi eski (SharedPreferences) lokal ro'yxatni
  /// birinchi muvaffaqiyatli auth'dan so'ng joriy akkountga ko'chiradi.
  Future<void> migrateLegacyLocalIds(String prefsKey) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(prefsKey) ?? [];
    if (ids.isEmpty) return;

    try {
      final batch = _db.batch();
      for (final id in ids) {
        batch.set(_doc(user.uid, id), _payload(id), SetOptions(merge: true));
      }
      await _commit(batch.commit());
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
