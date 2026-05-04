import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/trip.g.dart';
import '../models/member.g.dart';
import '../models/expense.g.dart';

class StorageService {
  static const String _tripsBox = 'trips';
  static late Box<Trip> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MemberAdapter());
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(TripAdapter());
    _box = await Hive.openBox<Trip>(_tripsBox);
  }

  static List<Trip> getAllTrips() {
    return _box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> saveTrip(Trip trip) async {
    await _box.put(trip.id, trip);
  }

  static Future<void> deleteTrip(String id) async {
    await _box.delete(id);
  }

  static Trip? getTrip(String id) {
    return _box.get(id);
  }
}
