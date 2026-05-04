import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/favourites_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import 'detail_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PlaceModel> _places = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
    FavouritesService.instance.addListener(_onFavouritesChanged);
  }

  @override
  void dispose() {
    FavouritesService.instance.removeListener(_onFavouritesChanged);
    super.dispose();
  }

  void _onFavouritesChanged() {
    if (mounted) _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    setState(() => _loading = true);
    final ids = await FavouritesService.instance.getAll();
    final futures = ids.map((id) => FirebaseService.instance.getPlace(id));
    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _places = results.whereType<PlaceModel>().toList();
      _loading = false;
    });
  }

  Future<void> _removeFavourite(PlaceModel place) async {
    HapticFeedback.mediumImpact();
    await FavouritesService.instance.remove(place.id);
    if (!mounted) return;
    setState(() => _places.removeWhere((p) => p.id == place.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${place.name} sevimlilardan olib tashlandi',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
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
    ).then((_) => _loadFavourites());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Sevimlilar',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: -0.3),
        ),
        centerTitle: false,
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
        onRefresh: _loadFavourites,
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
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
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
            Icon(Icons.favorite_border_rounded, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('Olib\ntashlash',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      onDismissed: (_) => _removeFavourite(p),
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
                  child: GestureDetector(
                    onTap: () => _removeFavourite(p),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 16, color: Color(0xFFEF4444)),
                    ),
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
              color: const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('❤️', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 16),
          const Text('Sevimlilar yo\'q',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain)),
          const SizedBox(height: 8),
          const Text(
            "Joylarni sevimliga qo'shish uchun\n️ ❤️ tugmasini bosing",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}