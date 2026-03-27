import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

class DetailScreen extends StatefulWidget {
  final String placeId;
  const DetailScreen({super.key, required this.placeId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  PlaceModel? _place;
  bool _loading = true;
  int _currentImg = 0;
  late PageController _imgCtrl;
  YandexMapController? _mapController;
  String? _geocodedAddress;
  bool _routeDownloading = false;

  @override
  void initState() {
    super.initState();
    _imgCtrl = PageController();
    _loadPlace();
  }

  Future<void> _loadPlace() async {
    final place = await FirebaseService.instance.getPlace(widget.placeId);
    if (mounted) {
      setState(() {
        _place = place;
        _loading = false;
      });
      if (place != null) _loadAddress(place);
    }
  }

  Future<void> _loadAddress(PlaceModel p) async {
    final addr = await LocationService.instance.getFullAddress(p.lat, p.lng);
    if (mounted) setState(() => _geocodedAddress = addr);
  }

  Future<void> _openRouteFile(String url) async {
    setState(() => _routeDownloading = true);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _showSnack('Faylni ochib bo\'lmadi', isError: true);
    } finally {
      if (mounted) setState(() => _routeDownloading = false);
    }
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: isError ? const Color(0xFFEF4444) : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _imgCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7F5),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5)),
      );
    }
    if (_place == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Topilmadi')),
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
          _buildSliverAppBar(p, pt),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildTitleSection(p, pt),
                const SizedBox(height: 12),
                _buildChipsRow(p),
                const SizedBox(height: 16),
                _buildActionButtons(p),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildDescription(p),
                ],
                if (p.routeFileUrl != null) ...[
                  const SizedBox(height: 14),
                  _buildRouteFileCard(p),
                ],
                const SizedBox(height: 14),
                _buildMapCard(p),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(PlaceModel p, PlaceType pt) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: _buildHeroImage(p, pt),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(PlaceModel p, PlaceType pt) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (p.images.isNotEmpty)
          PageView.builder(
            controller: _imgCtrl,
            onPageChanged: (i) => setState(() => _currentImg = i),
            itemCount: p.images.length,
            itemBuilder: (_, i) => kIsWeb
                ? Image.network(
                    p.images[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) =>
                        progress == null
                            ? child
                            : Container(
                                color: pt.bg,
                                child: Center(
                                    child: Text(pt.icon,
                                        style: const TextStyle(fontSize: 80))),
                              ),
                    errorBuilder: (_, __, ___) => Container(
                      color: pt.bg,
                      child: Center(
                          child: Text(pt.icon,
                              style: const TextStyle(fontSize: 80))),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: p.images[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: pt.bg,
                      child: Center(child: Text(pt.icon, style: const TextStyle(fontSize: 80))),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: pt.bg,
                      child: Center(child: Text(pt.icon, style: const TextStyle(fontSize: 80))),
                    ),
                  ),
          )
        else
          Container(
            color: pt.bg,
            child: Center(child: Text(pt.icon, style: const TextStyle(fontSize: 80))),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                  stops: const [0.0, 0.45, 1.0],
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
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (p.images.length > 1)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  p.images.length,
                      (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentImg ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentImg ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleSection(PlaceModel p, PlaceType pt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 3),
                  Text(
                    p.baseRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipsRow(PlaceModel p) {
    final pt = p.placeType;
    return SizedBox(
      height: 32,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          ...p.seasonTypes.map((s) {
            final color = kSeasonColors[s] ?? AppTheme.primary;
            return _chip(
              label: kSeasonUz[s] ?? s,
              bg: color.withOpacity(0.1),
              textColor: color,
              border: color.withOpacity(0.3),
            );
          }),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: pt.bg, borderRadius: BorderRadius.circular(25)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pt.icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(pt.label,
                    style: TextStyle(color: pt.color, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ...p.tags.map((t) => _chip(
            label: '# ${kTagUz[t] ?? t}',
            bg: const Color(0xFFEEF2EE),
            textColor: AppTheme.textSecondary,
          )),
        ],
      ),
    );
  }

  Widget _chip({required String label, required Color bg, required Color textColor, Color? border}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(25),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildActionButtons(PlaceModel p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.map_outlined,
              label: 'Xaritada ochish',
              color: AppTheme.primary,
              onTap: () => _openYandex(p, route: false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionBtn(
              icon: Icons.turn_right_rounded,
              label: 'Marshrut',
              color: const Color(0xFFFF6F00),
              onTap: () => _openYandex(p, route: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(PlaceModel p) {
    return _SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('📖', 'Tavsif'),
          const SizedBox(height: 10),
          Text(p.description,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.7)),
        ],
      ),
    );
  }

  Widget _buildRouteFileCard(PlaceModel p) {
    final url = p.routeFileUrl!;
    final fileName = url.split('/').last.split('?').first;
    final rawExt = fileName.split('.').last.toUpperCase();
    final ext = rawExt.length > 7 ? 'FAYL' : rawExt;

    final color = switch (ext) {
      'GPX' => const Color(0xFF16A34A),
      'KML' => const Color(0xFFD97706),
      'GEOJSON' || 'JSON' => const Color(0xFF2563EB),
      _ => AppTheme.primary,
    };

    return _SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('🛤️', 'Marshrut fayli'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(ext,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Marshrut ($ext)',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                      const SizedBox(height: 3),
                      const Text('GPS ilovasida ochish uchun yuklab oling',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _routeDownloading ? null : () => _openRouteFile(url),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _routeDownloading ? color.withOpacity(0.5) : color,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: _routeDownloading
                        ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(PlaceModel p) {
    return _SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                _sectionHeader('🗺️', 'Joylashuv'),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openYandex(p, route: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 13, color: AppTheme.primary),
                        SizedBox(width: 5),
                        Text('Kattalashtirish',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: SizedBox(
              height: 220,
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
                          scale: 0.18,
                        )),
                      ),
                    ],
                  ),
                  if (_geocodedAddress != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _geocodedAddress!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMain),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String emoji, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;

  const _SectionCard({
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}