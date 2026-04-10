import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';

class VideoService {
  VideoService._();

  static final Map<String, String> _registeredViewIds = {};

  static String? extractId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      final seg = uri.pathSegments.firstOrNull;
      return (seg != null && seg.length == 11) ? seg : null;
    }

    final v = uri.queryParameters['v'];
    if (v != null && v.length == 11) return v;

    final segments = uri.pathSegments;
    if (segments.length >= 2) {
      const knownPaths = {'shorts', 'embed', 'live', 'v'};
      final parent = segments[segments.length - 2];
      final last = segments.last;
      if (knownPaths.contains(parent) && last.length == 11) return last;
    }

    return null;
  }

  static String getOrRegisterWebView(String videoId) {
    if (_registeredViewIds.containsKey(videoId)) {
      return _registeredViewIds[videoId]!;
    }
    final viewId = 'yt-iframe-$videoId';
    ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
      return html.IFrameElement()
        ..src = _embedUrl(videoId)
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute(
          'allow',
          'accelerometer; autoplay; clipboard-write; '
              'encrypted-media; gyroscope; picture-in-picture',
        );
    });
    _registeredViewIds[videoId] = viewId;
    return viewId;
  }

  static WebViewController buildMobileController(String videoId) {
    throw UnsupportedError('buildMobileController web-da ishlamaydi');
  }

  static String _embedUrl(String videoId) =>
      'https://www.youtube.com/embed/$videoId'
          '?autoplay=1&playsinline=1&rel=0&modestbranding=1';
}