import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/utils/youtube_utils.dart';

void main() {
  const id = 'dQw4w9WgXcQ';

  group('extractYoutubeId', () {
    test("turli havola ko'rinishlaridan ID ajratadi", () {
      for (final url in [
        'https://www.youtube.com/watch?v=$id',
        'https://youtube.com/watch?v=$id&list=PL123&t=10s',
        'https://m.youtube.com/watch?v=$id',
        'https://music.youtube.com/watch?v=$id',
        'https://youtu.be/$id',
        'https://youtu.be/$id?si=abc',
        'https://www.youtube.com/embed/$id',
        'https://www.youtube-nocookie.com/embed/$id',
        'https://www.youtube.com/shorts/$id',
        'https://www.youtube.com/live/$id?feature=share',
        'https://www.youtube.com/v/$id',
        'www.youtube.com/watch?v=$id',
        'youtu.be/$id',
        '  https://youtu.be/$id  ',
        id,
      ]) {
        expect(extractYoutubeId(url), id, reason: url);
      }
    });

    test("YouTube bo'lmagan yoki noto'g'ri havolada null qaytaradi", () {
      for (final url in [
        '',
        'https://example.com/watch?v=$id',
        'https://vimeo.com/123456789',
        'https://www.youtube.com/watch?v=short',
        'https://www.youtube.com/channel/UC1234567890abcdefghij',
        'https://www.youtube.com/@naturego',
        'https://notyoutube.com/embed/$id',
        'not a url',
      ]) {
        expect(extractYoutubeId(url), isNull, reason: url);
      }
    });
  });

  test('youtubeWatchUrl', () {
    expect(youtubeWatchUrl(id), 'https://www.youtube.com/watch?v=$id');
  });

  group('youtubePlayerErrorMessage', () {
    test("embed cheklangan kodlar bir xil xabar beradi", () {
      final msg = youtubePlayerErrorMessage(153);
      for (final code in [101, 150, 152]) {
        expect(youtubePlayerErrorMessage(code), msg);
      }
    });

    test("noma'lum kod uchun umumiy xabar", () {
      expect(youtubePlayerErrorMessage(999), isNotEmpty);
      expect(youtubePlayerErrorMessage(100), contains('topilmadi'));
    });
  });
}
