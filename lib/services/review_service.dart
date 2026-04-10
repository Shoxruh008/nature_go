import 'dart:io';
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
      if (kIsWeb) {
        final originalBytes = await images[i].readAsBytes();
        final bytes = await compressImage(originalBytes);

        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final originalBytes = await images[i].readAsBytes();
        final bytes = await compressImage(originalBytes);

        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );      }
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  static Future<bool> _hasRecentReview(String placeId, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_review_${placeId}_$uid';
    final lastMs = prefs.getInt(key);
    if (lastMs == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) < const Duration(hours: 24);
  }

  static Future<void> _saveReviewTimestamp(String placeId, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_review_${placeId}_$uid';
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
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

    final hasRecent = await _hasRecentReview(placeId, uid);
    if (hasRecent) {
      throw Exception('Siz bu joyga so\'nggi 24 soat ichida sharh yozgansiz.');
    }

    final docRef = _firestore.collection('reviews').doc();

    final imageUrls =
    images.isNotEmpty ? await uploadImages(docRef.id, images) : <String>[];

    final review = ReviewModel(
      id: docRef.id,
      placeId: placeId,
      authorId: uid,
      authorName: 'Mehmon',
      authorAvatar: null,
      rating: rating,
      text: text,
      images: imageUrls,
      isPublished: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(review.toMap());
    await _saveReviewTimestamp(placeId, uid);
  }
}
