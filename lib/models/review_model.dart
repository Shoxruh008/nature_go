import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String placeId;
  final String author;
  final double rating;
  final String comment;
  final DateTime date;

  ReviewModel({
    required this.id,
    required this.placeId,
    required this.author,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      placeId: d['placeId'] ?? '',
      author: d['author'] ?? 'Mehmon',
      rating: (d['rating'] ?? 5.0).toDouble(),
      comment: d['comment'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'placeId': placeId,
    'author': author,
    'rating': rating,
    'comment': comment,
    'date': Timestamp.fromDate(date),
  };
}