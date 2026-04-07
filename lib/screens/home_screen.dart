import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../widgets/favourite_button.dart';
import 'add_place_screen.dart';
import 'detail_screen.dart';
import 'favourites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0; // 0 = Bosh sahifa, 1 = Joy qo'shish, 2 = Sevimlilar

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

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerAnim.forward();
    _scrollCtrl.addListener(_onScroll);
    _searchFocus.addListener(
            () => setState(() => _searchFocused = _searchFocus.hasFocus));
    _initLocation();
    _listenPlaces();
  }

  void _onScroll() {}

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
          _cityName = city ?? 'Noma\'lum';
          _locationLoading = false;
          _applyFiltersInner();
        });
      } else if (mounted) {
        setState(() {
          _cityName = 'Ruxsat yo\'q';
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
    _placesSub = FirebaseService.instance.publishedPlaces().listen((places) {
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
      result =
          result.where((p) => p.seasonTypes.contains(_selectedSeason)).toList();
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
  }

  void _applyFilters() {
    setState(_applyFiltersInner);
  }

  @override
  void dispose() {
    _placesSub?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _headerAnim.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 1) {
      // Joy qo'shish — promo sheet ko'rsatish, index o'zgarmaydi
      _showAddPromoSheet();
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        body: IndexedStack(
          index: _currentIndex == 2 ? 1 : 0,
          children: [
            // 0: Bosh sahifa
            Stack(
              children: [
                _buildBg(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildSearch(),
                      _buildSeasonChips(),
                      _buildTypeChips(),
                      _buildDistanceSlider(),
                      const SizedBox(height: 6),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ],
            ),
            // 2: Sevimlilar (index 1 — joy qo'shish sheet, bu yerda placeholder)
            const FavouritesScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Bosh sahifa',
              ),
              _buildNavAddButton(),
              _buildNavItem(
                index: 2,
                icon: Icons.favorite_rounded,
                label: 'Sevimlilar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    Color? activeColor,
  }) {
    final isActive = _currentIndex == index;
    final color = activeColor ?? AppTheme.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isActive ? color : const Color(0xFFB0BDB0),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : const Color(0xFFB0BDB0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavAddButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavTap(1),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.add_location_alt_rounded,
                size: 24,
                color: Color(0xFFB0BDB0),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "Joy qo'shish",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFFB0BDB0),
              ),
            ),
          ],
        ),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        title: 'GPS o\'chirilgan',
        message: 'Joylashuvni aniqlash uchun qurilmangizda GPS ni yoqing.',
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
            ? 'Joylashuv ruxsati doimiy rad etilgan. Sozlamalarda qo\'lda yoqing.'
            : 'Ilovaga joylashuvdan foydalanish uchun ruxsat bering.',
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
        onChanged: (v) {
          _searchQuery = v.trim();
          _applyFilters();
        },
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
          suffixIcon: _searchQuery.isNotEmpty
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildDistanceSlider() {
    final bool isInfinite = _maxDistanceKm >= 500;
    final String label = isInfinite
        ? '∞  Cheksiz'
        : _maxDistanceKm < 1
        ? '< 1 km'
        : '≤ ${_maxDistanceKm.round()} km';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 7,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.social_distance_rounded,
                size: 13, color: AppTheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.primary,
                  inactiveTrackColor: AppTheme.primary.withOpacity(0.15),
                  thumbColor: AppTheme.primary,
                  overlayColor: AppTheme.primary.withOpacity(0.12),
                  trackHeight: 2.5,
                  thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: _maxDistanceKm,
                  min: 0,
                  max: 500,
                  divisions: 100,
                  onChanged: _userPos == null
                      ? null
                      : (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _maxDistanceKm = v);
                    _applyFilters();
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                label,
                key: ValueKey(label),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                  isInfinite ? AppTheme.textSecondary : AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
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
        else if (_networkError)
          SliverFillRemaining(child: _buildNetworkError())
        else if (_filtered.isEmpty)
          SliverFillRemaining(child: _buildEmpty())
        else
          _buildNearby(),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
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
                    p.images.isNotEmpty
                        ? (kIsWeb
                        ? Image.network(
                        p.images.first,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                        progress == null
                            ? child
                            : Container(color: pt.bg),
                        errorBuilder: (_, __, ___) => Container(
                            color: pt.bg,
                            child: Center(
                                child: Text(pt.icon,
                                    style: const TextStyle(fontSize: 40)))))
                        : CachedNetworkImage(
                        imageUrl: p.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: pt.bg),
                        errorWidget: (_, __, ___) => Container(
                            color: pt.bg,
                            child: Center(
                                child: Text(pt.icon,
                                    style: const TextStyle(fontSize: 40))))))
                        : Container(
                        color: pt.bg,
                        child: Center(
                            child: Text(pt.icon,
                                style: const TextStyle(fontSize: 40)))),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.68)
                            ],
                            stops: const [0.38, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FavouriteButton(
                        placeId: p.id,
                        size: 32,
                        dark: true,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 10, color: Colors.white70),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(p.region,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 12, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 3),
                                Text(p.baseRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
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

  Widget _buildNearby() {
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
                      BoxShadow(
                          color: Colors.black.withOpacity(0.055),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(18)),
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: p.images.isNotEmpty
                              ? (kIsWeb
                              ? Image.network(
                              p.images.first,
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
                                              fontSize: 26)))))
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
                                              fontSize: 26))))))
                              : Container(
                              color: pt.bg,
                              child: Center(
                                  child: Text(pt.icon,
                                      style: const TextStyle(
                                          fontSize: 26)))),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMain)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 11,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(p.region,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: pt.bg,
                                        borderRadius:
                                        BorderRadius.circular(5)),
                                    child: Text('${pt.icon} ${pt.label}',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: pt.color)),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.star_rounded,
                                      size: 12, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 2),
                                  Text(p.baseRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textMain)),
                                  if (p.distanceTo != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      LocationService.instance
                                          .formatDistance(p.distanceTo!),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: FavouriteButton(
                          placeId: p.id,
                          size: 30,
                          dark: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: _filtered.length,
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
          position: Tween<Offset>(
              begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
  }

  Widget _buildLoader() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
            color: AppTheme.primary, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Yuklanmoqda...',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
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
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('📡', style: TextStyle(fontSize: 34))),
          ),
          const SizedBox(height: 14),
          const Text('Internet bilan muammo',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain)),
          const SizedBox(height: 5),
          const Text(
            'Internetni tekshirib, qayta urinib ko\'ring',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() { _loading = true; _networkError = false; });
              _listenPlaces();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text('Qayta urinish',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
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
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child:
          const Center(child: Text('🔍', style: TextStyle(fontSize: 34))),
        ),
        const SizedBox(height: 14),
        const Text('Joy topilmadi',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain)),
        const SizedBox(height: 5),
        Text(
          _userPos == null
              ? 'Joylashuvga ruxsat bering'
              : "Boshqa filtr yoki kalit so'z kiriting",
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );

  void _showAddPromoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPromoSheet(
        onAddTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => const AddPlaceScreen(),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: anim, child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddPromoSheet extends StatelessWidget {
  final VoidCallback onAddTap;
  const _AddPromoSheet({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)),
          ),
          Image.asset(
            'assets/c1.png',
            width: 150,
            height: 150,
          ),
          const Text(
            "Ko'proq joy qo'shing",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ko\'proq yangi joy qo\'shing , agar admin tomonidan tasdiqlanib dasturga qo\'shilsa biz sizga pul mukofotini taqdim qilamiz!!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onAddTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "Joy qo'shish",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
