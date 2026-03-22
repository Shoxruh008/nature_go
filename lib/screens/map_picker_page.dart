import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../main.dart';
import '../services/location_service.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String label;
  const PickedLocation(
      {required this.lat, required this.lng, required this.label});
}

class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerPage({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  YandexMapController? _mapController;
  double? _pickedLat;
  double? _pickedLng;
  String? _pickedLabel;
  bool _loadingLabel = false;
  bool _loadingGps = false;

  final GlobalKey _bottomKey = GlobalKey();
  double _bottomPanelHeight = 180;

  late double _centerLat;
  late double _centerLng;

  @override
  void initState() {
    super.initState();
    _centerLat = widget.initialLat ?? 41.2995;
    _centerLng = widget.initialLng ?? 69.2401;
    if (widget.initialLat != null) {
      _pickedLat = widget.initialLat;
      _pickedLng = widget.initialLng;
      _resolveLabel(_pickedLat!, _pickedLng!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottom());
  }

  void _measureBottom() {
    final ctx = _bottomKey.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && mounted) {
        setState(() => _bottomPanelHeight = box.size.height);
      }
    }
  }

  Future<void> _resolveLabel(double lat, double lng) async {
    setState(() => _loadingLabel = true);
    final label = await LocationService.instance.getFullAddress(lat, lng);
    if (mounted) {
      setState(() {
        _pickedLabel = label ??
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
        _loadingLabel = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottom());
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _loadingGps = true);
    HapticFeedback.mediumImpact();
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      await _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: pos.latitude, longitude: pos.longitude),
            zoom: 15,
          ),
        ),
      );
      setState(() {
        _pickedLat = pos.latitude;
        _pickedLng = pos.longitude;
        _loadingGps = false;
      });
      _resolveLabel(pos.latitude, pos.longitude);
    } else {
      setState(() => _loadingGps = false);
    }
  }

  void _onMapTap(Point point) {
    HapticFeedback.selectionClick();
    setState(() {
      _pickedLat = point.latitude;
      _pickedLng = point.longitude;
      _pickedLabel = null;
    });
    _resolveLabel(point.latitude, point.longitude);
  }

  void _onCameraPositionChanged(
      CameraPosition pos, CameraUpdateReason reason, bool finished) {
    setState(() {
      _centerLat = pos.target.latitude;
      _centerLng = pos.target.longitude;
    });
  }

  void _confirmCenter() {
    HapticFeedback.mediumImpact();
    setState(() {
      _pickedLat = _centerLat;
      _pickedLng = _centerLng;
    });
    _resolveLabel(_centerLat, _centerLng);
  }

  void _confirmAndPop() {
    if (_pickedLat == null || _loadingLabel) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      PickedLocation(
        lat: _pickedLat!,
        lng: _pickedLng!,
        label: _pickedLabel ??
            '${_pickedLat!.toStringAsFixed(3)}, ${_pickedLng!.toStringAsFixed(3)}',
      ),
    );
  }

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
            Positioned.fill(
              child: YandexMap(
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await controller.moveCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: Point(
                            latitude: _centerLat, longitude: _centerLng),
                        zoom: 12,
                      ),
                    ),
                  );
                },
                onMapTap: _onMapTap,
                onCameraPositionChanged: _onCameraPositionChanged,
                mapObjects: [
                  if (_pickedLat != null && _pickedLng != null)
                    PlacemarkMapObject(
                      mapId: const MapObjectId('picked'),
                      point: Point(
                          latitude: _pickedLat!, longitude: _pickedLng!),
                      icon: PlacemarkIcon.single(
                        PlacemarkIconStyle(
                          image: BitmapDescriptor.fromAssetImage(
                              'assets/marker.png'),
                          scale: 0.15,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            size: 16, color: AppTheme.textMain),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.map_rounded,
                                size: 16, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              'Xaritadan joy tanlang',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMain),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 2,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
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
                          horizontal: 10, vertical: 5),
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

            Positioned(
              right: 16,
              bottom: _bottomPanelHeight + 15,
              child: GestureDetector(
                onTap: _goToMyLocation,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _loadingGps
                      ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded,
                      color: AppTheme.primary, size: 22),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                key: _bottomKey,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2)),
                    ),

                    // Tanlangan joy
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
                              width: 36,
                              height: 36,
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
                                  ? const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        color: AppTheme.primary,
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Manzil aniqlanmoqda...',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color:
                                          AppTheme.textSecondary)),
                                ],
                              )
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
                                    maxLines: 3,
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
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app_rounded,
                                color: AppTheme.textSecondary, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Xaritani yoki belgilashni bosing',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Tasdiqlash tugmasi
                    SizedBox(
                      width: double.infinity,
                      height: 52,
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