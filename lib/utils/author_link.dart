/// Video muallifi havolasini xavfsiz [Uri]ga aylantiradi. Faqat http/https
/// qabul qilinadi; sxemasiz yozilgan bo'lsa ("instagram.com/user") https qo'shiladi.
/// Yaroqsiz yoki bo'sh bo'lsa `null`.
Uri? normalizeAuthorUrl(String? raw) {
  var text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  if (!text.contains('://')) {
    // "javascript:...", "mailto:..." kabi sxemalarni o'tkazmaymiz.
    final colon = text.indexOf(':');
    final slash = text.indexOf('/');
    if (colon != -1 && (slash == -1 || colon < slash)) return null;
    text = 'https://$text';
  }
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (!uri.host.contains('.')) return null;
  return uri;
}

/// Havola uchun ko'rinadigan nom: [name] berilgan bo'lsa shu, bo'lmasa havoladan
/// ("@kanal", "@foydalanuvchi" yoki sayt nomi) ajratiladi.
String authorLabel(Uri url, {String? name}) {
  final custom = name?.trim() ?? '';
  if (custom.isNotEmpty) return custom;

  final host = url.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
  final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
  final first = segments.isNotEmpty ? segments.first : '';

  bool isHost(String domain) => host == domain || host.endsWith('.$domain');

  if (isHost('youtube.com')) {
    if (first.startsWith('@')) return first;
    if ((first == 'c' || first == 'user') && segments.length > 1) {
      return segments[1];
    }
    return 'YouTube kanali';
  }
  if (isHost('instagram.com') || isHost('t.me') || isHost('telegram.me')) {
    return first.isEmpty ? host : '@${first.replaceFirst('@', '')}';
  }
  if (isHost('tiktok.com')) {
    return first.startsWith('@') ? first : host;
  }
  if (isHost('facebook.com') || isHost('x.com') || isHost('twitter.com')) {
    return first.isEmpty ? host : first;
  }
  return host;
}
