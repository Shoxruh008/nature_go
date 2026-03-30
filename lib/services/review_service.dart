import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/review_model.dart';

class GuestSession {
  static const _kGuestId = 'guest_id';

  static Future<String> getOrCreateId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kGuestId);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = const Uuid().v4();
    await prefs.setString(_kGuestId, newId);
    return newId;
  }
}

class ReviewService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static Stream<List<ReviewModel>> watchPublished(String placeId) {
    return _firestore
        .collection('reviews')
        .where('placeId', isEqualTo: placeId)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ReviewModel.fromDoc).toList());
  }

  static Future<List<String>> uploadImages(
      String reviewId,
      List<XFile> images,
      ) async {
    final urls = <String>[];
    for (int i = 0; i < images.length; i++) {
      final ref = _storage.ref('reviews/$reviewId/img_$i.jpg');
      if (kIsWeb) {
        final bytes = await images[i].readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(images[i].path));
      }
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  static Future<void> submitReview({
    required String placeId,
    required double rating,
    required String text,
    required List<XFile> images,
  }) async {
    final guestId = await GuestSession.getOrCreateId();
    final docRef = _firestore.collection('reviews').doc();

    final imageUrls =
    images.isNotEmpty ? await uploadImages(docRef.id, images) : <String>[];

    final review = ReviewModel(
      id: docRef.id,
      placeId: placeId,
      authorId: guestId,
      authorName: 'Mehmon',
      authorAvatar: null,
      rating: rating,
      text: text,
      images: imageUrls,
      isPublished: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(review.toMap());
  }
}