import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/models/place_model.dart';

Future<PlaceModel> _load(Map<String, dynamic> data) async {
  final db = FakeFirebaseFirestore();
  await db.collection('places').doc('p1').set({
    'name': 'Boboiob',
    'region': 'Surxondaryo',
    'type': 'choqqilar',
    ...data,
  });
  return PlaceModel.fromFirestore(await db.collection('places').doc('p1').get());
}

void main() {
  group('requiresPermit', () {
    test("ko'rsatilmagan bo'lsa null", () async {
      expect((await _load({})).requiresPermit, isNull);
    });

    test("bool qiymatlar o'zgarishsiz o'qiladi", () async {
      expect((await _load({'requiresPermit': true})).requiresPermit, isTrue);
      expect((await _load({'requiresPermit': false})).requiresPermit, isFalse);
    });

    test("matn va son ko'rinishlari ham tushuniladi", () async {
      expect((await _load({'requiresPermit': 'true'})).requiresPermit, isTrue);
      expect((await _load({'requiresPermit': 'false'})).requiresPermit, isFalse);
      expect((await _load({'requiresPermit': 1})).requiresPermit, isTrue);
      expect((await _load({'requiresPermit': 0})).requiresPermit, isFalse);
      expect((await _load({'requiresPermit': 'noma\'lum'})).requiresPermit, isNull);
    });
  });

  group('bardoshli o\'qish', () {
    test("trek qiymatlari son bo'lsa ham yiqilmaydi", () async {
      final p = await _load({
        'trekLength': 25.6,
        'trekElevation': 2330,
        'trekHeight': '3770m',
        'trekDifficulty': "  O'rta  ",
      });
      expect(p.trekLength, '25.6');
      expect(p.trekElevationGain, '2330');
      expect(p.trekHeight, '3770m');
      expect(p.trekDifficulty, "O'rta");
    });

    test("bo'sh matnlar null bo'ladi (bo'sh karta chiqmaydi)", () async {
      final p = await _load({'trekLength': '  ', 'videoUrl': '', 'phone': ''});
      expect(p.trekLength, isNull);
      expect(p.videoUrl, isNull);
      expect(p.phone, isNull);
    });

    test("koordinata va reyting matn bo'lsa ham o'qiladi", () async {
      final p = await _load({'lat': '40.5', 'lng': 70, 'baseRating': '4.5'});
      expect(p.lat, 40.5);
      expect(p.lng, 70.0);
      expect(p.baseRating, 4.5);
    });

    test('mavjud bo\'lmagan qiymatlar uchun standart', () async {
      final p = await _load({});
      expect(p.lat, 0.0);
      expect(p.baseRating, 4.0);
    });
  });
}
