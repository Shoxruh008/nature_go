import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../widgets/add_place_sheet.dart';
import 'detail_screen.dart';

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
  String _sortBy = 'nearest';
  String _searchQuery = '';

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _fabAnim;
  late AnimationController _headerAnim;
  bool _fabVisible = true;
  bool _searchFocused = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250), value: 1);
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerAnim.forward();
    _scrollCtrl.addListener(_onScroll);
    _searchFocus.addListener(
            () => setState(() => _searchFocused = _searchFocus.hasFocus));
    _initLocation();
    _listenPlaces();
  }

  void _onScroll() {
    final dir = _scrollCtrl.position.userScrollDirection;
    if (dir == ScrollDirection.reverse && _fabVisible) {
      setState(() => _fabVisible = false);
      _fabAnim.reverse();
    } else if (dir == ScrollDirection.forward && !_fabVisible) {
      setState(() => _fabVisible = true);
      _fabAnim.forward();
    }
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      final city =
      await LocationService.instance.getCityName(pos.latitude, pos.longitude);
      setState(() { _userPos = pos; _cityName = city; });
      _applyFilters();
    }
  }

  void _listenPlaces() {
    FirebaseService.instance.publishedPlaces().listen((places) {
      if (mounted) {
        setState(() { _allPlaces = places; _loading = false; });
        _applyFilters();
      }
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _applyFilters() {
    List<PlaceModel> result = List.from(_allPlaces);
    if (_selectedType != 'all') {
      result = result.where((p) => p.type == _selectedType).toList();
    }
    if (_selectedSeason != 'all') {
      result = result.where((p) => p.seasonTypes.contains(_selectedSeason)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) =>
      p.name.toLowerCase().contains(q) ||
          p.region.toLowerCase().contains(q) ||
          p.tags.any((t) => t.contains(q))).toList();
    }
    if (_userPos != null) {
      for (final p in result) {
        p.distanceTo = LocationService.distanceBetween(
            _userPos!.latitude, _userPos!.longitude, p.lat, p.lng);
      }
    }
    switch (_sortBy) {
      case 'nearest':
        if (_userPos != null) {
          result.sort((a, b) =>
              (a.distanceTo ?? 9999).compareTo(b.distanceTo ?? 9999));
        }
        break;
      case 'rating':
        result.sort((a, b) => b.baseRating.compareTo(a.baseRating));
        break;
      case 'name':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    setState(() => _filtered = result);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _fabAnim.dispose();
    _headerAnim.dispose();
    _searchFocus.dispose();
    super.dispose();
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
        body: Stack(
          children: [
            _buildBg(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearch(),
                  _buildTypeChips(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
            _buildFab(),
          ],
        ),
      ),
    );
  }

  Widget _buildBg() => Positioned(
    top: -80, right: -60,
    child: Container(
      width: 240, height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primary.withOpacity(0.07),
      ),
    ),
  );

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerAnim,
      builder: (_, __) => Opacity(
        opacity: _headerAnim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - _headerAnim.value) * -16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 12, color: AppTheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  _cityName ?? 'Joylashuv...',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bugun sayohat\nqilasizmi? 🌿',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                          height: 1.22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _initLocation();
                  },
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Search ───────────────────────────────────────────────────
  Widget _buildSearch() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _searchFocused
                ? AppTheme.primary.withOpacity(0.2)
                : Colors.black.withOpacity(0.07),
            blurRadius: _searchFocused ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _searchFocused
              ? AppTheme.primary.withOpacity(0.45)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: (v) { _searchQuery = v.trim(); _applyFilters(); },
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMain),
        decoration: InputDecoration(
          hintText: 'Joy, hudud yoki teg qidiring...',
          hintStyle: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.65), fontSize: 13.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(13),
            child: Icon(Icons.search_rounded,
                color: _searchFocused ? AppTheme.primary : AppTheme.textSecondary,
                size: 21),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 13,
                    color: AppTheme.textSecondary),
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
          const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        ),
      ),
    );
  }

  // ── Type Chips ───────────────────────────────────────────────
  Widget _buildTypeChips() {
    final types = [
      PlaceType(id: 'all', label: 'Barchasi', icon: '🗺️',
          color: AppTheme.primary, bg: const Color(0xFFE8F5E9)),
      ...kPlaceTypes,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 44,
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
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? t.color : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: sel
                      ? [BoxShadow(
                      color: t.color.withOpacity(0.38),
                      blurRadius: 10, offset: const Offset(0, 3))]
                      : [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(t.label,
                        style: TextStyle(
                            color: sel ? Colors.white : AppTheme.textMain,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────
  Widget _buildBody() {
    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildToolbar()),
        if (!_loading && _filtered.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader('Mashhur joylar')),
          SliverToBoxAdapter(child: _buildPopular()),
          SliverToBoxAdapter(
            child: _sectionHeader(
              _userPos != null ? 'Yaqin atrofda' : 'Barcha joylar',
              trailing: _buildSortRow(),
            ),
          ),
        ],
        if (_loading)
          SliverFillRemaining(child: _buildLoader())
        else if (_filtered.isEmpty)
          SliverFillRemaining(child: _buildEmpty())
        else
          _buildNearby(),
        const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
      ],
    );
  }

  Widget _buildToolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Row(
      children: [
        Text('${_filtered.length} joy',
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        _buildSeasonPill(),
      ],
    ),
  );

  Widget _buildSeasonPill() {
    const s = {
      'all': ('🌐', 'Barchasi'),
      'Spring': ('🌸', 'Bahor'),
      'Summer': ('☀️', 'Yoz'),
      'Autumn': ('🍂', 'Kuz'),
      'Winter': ('❄️', 'Qish'),
    };
    final cur = s[_selectedSeason]!;
    return GestureDetector(
      onTap: _showSeasonPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07), blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cur.$1, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(cur.$2,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.textMain)),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 15, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showSeasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeasonSheet(
        selected: _selectedSeason,
        onChanged: (v) { setState(() => _selectedSeason = v); _applyFilters(); },
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

  Widget _buildSortRow() {
    final sorts = [
      if (_userPos != null) ('nearest', '📍'),
      ('rating', '⭐'),
      ('name', '🔤'),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sorts.map((s) {
        final sel = _sortBy == s.$1;
        return GestureDetector(
          onTap: () { setState(() => _sortBy = s.$1); _applyFilters(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
            ),
            child: Text(s.$2,
                style: TextStyle(
                    fontSize: 12,
                    color: sel ? Colors.white : AppTheme.textSecondary)),
          ),
        );
      }).toList(),
    );
  }

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
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    p.images.isNotEmpty
                        ? Image.network(p.images.first, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: pt.bg,
                            child: Center(child: Text(pt.icon,
                                style: const TextStyle(fontSize: 40)))))
                        : Container(color: pt.bg,
                        child: Center(child: Text(pt.icon,
                            style: const TextStyle(fontSize: 40)))),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent,
                              Colors.black.withOpacity(0.68)],
                            stops: const [0.38, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.favorite_border_rounded,
                            color: Colors.white, size: 15),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.name, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13,
                                    fontWeight: FontWeight.w700, height: 1.2)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 10, color: Colors.white70),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(p.region, maxLines: 1,
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
                                        color: Colors.white, fontSize: 11,
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
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.055),
                        blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(18)),
                        child: SizedBox(
                          width: 88, height: 88,
                          child: p.images.isNotEmpty
                              ? Image.network(p.images.first, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: pt.bg,
                                  child: Center(child: Text(pt.icon,
                                      style: const TextStyle(fontSize: 26)))))
                              : Container(color: pt.bg,
                              child: Center(child: Text(pt.icon,
                                  style: const TextStyle(fontSize: 26)))),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p.name, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: AppTheme.textMain)),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 11, color: AppTheme.textSecondary),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(p.region, maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: pt.bg,
                                        borderRadius: BorderRadius.circular(5)),
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
                                          fontSize: 12, fontWeight: FontWeight.w700,
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
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 13, color: AppTheme.primary),
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
        Text('Yuklanmoqda...',
            style: TextStyle(
                color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
              child: Text('🔍', style: TextStyle(fontSize: 34))),
        ),
        const SizedBox(height: 14),
        const Text('Joy topilmadi',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppTheme.textMain)),
        const SizedBox(height: 5),
        const Text('Boshqa filtr yoki kalit so\'z kiriting',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    ),
  );

  Widget _buildFab() => Positioned(
    bottom: 24, right: 20,
    child: ScaleTransition(
      scale: _fabAnim,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddPlaceSheet(
              onAdded: (msg) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  margin: const EdgeInsets.all(16),
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryLight, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.45),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_location_alt_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Joy qo\'shish',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 14, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Season picker sheet ───────────────────────────────────────
class _SeasonSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _SeasonSheet({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const seasons = [
      ('all', '🌐', 'Barcha fasl', Color(0xFF607D8B)),
      ('Spring', '🌸', 'Bahor', Color(0xFF16A34A)),
      ('Summer', '☀️', 'Yoz', Color(0xFFD97706)),
      ('Autumn', '🍂', 'Kuz', Color(0xFFEA580C)),
      ('Winter', '❄️', 'Qish', Color(0xFF2563EB)),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
                color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Mavsum tanlang',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppTheme.textMain)),
          ),
          const SizedBox(height: 14),
          ...seasons.map((s) {
            final sel = selected == s.$1;
            return GestureDetector(
              onTap: () { onChanged(s.$1); Navigator.pop(context); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: sel ? s.$4.withOpacity(0.08) : const Color(0xFFF5F7F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel ? s.$4 : Colors.transparent, width: 1.5),
                ),
                child: Row(
                  children: [
                    Text(s.$2, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(s.$3,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: sel ? s.$4 : AppTheme.textMain)),
                    const Spacer(),
                    if (sel)
                      Icon(Icons.check_circle_rounded, color: s.$4, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}