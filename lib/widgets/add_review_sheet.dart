import 'package:flutter/material.dart';
import '../main.dart';
import '../models/review_model.dart';
import '../services/firebase_service.dart';
import 'star_rating.dart';

class AddReviewSheet extends StatefulWidget {
  final String placeId;
  final VoidCallback onAdded;
  const AddReviewSheet({super.key, required this.placeId, required this.onAdded});

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _authorCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  double _rating = 5.0;
  bool _loading = false;

  @override
  void dispose() {
    _authorCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Row(
            children: [
              Text('💬', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'Sharh yozish',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rating
          const Text(
            'Baholash',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Center(
            child: StarPicker(
              initialValue: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          const Text('Ismingiz',
              style:
              TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _authorCtrl,
            decoration: const InputDecoration(hintText: 'Masalan: Jasur T.'),
          ),
          const SizedBox(height: 12),

          // Comment
          const Text('Sharh',
              style:
              TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Bu joy haqida fikringiz...'),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Sharh yuborish',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharh matni kiriting')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final review = ReviewModel(
        id: '',
        placeId: widget.placeId,
        author: _authorCtrl.text.trim().isEmpty
            ? 'Mehmon'
            : _authorCtrl.text.trim(),
        rating: _rating,
        comment: comment,
        date: DateTime.now(),
      );
      await FirebaseService.instance.addReview(review);
      if (mounted) {
        Navigator.pop(context);
        widget.onAdded();
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}