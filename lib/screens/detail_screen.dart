import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../models/review_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../widgets/star_rating.dart';
import '../widgets/review_card.dart';
import '../widgets/add_review_sheet.dart';

class DetailScreen extends StatefulWidget {
  final String placeId;
  const DetailScreen({super.key, required this.placeId});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  PlaceModel? _place;
  bool _loading = true;
  int _currentImg = 0;
  late PageController _imgCtrl;
  YandexMapController? _mapController;
  late TabController _tabCtrl;
  String? _geocodedAddress;

  @override
  void initState() {
    super.initState();
    _imgCtrl = PageController();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPlace();
  }

  Future<void> _loadPlace() async {
    final place = await FirebaseService.instance.getPlace(widget.placeId);
    if (mounted) {
      setState(() { _place = place; _loading = false; });
      if (place != null) _loadGeocodedAddress(place);
    }
  }

  Future<void> _loadGeocodedAddress(PlaceModel p) async {
    final addr = await LocationService.instance.getFullAddress(p.lat, p.lng);
    if (mounted) setState(() => _geocodedAddress = addr);
  }

  @override
  void dispose() {
    _imgCtrl.dispose();
    _tabCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7F5),
        body: Center(
            child: CircularProgressIndicator(
                color: AppTheme.primary, strokeWidth: 2.5)),
      );
    }
    if (_place == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Topilmadi')),
        body: const Center(child: Text('Joy topilmadi 😔')),
      );
    }

    final p = _place!;
    final pt = p.placeType;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildImageAppBar(p, pt),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(p, pt),
                _buildSeasonTags(p),
                _buildActionButtons(p),
                _buildTabBar(),
                _buildTabContent(p),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Image App Bar ────────────────────────────────────────────
  Widget _buildImageAppBar(PlaceModel p, PlaceType pt) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      backgroundColor: pt.color,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 17),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
          child: GestureDetector(
            onTap: () => _sharePlace(p),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image slider
            if (p.images.isNotEmpty)
              PageView.builder(
                controller: _imgCtrl,
                onPageChanged: (i) => setState(() => _currentImg = i),
                itemCount: p.images.length,
                itemBuilder: (_, i) => Image.network(
                  p.images[i], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: pt.bg,
                    child: Center(child: Text(pt.icon,
                        style: const TextStyle(fontSize: 70))),
                  ),
                ),
              )
            else
              Container(color: pt.bg,
                  child: Center(child: Text(pt.icon,
                      style: const TextStyle(fontSize: 70)))),

            // Bottom gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                    stops: const [0.0, 0.5],
                  ),
                ),
              ),
            ),

            // Dots + counter — both at bottom
            Positioned(
              bottom: 18, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Counter pill (left)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentImg + 1}/${p.images.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  // Dots (center-right)
                  if (p.images.length > 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(p.images.length, (i) =>
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _currentImg ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _currentImg
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )),
                    ),
                  const Spacer(),
                  // Invisible spacer to balance left counter
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info Card ────────────────────────────────────────────────
  Widget _buildInfoCard(PlaceModel p, PlaceType pt) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: pt.bg, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pt.icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(pt.label,
                    style: TextStyle(
                        color: pt.color, fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Name
          Text(p.name,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800,
                  color: AppTheme.textMain, letterSpacing: -0.5, height: 1.2)),
          const SizedBox(height: 8),
          // Region (geocoded if available)
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 15, color: AppTheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _geocodedAddress ?? p.region,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Coordinates pill
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text: '${p.lat.toStringAsFixed(6)}, ${p.lng.toStringAsFixed(6)}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Koordinata nusxalandi'),
                  duration: Duration(seconds: 1)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${p.lat.toStringAsFixed(4)}°, ${p.lng.toStringAsFixed(4)}°',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Rating row
          Row(
            children: [
              StarRating(rating: p.baseRating, size: 18),
              const SizedBox(width: 8),
              Text(p.baseRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: AppTheme.textMain)),
              Text(' / 5.0',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const Spacer(),
              // Tags row (compact)
              Wrap(
                spacing: 4,
                children: p.tags.take(2).map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('# ${kTagUz[t] ?? t}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary)),
                )).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Season Tags ──────────────────────────────────────────────
  Widget _buildSeasonTags(PlaceModel p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8, runSpacing: 6,
        children: p.seasonTypes.map((s) {
          final color = kSeasonColors[s] ?? AppTheme.primary;
          final label = kSeasonUz[s] ?? s;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          );
        }).toList(),
      ),
    );
  }

  // ── Action Buttons ───────────────────────────────────────────
  Widget _buildActionButtons(PlaceModel p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.map_outlined,
              label: 'Xaritada ko\'r',
              color: AppTheme.primary,
              onTap: () => _openYandex(p, route: false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              icon: Icons.directions_rounded,
              label: 'Marshrut',
              color: const Color(0xFFFF6F00),
              onTap: () => _openYandex(p, route: true),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openYandex(PlaceModel p, {required bool route}) async {
    final yapp = route
        ? Uri.parse('yandexmaps://maps.yandex.ru/?rtext=~${p.lat},${p.lng}&rtt=auto')
        : Uri.parse('yandexmaps://maps.yandex.ru/?pt=${p.lng},${p.lat}&z=14&text=${Uri.encodeComponent(p.name)}');
    final yweb = route
        ? Uri.parse('https://maps.yandex.ru/?rtext=~${p.lat},${p.lng}&rtt=auto')
        : Uri.parse('https://maps.yandex.ru/?pt=${p.lng},${p.lat}&z=14&text=${Uri.encodeComponent(p.name)}');
    try {
      if (await canLaunchUrl(yapp)) {
        await launchUrl(yapp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(yweb, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      final g = route
          ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}')
          : Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}');
      await launchUrl(g, mode: LaunchMode.externalApplication);
    }
  }

  // ── Tab Bar ──────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Tavsif va xarita'),
            Tab(text: 'Sharhlar'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(PlaceModel p) {
    return SizedBox(
      height: 600,
      child: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildOverviewTab(p),
          _buildReviewsTab(p),
        ],
      ),
    );
  }

  // ── Overview Tab ─────────────────────────────────────────────
  Widget _buildOverviewTab(PlaceModel p) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Description
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('📄', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text('Tavsif',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: AppTheme.textMain)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(p.description.isEmpty
                    ? 'Tavsif kiritilmagan.'
                    : p.description,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13.5, height: 1.65)),
              ],
            ),
          ),
          // Map
          _buildMap(p),
        ],
      ),
    );
  }

  Widget _buildMap(PlaceModel p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08), blurRadius: 14,
            offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            YandexMap(
              onMapCreated: (ctrl) async {
                _mapController = ctrl;
                await ctrl.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: Point(latitude: p.lat, longitude: p.lng),
                      zoom: 13,
                    ),
                  ),
                );
              },
              mapObjects: [
                PlacemarkMapObject(
                  mapId: const MapObjectId('place'),
                  point: Point(latitude: p.lat, longitude: p.lng),
                  icon: PlacemarkIcon.single(PlacemarkIconStyle(
                    image: BitmapDescriptor.fromAssetImage('assets/marker.png'),
                    scale: 2.5,
                  )),
                ),
              ],
            ),
            Positioned(
              bottom: 10, right: 10,
              child: GestureDetector(
                onTap: () => _openYandex(p, route: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.12), blurRadius: 6)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 13, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text('Kattalashtirish',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
            ),
            // Geocoded location label
            if (_geocodedAddress != null)
              Positioned(
                top: 10, left: 10, right: 50,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(_geocodedAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: AppTheme.textMain)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Reviews Tab ──────────────────────────────────────────────
  Widget _buildReviewsTab(PlaceModel p) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Text('💬 Sharhlar',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppTheme.textMain)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddReview(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rate_review_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('Sharh yozish',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReviewModel>>(
            stream: FirebaseService.instance.reviewsForPlace(p.id),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2));
              }
              final reviews = snap.data ?? [];
              if (reviews.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                            child: Text('💬',
                                style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(height: 12),
                      const Text('Hali sharh yo\'q',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: AppTheme.textMain)),
                      const SizedBox(height: 4),
                      const Text('Birinchi sharh yozing!',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ReviewCard(review: reviews[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddReview(PlaceModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReviewSheet(
        placeId: p.id,
        onAdded: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Sharhingiz qo\'shildi!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        )),
      ),
    );
  }

  void _sharePlace(PlaceModel p) {
    final url =
        'https://maps.yandex.ru/?pt=${p.lng},${p.lat}&text=${Uri.encodeComponent(p.name)}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Havola nusxalandi! 📋'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ── Action Button ─────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.35), blurRadius: 12,
              offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}