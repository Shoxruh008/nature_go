import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/services/saved_places_service.dart';
import 'package:nature_go/utils/date_format.dart';
import 'package:nature_go/widgets/visit_date_dialog.dart';

void main() {
  group('formatUzDate', () {
    test("kun-oy, yil ko'rinishida chiqaradi", () {
      expect(formatUzDate(DateTime(2026, 8, 5)), '5-Avgust, 2026');
      expect(formatUzDate(DateTime(2025, 1, 31)), '31-Yanvar, 2025');
      expect(formatUzDate(DateTime(2024, 12, 1)), '1-Dekabr, 2024');
    });

    test('visitDay vaqtni tushga qo\'yadi, kun o\'zgarmaydi', () {
      final d = visitDay(DateTime(2026, 8, 5, 23, 59));
      expect(d, DateTime(2026, 8, 5, 12));
      expect(isSameDay(d, DateTime(2026, 8, 5, 1)), isTrue);
      expect(isSameDay(d, DateTime(2026, 8, 6)), isFalse);
    });
  });

  group('tashrif sanasi (SavedPlacesService)', () {
    late FakeFirebaseFirestore db;
    late MockFirebaseAuth auth;
    late SavedPlacesService visited;
    late SavedPlacesService wishlist;

    setUp(() {
      db = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', isAnonymous: false),
      );
      visited = SavedPlacesService('visited', db: db, auth: auth);
      wishlist = SavedPlacesService('wishlist', db: db, auth: auth);
    });

    test('toggle: tanlangan sana saqlanadi va dateOf qaytaradi', () async {
      final day = visitDay(DateTime(2026, 8, 5));
      await visited.toggle('p1', visitedAt: day);
      await pumpEventQueue();

      expect(visited.dateOf('p1'), day);
    });

    test("moveTo: sana borganlarga yoziladi, bormoqchilardan o'chadi", () async {
      final day = visitDay(DateTime(2026, 3, 14));
      await visited.getAll(); // ro'yxat ekrani ochilganidek: servis ulanadi
      await wishlist.toggle('p1');
      await pumpEventQueue();

      await wishlist.moveTo(visited, 'p1', visitedAt: day);
      await pumpEventQueue();

      expect(visited.dateOf('p1'), day);
      expect(wishlist.isSavedSync('p1'), isFalse);
    });

    test('setVisitDate: sanani yangilaydi', () async {
      await visited.toggle('p1', visitedAt: visitDay(DateTime(2026, 1, 1)));
      await pumpEventQueue();

      final newDay = visitDay(DateTime(2026, 2, 2));
      await visited.setVisitDate('p1', newDay);
      await pumpEventQueue();

      expect(visited.dateOf('p1'), newDay);
    });

    test("sanasiz eski yozuvlar uchun qo'shilgan vaqt ishlatiladi", () async {
      final added = DateTime(2025, 6, 1, 10);
      await db
          .collection('users')
          .doc('u1')
          .collection('visited')
          .doc('old')
          .set({'placeId': 'old', 'addedAt': Timestamp.fromDate(added)});

      expect(await visited.getAll(), contains('old'));
      expect(visited.dateOf('old'), added);
    });
  });

  group('showVisitDateDialog', () {
    Future<void> open(WidgetTester tester, {DateTime? initial}) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showVisitDateDialog(context,
                    placeName: 'Boboiob', initial: initial),
                child: const Text('ochish'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ochish'));
      await tester.pumpAndSettle();
    }

    testWidgets('standart sana bugun bo\'ladi', (tester) async {
      await open(tester);

      expect(find.text(formatUzDate(DateTime.now())), findsOneWidget);
      expect(find.text('Bugun'), findsOneWidget);
      expect(find.text('Boboiob'), findsOneWidget);
    });

    testWidgets('berilgan sana ko\'rsatiladi va "Bugun" belgisi yo\'q',
        (tester) async {
      await open(tester, initial: DateTime(2026, 8, 5));

      expect(find.text('5-Avgust, 2026'), findsOneWidget);
      expect(find.text('Bugun'), findsNothing);
    });

    testWidgets('Qo\'shish bosilsa tanlangan kun qaytadi', (tester) async {
      DateTime? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    result = await showVisitDateDialog(context),
                child: const Text('ochish'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ochish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Qo'shish"));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(isSameDay(result!, DateTime.now()), isTrue);
    });

    testWidgets('Bekor qilish null qaytaradi', (tester) async {
      DateTime? result = DateTime(2000);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    result = await showVisitDateDialog(context),
                child: const Text('ochish'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ochish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
