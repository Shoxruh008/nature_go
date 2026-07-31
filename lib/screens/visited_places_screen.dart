import 'package:flutter/material.dart';

import '../main.dart';
import '../services/saved_places_service.dart';
import 'saved_places_list_screen.dart';

class VisitedPlacesScreen extends StatelessWidget {
  const VisitedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SavedPlacesListScreen(
      title: 'Borgan joylarim',
      service: VisitedPlacesService.instance,
      activeIcon: Icons.check_circle_rounded,
      activeColor: AppTheme.primary,
      activeBg: const Color(0xFFE8F5E9),
      emptyEmoji: '✅',
      emptyTitle: "Hali hech qayerga bormadingiz",
      emptyMessage:
          "Joyga tashrif buyurganingizda uni\nbelgilash uchun ✅ tugmasini bosing",
      removedSuffix: "borgan joylar ro'yxatidan olib tashlandi",
      confirmBeforeRemove: true,
    );
  }
}
