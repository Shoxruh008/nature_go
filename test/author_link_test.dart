import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/models/place_model.dart';
import 'package:nature_go/utils/author_link.dart';

void main() {
  group('normalizeAuthorUrl', () {
    test('http/https havolalarni qabul qiladi', () {
      expect(normalizeAuthorUrl('https://www.youtube.com/@naturego').toString(),
          'https://www.youtube.com/@naturego');
      expect(normalizeAuthorUrl('http://example.com/x')?.scheme, 'http');
    });

    test("sxemasiz havolaga https qo'shadi va bo'sh joyni olib tashlaydi", () {
      expect(normalizeAuthorUrl('  instagram.com/naturego  ').toString(),
          'https://instagram.com/naturego');
      expect(normalizeAuthorUrl('t.me/naturego').toString(),
          'https://t.me/naturego');
    });

    test("xavfli yoki yaroqsiz qiymatlarni rad etadi", () {
      for (final raw in [
        null,
        '',
        '   ',
        'javascript:alert(1)',
        'mailto:a@b.com',
        'tel:+998901234567',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///etc/passwd',
        'ftp://example.com/x',
        'faqat matn',
        'localhost',
      ]) {
        expect(normalizeAuthorUrl(raw), isNull, reason: '$raw');
      }
    });
  });

  group('authorLabel', () {
    Uri u(String s) => Uri.parse(s);

    test("berilgan nom birinchi o'rinda", () {
      expect(authorLabel(u('https://youtube.com/@abc'), name: 'Ali Valiyev'),
          'Ali Valiyev');
      expect(authorLabel(u('https://youtube.com/@abc'), name: '   '), '@abc');
    });

    test('havoladan nom ajratadi', () {
      expect(authorLabel(u('https://www.youtube.com/@naturego')), '@naturego');
      expect(authorLabel(u('https://youtube.com/c/NatureGo')), 'NatureGo');
      expect(authorLabel(u('https://youtube.com/channel/UC123')), 'YouTube kanali');
      expect(authorLabel(u('https://instagram.com/naturego/')), '@naturego');
      expect(authorLabel(u('https://t.me/@naturego')), '@naturego');
      expect(authorLabel(u('https://www.tiktok.com/@naturego')), '@naturego');
      expect(authorLabel(u('https://facebook.com/naturego')), 'naturego');
      expect(authorLabel(u('https://www.example.com/page')), 'example.com');
    });
  });

  test('PlaceModel muallif maydonlarini o\'qiydi', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('places').doc('p1').set({
      'name': 'X',
      'region': 'Y',
      'type': 'kollar',
      'videoUrl': 'https://youtu.be/dQw4w9WgXcQ',
      'videoAuthorUrl': 'https://youtube.com/@naturego',
      'videoAuthorName': '  NatureGo jamoasi ',
    });
    final p = PlaceModel.fromFirestore(await db.collection('places').doc('p1').get());

    expect(p.videoAuthorUrl, 'https://youtube.com/@naturego');
    expect(p.videoAuthorName, 'NatureGo jamoasi');
  });

  test("muallif ko'rsatilmasa null", () async {
    final db = FakeFirebaseFirestore();
    await db.collection('places').doc('p1').set({'name': 'X', 'region': 'Y', 'type': 'kollar'});
    final p = PlaceModel.fromFirestore(await db.collection('places').doc('p1').get());

    expect(p.videoAuthorUrl, isNull);
    expect(p.videoAuthorName, isNull);
  });
}
