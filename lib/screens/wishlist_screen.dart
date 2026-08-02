import 'package:flutter/material.dart';

import '../main.dart';
import '../services/saved_places_service.dart';
import 'saved_places_list_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SavedPlacesListScreen(
      title: "Bormoqchi bo'lgan joylarim",
      service: WishlistService.instance,
      activeIcon: Icons.bookmark_rounded,
      activeColor: const Color(0xFFFF6F00),
      activeBg: const Color(0xFFFFF3E0),
      emptyEmoji: '🔖',
      emptyTitle: "Ro'yxat bo'sh",
      emptyMessage:
          "Bormoqchi bo'lgan joylaringizni belgilash\nuchun 🔖 tugmasini bosing",
      removedSuffix: "ro'yxatdan olib tashlandi",
      confirmBeforeRemove: true,
      moveToService: VisitedPlacesService.instance,
      moveToLabel: 'Bordim',
      moveToIcon: Icons.check_circle_rounded,
      moveToColor: AppTheme.primary,
      moveToBg: const Color(0xFFE8F5E9),
      moveToSuffix: "borgan joylarga ko'chirildi",
    );
  }
}
