import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/screens/auth_screen.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("standart holatda ro'yxatdan o'tish rejimi ko'rinadi",
      (tester) async {
    await _pumpScreen(tester);

    expect(find.text('NatureGo'), findsOneWidget);
    // Tab + asosiy tugma
    expect(find.text("Ro'yxatdan o'tish"), findsNWidgets(2));
    expect(find.text('Telefon raqam'), findsOneWidget);
    expect(find.text('Parol'), findsOneWidget);
  });

  testWidgets("Kirish tabiga o'tganda matn almashadi", (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Kirish').first);
    await tester.pumpAndSettle();

    expect(
        find.text('Davom etish uchun akkountingizga kiring'), findsOneWidget);
  });

  testWidgets('telefon kiritilganda 2-3-2-2 formatlanadi', (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '901234567');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '90 123 45 67');
  });

  testWidgets("bo'sh telefon bilan yuborilsa xato xabari chiqadi",
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();

    expect(find.text('Telefon raqamingizni kiriting'), findsOneWidget);
  });

  testWidgets("parol bo'sh bo'lsa parol xatosi chiqadi", (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '901234567');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();

    expect(find.text('Parolingizni kiriting'), findsOneWidget);
  });
}
