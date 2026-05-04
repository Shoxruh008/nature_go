import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 2)
class Expense {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String payerId;

  @HiveField(4)
  String category;

  @HiveField(5)
  DateTime createdAt;

  Expense({
    String? id,
    required this.title,
    required this.amount,
    required this.payerId,
    this.category = 'other',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}

class ExpenseCategory {
  static const Map<String, Map<String, dynamic>> categories = {
    'food': {'label': 'Ovqat', 'emoji': '🍽️'},
    'transport': {'label': 'Transport', 'emoji': '🚗'},
    'hotel': {'label': 'Mehmonxona', 'emoji': '🏨'},
    'entertainment': {'label': 'Ko\'ngil ochish', 'emoji': '🎉'},
    'shopping': {'label': 'Xarid', 'emoji': '🛍️'},
    'other': {'label': 'Boshqa', 'emoji': '📋'},
  };

  static String emoji(String category) =>
      categories[category]?['emoji'] ?? '💸';

  static String label(String category) =>
      categories[category]?['label'] ?? 'Boshqa';
}
