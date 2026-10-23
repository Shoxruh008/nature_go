final _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// YouTube havolasidan 11 belgili video ID'ni ajratadi. Tanilgan formatlar:
/// watch?v=, youtu.be/, /embed/, /shorts/, /live/, /v/, m. va music. subdomenlar,
/// youtube-nocookie.com, sxemasiz havola va yalang'och ID. Boshqa saytlar uchun `null`.
String? extractYoutubeId(String url) {
  var text = url.trim();
  if (text.isEmpty) return null;
  if (_videoIdPattern.hasMatch(text)) return text;

  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  bool isHost(String domain) => host == domain || host.endsWith('.$domain');

  String? candidate;
  if (isHost('youtu.be')) {
    candidate = uri.pathSegments.firstWhere((s) => s.isNotEmpty, orElse: () => '');
  } else if (isHost('youtube.com') || isHost('youtube-nocookie.com')) {
    candidate = uri.queryParameters['v'];
    if (candidate == null) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      const idPaths = {'shorts', 'embed', 'live', 'v', 'e'};
      if (segments.length >= 2 && idPaths.contains(segments[segments.length - 2])) {
        candidate = segments.last;
      }
    }
  }

  if (candidate != null && _videoIdPattern.hasMatch(candidate)) return candidate;
  return null;
}

String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';

/// YouTube IFrame API `onError` kodlari uchun foydalanuvchiga tushunarli xabar.
String youtubePlayerErrorMessage(int code) {
  switch (code) {
    case 2:
      return "Video havolasi noto'g'ri";
    case 5:
      return "Videoni bu qurilmada ijro etib bo'lmadi";
    case 100:
      return "Video topilmadi yoki yopiq qilingan";
    case 101:
    case 150:
    case 152:
    case 153:
      return "Video egasi uni ilova ichida ko'rsatishni cheklagan";
    case -2:
      return "Internet aloqasi yo'q yoki video yuklanmadi";
    case -3:
      return "Video juda uzoq yuklandi";
    default:
      return "Videoni ilova ichida ochib bo'lmadi";
  }
}
