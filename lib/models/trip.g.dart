import 'package:hive/hive.dart';
import 'trip.dart';
import 'member.dart';
import 'expense.dart';

class TripAdapter extends TypeAdapter<Trip> {
  @override
  final int typeId = 0;

  @override
  Trip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Trip(
      id: fields[0] as String,
      name: fields[1] as String,
      date: fields[2] as DateTime,
      members: (fields[3] as List).cast<Member>(),
      expenses: (fields[4] as List).cast<Expense>(),
      emoji: fields[5] as String? ?? '✈️',
    );
  }

  @override
  void write(BinaryWriter writer, Trip obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.members)
      ..writeByte(4)
      ..write(obj.expenses)
      ..writeByte(5)
      ..write(obj.emoji);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
