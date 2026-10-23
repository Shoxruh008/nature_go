import '../models/place_model.dart';

/// Joy nomi, viloyati yoki tegi bo'yicha qidiruv. Teglar bazada inglizcha
/// saqlanadi, shuning uchun o'zbekcha tarjimasi bo'yicha ham qidiriladi.
bool placeMatchesQuery(PlaceModel p, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (p.name.toLowerCase().contains(q) || p.region.toLowerCase().contains(q)) {
    return true;
  }
  return p.tags.any((tag) {
    final lower = tag.toLowerCase();
    if (lower.contains(q)) return true;
    final uz = kTagUz[lower];
    return uz != null && uz.toLowerCase().contains(q);
  });
}
