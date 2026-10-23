import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/utils/map_links.dart';

void main() {
  const lat = 40.788041;
  const lng = 70.401003;

  test('Yandex havolalari manzil koordinatasini o\'z ichiga oladi', () {
    expect(MapLinks.yandexApp(lat, lng).toString(),
        'yandexmaps://maps.yandex.ru/?rtext=~40.788041,70.401003&rtt=auto');
    expect(MapLinks.yandexWeb(lat, lng).host, 'yandex.com');
    expect(MapLinks.yandexWeb(lat, lng).queryParameters['rtext'],
        '~40.788041,70.401003');
  });

  test('Google Maps marshruti manzilni destination sifatida beradi', () {
    final uri = MapLinks.google(lat, lng);
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['destination'], '40.788041,70.401003');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  test('geo havolasi nomni xavfsiz kodlaydi', () {
    final uri = MapLinks.geo(lat, lng, "Qizil Navr & sharshara (G'or)");
    expect(uri.scheme, 'geo');
    expect(uri.toString(), contains('40.788041,70.401003'));
    expect(uri.toString(), isNot(contains(' ')));
  });

  test('koordinatalar 6 xonagacha yaxlitlanadi', () {
    expect(MapLinks.apple(1.5, 2.25).queryParameters['daddr'],
        '1.500000,2.250000');
  });

  test('OpenStreetMap havolasi to\'g\'ri tuzilgan', () {
    final uri = MapLinks.openStreetMap(lat, lng);
    expect(uri.host, 'www.openstreetmap.org');
    expect(uri.queryParameters['route'], ';40.788041,70.401003');
  });
}
