import 'package:flutter/material.dart';

import '../services/favourites_service.dart';
import 'saved_toggle_button.dart';

class FavouriteButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SavedToggleButton(
      service: FavouritesService.instance,
      placeId: placeId,
      size: size,
      dark: dark,
      activeIcon: Icons.favorite_rounded,
      inactiveIcon: Icons.favorite_border_rounded,
      activeColor: const Color(0xFFEF4444),
      activeBg: const Color(0xFFFFEBEE),
    );
  }
}
