import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../widgets/favourite_button.dart';
import 'detail_screen.dart';
import 'donate_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<PlaceModel> _allPlaces = [];
  List<PlaceModel> _filtered = [];
  bool _loading = true;
  Position? _userPos;
  String? _cityName;

  String _selectedType = 'all';
  String _selectedSeason = 'all';
  double _maxDistanceKm = 500;
  String _searchQuery = '';

  StreamSubscription<List<PlaceModel>>? _placesSub;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _headerAnim;
  bool _searchFocused = false;
  final FocusNode _searchFocus = FocusNode();

  Timer? _debounceTimer;

  static const int _pageSize = 15;
  int _visibleCount = _pageSize;
  bool _hasMore = false;

  bool _isOffline = false;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerAnim.forward();
    _searchFocus.addListener(
        () => setState(() => _searchFocused = _searchFocus.hasFocus));
    _initConnectivity();
    _initLocation();
    _listenPlaces();
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && _isOffline != offline) {
        setState(() => _isOffline = offline);
      }
    });
  }

  bool _locationLoading = false;

  Future<void> _initLocation() async {
    if (_locationLoading) return;
    setState(() => _locationLoading = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        final city = await LocationService.instance
            .getCityName(pos.latitude, pos.longitude);
        setState(() {
          _userPos = pos;
          _cityName = city ?? "Noma'lum";
          _locationLoading = false;
          _applyFiltersInner();
        });
      } else if (mounted) {
        setState(() {
          _cityName = "Ruxsat yo'q";
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cityName = 'Xato';
          _locationLoading = false;
        });
      }
    }
  }

  bool _networkError = false;

  void _listenPlaces() {
    _placesSub = FirebaseService.instance.publishedPlacesOffline().listen((places) {
      if (mounted) {
        setState(() {
          _allPlaces = places;
          _loading = false;
          _networkError = false;
          _applyFiltersInner();
        });
      }
    }, onError: (_) {
      if (mounted) setState(() { _loading = false; _networkError = true; });
    });
  }

  void _applyFiltersInner() {
    List<PlaceModel> result = List.from(_allPlaces);

    if (_selectedType != 'all') {
      result = result.where((p) => p.type == _selectedType).toList();
    }
    if (_selectedSeason != 'all') {
      result = result.where((p) => p.seasonTypes.contains(_selectedSeason)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
      p.name.toLowerCase().contains(q) ||
          p.region.toLowerCase().contains(q) ||
          p.tags.any((t) => t.contains(q)))
          .toList();
    }

    if (_userPos != null) {
      for (final p in result) {
        p.distanceTo = LocationService.distanceBetween(
            _userPos!.latitude, _userPos!.longitude, p.lat, p.lng);
      }
      if (_maxDistanceKm < 500) {
        result = result
            .where((p) => (p.distanceTo ?? double.infinity) <= _maxDistanceKm)
            .toList();
      }
      result.sort(
          (a, b) => (a.distanceTo ?? 9999).compareTo(b.distanceTo ?? 9999));
    }

    _filtered = result;
    _visibleCount = _pageSize;
    _hasMore = _filtered.length > _visibleCount;
  }

  void _applyFilters() {
    setState(_applyFiltersInner);
  }

  void _loadMore() {
    setState(() {
      _visibleCount += _pageSize;
      _hasMore = _filtered.length > _visibleCount;
    });
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _searchQuery = value.trim();
        _applyFilters();
      }
    });
  }

  @override
  void dispose() {
    _placesSub?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _headerAnim.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearch(),
                _buildSeasonChips(),
                _buildTypeChips(),
                const SizedBox(height: 6),
                if (_isOffline) _buildOfflineBanner(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFE65100)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Oflayn rejim — saqlangan ma\'lumotlar ko\'rsatilmoqda',
              style: TextStyle(fontSize: 11, color: Color(0xFF795548), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBg() => Positioned(
    top: -80,
    right: -60,
    child: Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primary.withOpacity(0.07),
      ),
    ),
  );

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerAnim,
      builder: (_, __) => Opacity(
        opacity: _headerAnim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - _headerAnim.value) * -16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_locationLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppTheme.primary),
                        )
                      else
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        _locationLoading
                            ? 'Aniqlanmoqda...'
                            : (_cityName ?? 'Aniqlanmadi'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _onLocationTap,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const DonatePage()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("Donat qilish",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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

  Future<void> _onLocationTap() async {
    HapticFeedback.mediumImpact();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showLocationDialog(
        icon: Icons.location_off_rounded,
        title: "GPS o'chirilgan",
        message: "Joylashuvni aniqlash uchun qurilmangizda GPS ni yoqing.",
        actionLabel: 'GPS sozlamalarini ochish',
        onAction: () => Geolocator.openLocationSettings(),
      );
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showLocationDialog(
        icon: Icons.location_disabled_rounded,
        title: 'Ruxsat berilmagan',
        message: permission == LocationPermission.deniedForever
            ? "Joylashuv ruxsati doimiy rad etilgan. Sozlamalarda qo'lda yoqing."
            : "Ilovaga joylashuvdan foydalanish uchun ruxsat bering.",
        actionLabel: permission == LocationPermission.deniedForever
            ? 'Ilova sozlamalarini ochish'
            : 'Ruxsat berish',
        onAction: () async {
          if (permission == LocationPermission.deniedForever) {
            await Geolocator.openAppSettings();
          } else {
            final result = await Geolocator.requestPermission();
            if (result == LocationPermission.whileInUse ||
                result == LocationPermission.always) {
              _initLocation();
            }
          }
        },
      );
      return;
    }

    _initLocation();
  }

  void _showLocationDialog({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onAction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(actionLabel,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Bekor qilish',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _searchFocused
                ? AppTheme.primary.withOpacity(0.2)
                : Colors.black.withOpacity(0.07),
            blurRadius: _searchFocused ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMain),
        decoration: InputDecoration(
          hintText: 'Joy, hudud yoki teg qidiring...',
          hintStyle: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.65), fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.search_rounded,
                color: _searchFocused
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 19),
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    size: 12, color: AppTheme.textSecondary),
              ),
              onPressed: () {
                _searchCtrl.clear();
                _debounceTimer?.cancel();
                _searchQuery = '';
                _applyFilters();
              })
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildSeasonChips() {
    const seasons = [
      ('Spring', '🌸', 'Bahor', Color(0xFF16A34A)),
      ('Summer', '☀️', 'Yoz', Color(0xFFD97706)),
      ('Autumn', '🍂', 'Kuz', Color(0xFFEA580C)),
      ('Winter', '❄️', 'Qish', Color(0xFF2563EB)),
    ];

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const SizedBox(width: 20),
          ...seasons.map((s) {
            final sel = _selectedSeason == s.$1;
            final color = s.$4;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSeason = sel ? 'all' : s.$1);
                  _applyFilters();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(
                    right: s.$1 == 'Winter' ? 0 : 8,
                    top: 8,
                    bottom: 4,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? color : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: sel
                        ? [
                      BoxShadow(
                          color: color.withOpacity(0.38),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                        : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.$2, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          s.$3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sel ? Colors.white : AppTheme.textMain,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildTypeChips() {
    final types = [
      PlaceType(
          id: 'all',
          label: 'Barchasi',
          icon: '🗺️',
          color: AppTheme.primary,
          bg: const Color(0xFFE8F5E9)),
      ...kPlaceTypes,
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = types[i];
          final sel = _selectedType == t.id;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedType = t.id);
              _applyFilters();
            },
            child: AnimatedContainer(
              margin: const EdgeInsets.only(bottom: 7, top: 7),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? t.color : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: sel
                    ? [
                  BoxShadow(
                      color: t.color.withOpacity(0.38),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
                    : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 5,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(t.label,
                      style: TextStyle(
                          color: sel ? Colors.white : AppTheme.textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final displayCount = _filtered.length > _visibleCount
        ? _visibleCount
        : _filtered.length;

    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text('${_filtered.length} joy',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        if (!_loading && _filtered.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader('Mashhur joylar')),
          SliverToBoxAdapter(child: _buildPopular()),
          SliverToBoxAdapter(
            child: _sectionHeader(
              _userPos != null ? 'Yaqin atrofda' : 'Barcha joylar',
            ),
          ),
        ],
        if (_loading)
          SliverFillRemaining(child: _buildLoader())
        else if (_networkError && _allPlaces.isEmpty)
          SliverFillRemaining(child: _buildNetworkError())
        else if (_filtered.isEmpty)
          SliverFillRemaining(child: _buildEmpty())
        else
          _buildNearby(displayCount),
        if (_hasMore && !_loading)
          SliverToBoxAdapter(child: _buildLoadMoreButton()),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  Widget _buildLoadMoreButton() {
    final remaining = _filtered.length - _visibleCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: GestureDetector(
        onTap: _loadMore,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.expand_more_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                'Ko\'proq ko\'rish (+${remaining > _pageSize ? _pageSize : remaining} joy)',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
                letterSpacing: -0.3)),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _buildPopular() {
    final top = [..._filtered]
      ..sort((a, b) => b.baseRating.compareTo(a.baseRating));
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: top.take(6).length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = top[i];
          final pt = p.placeType;
          return GestureDetector(
            onTap: () => _openDetail(p),
            child: Container(
              width: 155,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPlaceImage(p.images.isNotEmpty ? p.images.first : null, pt, BoxFit.cover),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.68)],
                            stops: const [0.38, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FavouriteButton(placeId: p.id, size: 32, dark: true),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.location_on_rounded, size: 10, color: Colors.white70),
                              const SizedBox(width: 2),
                              Expanded(child: Text(p.region, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10))),
                            ]),
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text(p.baseRating.toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceImage(String? imageUrl, PlaceType pt, BoxFit fit) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: pt.bg,
        child: Center(child: Text(pt.icon, style: const TextStyle(fontSize: 40))),
      );
    }
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : Container(color: pt.bg),
        errorBuilder: (_, __, ___) => Container(
          color: pt.bg,
          child: Center(child: Text(pt.icon, style: const TextStyle(fontSize: 40))),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: 400,
      memCacheHeight: 400,
      maxWidthDiskCache: 800,
      maxHeightDiskCache: 800,
      placeholder: (_, __) => Container(color: pt.bg),
      errorWidget: (_, __, ___) => Container(
        color: pt.bg,
        child: Center(child: Text(pt.icon, style: const TextStyle(fontSize: 40))),
      ),
    );
  }

  Widget _buildNearby(int displayCount) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final p = _filtered[i];
            final pt = p.placeType;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _openDetail(p),
                child: Container(
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.055), blurRadius: 10, offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                        child: SizedBox(
                          width: 104, height: 104,
                          child: _buildPlaceImage(
                            p.images.isNotEmpty ? p.images.first : null,
                            pt,
                            BoxFit.cover,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.location_on_rounded, size: 11, color: AppTheme.textSecondary),
                                const SizedBox(width: 2),
                                Expanded(child: Text(p.region, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: pt.bg, borderRadius: BorderRadius.circular(5)),
                                  child: Text('${pt.icon} ${pt.label}',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: pt.color)),
                                ),
                                const Spacer(),
                                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 2),
                                Text(p.baseRating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                                if (p.distanceTo != null) ...[
                                  const SizedBox(width: 6),
                                  Text(LocationService.instance.formatDistance(p.distanceTo!),
                                      style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                ],
                              ]),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: FavouriteButton(placeId: p.id, size: 30, dark: false),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: displayCount,
        ),
      ),
    );
  }

  void _openDetail(PlaceModel p) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => DetailScreen(placeId: p.id),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
  }

  Widget _buildLoader() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Yuklanmoqda...', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _buildNetworkError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76, height: 76,
            decoration: const BoxDecoration(color: Color(0xFFFFEBEE), shape: BoxShape.circle),
            child: const Center(child: Text('📡', style: TextStyle(fontSize: 34))),
          ),
          const SizedBox(height: 14),
          const Text('Internet bilan muammo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
          const SizedBox(height: 5),
          const Text("Internetni tekshirib, qayta urinib ko'ring",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() { _loading = true; _networkError = false; });
              _listenPlaces();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(25)),
              child: const Text('Qayta urinish',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Center(child: Text('🔍', style: TextStyle(fontSize: 34))),
        ),
        const SizedBox(height: 14),
        const Text('Joy topilmadi',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
        const SizedBox(height: 5),
        Text(
          _userPos == null ? 'Joylashuvga ruxsat bering' : "Boshqa filtr yoki kalit so'z kiriting",
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}
