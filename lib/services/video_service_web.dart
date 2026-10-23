import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/youtube_utils.dart';

/// Veb uchun YouTube pleyeri (iframe).
class VideoService {
  VideoService._();

  static final Map<String, String> _registeredViewIds = {};
  static bool _listening = false;

  /// Pleyer xato bersa (masalan, egasi embed'ni taqiqlagan) chaqiriladi.
  static void Function(int code)? onPlayerError;

  static String? extractId(String url) => extractYoutubeId(url);

  static String getOrRegisterWebView(String videoId) {
    _listenForPlayerErrors();
    if (_registeredViewIds.containsKey(videoId)) {
      return _registeredViewIds[videoId]!;
    }
    final viewId = 'yt-iframe-$videoId';
    ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
      final iframe = html.IFrameElement()
        ..src = _embedUrl(videoId)
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin'
        ..setAttribute(
          'allow',
          'accelerometer; autoplay; clipboard-write; '
              'encrypted-media; gyroscope; picture-in-picture',
        );
      // IFrame API'dan `onError` xabarlarini olish uchun "listening" yuboriladi.
      iframe.onLoad.listen((_) {
        iframe.contentWindow?.postMessage(
          jsonEncode({'event': 'listening', 'id': videoId}),
          '*',
        );
      });
      return iframe;
    });
    _registeredViewIds[videoId] = viewId;
    return viewId;
  }

  static void _listenForPlayerErrors() {
    if (_listening) return;
    _listening = true;
    html.window.onMessage.listen((event) {
      if (!event.origin.contains('youtube')) return;
      try {
        final data = event.data is String ? jsonDecode(event.data as String) : null;
        if (data is Map && data['event'] == 'onError') {
          final code = data['info'];
          onPlayerError?.call(code is num ? code.toInt() : -1);
        }
      } catch (_) {}
    });
  }

  static WebViewController buildMobileController(
    String videoId, {
    required VoidCallback onReady,
    required void Function(int code) onError,
    required void Function(Uri url) onExternalLink,
  }) {
    throw UnsupportedError('buildMobileController web-da ishlamaydi');
  }

  static String _embedUrl(String videoId) {
    final origin = Uri.encodeComponent(html.window.location.origin);
    return 'https://www.youtube.com/embed/$videoId'
        '?autoplay=1&playsinline=1&rel=0&modestbranding=1'
        '&enablejsapi=1&origin=$origin';
  }
}
