import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/regions.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import 'map_picker_page.dart';

const List<String> _kRouteExtensions = ['gpx', 'kml', 'geojson', 'json'];

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _selectedType = 'toglar';
  String? _selectedCountry;
  String? _selectedRegion;
  List<String> _selectedSeasons = [];
  List<String> _selectedTags = [];

  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  final _videoCtrl = TextEditingController();

  PlatformFile? _routeFile;
  String? _routeFileName;
  bool _routeUploading = false;

  bool _uploading = false;
  double _uploadProgress = 0;
  bool _loading = false;

  String? _resolvedAddress;
  bool _resolvingAddress = false;

  String? _trekDifficulty;
  final _trekLengthCtrl = TextEditingController();
  final _trekElevationCtrl = TextEditingController();

  static const List<String> _allTags = [
    'hiking',
    'camping',
    'picnic',
    'swimming',
    'skiing',
    'boating',
    'wildlife',
    'trekking',
    'mountain',
    'forest',
    'river',
    'valley',
    'waterfall',
    'lake',
    'walking',
    'botanical',
    'nature reserve',
  ];

  @override
  void initState() {
    super.initState();
    _latCtrl.addListener(_onCoordChanged);
    _lngCtrl.addListener(_onCoordChanged);
  }

  void _onCoordChanged() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat != null && lng != null) {
      _resolveAddress(lat, lng);
    } else {
      setState(() => _resolvedAddress = null);
    }
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    setState(() => _resolvingAddress = true);
    final address = await LocationService.instance.getFullAddress(lat, lng);
    if (mounted) {
      setState(() {
        _resolvedAddress = address;
        _resolvingAddress = false;
      });
    }
  }

  Future<void> _pickImages() async {
    HapticFeedback.selectionClick();
    final result = await _picker.pickMultiImage(imageQuality: 100);
    if (result.isEmpty) return;
    setState(() {
      for (final x in result) {
        if (_pickedImages.length < 8) _pickedImages.add(x);
      }
    });
  }

  Future<void> _pickFromCamera() async {
    HapticFeedback.selectionClick();
    final result = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (result == null) return;
    if (_pickedImages.length < 8) {
      setState(() => _pickedImages.add(result));
    }
  }

  void _removeImage(int index) {
    HapticFeedback.selectionClick();
    setState(() => _pickedImages.removeAt(index));
  }

  Future<void> _pickRouteFile() async {
    HapticFeedback.selectionClick();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _kRouteExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final ext = (file.extension ?? '').toLowerCase();
      if (!_kRouteExtensions.contains(ext)) {
        if (mounted)
          _showSnack('Faqat GPX, KML yoki GeoJSON fayl tanlang', error: true);
        return;
      }
      setState(() {
        _routeFile = file;
        _routeFileName = file.name;
      });
    } catch (e) {
      if (mounted) _showSnack('Faylni ochib bo\'lmadi: $e', error: true);
    }
  }

  void _removeRouteFile() {
    HapticFeedback.selectionClick();
    setState(() {
      _routeFile = null;
      _routeFileName = null;
    });
  }

  Future<void> _openMapPicker() async {
    HapticFeedback.mediumImpact();
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    final result = await Navigator.push<PickedLocation>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            MapPickerPage(initialLat: lat, initialLng: lng),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latCtrl.text = result.lat.toStringAsFixed(6);
        _lngCtrl.text = result.lng.toStringAsFixed(6);
        _resolvedAddress = result.label;
      });
    }
  }

  // ── Country / Region picker ──────────────────────────────────────────────

  void _showLocationPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        initialCountry: _selectedCountry,
        initialRegion: _selectedRegion,
        onSelected: (country, region) {
          setState(() {
            _selectedCountry = country;
            _selectedRegion = region;
          });
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRegion == null) {
      _showSnack('Viloyatni tanlang');
      return;
    }
    if (_selectedSeasons.isEmpty) {
      _showSnack('Kamida 1 ta mavsum tanlang');
      return;
    }
    if (_pickedImages.isEmpty) {
      _showSnack('Kamida 1 ta rasm tanlang');
      return;
    }

    setState(() {
      _loading = true;
      _uploading = true;
      _uploadProgress = 0;
    });
    HapticFeedback.mediumImpact();

    try {
      final imageUrls = await FirebaseService.instance.uploadXImages(
        _pickedImages,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );
      setState(() => _uploading = false);

      String? routeUrl;
      if (_routeFile != null) {
        setState(() => _routeUploading = true);
        routeUrl = await FirebaseService.instance.uploadRouteFileFromPlatform(
          _routeFile!,
        );
        setState(() => _routeUploading = false);
      }

      final lat = double.parse(_latCtrl.text.trim());
      final lng = double.parse(_lngCtrl.text.trim());

      final phoneText = _phoneCtrl.text.trim();
      final fullPhone = phoneText.isEmpty ? null : '+998$phoneText';
      final trekLength = _trekLengthCtrl.text.trim().isEmpty
          ? null
          : _trekLengthCtrl.text.trim();
      final trekAltitude = _trekElevationCtrl.text.trim().isEmpty
          ? null
          : _trekElevationCtrl.text.trim();

      final place = PlaceModel(
        id: '',
        name: _nameCtrl.text.trim(),
        region: _selectedRegion!,
        type: _selectedType,
        seasonTypes: _selectedSeasons,
        lat: lat,
        lng: lng,
        images: imageUrls,
        description: _descCtrl.text.trim(),
        tags: _selectedTags,
        baseRating: 0,
        isPublished: false,
        routeFileUrl: routeUrl,
        videoUrl: _videoCtrl.text.trim().isEmpty
            ? null
            : _videoCtrl.text.trim(),
        phone: fullPhone,
        trekLength: (_selectedType == 'toglar' || _selectedType == 'choqqilar')
            ? trekLength
            : null,
        trekDifficulty:
        (_selectedType == 'toglar' || _selectedType == 'choqqilar')
            ? _trekDifficulty
            : null,
        trekAltitude:
        (_selectedType == 'toglar' || _selectedType == 'choqqilar')
            ? trekAltitude
            : null,
      );

      await FirebaseService.instance.addPlace(place);
      if (mounted) {
        setState(() => _loading = false);
        Navigator.pop(
          context,
          '"${place.name}" qo\'shildi! Admin tasdiqlashini kuting.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploading = false;
          _routeUploading = false;
        });
        _showSnack('Xato: $e', error: true);
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _videoCtrl.dispose();
    _phoneCtrl.dispose();
    _trekLengthCtrl.dispose();
    _trekElevationCtrl.dispose();
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
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_uploading || _routeUploading) _uploadBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _card([
                        _secTitle('Asosiy ma\'lumot', '📝'),
                        const SizedBox(height: 14),
                        _textField(
                          'Joy nomi *',
                          _nameCtrl,
                          hint: 'Masalan: Charvak ko\'li',
                          icon: Icons.landscape_rounded,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      // ── Mamlakat va Viloyat — bitta card ──
                      _card([
                        _secTitle('Joylashuv (mamlakat / viloyat)', '🗺️'),
                        const SizedBox(height: 12),
                        _buildLocationSelector(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Joy turi', '🏷️'),
                        const SizedBox(height: 12),
                        _buildTypePicker(),
                      ]),
                      const SizedBox(height: 12),
                      if (_selectedType == 'toglar' ||
                          _selectedType == 'choqqilar') ...[
                        _card([
                          _secTitle('Trek ma\'lumotlari', '🥾'),
                          const SizedBox(height: 12),
                          _buildTrekDifficultyPicker(),
                          const SizedBox(height: 10),
                          Text(
                            'Uzunligi',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _textField(
                            'Trek uzunligi',
                            _trekLengthCtrl,
                            hint: 'Masalan: 5km',
                            required: false,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Ko\'tarilish balandligi',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _textField(
                            'Trek ko\'tarilish balandligi',
                            _trekElevationCtrl,
                            hint: 'Masalan: 100m',
                            required: false,
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      _card([
                        _secTitle('Mavsum', '🌤️'),
                        const SizedBox(height: 12),
                        _buildSeasonPicker(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Joylashuv', '📍'),
                        const SizedBox(height: 12),
                        _buildMapPickerBtn(),
                        const SizedBox(height: 10),
                        _dividerOr(),
                        const SizedBox(height: 10),
                        _buildCoordFields(),
                        if (_resolvingAddress || _resolvedAddress != null)
                          _addressPill(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Rasmlar', '🖼️'),
                        const SizedBox(height: 4),
                        Text(
                          'Qurilmadan tanlang (max 8 ta)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildImagePicker(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Marshrut fayli', '🛤️'),
                        const SizedBox(height: 4),
                        Text(
                          'GPX, KML yoki GeoJSON format',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRouteFilePicker(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Tavsif', '📄'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDec(
                            'Joy haqida qisqacha yozing...',
                            null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _videoCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDec(
                            'Video link (ixtiyoriy)',
                            Icons.video_call,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Teglar', '🏷️'),
                        const SizedBox(height: 12),
                        _buildTagPicker(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Telefon raqam', '📞'),
                        const SizedBox(height: 4),
                        Text(
                          'Siz bilan bog\'lanishimiz uchun telefon raqamingizni qoldiring',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPhoneField(),
                      ]),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: const Row(
                          children: [
                            Text('⏳', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Qo\'shilgan joy admin tomonidan tasdiqlanganidan so\'ng ko\'rsatiladi.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF795548),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_loading || _uploading || _routeUploading)
                              ? null
                              : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            disabledBackgroundColor:
                            AppTheme.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_location_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Joy qo\'shish',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Location selector button ─────────────────────────────────────────────

  Widget _buildLocationSelector() {
    final hasSelection = _selectedCountry != null && _selectedRegion != null;

    return GestureDetector(
      onTap: _showLocationPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasSelection
              ? AppTheme.primary.withOpacity(0.06)
              : const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: hasSelection
                ? AppTheme.primary.withOpacity(0.35)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasSelection ? Icons.location_on_rounded : Icons.public_rounded,
              color: hasSelection ? AppTheme.primary : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasSelection
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCountry!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedRegion!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
                  : const Text(
                'Davlat va viloyatni tanlang...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasSelection ? AppTheme.primary : AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Trek difficulty ──────────────────────────────────────────────────────

  Widget _buildTrekDifficultyPicker() {
    final levels = ['Boshlang\'ich', 'O\'rta', 'Qiyin', 'O\'ta qiyin'];
    return Wrap(
      spacing: 8,
      children: levels.map((level) {
        final selected = _trekDifficulty == level;
        return GestureDetector(
          onTap: () => setState(() => _trekDifficulty = level),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color:
                selected ? AppTheme.primary : const Color(0xFFE0E0E0),
              ),
            ),
            child: Text(
              level,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Phone field ──────────────────────────────────────────────────────────

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
      maxLength: 9,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        counterText: '',
        hintText: '__ ___ ____',
        hintStyle:
        const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF5F7F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: EdgeInsets.zero,
        prefixIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius:
            const BorderRadius.horizontal(left: Radius.circular(25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 6),
              Text(
                '+998',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        if (v.trim().length != 9) return 'Telefon raqam formati noto\'g\'ri';
        return null;
      },
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F7F5),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            size: 16,
            color: AppTheme.textMain,
          ),
        ),
      ),
      title: const Text(
        "Yangi joy qo'shish",
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.textMain,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── Upload bar ───────────────────────────────────────────────────────────

  Widget _uploadBar() {
    final isRoute = _routeUploading && !_uploading;
    final label = isRoute
        ? 'Marshrut fayli yuklanmoqda...'
        : 'Rasmlar yuklanmoqda... ${(_uploadProgress * 100).round()}%';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (!isRoute) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: const Color(0xFFE0E0E0),
                color: AppTheme.primary,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Reusable card / helpers ──────────────────────────────────────────────

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _secTitle(String t, String icon) => Row(
    children: [
      Text(icon, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 7),
      Text(
        t,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMain,
        ),
      ),
    ],
  );

  InputDecoration _inputDec(String hint, IconData? icon) => InputDecoration(
    hintText: hint,
    hintStyle:
    const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
    prefixIcon: icon != null
        ? Icon(icon, size: 18, color: AppTheme.textSecondary)
        : null,
    filled: true,
    fillColor: const Color(0xFFF5F7F5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Widget _textField(
      String label,
      TextEditingController ctrl, {
        String? hint,
        IconData? icon,
        bool required = true,
      }) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
      decoration: _inputDec(hint ?? label, icon),
      validator: required
          ? (v) =>
      (v == null || v.trim().isEmpty) ? 'Majburiy maydon' : null
          : null,
    );
  }

  // ── Map picker ───────────────────────────────────────────────────────────

  Widget _buildMapPickerBtn() => GestureDetector(
    onTap: _openMapPicker,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.08),
            AppTheme.primaryLight.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(Icons.map_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xaritadan tanlash',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _resolvedAddress ?? 'Joylashuvni xaritadan belgilang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: _resolvedAddress != null
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.primary),
        ],
      ),
    ),
  );

  Widget _dividerOr() => Row(
    children: [
      const Expanded(
          child: Divider(color: Color(0xFFE0E0E0), height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          "yoki qo'lda kiriting",
          style:
          TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ),
      const Expanded(
          child: Divider(color: Color(0xFFE0E0E0), height: 1)),
    ],
  );

  Widget _buildCoordFields() => Row(
    children: [
      Expanded(
          child:
          _coordField('Kenglik (lat)', _latCtrl, '41.627')),
      const SizedBox(width: 10),
      Expanded(
          child:
          _coordField('Uzunlik (lng)', _lngCtrl, '70.017')),
    ],
  );

  Widget _coordField(
      String label, TextEditingController ctrl, String hint) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            style:
            const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: _inputDec(hint, null).copyWith(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Kiriting';
              final val = double.tryParse(v.trim());
              if (val == null) return 'Noto\'g\'ri';
              if (label.contains('lat') ||
                  label.contains('Kenglik')) {
                if (val < -90 || val > 90) return '-90 dan 90 gacha';
              } else {
                if (val < -180 || val > 180)
                  return '-180 dan 180 gacha';
              }
              return null;
            },
          ),
        ],
      );

  Widget _addressPill() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              size: 13, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: _resolvingAddress
                ? const Text(
              'Manzil aniqlanmoqda...',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary),
            )
                : Text(
              _resolvedAddress!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Image picker ─────────────────────────────────────────────────────────

  Widget _buildImagePicker() {
    return Column(
      children: [
        if (_pickedImages.isNotEmpty) ...[
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pickedImages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == _pickedImages.length) {
                  if (_pickedImages.length < 8) return _addMoreBtn();
                  return const SizedBox.shrink();
                }
                return _imageThumb(_pickedImages[i], i);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_pickedImages.length}/8 rasm tanlandi',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _pickBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Galereya',
                  onTap: _pickImages,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pickBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Kamera',
                  onTap: _pickFromCamera,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _imageThumb(XFile file, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (_, snap) {
              if (snap.hasData) {
                return Image.memory(snap.data!,
                    width: 80, height: 80, fit: BoxFit.cover);
              }
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.image_rounded,
                    color: AppTheme.textSecondary, size: 28),
              );
            },
          ),
        ),
        Positioned(
          top: 3,
          right: 3,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 12),
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            bottom: 3,
            left: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Asosiy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _addMoreBtn() => GestureDetector(
    onTap: _pickImages,
    child: Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_rounded,
              color: AppTheme.primary, size: 22),
          const SizedBox(height: 3),
          const Text(
            'Qo\'shish',
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pickBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

  // ── Route file picker ────────────────────────────────────────────────────

  Widget _buildRouteFilePicker() {
    if (_routeFile != null) {
      final ext = (_routeFile!.extension ?? '').toUpperCase();
      final name = _routeFile!.name;
      final color = _routeExtColor(ext);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  ext,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Marshrut fayli tayyor',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _removeRouteFile,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 17, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickRouteFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.route_rounded,
                  color: Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Marshrut faylini yuklash',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: ['GPX', 'KML', 'GeoJSON']
                        .map(
                          (f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.upload_file_rounded,
                color: Color(0xFF2563EB), size: 22),
          ],
        ),
      ),
    );
  }

  Color _routeExtColor(String ext) {
    switch (ext) {
      case 'GPX':
        return const Color(0xFF16A34A);
      case 'KML':
        return const Color(0xFFD97706);
      case 'GEOJSON':
      case 'JSON':
        return const Color(0xFF2563EB);
      default:
        return AppTheme.primary;
    }
  }

  // ── Type / Season / Tag pickers ──────────────────────────────────────────

  Widget _buildTypePicker() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: kPlaceTypes.map((t) {
      final sel = _selectedType == t.id;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedType = t.id;
            if (_selectedType != 'toglar' &&
                _selectedType != 'choqqilar') {
              _trekDifficulty = null;
              _trekLengthCtrl.clear();
              _trekElevationCtrl.clear();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? t.color : const Color(0xFFF5F7F5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: sel ? t.color : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.icon,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                  sel ? Colors.white : AppTheme.textMain,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildSeasonPicker() {
    final seasons = [
      ('Spring', '🌸', 'Bahor', const Color(0xFF16A34A)),
      ('Summer', '☀️', 'Yoz', const Color(0xFFD97706)),
      ('Autumn', '🍂', 'Kuz', const Color(0xFFEA580C)),
      ('Winter', '❄️', 'Qish', const Color(0xFF2563EB)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: seasons.map((s) {
        final sel = _selectedSeasons.contains(s.$1);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (sel)
                _selectedSeasons.remove(s.$1);
              else
                _selectedSeasons.add(s.$1);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel
                  ? s.$4.withOpacity(0.12)
                  : const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: sel ? s.$4 : const Color(0xFFE0E0E0),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.$2,
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  s.$3,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? s.$4 : AppTheme.textMain,
                  ),
                ),
                if (sel) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded,
                      size: 13, color: s.$4),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTagPicker() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: _allTags.map((t) {
      final sel = _selectedTags.contains(t);
      final label = kTagUz[t] ?? t;
      return GestureDetector(
        onTap: () => setState(() {
          if (sel)
            _selectedTags.remove(t);
          else
            _selectedTags.add(t);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sel
                ? AppTheme.primary
                : const Color(0xFFF5F7F5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: sel
                  ? AppTheme.primary
                  : const Color(0xFFE0E0E0),
            ),
          ),
          child: Text(
            '# $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: sel
                  ? Colors.white
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// _LocationPickerSheet  — bitta sheet ichida mamlakat → viloyat
// ════════════════════════════════════════════════════════════════════════════

class _LocationPickerSheet extends StatefulWidget {
  final String? initialCountry;
  final String? initialRegion;
  final void Function(String country, String region) onSelected;

  const _LocationPickerSheet({
    required this.initialCountry,
    required this.initialRegion,
    required this.onSelected,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  // null = mamlakat ro'yxati ko'rsatiladi
  // non-null = o'sha mamlakat viloyatlari ko'rsatiladi
  String? _activeCountry;

  @override
  void initState() {
    super.initState();
    // Agar avval mamlakat tanlangan bo'lsa, to'g'ridan viloyat sahifasiga o't
    _activeCountry = widget.initialCountry;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sheet balandligi
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header: orqaga + sarlavha
          _buildHeader(),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Content: AnimatedSwitcher yordamida silliq o'tish
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                // Agar activeCountry null bo'lsa (countries) → chapdan,
                // aks holda (regions) → o'ngdan kiradi
                final isCountryList = (child.key == const ValueKey('countries'));
                final slideIn = Tween<Offset>(
                  begin: Offset(isCountryList ? -0.08 : 0.08, 0),
                  end: Offset.zero,
                ).animate(anim);
                return SlideTransition(
                  position: slideIn,
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: _activeCountry == null
                  ? _CountryList(
                key: const ValueKey('countries'),
                selectedCountry: widget.initialCountry,
                onCountryTap: (c) {
                  HapticFeedback.selectionClick();
                  setState(() => _activeCountry = c);
                },
              )
                  : _RegionList(
                key: ValueKey('regions_$_activeCountry'),
                country: _activeCountry!,
                selectedRegion: widget.initialCountry == _activeCountry
                    ? widget.initialRegion
                    : null,
                onRegionTap: (region) {
                  HapticFeedback.selectionClick();
                  widget.onSelected(_activeCountry!, region);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _activeCountry != null
                ? GestureDetector(
              key: const ValueKey('back_btn'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeCountry = null);
              },
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(left: 8, right: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 14,
                  color: AppTheme.textMain,
                ),
              ),
            )
                :Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(left: 8, right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Icon(
        Icons.select_all,
        size: 14,
        color: AppTheme.textMain,
      ),
    ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Align(
                key: ValueKey('title_${_activeCountry ?? "countries"}'),
                alignment: Alignment.centerLeft,
                child: Text(
                  _activeCountry ?? 'Davlatni tanlang',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mamlakat ro'yxati ────────────────────────────────────────────────────────

class _CountryList extends StatelessWidget {
  final String? selectedCountry;
  final void Function(String) onCountryTap;

  const _CountryList({
    super.key,
    required this.selectedCountry,
    required this.onCountryTap,
  });

  @override
  Widget build(BuildContext context) {
    final countries = kRegionsByCountry.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: countries.length,
      itemBuilder: (_, i) {
        final country = countries[i];
        final regionCount = kRegionsByCountry[country]!.length;
        final isSel = selectedCountry == country;

        return GestureDetector(
          onTap: () => onCountryTap(country),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isSel
                  ? AppTheme.primary.withOpacity(0.07)
                  : const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel
                    ? AppTheme.primary.withOpacity(0.4)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Flag / globe icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppTheme.primary.withOpacity(0.15)
                        : const Color(0xFFE8EDE8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    color: isSel ? AppTheme.primary : AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        country,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSel ? AppTheme.primary : AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$regionCount ta viloyat',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isSel ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Viloyat ro'yxati ─────────────────────────────────────────────────────────

class _RegionList extends StatelessWidget {
  final String country;
  final String? selectedRegion;
  final void Function(String) onRegionTap;

  const _RegionList({
    super.key,
    required this.country,
    required this.selectedRegion,
    required this.onRegionTap,
  });

  @override
  Widget build(BuildContext context) {
    final regions = kRegionsByCountry[country] ?? [];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: regions.length,
      itemBuilder: (_, i) {
        final region = regions[i];
        final isSel = selectedRegion == region;

        return GestureDetector(
          onTap: () => onRegionTap(region),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSel
                  ? AppTheme.primary.withOpacity(0.09)
                  : const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSel
                    ? AppTheme.primary.withOpacity(0.5)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSel
                      ? Icons.location_on_rounded
                      : Icons.location_on_outlined,
                  size: 18,
                  color: isSel ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    region,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                      isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? AppTheme.primary : AppTheme.textMain,
                    ),
                  ),
                ),
                if (isSel)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}