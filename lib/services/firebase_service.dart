import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/place_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._();
  static FirebaseService get instance => _instance;
  FirebaseService._();

  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final Map<String, PlaceModel> _placeCache = {};

  List<PlaceModel>? _placesCache;

  Stream<List<PlaceModel>> publishedPlaces() {
    return _db
        .collection('places')
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((s) {
      final places = s.docs.map(PlaceModel.fromFirestore).toList();
      _placesCache = places;
      for (final p in places) {
        _placeCache[p.id] = p;
      }
      return places;
    });
  }

  Future<PlaceModel?> getPlace(String id) async {
    if (_placeCache.containsKey(id)) return _placeCache[id];

    final doc = await _db.collection('places').doc(id).get();
    if (!doc.exists) return null;
    final place = PlaceModel.fromFirestore(doc);
    _placeCache[place.id] = place;
    return place;
  }

  void invalidateCache(String id) => _placeCache.remove(id);

  Future<List<String>> uploadImages(
      List<File> files, {
        required void Function(double progress) onProgress,
      }) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName =
          'places/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final ref = _storage.ref().child(fileName);
      final task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      task.snapshotEvents.listen((snap) {
        final progress =
            (i + snap.bytesTransferred / snap.totalBytes) / files.length;
        onProgress(progress);
      });
      await task;
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<String?> uploadRouteFile(
      File file, {
        required String fileName,
      }) async {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'gpx'     => 'application/gpx+xml',
        'kml'     => 'application/vnd.google-earth.kml+xml',
        'geojson' => 'application/geo+json',
        _         => 'application/octet-stream',
      };
      final storagePath =
          'routes/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref().child(storagePath);
      await ref.putFile(
        file,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {'originalName': fileName},
        ),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> uploadXImages(
    List<XFile> files, {
    required void Function(double progress) onProgress,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final bytes = await files[i].readAsBytes();
      final fileName =
          'places/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final ref = _storage.ref().child(fileName);
      final task = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      task.snapshotEvents.listen((snap) {
        final progress =
            (i + snap.bytesTransferred / snap.totalBytes) / files.length;
        onProgress(progress);
      });
      await task;
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<String?> uploadRouteFileFromPlatform(PlatformFile file) async {
    try {
      final Uint8List? bytes = file.bytes;
      if (bytes == null) return null;

      final ext = (file.extension ?? '').toLowerCase();
      final contentType = switch (ext) {
        'gpx' => 'application/gpx+xml',
        'kml' => 'application/vnd.google-earth.kml+xml',
        'geojson' || 'json' => 'application/geo+json',
        _ => 'application/octet-stream',
      };
      final storagePath =
          'routes/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child(storagePath);
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {'originalName': file.name},
        ),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String> addPlace(PlaceModel place) async {
    final ref = await _db.collection('places').add(place.toFirestore());
    return ref.id;
  }
}