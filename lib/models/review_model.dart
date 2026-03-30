import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String placeId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final double rating;
  final String text;
  final List<String> images;
  final bool isPublished;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.placeId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.rating,
    required this.text,
    required this.images,
    required this.isPublished,
    required this.createdAt,
  });

  factory ReviewModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      placeId: d['placeId'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Foydalanuvchi',
      authorAvatar: d['authorAvatar'],
      rating: (d['rating'] as num).toDouble(),
      text: d['text'] ?? '',
      images: List<String>.from(d['images'] ?? []),
      isPublished: d['isPublished'] ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'placeId': placeId,
    'authorId': authorId,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'rating': rating,
    'text': text,
    'images': images,
    'isPublished': isPublished,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}