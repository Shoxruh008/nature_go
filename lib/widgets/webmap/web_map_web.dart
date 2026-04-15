// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

class WebYandexMap extends StatelessWidget {
  final double lat;
  final double lng;

  const WebYandexMap({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final viewId = 'map-$lat-$lng';

    ui.platformViewRegistry.registerViewFactory(
      viewId,
          (int viewId) {
        final iframe = html.IFrameElement()
          ..src =
              'https://yandex.com/map-widget/v1/?ll=$lng,$lat&z=12&pt=$lng,$lat,pm2rdm'
          ..style.border = 'none';

        return iframe;
      },
    );

    return HtmlElementView(viewType: viewId);
  }
}