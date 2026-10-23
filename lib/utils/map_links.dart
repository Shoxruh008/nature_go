/// Tashqi xarita ilovalarida "shu joyga marshrut" ochish uchun havolalar.
/// Marshrut boshlanishi sifatida foydalanuvchining joriy joylashuvi olinadi.
class MapLinks {
  MapLinks._();

  static String _c(double v) => v.toStringAsFixed(6);

  /// Yandex Maps ilovasi (o'rnatilgan bo'lsa).
  static Uri yandexApp(double lat, double lng) => Uri.parse(
      'yandexmaps://maps.yandex.ru/?rtext=~${_c(lat)},${_c(lng)}&rtt=auto');

  /// Yandex Maps veb versiyasi.
  static Uri yandexWeb(double lat, double lng) => Uri.parse(
      'https://yandex.com/maps/?rtext=~${_c(lat)},${_c(lng)}&rtt=auto');

  /// Google Maps (ilova o'rnatilgan bo'lsa ilovada, aks holda brauzerda ochiladi).
  static Uri google(double lat, double lng) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_c(lat)},${_c(lng)}&travelmode=driving');

  /// Android'dagi standart xarita ilovalari.
  static Uri geo(double lat, double lng, String label) => Uri.parse(
      'geo:${_c(lat)},${_c(lng)}?q=${_c(lat)},${_c(lng)}(${Uri.encodeComponent(label)})');

  /// iOS Apple Maps.
  static Uri apple(double lat, double lng) => Uri.parse(
      'https://maps.apple.com/?daddr=${_c(lat)},${_c(lng)}&dirflg=d');

  /// Hech qanday xarita ilovasi bo'lmasa ishlaydigan ochiq variant.
  static Uri openStreetMap(double lat, double lng) => Uri.parse(
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=%3B${_c(lat)}%2C${_c(lng)}');
}
