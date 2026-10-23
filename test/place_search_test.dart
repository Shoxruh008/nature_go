import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/models/place_model.dart';
import 'package:nature_go/utils/place_search.dart';

PlaceModel _place({
  String name = 'SuvTushar sharsharasi',
  String region = 'Qashqadaryo viloyati',
  List<String> tags = const ['hiking', 'waterfall'],
}) =>
    PlaceModel(
      id: '1',
      name: name,
      region: region,
      type: 'sharsharalar',
      seasonTypes: const [],
      lat: 0,
      lng: 0,
      images: const [],
      description: '',
      tags: tags,
      baseRating: 4,
    );

void main() {
  test("bo'sh qidiruv hammasini o'tkazadi", () {
    expect(placeMatchesQuery(_place(), ''), isTrue);
    expect(placeMatchesQuery(_place(), '   '), isTrue);
  });

  test("nom va viloyat bo'yicha, harf registrisiz topadi", () {
    expect(placeMatchesQuery(_place(), 'suvtushar'), isTrue);
    expect(placeMatchesQuery(_place(), 'QASHQADARYO'), isTrue);
  });

  test("inglizcha teg bo'yicha topadi", () {
    expect(placeMatchesQuery(_place(), 'hiking'), isTrue);
  });

  test("o'zbekcha teg tarjimasi bo'yicha topadi", () {
    expect(placeMatchesQuery(_place(), 'piyoda'), isTrue);
    expect(placeMatchesQuery(_place(), 'sharsara'), isTrue);
  });

  test('mos kelmasa false', () {
    expect(placeMatchesQuery(_place(), "cho'l"), isFalse);
    expect(placeMatchesQuery(_place(tags: const []), 'piyoda'), isFalse);
  });
}
