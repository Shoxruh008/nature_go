import 'package:flutter/material.dart';

class WebYandexMap extends StatelessWidget {
  final double lat;
  final double lng;

  const WebYandexMap({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Map not supported"));
  }
}