import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import 'map_picker_sheet.dart';

// O'zbekiston viloyatlari
const List<String> kUzbekistanRegions = [
  'Toshkent shahri',
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

class AddPlaceSheet extends StatefulWidget {
  final ValueChanged<String> onAdded;
  const AddPlaceSheet({super.key, required this.onAdded});

  @override
  State<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<AddPlaceSheet>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _latCtrl   = TextEditingController();
  final _lngCtrl   = TextEditingController();

  String  _selectedType   = 'toglar';
  String? _selectedRegion;           // viloyat dropdown
  List<String> _selectedSeasons = [];
  List<String> _selectedTags    = [];

  // Images
  final List<File> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Upload state
  bool   _uploading    = false;
  double _uploadProgress = 0;
  bool   _loading      = false;

  // Location
  String? _resolvedAddress;
  bool    _resolvingAddress = false;

  late AnimationController _sheetAnim;

  static const List<String> _allTags = [
    'hiking', 'camping', 'picnic', 'swimming',
    'skiing', 'boating', 'wildlife', 'trekking',
    'mountain', 'forest', 'river', 'valley',
  ];

  @override
  void initState() {
    super.initState();
    _sheetAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _sheetAnim.forward();
    _latCtrl.addListener(_onCoordChanged);
    _lngCtrl.addListener(_onCoordChanged);
  }

  void _onCoordChanged() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat != null && lng != null) _resolveAddress(lat, lng);
    else setState(() => _resolvedAddress = null);
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    setState(() => _resolvingAddress = true);
    final address = await LocationService.instance.getFullAddress(lat, lng);
    if (mounted) setState(() { _resolvedAddress = address; _resolvingAddress = false; });
  }

  // ── Image picking ────────────────────────────────────────────

  Future<void> _pickImages() async {
    HapticFeedback.selectionClick();
    final result = await _picker.pickMultiImage(imageQuality: 85);
    if (result.isEmpty) return;
    setState(() {
      for (final x in result) {
        if (_pickedImages.length < 8) _pickedImages.add(File(x.path));
      }
    });
  }

  Future<void> _pickFromCamera() async {
    HapticFeedback.selectionClick();
    final result = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 85);
    if (result == null) return;
    if (_pickedImages.length < 8) {
      setState(() => _pickedImages.add(File(result.path)));
    }
  }

  void _removeImage(int index) {
    HapticFeedback.selectionClick();
    setState(() => _pickedImages.removeAt(index));
  }

  // ── Map picker ───────────────────────────────────────────────

  Future<void> _openMapPicker() async {
    HapticFeedback.mediumImpact();
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    final result = await showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapPickerSheet(initialLat: lat, initialLng: lng),
    );
    if (result != null && mounted) {
      setState(() {
        _latCtrl.text      = result.lat.toStringAsFixed(6);
        _lngCtrl.text      = result.lng.toStringAsFixed(6);
        _resolvedAddress   = result.label;
      });
    }
  }

  // ── Submit ───────────────────────────────────────────────────

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

    setState(() { _loading = true; _uploading = true; _uploadProgress = 0; });
    HapticFeedback.mediumImpact();

    try {
      // Upload images to Firebase Storage
      final urls = await FirebaseService.instance.uploadImages(
        _pickedImages,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      setState(() => _uploading = false);

      final lat = double.parse(_latCtrl.text.trim());
      final lng = double.parse(_lngCtrl.text.trim());

      final place = PlaceModel(
        id: '',
        name:        _nameCtrl.text.trim(),
        region:      _selectedRegion!,
        type:        _selectedType,
        seasonTypes: _selectedSeasons,
        lat: lat, lng: lng,
        images:      urls,
        description: _descCtrl.text.trim(),
        tags:        _selectedTags,
        baseRating:  0,
        isPublished: false,
      );

      await FirebaseService.instance.addPlace(place);
      if (mounted) {
        Navigator.pop(context);
        widget.onAdded('"${place.name}" qo\'shildi! Admin tasdiqlashini kuting.');
      }
    } catch (e) {
      setState(() { _loading = false; _uploading = false; });
      if (mounted) _showSnack('Xato: $e', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _sheetAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedBuilder(
      animation: _sheetAnim,
      builder: (_, child) => Opacity(
        opacity: _sheetAnim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _sheetAnim.value) * 40),
          child: child,
        ),
      ),
      child: Container(
        padding: EdgeInsets.only(bottom: bottomPad),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            _header(),
            if (_uploading) _uploadBar(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Asosiy
                      _card([
                        _secTitle('Asosiy ma\'lumot', '📝'),
                        const SizedBox(height: 14),
                        _textField('Joy nomi *', _nameCtrl,
                            hint: 'Masalan: Charvak ko\'li',
                            icon: Icons.landscape_rounded),
                      ]),
                      const SizedBox(height: 12),

                      // 2. Viloyat
                      _card([
                        _secTitle('Viloyat *', '🗺️'),
                        const SizedBox(height: 12),
                        _buildRegionDropdown(),
                      ]),
                      const SizedBox(height: 12),

                      // 3. Joy turi
                      _card([
                        _secTitle('Joy turi *', '🏷️'),
                        const SizedBox(height: 12),
                        _buildTypePicker(),
                      ]),
                      const SizedBox(height: 12),

                      // 4. Mavsum
                      _card([
                        _secTitle('Mavsum', '🌤️'),
                        const SizedBox(height: 12),
                        _buildSeasonPicker(),
                      ]),
                      const SizedBox(height: 12),

                      // 5. Joylashuv
                      _card([
                        _secTitle('Joylashuv *', '📍'),
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

                      // 6. Rasmlar
                      _card([
                        _secTitle('Rasmlar *', '🖼️'),
                        const SizedBox(height: 4),
                        Text('Qurilmadan tanlang (max 8 ta)',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        _buildImagePicker(),
                      ]),
                      const SizedBox(height: 12),

                      // 7. Tavsif
                      _card([
                        _secTitle('Tavsif', '📄'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDec(
                              'Joy haqida qisqacha yozing...', null),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // 8. Teglar
                      _card([
                        _secTitle('Teglar', '🏷️'),
                        const SizedBox(height: 12),
                        _buildTagPicker(),
                      ]),
                      const SizedBox(height: 16),

                      // Disclaimer
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(14),
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
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_loading || _uploading) ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            disabledBackgroundColor:
                            AppTheme.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_location_alt_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Joy qo\'shish',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.2)),
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

  // ════════════════════════════════════════════════════════════
  // SECTION WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _handle() => Container(
    width: 40, height: 4,
    margin: const EdgeInsets.only(top: 10, bottom: 4),
    decoration: BoxDecoration(
        color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    child: Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryLight],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.add_location_alt_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yangi joy qo\'shish',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppTheme.textMain)),
            Text('Tabiat manzilini ulashing',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.close, size: 18,
                color: AppTheme.textSecondary),
          ),
        ),
      ],
    ),
  );

  Widget _uploadBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Rasmlar yuklanmoqda... ${(_uploadProgress * 100).round()}%',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: AppTheme.border,
            color: AppTheme.primary,
            minHeight: 4,
          ),
        ),
      ],
    ),
  );

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _secTitle(String t, String icon) => Row(
    children: [
      Text(icon, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 7),
      Text(t,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppTheme.textMain)),
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
    fillColor: AppTheme.bg,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _textField(String label, TextEditingController ctrl,
      {String? hint, IconData? icon, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
      decoration: _inputDec(hint ?? label, icon),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Majburiy maydon' : null
          : null,
    );
  }

  // ── Region Dropdown ──────────────────────────────────────────
  Widget _buildRegionDropdown() {
    return GestureDetector(
      onTap: _showRegionPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedRegion == null
                ? AppTheme.border
                : AppTheme.primary.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_city_rounded,
              size: 18,
              color: _selectedRegion != null
                  ? AppTheme.primary
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedRegion ?? 'Viloyatni tanlang...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _selectedRegion != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: _selectedRegion != null
                      ? AppTheme.textMain
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: _selectedRegion != null
                    ? AppTheme.primary
                    : AppTheme.textSecondary),
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

  // ── Map picker button ────────────────────────────────────────
  Widget _buildMapPickerBtn() => GestureDetector(
    onTap: _openMapPicker,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primary.withOpacity(0.08),
          AppTheme.primaryLight.withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: AppTheme.primary.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.map_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xaritadan tanlash',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppTheme.textMain)),
                SizedBox(height: 2),
                Text('Joylashuvni xaritadan belgilang',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.primary),
        ],
      ),
    ),
  );

  Widget _dividerOr() => Row(
    children: [
      Expanded(child: Divider(color: AppTheme.border, height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('yoki qo\'lda kiriting',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ),
      Expanded(child: Divider(color: AppTheme.border, height: 1)),
    ],
  );

  Widget _buildCoordFields() => Row(
    children: [
      Expanded(child: _coordField('Kenglik (lat)', _latCtrl, '41.627')),
      const SizedBox(width: 10),
      Expanded(child: _coordField('Uzunlik (lng)', _lngCtrl, '70.017')),
    ],
  );

  Widget _coordField(String label, TextEditingController ctrl, String hint) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: _inputDec(hint, null).copyWith(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Kiriting';
              if (double.tryParse(v.trim()) == null) return 'Noto\'g\'ri';
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, size: 13, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: _resolvingAddress
                ? const Text('Manzil aniqlanmoqda...',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary))
                : Text(_resolvedAddress!,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.primary,
                    fontWeight: FontWeight.w500),
                maxLines: 2),
          ),
        ],
      ),
    ),
  );

  // ── Image Picker ─────────────────────────────────────────────
  Widget _buildImagePicker() {
    return Column(
      children: [
        // Image grid
        if (_pickedImages.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pickedImages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == _pickedImages.length) {
                  // Add more button
                  if (_pickedImages.length < 8) {
                    return _addMoreBtn();
                  }
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
                fontSize: 11, color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ] else ...[
          // Empty state — big pick button
          Row(
            children: [
              Expanded(
                child: _pickBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Galereyadan',
                  onTap: _pickImages,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pickBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Kameradan',
                  onTap: _pickFromCamera,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _imageThumb(File file, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file,
              width: 100, height: 100, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            bottom: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text('Asosiy',
                  style: TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Widget _addMoreBtn() => GestureDetector(
    onTap: _pickImages,
    child: Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.primary.withOpacity(0.3),
            style: BorderStyle.solid, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_rounded,
              color: AppTheme.primary, size: 28),
          const SizedBox(height: 4),
          const Text('Qo\'shish',
              style: TextStyle(
                  fontSize: 10, color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );

  Widget _pickBtn(
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.primary.withOpacity(0.25), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primary, size: 30),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  // ── Type Picker ──────────────────────────────────────────────
  Widget _buildTypePicker() => Wrap(
    spacing: 8, runSpacing: 8,
    children: kPlaceTypes.map((t) {
      final sel = _selectedType == t.id;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedType = t.id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? t.color : AppTheme.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? t.color : AppTheme.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(t.label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppTheme.textMain)),
            ],
          ),
        ),
      );
    }).toList(),
  );

  // ── Season Picker ────────────────────────────────────────────
  Widget _buildSeasonPicker() {
    final seasons = [
      ('Spring', '🌸', 'Bahor', const Color(0xFF16A34A)),
      ('Summer', '☀️', 'Yoz',   const Color(0xFFD97706)),
      ('Autumn', '🍂', 'Kuz',   const Color(0xFFEA580C)),
      ('Winter', '❄️', 'Qish',  const Color(0xFF2563EB)),
    ];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: seasons.map((s) {
        final sel = _selectedSeasons.contains(s.$1);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (sel) _selectedSeasons.remove(s.$1);
              else _selectedSeasons.add(s.$1);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? s.$4.withOpacity(0.12) : AppTheme.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? s.$4 : AppTheme.border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.$2, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(s.$3,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
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

  // ── Tag Picker ───────────────────────────────────────────────
  Widget _buildTagPicker() => Wrap(
    spacing: 6, runSpacing: 6,
    children: _allTags.map((t) {
      final sel = _selectedTags.contains(t);
      final label = kTagUz[t] ?? t;
      return GestureDetector(
        onTap: () => setState(() {
          if (sel) _selectedTags.remove(t);
          else _selectedTags.add(t);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primary : AppTheme.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: sel ? AppTheme.primary : AppTheme.border),
          ),
          child: Text('# $label',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : AppTheme.textSecondary)),
        ),
      );
    }).toList(),
  );
}

// ════════════════════════════════════════════════════════════
// VILOYAT TANLASH BOTTOM SHEET
// ════════════════════════════════════════════════════════════
class _RegionPickerSheet extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;
  const _RegionPickerSheet({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Viloyatni tanlang',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppTheme.textMain)),
            ),
          ),
          // List
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTheme.primary.withOpacity(0.09)
                          : const Color(0xFFF5F7F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? AppTheme.primary.withOpacity(0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sel
                              ? Icons.location_on_rounded
                              : Icons.location_on_outlined,
                          size: 18,
                          color: sel
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(region,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: sel
                                      ? AppTheme.primary
                                      : AppTheme.textMain)),
                        ),
                        if (sel)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.primary, size: 20),
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