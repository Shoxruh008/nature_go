import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/favourites_service.dart';

class FavouriteButton extends StatefulWidget {
  final String placeId;
  final double size;
  final bool dark;

  const FavouriteButton({
    super.key,
    required this.placeId,
    this.size = 34,
    this.dark = false,
  });

  @override
  State<FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<FavouriteButton> {
  bool _isFav = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    FavouritesService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    FavouritesService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    // Async yo'q — to'g'ridan to'g'ri in-memory cache dan o'qiladi
    final isFav = FavouritesService.instance.isFavouriteSync(widget.placeId);
    setState(() => _isFav = isFav);
  }

  Future<void> _load() async {
    final isFav = await FavouritesService.instance.isFavourite(widget.placeId);
    if (mounted) setState(() { _isFav = isFav; _loaded = true; });
  }

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    final newVal = await FavouritesService.instance.toggle(widget.placeId);
    if (mounted) setState(() => _isFav = newVal);
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
              : (_isFav ? const Color(0xFFFFEBEE) : Colors.white.withOpacity(0.9)),
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
            _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(_isFav),
            size: widget.size * 0.47,
            color: _isFav
                ? const Color(0xFFEF4444)
                : (widget.dark ? Colors.white70 : const Color(0xFFBDBDBD)),
          ),
        ),
      ),
    );
  }
}
