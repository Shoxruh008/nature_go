import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/place_model.dart';
import '../models/review_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._();
  static FirebaseService get instance => _instance;
  FirebaseService._();

  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ── Places ────────────────────────────────────────────────

  Stream<List<PlaceModel>> publishedPlaces() {
    return _db
        .collection('places')
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map(PlaceModel.fromFirestore).toList());
  }

  Future<PlaceModel?> getPlace(String id) async {
    final doc = await _db.collection('places').doc(id).get();
    if (!doc.exists) return null;
    return PlaceModel.fromFirestore(doc);
  }

  /// Upload multiple images to Firebase Storage, return download URLs
  Future<List<String>> uploadImages(
      List<File> files, {
        required void Function(double progress) onProgress,
      }) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName =
          'places/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final ref = _storage.ref().child(fileName);
      final task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      task.snapshotEvents.listen((snap) {
        final progress = (i + snap.bytesTransferred / snap.totalBytes) / files.length;
        onProgress(progress);
      });
      await task;
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  /// Add new place (isPublished = false, awaiting admin approval)
  Future<String> addPlace(PlaceModel place) async {
    final ref = await _db.collection('places').add(place.toFirestore());
    return ref.id;
  }

  // ── Reviews ───────────────────────────────────────────────

  Stream<List<ReviewModel>> reviewsForPlace(String placeId) {
    return _db
        .collection('reviews')
        .where('placeId', isEqualTo: placeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReviewModel.fromFirestore).toList());
  }

  Future<void> addReview(ReviewModel review) async {
    await _db.collection('reviews').add(review.toFirestore());
  }
}