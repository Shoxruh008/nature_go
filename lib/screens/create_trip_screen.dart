import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../models/member.dart';
import '../services/storage_service.dart';
import '../main.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _nameController = TextEditingController();
  final _memberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  List<Member> _members = [];
  String _selectedEmoji = '✈️';
  bool _isSaving = false;

  final List<String> _emojis = [
    '✈️', '🏔️', '🏖️', '🌊', '🏕️', '🎿', '🚂', '🚢',
    '🌍', '🗺️', '🎒', '🏙️', '🌄', '🎭', '🍽️', '🎪',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;
    if (_members.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
      _showSnack('Bu ism allaqachon qo\'shilgan', error: true);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _members.add(Member(
        name: name,
        color: AppTheme.memberColors[
        _members.length % AppTheme.memberColors.length]
            .toString(),
      ));
    });
    _memberController.clear();
  }

  void _removeMember(int index) {
    HapticFeedback.selectionClick();
    setState(() => _members.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_members.isEmpty) {
      _showSnack('Kamida 1 ta ishtirokchi qo\'shing');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final trip = Trip(
      name: _nameController.text.trim(),
      date: _selectedDate,
      members: _members,
      emoji: _selectedEmoji,
    );
    await StorageService.saveTrip(trip);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => child!,
    );
    if (picked != null) setState(() => _selectedDate = picked);
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
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        appBar: _buildAppBar(),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card([
                  _secTitle('Emoji tanlang', '🎨'),
                  const SizedBox(height: 14),
                  _buildEmojiPicker(),
                ]),
                const SizedBox(height: 12),
                _card([
                  _secTitle('Sayohat nomi', '📝'),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMain,
                    ),
                    decoration: _inputDec(
                      'Miraki safari, Samarqand...',
                      Icons.map_outlined,
                    ),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nom kiriting' : null,
                  ),
                ]),
                const SizedBox(height: 12),
                _card([
                  _secTitle('Sana', '📅'),
                  const SizedBox(height: 14),
                  _buildDatePicker(),
                ]),
                const SizedBox(height: 12),
                _card([
                  _secTitle('Ishtirokchilar', '👥'),
                  const SizedBox(height: 14),
                  _buildMembersSection(),
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
                      Text('💡', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sayohatni yaratgandan so\'ng xarajatlarni qo\'shishingiz mumkin.',
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
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      disabledBackgroundColor:
                      AppTheme.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
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
                          'Sayohat yaratish',
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
        'Yangi sayohat',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.textMain,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildEmojiPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _emojis.map((e) {
        final selected = e == _selectedEmoji;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedEmoji = e);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withOpacity(0.12)
                  : const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.primary
                    : const Color(0xFFE0E0E0),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('dd MMMM, yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _memberController,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMain,
                ),
                decoration: _inputDec('Ism kiriting...', Icons.person_add_outlined),
                onFieldSubmitted: (_) => _addMember(),
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _addMember,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        if (_members.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EDE8)),
            ),
            child: Column(
              children: _members.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final color = AppTheme.memberColors[
                i % AppTheme.memberColors.length];
                final isLast = i == _members.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                m.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              m.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _removeMember(i),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.red,
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        indent: 64,
                        endIndent: 14,
                        color: Color(0xFFE8EDE8),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '${_members.length} ta ishtirokchi qo\'shildi',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

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
    hintStyle: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 13,
    ),
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}