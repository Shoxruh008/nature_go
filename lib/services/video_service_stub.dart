import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../utils/youtube_utils.dart';

/// Mobil (Android/iOS) uchun YouTube pleyeri.
///
/// Muhim: YouTube embed so'rovida `Referer` bo'lmasa "Ошибка 153" beradi.
/// Shuning uchun embed manzili to'g'ridan-to'g'ri ochilmaydi: IFrame API
/// HTML ichida, `baseUrl`i haqiqiy https manzil bo'lgan holda yuklanadi.
class VideoService {
  VideoService._();

  /// WebView sahifasining "origin"i (YouTube'ga Referer sifatida boradi).
  static const baseUrl = 'https://nature-go.vercel.app';

  /// Faqat veb uchun; mobilda ishlatilmaydi.
  static void Function(int code)? onPlayerError;

  static String? extractId(String url) => extractYoutubeId(url);

  static String? getOrRegisterWebView(String videoId) => null;

  static WebViewController buildMobileController(
    String videoId, {
    required VoidCallback onReady,
    required void Function(int code) onError,
    required void Function(Uri url) onExternalLink,
  }) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS: video to'liq ekranga o'tib ketmasdan sahifa ichida ijro etilsin.
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'VideoChannel',
        onMessageReceived: (message) {
          final text = message.message;
          if (text == 'ready') {
            onReady();
          } else if (text.startsWith('error:')) {
            onError(int.tryParse(text.substring(6)) ?? -1);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final isInternal = uri == null ||
                !request.isMainFrame ||
                uri.scheme == 'about' ||
                uri.scheme == 'data' ||
                uri.host == Uri.parse(baseUrl).host;
            if (isInternal) return NavigationDecision.navigate;
            // YouTube logotipi, "YouTube'da ko'rish" kabi havolalar WebView
            // ichida emas, tashqarida ochiladi.
            onExternalLink(uri);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) onError(-2);
          },
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    controller.loadHtmlString(_playerHtml(videoId), baseUrl: baseUrl);
    return controller;
  }

  static String _playerHtml(String videoId) => '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
  #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
</style>
</head>
<body>
<div id="player"></div>
<script>
  var done = false;
  function send(msg) { try { VideoChannel.postMessage(msg); } catch (e) {} }
  // IFrame API yuklanmasa yoki pleyer javob bermasa: xato deb xabar beramiz.
  setTimeout(function () { if (!done) send('error:-3'); }, 20000);
  var tag = document.createElement('script');
  tag.src = 'https://www.youtube.com/iframe_api';
  tag.onerror = function () { send('error:-2'); };
  document.head.appendChild(tag);
  function onYouTubeIframeAPIReady() {
    new YT.Player('player', {
      videoId: '$videoId',
      width: '100%',
      height: '100%',
      playerVars: {
        autoplay: 1, playsinline: 1, rel: 0, modestbranding: 1,
        origin: '$baseUrl'
      },
      events: {
        onReady: function (e) { done = true; send('ready'); try { e.target.playVideo(); } catch (x) {} },
        onError: function (e) { done = true; send('error:' + e.data); }
      }
    });
  }
</script>
</body>
</html>
''';
}
