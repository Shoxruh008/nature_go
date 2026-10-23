import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/models/expense.dart';
import 'package:nature_go/models/member.dart';
import 'package:nature_go/models/trip.dart';

Trip _trip(List<Member> members, List<Expense> expenses) => Trip(
      name: 'Test',
      date: DateTime(2026, 1, 1),
      members: members,
      expenses: expenses,
    );

void main() {
  final a = Member(id: 'a', name: 'Ali');
  final b = Member(id: 'b', name: 'Vali');
  final c = Member(id: 'c', name: 'Soli');

  test("bitta kishi to'lagan: qolganlar unga qarzdor", () {
    final trip = _trip([a, b, c], [
      Expense(title: 'Mehmonxona', amount: 90, payerId: 'a'),
    ]);

    expect(trip.totalAmount, 90);
    expect(trip.perPerson, 30);

    final s = trip.settlements;
    expect(s, hasLength(2));
    expect(s.every((x) => x.toId == 'a'), isTrue);
    expect(s.map((x) => x.amount), everyElement(closeTo(30, 0.001)));
  });

  test('hisob-kitob balansni nolga tushiradi', () {
    final trip = _trip([a, b, c], [
      Expense(title: 'Ovqat', amount: 100, payerId: 'a'),
      Expense(title: "Yoqilg'i", amount: 50, payerId: 'b'),
      Expense(title: 'Suv', amount: 10, payerId: 'c'),
    ]);

    final balance = trip.balances;
    for (final s in trip.settlements) {
      balance[s.fromId] = balance[s.fromId]! + s.amount;
      balance[s.toId] = balance[s.toId]! - s.amount;
    }
    for (final v in balance.values) {
      expect(v, closeTo(0, 0.02));
    }
  });

  test("hamma teng to'lagan bo'lsa to'lov kerak emas", () {
    final trip = _trip([a, b], [
      Expense(title: 'A', amount: 40, payerId: 'a'),
      Expense(title: 'B', amount: 40, payerId: 'b'),
    ]);
    expect(trip.settlements, isEmpty);
  });

  test("a'zolar yoki xarajat bo'lmasa xatosiz ishlaydi", () {
    expect(_trip([], []).perPerson, 0);
    expect(_trip([a, b], []).settlements, isEmpty);
  });

  test('memberById topilmasa null qaytaradi', () {
    final trip = _trip([a], []);
    expect(trip.memberById('a')?.name, 'Ali');
    expect(trip.memberById('x'), isNull);
  });
}
