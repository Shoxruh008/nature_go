import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../models/trip.g.dart';
import '../models/member.g.dart';
import '../models/expense.g.dart';

class StorageService {
  static const String _tripsBox = 'trips';
  static Box<Trip>? _box;

  /// Xotira ochilgan bo'lsa `true`. Ochilmasa (masalan, brauzer IndexedDB'ni
  /// taqiqlagan) ilova ishlayveradi, faqat xarajatlar saqlanmaydi.
  static bool get isReady => _box != null;

  static Future<void> init() async {
    await Hive.initFlutter();
    // Adapterlar konkret tip bilan ro'yxatdan o'tishi shart (generic Hive
    // tip bo'yicha qidiradi), shuning uchun alohida-alohida.
    final member = MemberAdapter();
    if (!Hive.isAdapterRegistered(member.typeId)) Hive.registerAdapter(member);
    final expense = ExpenseAdapter();
    if (!Hive.isAdapterRegistered(expense.typeId)) {
      Hive.registerAdapter(expense);
    }
    final trip = TripAdapter();
    if (!Hive.isAdapterRegistered(trip.typeId)) Hive.registerAdapter(trip);
    _box = await Hive.openBox<Trip>(_tripsBox);
  }

  static Future<Box<Trip>> _requireBox() async {
    if (_box == null) {
      try {
        await init();
      } catch (_) {}
    }
    final box = _box;
    if (box == null) {
      throw Exception(
          "Qurilma xotirasi ochilmadi, xarajatlarni saqlab bo'lmaydi");
    }
    return box;
  }

  static List<Trip> getAllTrips() {
    final box = _box;
    if (box == null) return [];
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> saveTrip(Trip trip) async {
    final box = await _requireBox();
    await box.put(trip.id, trip);
  }

  static Future<void> deleteTrip(String id) async {
    final box = await _requireBox();
    await box.delete(id);
  }

  static Trip? getTrip(String id) => _box?.get(id);
}
