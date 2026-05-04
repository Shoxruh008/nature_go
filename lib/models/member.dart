import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 1)
class Member {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String color;

  Member({
    String? id,
    required this.name,
    this.color = '#6C63FF',
  }) : id = id ?? const Uuid().v4();
}
