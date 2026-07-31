import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';

class VideoService {
  VideoService._();

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

    if (segments.isNotEmpty && segments.last.length == 11) {
      return segments.last;
    }

    return null;
  }

  static String? getOrRegisterWebView(String videoId) => null;

  static WebViewController buildMobileController(String videoId) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse(_embedUrl(videoId)));
    return controller;
  }

  static String _embedUrl(String videoId) =>
      'https://www.youtube.com/embed/$videoId'
      '?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1';
}
