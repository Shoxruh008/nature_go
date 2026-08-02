import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/saved_places_service.dart';
import '../utils/confirm_dialog.dart';
import 'detail_screen.dart';

/// Joy ro'yxatlarini (sevimlilar, borgan joylar, bormoqchi bo'lgan joylar)
/// ko'rsatadigan umumiy sahifa.
class SavedPlacesListScreen extends StatefulWidget {
  final String title;
  final SavedPlacesService service;
  final IconData activeIcon;
  final Color activeColor;
  final Color activeBg;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptyMessage;
  final String removedSuffix;

  /// `true` bo'lsa, ro'yxatdan olib tashlashdan oldin tasdiqlash oynasi chiqadi.
  final bool confirmBeforeRemove;

  /// Berilsa, joyni shu ro'yxatdan boshqasiga "ko'chirish" imkoniyati
  /// qo'shiladi (masalan, bormoqchi bo'lganlardan borganlarga).
  final SavedPlacesService? moveToService;
  final String? moveToLabel;
  final IconData? moveToIcon;
  final Color? moveToColor;
  final Color? moveToBg;
  final String? moveToSuffix;

  const SavedPlacesListScreen({
    super.key,
    required this.title,
    required this.service,
    required this.activeIcon,
    required this.activeColor,
    required this.activeBg,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.removedSuffix,
    this.confirmBeforeRemove = false,
    this.moveToService,
    this.moveToLabel,
    this.moveToIcon,
    this.moveToColor,
    this.moveToBg,
    this.moveToSuffix,
  });

  @override
  State<SavedPlacesListScreen> createState() => _SavedPlacesListScreenState();
}

class _SavedPlacesListScreenState extends State<SavedPlacesListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PlaceModel> _places = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    widget.service.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => _loading = true);
    final ids = await widget.service.getAll();
    final futures = ids.map((id) => FirebaseService.instance.getPlace(id));
    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _places = results.whereType<PlaceModel>().toList();
      _loading = false;
    });
  }

  Future<bool> _confirmRemoval(PlaceModel place) async {
    if (!widget.confirmBeforeRemove) return true;
    return showConfirmDialog(
      context,
      title: 'Olib tashlashni tasdiqlang',
      message: "\"${place.name}\" ro'yxatdan olib tashlansinmi?",
      confirmLabel: 'Olib tashlash',
      destructive: true,
    );
  }

  Future<void> _doRemove(PlaceModel place) async {
    HapticFeedback.mediumImpact();
    await widget.service.remove(place.id);
    if (!mounted) return;
    setState(() => _places.removeWhere((p) => p.id == place.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${place.name} ${widget.removedSuffix}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeWithConfirm(PlaceModel place) async {
    final confirmed = await _confirmRemoval(place);
    if (confirmed) await _doRemove(place);
  }

  Future<bool> _confirmMove(PlaceModel place) async {
    return showConfirmDialog(
      context,
      title: '${widget.moveToLabel} tasdiqlang',
      message:
          "\"${place.name}\" ${widget.moveToLabel!.toLowerCase()}, u ro'yxatdan olib tashlanadi. Davom etilsinmi?",
      confirmLabel: widget.moveToLabel!,
    );
  }

  Future<void> _doMove(PlaceModel place) async {
    HapticFeedback.mediumImpact();
    await widget.moveToService!.add(place.id);
    await widget.service.remove(place.id);
    if (!mounted) return;
    setState(() => _places.removeWhere((p) => p.id == place.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${place.name} ${widget.moveToSuffix}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: widget.moveToColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _moveWithConfirm(PlaceModel place) async {
    final confirmed = await _confirmMove(place);
    if (confirmed) await _doMove(place);
  }

  void _openDetail(PlaceModel p) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => DetailScreen(placeId: p.id),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    ).then((_) => _loadPlaces());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: -0.3),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black.withOpacity(0.06)),
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2.5))
          : _places.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadPlaces,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: _places.length,
          itemBuilder: (_, i) => _buildCard(_places[i]),
        ),
      ),
    );
  }

  Widget _buildCard(PlaceModel p) {
    final pt = p.placeType;
    final canMove = widget.moveToService != null;

    final removeBackground = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.close_rounded, color: Colors.white, size: 22),
          SizedBox(height: 4),
          Text('Olib\ntashlash',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );

    final moveBackground = canMove
        ? Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: widget.moveToColor,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.moveToIcon, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(widget.moveToLabel ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          )
        : null;

    return Dismissible(
      key: ValueKey(p.id),
      direction:
          canMove ? DismissDirection.horizontal : DismissDirection.endToStart,
      background: canMove ? moveBackground : removeBackground,
      secondaryBackground: canMove ? removeBackground : null,
      confirmDismiss: (direction) {
        if (canMove && direction == DismissDirection.startToEnd) {
          return _confirmMove(p);
        }
        return _confirmRemoval(p);
      },
      onDismissed: (direction) {
        if (canMove && direction == DismissDirection.startToEnd) {
          _doMove(p);
        } else {
          _doRemove(p);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => _openDetail(p),
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.055),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(18)),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: p.images.isNotEmpty
                        ? (kIsWeb
                        ? Image.network(p.images.first,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                        progress == null
                            ? child
                            : Container(color: pt.bg),
                        errorBuilder: (_, __, ___) => Container(
                            color: pt.bg,
                            child: Center(
                                child: Text(pt.icon,
                                    style: const TextStyle(
                                        fontSize: 30)))))
                        : CachedNetworkImage(
                        imageUrl: p.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: pt.bg),
                        errorWidget: (_, __, ___) => Container(
                            color: pt.bg,
                            child: Center(
                                child: Text(pt.icon,
                                    style: const TextStyle(
                                        fontSize: 30))))))
                        : Container(
                        color: pt.bg,
                        child: Center(
                            child: Text(pt.icon,
                                style: const TextStyle(fontSize: 30)))),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_rounded,
                              size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(p.region,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                                color: pt.bg,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('${pt.icon} ${pt.label}',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: pt.color)),
                          ),
                          const Spacer(),
                          const Icon(Icons.star_rounded,
                              size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(p.baseRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMain)),
                        ]),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canMove) ...[
                        GestureDetector(
                          onTap: () => _moveWithConfirm(p),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: widget.moveToBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(widget.moveToIcon,
                                size: 16, color: widget.moveToColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: () => _removeWithConfirm(p),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: widget.activeBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(widget.activeIcon,
                              size: 16, color: widget.activeColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: widget.activeBg,
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(widget.emptyEmoji, style: const TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 16),
          Text(widget.emptyTitle,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
