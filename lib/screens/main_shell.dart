import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'home_screen.dart';
import 'favourites_screen.dart';
import 'trip_list_screen.dart';
import 'add_place_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    if (index == 1) {
      _showAddPromoSheet();
      return;
    }
    setState(() => _currentIndex = index);
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
        body: IndexedStack(
          index: _pageIndex(_currentIndex),
          children: const [
            HomeScreen(),
            FavouritesScreen(),
            TripListScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  int _pageIndex(int navIndex) {
    if (navIndex == 0) return 0;
    if (navIndex == 2) return 1;
    if (navIndex == 3) return 2;
    return 0;
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Bosh sahifa',
              ),
              _buildNavAddButton(),
              _buildNavItem(
                index: 2,
                icon: Icons.favorite_rounded,
                label: 'Sevimlilar',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.calculate_rounded,
                label: 'Xarajatlar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    const color = AppTheme.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isActive ? color : const Color(0xFFB0BDB0),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : const Color(0xFFB0BDB0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavAddButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavTap(1),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.add_location_alt_rounded,
                size: 24,
                color: Color(0xFFB0BDB0),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "Joy qo'shish",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFFB0BDB0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPromoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPromoSheet(
        onAddTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => const AddPlaceScreen(),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: anim, child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddPromoSheet extends StatelessWidget {
  final VoidCallback onAddTap;
  const _AddPromoSheet({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)),
          ),
          Image.asset(
            'assets/c1.png',
            width: 150,
            height: 150,
          ),
          const Text(
            "Ko'proq joy qo'shing",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          const Text(
            "Ko'proq yangi joy qo'shing , agar admin tomonidan tasdiqlanib dasturga qo'shilsa biz sizga pul mukofotini taqdim qilamiz!!",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onAddTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "Joy qo'shish",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
