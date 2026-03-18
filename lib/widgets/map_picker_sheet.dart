import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../main.dart';
import '../services/location_service.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String label;
  const PickedLocation({required this.lat, required this.lng, required this.label});
}

class MapPickerSheet extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerSheet({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<MapPickerSheet> {
  YandexMapController? _mapController;
  double? _pickedLat;
  double? _pickedLng;
  String? _pickedLabel;
  bool _loadingLabel = false;
  bool _loadingGps = false;

  // Default: Toshkent
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
  }

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
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
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

  void _onCameraPositionChanged(CameraPosition pos, CameraUpdateReason reason, bool finished) {
    // Update center crosshair
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

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.85;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildTitle(),
          Expanded(child: _buildMap()),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildHandle() => Container(
    width: 40, height: 4,
    margin: const EdgeInsets.only(top: 10, bottom: 4),
    decoration: BoxDecoration(
        color: AppTheme.border,
        borderRadius: BorderRadius.circular(2)),
  );

  Widget _buildTitle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      children: [
        const Text('Xaritadan joy tanlang',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.close, size: 18,
                color: AppTheme.textSecondary),
          ),
        ),
      ],
    ),
  );

  Widget _buildMap() {
    return Stack(
      children: [
        // Yandex Map
        YandexMap(
          onMapCreated: (controller) async {
            _mapController = controller;
            await controller.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: Point(latitude: _centerLat, longitude: _centerLng),
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
                point: Point(latitude: _pickedLat!, longitude: _pickedLng!),
                icon: PlacemarkIcon.single(
                  PlacemarkIconStyle(
                    image: BitmapDescriptor.fromAssetImage('assets/marker.png'),
                    scale: 2.5,
                  ),
                ),
              ),
          ],
        ),

        // Center crosshair (for drag-to-pick)
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2, height: 20,
                color: AppTheme.primary,
              ),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 8)],
                ),
              ),
              GestureDetector(
                onTap: _confirmCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Text('Bu yerga',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),

        // My location button
        Positioned(
          bottom: 16, right: 16,
          child: GestureDetector(
            onTap: _goToMyLocation,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4))],
              ),
              child: _loadingGps
                  ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded,
                  color: AppTheme.primary, size: 22),
            ),
          ),
        ),

        // Zoom controls
        Positioned(
          bottom: 80, right: 16,
          child: Column(
            children: [
              _ZoomBtn(
                icon: Icons.add,
                onTap: () => _mapController?.moveCamera(
                    CameraUpdate.zoomIn(),
                    animation: const MapAnimation(
                        type: MapAnimationType.smooth, duration: 0.3)),
              ),
              const SizedBox(height: 4),
              _ZoomBtn(
                icon: Icons.remove,
                onTap: () => _mapController?.moveCamera(
                    CameraUpdate.zoomOut(),
                    animation: const MapAnimation(
                        type: MapAnimationType.smooth, duration: 0.3)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected location label
          if (_pickedLat != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _loadingLabel
                        ? Row(
                      children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text('Manzil aniqlanmoqda...',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary)),
                      ],
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedLabel ?? 'Noma\'lum',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMain),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_pickedLat!.toStringAsFixed(5)}, ${_pickedLng!.toStringAsFixed(5)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Xaritaga bosing yoki xochni surting',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _pickedLat != null && !_loadingLabel
                  ? () {
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
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: AppTheme.border,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
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
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.12), blurRadius: 8)],
        ),
        child: Icon(icon, color: AppTheme.textMain, size: 20),
      ),
    );
  }
}