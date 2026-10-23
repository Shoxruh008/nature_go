import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/saved_places_service.dart';
import '../utils/confirm_dialog.dart';
import 'visit_date_dialog.dart';

/// Joyni biror ro'yxatga (sevimlilar, borgan joylar, bormoqchi bo'lgan
/// joylar) qo'shish/olib tashlash uchun umumiy dumaloq tugma.
class SavedToggleButton extends StatefulWidget {
  final SavedPlacesService service;
  final String placeId;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final Color activeBg;
  final double size;
  final bool dark;

  /// `true` bo'lsa, holatni almashtirishdan oldin tasdiqlash oynasi chiqadi.
  final bool confirmBeforeToggle;

  /// Tasdiqlash xabarida ishlatiladigan ro'yxat nomi, masalan
  /// "borgan joylar" yoki "bormoqchi bo'lgan joylar".
  final String confirmSubject;

  /// `true` bo'lsa, qo'shishda tasdiq o'rniga "Qachon bordingiz?" sana oynasi
  /// chiqadi (borgan joylar uchun). Olib tashlashda oddiy tasdiq so'raladi.
  final bool askDate;

  const SavedToggleButton({
    super.key,
    required this.service,
    required this.placeId,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    required this.activeBg,
    this.size = 34,
    this.dark = false,
    this.confirmBeforeToggle = false,
    this.confirmSubject = '',
    this.askDate = false,
  });

  @override
  State<SavedToggleButton> createState() => _SavedToggleButtonState();
}

class _SavedToggleButtonState extends State<SavedToggleButton> {
  bool _isSaved = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    // Async yo'q — to'g'ridan to'g'ri in-memory cache dan o'qiladi
    final isSaved = widget.service.isSavedSync(widget.placeId);
    setState(() => _isSaved = isSaved);
  }

  Future<void> _load() async {
    final isSaved = await widget.service.isSaved(widget.placeId);
    if (mounted) setState(() { _isSaved = isSaved; _loaded = true; });
  }

  Future<void> _toggle() async {
    DateTime? visitedAt;
    if (widget.confirmBeforeToggle) {
      final adding = !_isSaved;
      if (adding && widget.askDate) {
        visitedAt = await showVisitDateDialog(context);
        if (visitedAt == null) return;
      } else {
        final confirmed = await showConfirmDialog(
          context,
          title: adding ? "Qo'shishni tasdiqlang" : 'Olib tashlashni tasdiqlang',
          message: adding
              ? "Bu joyni ${widget.confirmSubject} ro'yxatiga qo'shmoqchimisiz?"
              : "Bu joyni ${widget.confirmSubject} ro'yxatidan olib tashlamoqchimisiz?",
          confirmLabel: adding ? "Qo'shish" : 'Olib tashlash',
          destructive: !adding,
        );
        if (!confirmed) return;
      }
    }
    HapticFeedback.mediumImpact();
    try {
      final newVal =
          await widget.service.toggle(widget.placeId, visitedAt: visitedAt);
      if (mounted) setState(() => _isSaved = newVal);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text("Saqlab bo'lmadi. Qayta urinib ko'ring",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return SizedBox(width: widget.size, height: widget.size);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.dark
              ? Colors.black.withOpacity(0.35)
              : (_isSaved ? widget.activeBg : Colors.white.withOpacity(0.9)),
          shape: BoxShape.circle,
          border: widget.dark
              ? Border.all(color: Colors.white.withOpacity(0.2))
              : null,
          boxShadow: widget.dark
              ? null
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.elasticOut,
          child: Icon(
            _isSaved ? widget.activeIcon : widget.inactiveIcon,
            key: ValueKey(_isSaved),
            size: widget.size * 0.47,
            color: _isSaved
                ? widget.activeColor
                : (widget.dark ? Colors.white70 : const Color(0xFFBDBDBD)),
          ),
        ),
      ),
    );
  }
}
