import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart'; // AppTheme
import '../models/review_model.dart';
import '../services/review_service.dart';

void openCommentsSheet(BuildContext context, String placeId, double baseRating) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(placeId: placeId, baseRating: baseRating),
  );
}

class CommentsSheet extends StatefulWidget {
  final String placeId;
  final double baseRating;
  const CommentsSheet({super.key, required this.placeId, required this.baseRating});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.88, 0.95],
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _Handle(),
            _SheetHeader(
              onClose: () => Navigator.pop(context),
              onWriteReview: () => setState(() => _showForm = !_showForm),
              isFormOpen: _showForm,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showForm
                  ? _ReviewForm(
                placeId: widget.placeId,
                onSubmitted: () => setState(() => _showForm = false),
              )
                  : const SizedBox.shrink(),
            ),

            Expanded(
              child: _ReviewList(
                placeId: widget.placeId,
                baseRating: widget.baseRating,
                scrollController: scrollCtrl,
              ),
            ),

            SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onWriteReview;
  final bool isFormOpen;

  const _SheetHeader({
    required this.onClose,
    required this.onWriteReview,
    required this.isFormOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          const Text('💬', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text(
            'Sharhlar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onWriteReview();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isFormOpen
                    ? AppTheme.primary.withOpacity(0.1)
                    : AppTheme.primary,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFormOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.edit_rounded,
                    color: isFormOpen ? AppTheme.primary : Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isFormOpen ? 'Yopish' : 'Sharh yozish',
                    style: TextStyle(
                      color: isFormOpen ? AppTheme.primary : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final String placeId;
  final VoidCallback onSubmitted;

  const _ReviewForm({required this.placeId, required this.onSubmitted});

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _textCtrl = TextEditingController();
  double _rating = 0;
  final List<XFile> _selectedImages = [];
  bool _submitting = false;
  String? _error;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      _setError('Maksimal 3 ta rasm tanlash mumkin');
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked != null && mounted) {
      setState(() {
        _error = null;
        _selectedImages.add(picked);
      });
    }
  }

  void _removeImage(int i) => setState(() => _selectedImages.removeAt(i));

  void _setError(String? msg) => setState(() => _error = msg);

  bool _uploadingImages = false;

  Future<void> _submit() async {
    _setError(null);
    final text = _textCtrl.text.trim();

    if (_rating == 0) {
      _setError('Iltimos, baho bering (yulduzcha tanlang)');
      return;
    }
    if (text.isEmpty) {
      _setError('Iltimos, sharh matnini yozing');
      return;
    }

    setState(() { _submitting = true; _uploadingImages = _selectedImages.isNotEmpty; });

    try {
      await ReviewService.submitReview(
        placeId: widget.placeId,
        rating: _rating,
        text: text,
        images: _selectedImages,
      );

      if (mounted) {
        setState(() { _submitting = false; _uploadingImages = false; });
        _showSuccessDialog(onDone: widget.onSubmitted);
      }
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _setError(msg);
      if (mounted) setState(() { _submitting = false; _uploadingImages = false; });
    } catch (_) {
      _setError('Internet bilan muammo. Qayta urinib ko\'ring.');
      if (mounted) setState(() { _submitting = false; _uploadingImages = false; });
    }
  }

  void _showSuccessDialog({required VoidCallback onDone}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(  // ← o'z context ini ishlatadi
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sharh yuborildi! ✅',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Sharhingiz moderatsiyaga yuborildi.\n'
                    'Admin ko\'rib chiqqandan so\'ng barcha\nfoydalanuvchilarga ko\'rinadi.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx); // ← dialogCtx ishlatiladi!
                    onDone();                 // ← keyin callback
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Tushunarli',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Bahoyingiz',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          _StarRating(
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textCtrl,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMain),
            decoration: InputDecoration(
              hintText: 'Bu joy haqida fikringizni yozing...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          _ImagePickerRow(
            images: _selectedImages,
            onAdd: _pickImage,
            onRemove: _removeImage,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _submitting
                      ? AppTheme.primary.withOpacity(0.5)
                      : AppTheme.primary,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _submitting
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                    if (_uploadingImages) ...[
                      const SizedBox(height: 4),
                      const Text('Rasmlar yuklanmoqda...',
                          style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ],
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 7),
                    Text(
                      'Yuborish',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged((i + 1).toDouble());
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey(filled),
                color:
                filled ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                size: 34,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImagePickerRow({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Rasmlar (ixtiyoriy, max 3 ta)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...List.generate(images.length, (i) => _thumb(i)),
            if (images.length < 3) _addBtn(),
          ],
        ),
      ],
    );
  }

  ImageProvider _imageProvider(XFile file) {
    if (kIsWeb) {
      return NetworkImage(file.path);
    }
    return FileImage(File(file.path));
  }

  Widget _thumb(int i) => Container(
    width: 70,
    height: 70,
    margin: const EdgeInsets.only(right: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      image: DecorationImage(
        image: _imageProvider(images[i]),
        fit: BoxFit.cover,
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onRemove(i),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _addBtn() => GestureDetector(
    onTap: onAdd,
    child: Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: AppTheme.primary,
            size: 22,
          ),
          SizedBox(height: 3),
          Text(
            'Rasm',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReviewList extends StatelessWidget {
  final String placeId;
  final double baseRating;
  final ScrollController scrollController;

  const _ReviewList({
    required this.placeId,
    required this.baseRating,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: ReviewService.watchPublished(placeId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2,
            ),
          );
        }

        final reviews = snap.data ?? [];

        if (reviews.isEmpty) return const _EmptyReviews();

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _RatingSummary(avg: baseRating, count: reviews.length),
            const SizedBox(height: 12),
            ...reviews.map((r) => _ReviewCard(review: r)),
          ],
        );
      },
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final double avg;
  final int count;

  const _RatingSummary({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
              height: 1,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avg
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 18,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$count ta sharh',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} oy oldin';
    if (diff.inDays > 0) return '${diff.inDays} kun oldin';
    if (diff.inHours > 0) return '${diff.inHours} soat oldin';
    return 'Hozirgina';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: review.authorAvatar != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: CachedNetworkImage(
                    imageUrl: review.authorAvatar!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _initials(review.authorName),
                  ),
                )
                    : _initials(review.authorName),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    Text(
                      _timeAgo(review.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ],
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _openImageViewer(ctx, review.images, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: review.images[i],
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFF5F7F5)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _initials(String name) {
    final parts = name.trim().split(' ');
    final letters = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : '?';
    return Center(
      child: Text(
        letters,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  void _openImageViewer(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ImageViewerScreen(urls: urls, initialIndex: initialIndex),
      ),
    );
  }
}

class _ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _ImageViewerScreen({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.urls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_current + 1} / ${widget.urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Hali sharhlar yo\'q',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Birinchi bo\'lib sharh qoldiring!',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}