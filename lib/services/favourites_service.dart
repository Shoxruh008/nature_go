import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavouritesService extends ChangeNotifier {
  static final FavouritesService _instance = FavouritesService._();
  static FavouritesService get instance => _instance;
  FavouritesService._();

  static const _key = 'favourite_place_ids';

  Set<String> _favourites = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    _favourites = list.toSet();
    _loaded = true;
  }

  Future<Set<String>> getAll() async {
    await _ensureLoaded();
    return Set.from(_favourites);
  }

  Future<bool> isFavourite(String placeId) async {
    await _ensureLoaded();
    return _favourites.contains(placeId);
  }

  /// Listener ichida ishlatiladigan sync versiya — _ensureLoaded bo'lgan bo'lishi kerak
  bool isFavouriteSync(String placeId) {
    return _favourites.contains(placeId);
  }

  Future<bool> toggle(String placeId) async {
    await _ensureLoaded();
    if (_favourites.contains(placeId)) {
      _favourites.remove(placeId);
    } else {
      _favourites.add(placeId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favourites.toList());
    notifyListeners(); // FavouritesScreen avtomatik yangilanadi
    return _favourites.contains(placeId);
  }

  Future<void> remove(String placeId) async {
    await _ensureLoaded();
    _favourites.remove(placeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favourites.toList());
    notifyListeners();
  }
}
