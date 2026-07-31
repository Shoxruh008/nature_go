import 'package:flutter/material.dart';

import '../services/favourites_service.dart';
import 'saved_places_list_screen.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SavedPlacesListScreen(
      title: 'Sevimlilar',
      service: FavouritesService.instance,
      activeIcon: Icons.favorite_rounded,
      activeColor: const Color(0xFFEF4444),
      activeBg: const Color(0xFFFFEBEE),
      emptyEmoji: '❤️',
      emptyTitle: "Sevimlilar yo'q",
      emptyMessage: "Joylarni sevimliga qo'shish uchun\n️ ❤️ tugmasini bosing",
      removedSuffix: "sevimlilardan olib tashlandi",
    );
  }
}
