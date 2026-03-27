import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../main.dart';
import '../services/location_service.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String label;
  const PickedLocation({required this.lat, required this.lng, required this.label});
}

class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerPage({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late final MapController _mapController;

  double? _pickedLat;
  double? _pickedLng;
  String? _pickedLabel;
  bool _loadingLabel = false;
  bool _loadingGps = false;

  // Xaritada "center crosshair" uchun joriy markaz
  late double _centerLat;
  late double _centerLng;

  // Qidiruv
  final TextEditingController _searchCtrl = TextEditingController();
  List<LocationResult> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;
  bool _showSearch = false;

  static const double _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _centerLat = widget.initialLat ?? 41.2995;
    _centerLng = widget.initialLng ?? 69.2401;
    if (widget.initialLat != null) {
      _pickedLat = widget.initialLat;
      _pickedLng = widget.initialLng;
      _resolveLabel(_pickedLat!, _pickedLng!);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Manzil aniqlash ──────────────────────────────────────────────────────

  Future<void> _resolveLabel(double lat, double lng) async {
    setState(() => _loadingLabel = true);
    final label = await LocationService.instance.getFullAddress(lat, lng);
    if (mounted) {
      setState(() {
        _pickedLabel = label ?? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
        _loadingLabel = false;
      });
    }
  }

  // ─── GPS joylashuv ────────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    setState(() => _loadingGps = true);
    HapticFeedback.mediumImpact();
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      final ll = LatLng(pos.latitude, pos.longitude);
      _mapController.move(ll, 15.0);
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
        _pickedLat = pos.latitude;
        _pickedLng = pos.longitude;
        _loadingGps = false;
      });
      _resolveLabel(pos.latitude, pos.longitude);
    } else if (mounted) {
      setState(() => _loadingGps = false);
    }
  }

  // ─── Xaritaga tap ────────────────────────────────────────────────────────

  void _onMapTap(TapPosition _, LatLng ll) {
    HapticFeedback.selectionClick();
    setState(() {
      _pickedLat = ll.latitude;
      _pickedLng = ll.longitude;
      _centerLat = ll.latitude;
      _centerLng = ll.longitude;
      _pickedLabel = null;
      _searchResults = [];
      _showSearch = false;
    });
    _resolveLabel(ll.latitude, ll.longitude);
  }

  // ─── Markazni tasdiqlash ─────────────────────────────────────────────────

  void _confirmCenter() {
    HapticFeedback.mediumImpact();
    final center = _mapController.camera.center;
    setState(() {
      _pickedLat = center.latitude;
      _pickedLng = center.longitude;
      _centerLat = center.latitude;
      _centerLng = center.longitude;
      _pickedLabel = null;
    });
    _resolveLabel(center.latitude, center.longitude);
  }

  // ─── Xarita siljishi ─────────────────────────────────────────────────────

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _centerLat = camera.center.latitude;
        _centerLng = camera.center.longitude;
      });
    }
  }

  // ─── Qidiruv ──────────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final results = await LocationService.instance.searchByAddress(q);
      if (mounted) setState(() { _searchResults = results; _searching = false; });
    });
  }

  void _selectSearchResult(LocationResult r) {
    HapticFeedback.selectionClick();
    final ll = LatLng(r.lat, r.lng);
    _mapController.move(ll, 14.0);
    setState(() {
      _pickedLat = r.lat;
      _pickedLng = r.lng;
      _centerLat = r.lat;
      _centerLng = r.lng;
      _pickedLabel = r.label;
      _searchResults = [];
      _searchCtrl.clear();
      _showSearch = false;
    });
  }

  // ─── Tasdiqlash ───────────────────────────────────────────────────────────

  void _confirmAndPop() {
    if (_pickedLat == null || _loadingLabel) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      PickedLocation(
        lat: _pickedLat!,
        lng: _pickedLng!,
        label: _pickedLabel ??
            '${_pickedLat!.toStringAsFixed(5)}, ${_pickedLng!.toStringAsFixed(5)}',
      ),
    );
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ── OpenStreetMap xaritasi ──────────────────────────────────────
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_centerLat, _centerLng),
                  initialZoom: _defaultZoom,
                  onTap: _onMapTap,
                  onPositionChanged: _onPositionChanged,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.naturego.app',
                    maxZoom: 19,
                  ),
                  // Tanlangan joy markeri
                  if (_pickedLat != null && _pickedLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_pickedLat!, _pickedLng!),
                          width: 36,
                          height: 44,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppTheme.primary.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on_rounded,
                                    color: Colors.white, size: 14),
                              ),
                              CustomPaint(
                                size: const Size(10, 7),
                                painter: _MarkerTailPainter(AppTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ── Tepadan gradient ───────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0, height: 130,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.32),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Yuqori panel: ortga + qidiruv ─────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        // Ortga
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3)),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_ios_rounded,
                                size: 16, color: AppTheme.textMain),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Qidiruv maydoni
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showSearch = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                      color: _showSearch
                                          ? AppTheme.primary.withOpacity(0.22)
                                          : Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3)),
                                ],
                                border: _showSearch
                                    ? Border.all(
                                        color: AppTheme.primary.withOpacity(0.5),
                                        width: 1.2)
                                    : null,
                              ),
                              child: _showSearch
                                  ? Row(children: [
                                      const Icon(Icons.search_rounded,
                                          size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchCtrl,
                                          autofocus: true,
                                          onChanged: _onSearchChanged,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textMain),
                                          decoration: const InputDecoration(
                                            hintText: 'Manzil yoki joy nomi...',
                                            hintStyle: TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textSecondary),
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      if (_searching)
                                        const SizedBox(
                                          width: 14, height: 14,
                                          child: CircularProgressIndicator(
                                              color: AppTheme.primary,
                                              strokeWidth: 1.5),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: () {
                                            _searchCtrl.clear();
                                            setState(() {
                                              _searchResults = [];
                                              _showSearch = false;
                                            });
                                          },
                                          child: const Icon(Icons.close,
                                              size: 16,
                                              color: AppTheme.textSecondary),
                                        ),
                                    ])
                                  : const Row(children: [
                                      Icon(Icons.search_rounded,
                                          size: 16, color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Text('Manzil qidiring...',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textSecondary)),
                                    ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Qidiruv natijalari
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(68, 6, 16, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _searchResults
                              .take(5)
                              .map((r) => _SearchResultTile(
                                    result: r,
                                    onTap: () => _selectSearchResult(r),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Markazda crosshair + "Belgilash" tugmasi ──────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 1.5, height: 18,
                    color: AppTheme.primary.withOpacity(0.7),
                  ),
                  Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _confirmCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text('Belgilash',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),

            // ── GPS tugmasi ────────────────────────────────────────────────
            Positioned(
              right: 16,
              bottom: 220,
              child: GestureDetector(
                onTap: _goToMyLocation,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: _loadingGps
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded,
                          color: AppTheme.primary, size: 22),
                ),
              ),
            ),

            // ── Pastki panel ───────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2)),
                    ),

                    // Tanlangan joy kartasi
                    if (_pickedLat != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _loadingLabel
                                  ? const Row(children: [
                                      SizedBox(
                                        width: 14, height: 14,
                                        child: CircularProgressIndicator(
                                            color: AppTheme.primary,
                                            strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Manzil aniqlanmoqda...',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textSecondary)),
                                    ])
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _pickedLabel ?? 'Noma\'lum',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textMain),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_pickedLat!.toStringAsFixed(5)}, ${_pickedLng!.toStringAsFixed(5)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(children: [
                          Icon(Icons.touch_app_rounded,
                              color: AppTheme.textSecondary, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Xaritani bosing yoki "Belgilash" tugmasini bosing',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ),
                        ]),
                      ),
                    ],

                    // Tasdiqlash tugmasi
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed:
                            (_pickedLat != null && !_loadingLabel)
                                ? _confirmAndPop
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Shu joyni tanlash',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
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
      ),
    );
  }
}

// ─── Marker dum shakli ─────────────────────────────────────────────────────
class _MarkerTailPainter extends CustomPainter {
  final Color color;
  _MarkerTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SearchResultTile extends StatelessWidget {
  final LocationResult result;
  final VoidCallback onTap;
  const _SearchResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMain, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
