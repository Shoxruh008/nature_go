import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/trip.dart';
import '../services/storage_service.dart';
import '../utils/money.dart';
import 'create_trip_screen.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen>
    with SingleTickerProviderStateMixin {
  List<Trip> _trips = [];
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTrips();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _loadTrips() {
    setState(() {
      _trips = StorageService.getAllTrips();
    });
  }

  void _openCreateTrip() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTripScreen()),
    );
    if (result == true) _loadTrips();
  }

  void _openTrip(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
    );
    _loadTrips();
  }

  void _deleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sayohatni o'chirish",
            style: TextStyle(color: AppTheme.textMain)),
        content: Text(
          '"${trip.name}" ni o\'chirishni tasdiqlaysizmi?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentWarm,
              foregroundColor: Colors.white,
            ),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.deleteTrip(trip.id);
      _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text(
          'Xarajatlar',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openCreateTrip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text('Yangi',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (_trips.isEmpty)
            _buildEmptyState()
          else
            _buildTripsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text('🗺️', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Hali sayohat yo'q",
              style: TextStyle(
                color: AppTheme.textMain,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yangi sayohat yarating va\nxarajatlarni kuzating',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openCreateTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yangi sayohat yaratish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      sliver: AnimationLimiter(
        child: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                verticalOffset: 40,
                child: FadeInAnimation(
                  child: _TripCard(
                    trip: _trips[i],
                    onTap: () => _openTrip(_trips[i]),
                    onDelete: () => _deleteTrip(_trips[i]),
                  ),
                ),
              ),
            ),
            childCount: _trips.length,
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM, yyyy', 'uz').format(trip.date);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        trip.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: const TextStyle(
                            color: AppTheme.textMain,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(
                    label: 'Jami xarajat',
                    value: formatMoney(trip.totalAmount),
                    color: AppTheme.primary,
                  ),
                  _Stat(
                    label: 'Ishtirokchilar',
                    value: '${trip.members.length} kishi',
                    color: AppTheme.accentGold,
                  ),
                  _Stat(
                    label: 'Har biri',
                    value: formatMoney(trip.perPerson),
                    color: AppTheme.accentWarm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
