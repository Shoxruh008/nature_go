import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review_model.dart';
import 'auth_service.dart';
import 'image_compress_service.dart';

class ReviewService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static const _reviewCooldown = Duration(hours: 24);

  static Stream<List<ReviewModel>> watchPublished(String placeId) {
    return _firestore
        .collection('reviews')
        .where('placeId', isEqualTo: placeId)
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ReviewModel.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  static Future<List<String>> uploadImages(
    String reviewId,
    List<XFile> images,
  ) async {
    final urls = <String>[];
    for (int i = 0; i < images.length; i++) {
      final ref = _storage.ref('reviews/$reviewId/img_$i.jpg');
      final bytes = await compressImage(await images[i].readAsBytes());
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  /// Sharh yozilmay qolsa, allaqachon yuklangan rasmlarni o'chiradi.
  static Future<void> _deleteUploadedImages(String reviewId, int count) async {
    for (int i = 0; i < count; i++) {
      try {
        await _storage.ref('reviews/$reviewId/img_$i.jpg').delete();
      } catch (_) {}
    }
  }

  /// 24 soatlik cheklov akkauntga bog'langan: bazadagi o'z sharhlari
  /// tekshiriladi (qurilmani tozalash yoki boshqa qurilma uni aylanib o'tmaydi).
  /// Tarmoq bo'lmasa lokal belgi bo'yicha tekshiriladi.
  static Future<bool> _hasRecentReview(String placeId, String uid) async {
    final cutoff = DateTime.now().subtract(_reviewCooldown);
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('authorId', isEqualTo: uid)
          .where('placeId', isEqualTo: placeId)
          .get();
      return snap.docs.any((d) {
        final createdAt = d.data()['createdAt'];
        return createdAt is Timestamp && createdAt.toDate().isAfter(cutoff);
      });
    } catch (e) {
      debugPrint('Sharh cheklovini bazadan tekshirib bo\'lmadi: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('last_review_${placeId}_$uid');
    if (lastMs == null) return false;
    return DateTime.fromMillisecondsSinceEpoch(lastMs).isAfter(cutoff);
  }

  static Future<void> _saveReviewTimestamp(String placeId, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_review_${placeId}_$uid', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> submitReview({
    required String placeId,
    required double rating,
    required String text,
    required List<XFile> images,
  }) async {
    final uid = await AuthService.instance.getUid();
    if (uid == null) {
      throw Exception('Autentifikatsiya xatosi. Qayta urinib ko\'ring.');
    }

    if (await _hasRecentReview(placeId, uid)) {
      throw Exception('Siz bu joyga so\'nggi 24 soat ichida sharh yozgansiz.');
    }

    final docRef = _firestore.collection('reviews').doc();

    try {
      final imageUrls = images.isNotEmpty
          ? await uploadImages(docRef.id, images)
          : <String>[];

      final review = ReviewModel(
        id: docRef.id,
        placeId: placeId,
        authorId: uid,
        authorName: AuthService.instance.publicDisplayName(),
        authorAvatar: null,
        rating: rating,
        text: text,
        images: imageUrls,
        isPublished: false,
        createdAt: DateTime.now(),
      );

      await docRef.set(review.toMap());
    } catch (_) {
      await _deleteUploadedImages(docRef.id, images.length);
      rethrow;
    }
    await _saveReviewTimestamp(placeId, uid);
  }
}
