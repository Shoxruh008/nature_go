import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'member.dart';
import 'expense.dart';

@HiveType(typeId: 0)
class Trip extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  List<Member> members;

  @HiveField(4)
  List<Expense> expenses;

  @HiveField(5)
  String emoji;

  Trip({
    String? id,
    required this.name,
    required this.date,
    List<Member>? members,
    List<Expense>? expenses,
    this.emoji = '✈️',
  })  : id = id ?? const Uuid().v4(),
        members = members ?? [],
        expenses = expenses ?? [];

  double get totalAmount =>
      expenses.fold(0, (sum, e) => sum + e.amount);

  double get perPerson =>
      members.isEmpty ? 0 : totalAmount / members.length;

  Map<String, double> get balances {
    final Map<String, double> paid = {};
    for (var m in members) {
      paid[m.id] = 0;
    }
    for (var e in expenses) {
      paid[e.payerId] = (paid[e.payerId] ?? 0) + e.amount;
    }
    final per = perPerson;
    final Map<String, double> balances = {};
    for (var m in members) {
      balances[m.id] = (paid[m.id] ?? 0) - per;
    }
    return balances;
  }

  List<Settlement> get settlements {
    final b = balances;
    final creditors = <String, double>{};
    final debtors = <String, double>{};

    b.forEach((id, amount) {
      if (amount > 0.01) {
        creditors[id] = amount;
      } else if (amount < -0.01) {
        debtors[id] = -amount;
      }
    });

    final result = <Settlement>[];
    final cList = creditors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dList = debtors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int ci = 0, di = 0;
    final cAmounts = cList.map((e) => e.value).toList();
    final dAmounts = dList.map((e) => e.value).toList();

    while (ci < cList.length && di < dList.length) {
      final amount = cAmounts[ci] < dAmounts[di]
          ? cAmounts[ci]
          : dAmounts[di];
      result.add(Settlement(
        fromId: dList[di].key,
        toId: cList[ci].key,
        amount: amount,
      ));
      cAmounts[ci] -= amount;
      dAmounts[di] -= amount;
      if (cAmounts[ci] < 0.01) ci++;
      if (dAmounts[di] < 0.01) di++;
    }

    return result;
  }

  Member? memberById(String id) {
    try {
      return members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}

class Settlement {
  final String fromId;
  final String toId;
  final double amount;

  Settlement({
    required this.fromId,
    required this.toId,
    required this.amount,
  });
}
