import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import 'map_picker_page.dart';

const List<String> kUzbekistanRegions = [
  'Toshkent viloyati',
  'Andijon viloyati',
  'Farg\'ona viloyati',
  'Namangan viloyati',
  'Samarqand viloyati',
  'Buxoro viloyati',
  'Navoiy viloyati',
  'Qashqadaryo viloyati',
  'Surxondaryo viloyati',
  'Jizzax viloyati',
  'Sirdaryo viloyati',
  'Xorazm viloyati',
  'Qoraqalpog\'iston Respublikasi',
];

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

  static const List<String> _allTags = [
    'hiking', 'camping', 'picnic', 'swimming',
    'skiing', 'boating', 'wildlife', 'trekking',
    'mountain', 'forest', 'river', 'valley',
    'waterfall', 'lake', 'walking', 'botanical',
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
    final result = await _picker.pickMultiImage(imageQuality: 85);
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
        source: ImageSource.camera, imageQuality: 85);
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
        if (mounted) _showSnack('Faqat GPX, KML yoki GeoJSON fayl tanlang', error: true);
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
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRegion == null) { _showSnack('Viloyatni tanlang'); return; }
    if (_selectedSeasons.isEmpty) { _showSnack('Kamida 1 ta mavsum tanlang'); return; }
    if (_pickedImages.isEmpty) { _showSnack('Kamida 1 ta rasm tanlang'); return; }

    setState(() { _loading = true; _uploading = true; _uploadProgress = 0; });
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

      final place = PlaceModel(
        id: '', name: _nameCtrl.text.trim(), region: _selectedRegion!,
        type: _selectedType, seasonTypes: _selectedSeasons,
        lat: lat, lng: lng, images: imageUrls,
        description: _descCtrl.text.trim(), tags: _selectedTags,
        baseRating: 0, isPublished: false, routeFileUrl: routeUrl,
        videoUrl: _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
        phone: fullPhone,
      );

      await FirebaseService.instance.addPlace(place);
      if (mounted) {
        setState(() => _loading = false);
        Navigator.pop(context, '"${place.name}" qo\'shildi! Admin tasdiqlashini kuting.');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _uploading = false; _routeUploading = false; });
        _showSnack('Xato: $e', error: true);
      }
    }
  }
  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _videoCtrl.dispose();
    _phoneCtrl.dispose();
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
                        _textField('Joy nomi *', _nameCtrl,
                            hint: 'Masalan: Charvak ko\'li',
                            icon: Icons.landscape_rounded),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Viloyat', '🗺️'),
                        const SizedBox(height: 12),
                        _buildRegionDropdown(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Joy turi', '🏷️'),
                        const SizedBox(height: 12),
                        _buildTypePicker(),
                      ]),
                      const SizedBox(height: 12),
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
                        Text('Qurilmadan tanlang (max 8 ta)',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        _buildImagePicker(),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        _secTitle('Marshrut fayli', '🛤️'),
                        const SizedBox(height: 4),
                        Text('GPX, KML yoki GeoJSON format',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
                          decoration: _inputDec('Joy haqida qisqacha yozing...', null),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _videoCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDec('Video link (ixtiyoriy)', Icons.video_call),
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
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
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
                                style: TextStyle(fontSize: 12, color: Color(0xFF795548), height: 1.4),
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
                          onPressed: (_loading || _uploading || _routeUploading) ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Joy qo\'shish',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                      color: Colors.white, letterSpacing: 0.2)),
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

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
      maxLength: 9,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        counterText: '',
        hintText: '__ ___ ____',
        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(25)),
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
        if (v == null || v.trim().isEmpty) return null; // bo'sh bo'lsa OK
        if (v.trim().length != 9) return 'Telefon raqam formati no\'to\'g\'ri';
        return null;
      },
    );
  }

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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: AppTheme.textMain),
        ),
      ),
      title: Text("Yangi joy qo'shish",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
      centerTitle: true,
    );
  }

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
          Row(children: [
            const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ]),
          if (!isRoute) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: LinearProgressIndicator(value: _uploadProgress,
                  backgroundColor: const Color(0xFFE0E0E0), color: AppTheme.primary, minHeight: 4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _secTitle(String t, String icon) => Row(
    children: [
      Text(icon, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 7),
      Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
    ],
  );

  InputDecoration _inputDec(String hint, IconData? icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, size: 18, color: AppTheme.textSecondary) : null,
    filled: true,
    fillColor: const Color(0xFFF5F7F5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Widget _textField(String label, TextEditingController ctrl,
      {String? hint, IconData? icon, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
      decoration: _inputDec(hint ?? label, icon),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Majburiy maydon' : null : null,
    );
  }

  Widget _buildRegionDropdown() {
    return GestureDetector(
      onTap: _showRegionPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _selectedRegion == null ? const Color(0xFFE0E0E0) : AppTheme.primary.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.location_city_rounded, size: 18,
                color: _selectedRegion != null ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedRegion ?? 'Viloyatni tanlang...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _selectedRegion != null ? FontWeight.w600 : FontWeight.w400,
                  color: _selectedRegion != null ? AppTheme.textMain : AppTheme.textSecondary,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 20,
                color: _selectedRegion != null ? AppTheme.primary : AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RegionPickerSheet(
        selected: _selectedRegion,
        onChanged: (v) => setState(() => _selectedRegion = v),
      ),
    );
  }

  Widget _buildMapPickerBtn() => GestureDetector(
    onTap: _openMapPicker,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primary.withOpacity(0.08),
          AppTheme.primaryLight.withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(25)),
            child: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Xaritadan tanlash',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                const SizedBox(height: 2),
                Text(
                  _resolvedAddress ?? 'Joylashuvni xaritadan belgilang',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11,
                      color: _resolvedAddress != null ? AppTheme.primary : AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
        ],
      ),
    ),
  );

  Widget _dividerOr() => Row(
    children: [
      const Expanded(child: Divider(color: Color(0xFFE0E0E0), height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text("yoki qo'lda kiriting",
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ),
      const Expanded(child: Divider(color: Color(0xFFE0E0E0), height: 1)),
    ],
  );

  Widget _buildCoordFields() => Row(
    children: [
      Expanded(child: _coordField('Kenglik (lat)', _latCtrl, '41.627')),
      const SizedBox(width: 10),
      Expanded(child: _coordField('Uzunlik (lng)', _lngCtrl, '70.017')),
    ],
  );

  Widget _coordField(String label, TextEditingController ctrl, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        decoration: _inputDec(hint, null).copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Kiriting';
          final val = double.tryParse(v.trim());
          if (val == null) return 'Noto\'g\'ri';
          // lat: -90..90, lng: -180..180
          if (label.contains('lat') || label.contains('Kenglik')) {
            if (val < -90 || val > 90) return '-90 dan 90 gacha';
          } else {
            if (val < -180 || val > 180) return '-180 dan 180 gacha';
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
          const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: _resolvingAddress
                ? const Text('Manzil aniqlanmoqda...',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))
                : Text(_resolvedAddress!,
                style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500),
                maxLines: 2),
          ),
        ],
      ),
    ),
  );

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
          Text('${_pickedImages.length}/8 rasm tanlandi',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ] else ...[
          Row(
            children: [
              Expanded(child: _pickBtn(icon: Icons.photo_library_rounded, label: 'Galereya', onTap: _pickImages)),
              const SizedBox(width: 10),
              Expanded(child: _pickBtn(icon: Icons.camera_alt_rounded, label: 'Kamera', onTap: _pickFromCamera)),
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
                width: 80, height: 80,
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
          top: 3, right: 3,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            bottom: 3, left: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
              child: const Text('Asosiy',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Widget _addMoreBtn() => GestureDetector(
    onTap: _pickImages,
    child: Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primary, size: 22),
          const SizedBox(height: 3),
          const Text('Qo\'shish',
              style: TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );

  Widget _pickBtn({required IconData icon, required String label, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppTheme.primary.withOpacity(0.25), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

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
              width: 46, height: 46,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(25)),
              child: Center(child: Text(ext,
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 0.3))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text('Marshrut fayli tayyor',
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                  ]),
                ],
              ),
            ),
            GestureDetector(
              onTap: _removeRouteFile,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(25)),
                child: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
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
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25)),
              child: const Icon(Icons.route_rounded, color: Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Marshrut faylini yuklash',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4, runSpacing: 4,
                    children: ['GPX', 'KML', 'GeoJSON'].map((f) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(f, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB))),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB), size: 22),
          ],
        ),
      ),
    );
  }

  Color _routeExtColor(String ext) {
    switch (ext) {
      case 'GPX': return const Color(0xFF16A34A);
      case 'KML': return const Color(0xFFD97706);
      case 'GEOJSON':
      case 'JSON': return const Color(0xFF2563EB);
      default: return AppTheme.primary;
    }
  }

  Widget _buildTypePicker() => Wrap(
    spacing: 8, runSpacing: 8,
    children: kPlaceTypes.map((t) {
      final sel = _selectedType == t.id;
      return GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedType = t.id); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? t.color : const Color(0xFFF5F7F5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: sel ? t.color : const Color(0xFFE0E0E0), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(t.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppTheme.textMain)),
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
      spacing: 8, runSpacing: 8,
      children: seasons.map((s) {
        final sel = _selectedSeasons.contains(s.$1);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() { if (sel) _selectedSeasons.remove(s.$1); else _selectedSeasons.add(s.$1); });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? s.$4.withOpacity(0.12) : const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: sel ? s.$4 : const Color(0xFFE0E0E0), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.$2, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(s.$3, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? s.$4 : AppTheme.textMain)),
                if (sel) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_rounded, size: 13, color: s.$4),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTagPicker() => Wrap(
    spacing: 6, runSpacing: 6,
    children: _allTags.map((t) {
      final sel = _selectedTags.contains(t);
      final label = kTagUz[t] ?? t;
      return GestureDetector(
        onTap: () => setState(() { if (sel) _selectedTags.remove(t); else _selectedTags.add(t); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primary : const Color(0xFFF5F7F5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: sel ? AppTheme.primary : const Color(0xFFE0E0E0)),
          ),
          child: Text('# $label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
              color: sel ? Colors.white : AppTheme.textSecondary)),
        ),
      );
    }).toList(),
  );
}

class _RegionPickerSheet extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;
  const _RegionPickerSheet({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Viloyatni tanlang',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              shrinkWrap: true,
              itemCount: kUzbekistanRegions.length,
              itemBuilder: (_, i) {
                final region = kUzbekistanRegions[i];
                final sel = selected == region;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(region);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primary.withOpacity(0.09) : const Color(0xFFF5F7F5),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: sel ? AppTheme.primary.withOpacity(0.5) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(sel ? Icons.location_on_rounded : Icons.location_on_outlined,
                            size: 18, color: sel ? AppTheme.primary : AppTheme.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(region, style: TextStyle(
                              fontSize: 14,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? AppTheme.primary : AppTheme.textMain)),
                        ),
                        if (sel) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}