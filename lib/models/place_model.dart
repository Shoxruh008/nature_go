import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlaceModel {
  final String id;
  final String name;
  final String region;
  final String type;
  final List<String> seasonTypes;
  final double lat;
  final double lng;
  final List<String> images;
  final String description;
  final List<String> tags;
  final double baseRating;
  final bool isPublished;
  final DateTime? createdAt;
  final String? routeFileUrl;
  final String? videoUrl;

  PlaceModel({
    required this.id,
    required this.name,
    required this.region,
    required this.type,
    required this.seasonTypes,
    required this.lat,
    required this.lng,
    required this.images,
    required this.description,
    required this.tags,
    required this.baseRating,
    this.isPublished = true,
    this.createdAt,
    this.routeFileUrl,
    this.videoUrl,
  });

  double? distanceTo;

  factory PlaceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PlaceModel(
      id: doc.id,
      name: d['name'] ?? '',
      region: d['region'] ?? '',
      type: d['type'] ?? '',
      seasonTypes: List<String>.from(d['seasonTypes'] ?? []),
      lat: (d['lat'] ?? 0.0).toDouble(),
      lng: (d['lng'] ?? 0.0).toDouble(),
      images: List<String>.from(d['images'] ?? []),
      description: d['description'] ?? '',
      tags: List<String>.from(d['tags'] ?? []),
      baseRating: (d['baseRating'] ?? 4.0).toDouble(),
      isPublished: d['isPublished'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      routeFileUrl: d['routeFileUrl'] as String?,
      videoUrl: d['videoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'region': region,
    'type': type,
    'seasonTypes': seasonTypes,
    'lat': lat,
    'lng': lng,
    'images': images,
    'description': description,
    'tags': tags,
    'baseRating': baseRating,
    'isPublished': isPublished,
    'createdAt': FieldValue.serverTimestamp(),
    if (routeFileUrl != null) 'routeFileUrl': routeFileUrl,
    if (videoUrl != null) 'videoUrl': videoUrl,
  };

  PlaceType get placeType => placeTypeFromId(type);
}

class PlaceType {
  final String id;
  final String label;
  final String icon;
  final Color color;
  final Color bg;

  const PlaceType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });
}

final List<PlaceType> kPlaceTypes = [
  PlaceType(id: 'toglar', label: "Tog'lar", icon: '⛰️', color: const Color(0xFF2E7D32), bg: const Color(0xFFE8F5E9)),
  PlaceType(id: 'choqqilar', label: "Cho'qqilar", icon: '🏔️', color: const Color(0xFF1565C0), bg: const Color(0xFFE3F2FD)),
  PlaceType(id: 'adirlar', label: 'Adirlar', icon: '🌄', color: const Color(0xFF558B2F), bg: const Color(0xFFF1F8E9)),
  PlaceType(id: 'sharsharalar', label: 'Sharsharalar', icon: '💧', color: const Color(0xFF0277BD), bg: const Color(0xFFE1F5FE)),
  PlaceType(id: 'kollar', label: "Ko'llar", icon: '🏞️', color: const Color(0xFF00838F), bg: const Color(0xFFE0F7FA)),
  PlaceType(id: 'orollar', label: 'Orollar', icon: '🏝️', color: const Color(0xFFE65100), bg: const Color(0xFFFFF3E0)),
  PlaceType(id: 'sohillar', label: 'Sohillar', icon: '🌊', color: const Color(0xFF00695C), bg: const Color(0xFFE0F2F1)),
  PlaceType(id: 'chollar', label: "Cho'llar", icon: '🏜️', color: const Color(0xFFF57F17), bg: const Color(0xFFFFFDE7)),
  PlaceType(id: 'gorlar', label: "G'orlar", icon: '🪨', color: const Color(0xFF5D4037), bg: const Color(0xFFEFEBE9)),
];

PlaceType placeTypeFromId(String id) {
  return kPlaceTypes.firstWhere(
        (t) => t.id == id,
    orElse: () => kPlaceTypes.first,
  );
}

const Map<String, Color> kSeasonColors = {
  'Spring': Color(0xFF16A34A),
  'Summer': Color(0xFFD97706),
  'Autumn': Color(0xFFEA580C),
  'Winter': Color(0xFF2563EB),
};

const Map<String, String> kSeasonUz = {
  'Spring': 'Bahor',
  'Summer': 'Yoz',
  'Autumn': 'Kuz',
  'Winter': 'Qish',
};

const Map<String, String> kTagUz = {
  'hiking': 'Piyoda sayohat',
  'waterfall': 'Sharsara',
  'wildlife': 'Yovvoyi tabiat',
  'camping': 'Lager',
  'skiing': "Chang'i",
  'swimming': 'Suzish',
  'boating': 'Qayiq',
  'picnic': 'Piknik',
  'mountain': "Tog'",
  'trekking': 'Treking',
  'forest': "O'rmon",
  'river': 'Daryo',
  'lake': "Ko'l",
  'valley': 'Vodiy',
  'walking': 'Yurish',
  'botanical': 'Botanika',
  'nature reserve': "Qo'riqxona",
};