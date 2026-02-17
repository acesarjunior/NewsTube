import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'html_entities.dart';

class YoutubeChannelVideosService {
  /// Retorna vídeos (mais recente -> mais antigo)
  Future<List<Map<String, dynamic>>> fetchChannelVideos({
    required String channelUrl,
    int limit = 30,
  }) async {
    final normalized = _normalizeChannelUrl(channelUrl);
    final channelId = await _resolveChannelId(normalized);

    final feedUrl = Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');
    final r = await http.get(feedUrl, headers: _headers());

    if (r.statusCode != 200) {
      throw Exception('Falha ao baixar RSS (${r.statusCode}).');
    }

    final doc = XmlDocument.parse(r.body);
    final entries = doc.findAllElements('entry');

    final out = <Map<String, dynamic>>[];
    for (final e in entries) {
      if (out.length >= limit) break;

      final title = decodeHtmlEntities(_textOf(e, 'title'));
      final published = _textOf(e, 'published'); // ISO 8601
      final videoId = _textOfWithNs(e, 'videoId', ns: 'yt');
      final authorName = e.findAllElements('author').isNotEmpty
          ? decodeHtmlEntities(e.findAllElements('author').first.findElements('name').map((x) => x.innerText).join().trim())
          : '';

      // Link do vídeo
      String videoUrl = '';
      final linkEl = e.findElements('link').firstWhere(
            (x) => x.getAttribute('rel') == 'alternate' || x.getAttribute('href') != null,
        orElse: () => XmlElement(XmlName('link')),
      );
      videoUrl = linkEl.getAttribute('href') ?? '';
      if (videoUrl.isEmpty && videoId.isNotEmpty) {
        videoUrl = 'https://www.youtube.com/watch?v=$videoId';
      }

      // Thumbnail (media:group/media:thumbnail)
      String thumb = '';
      final mediaGroup = e.findAllElements('group', namespace: 'http://search.yahoo.com/mrss/').toList();
      if (mediaGroup.isNotEmpty) {
        final thumbs = mediaGroup.first.findAllElements('thumbnail', namespace: 'http://search.yahoo.com/mrss/').toList();
        if (thumbs.isNotEmpty) thumb = thumbs.first.getAttribute('url') ?? '';
      }
      if (thumb.isEmpty && videoId.isNotEmpty) {
        thumb = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      }

      // Parse date -> millis
      int publishedMillis = 0;
      try {
        if (published.isNotEmpty) {
          publishedMillis = DateTime.parse(published).millisecondsSinceEpoch;
        }
      } catch (_) {}

      out.add({
        'videoUrl': videoUrl,
        'title': title,
        'channel': authorName,
        'thumb': thumb,
        'publishedText': published,        // ISO string
        'publishedMillis': publishedMillis // para sort
      });
    }

    // Sort por data desc
    out.sort((a, b) {
      final am = (a['publishedMillis'] as int?) ?? 0;
      final bm = (b['publishedMillis'] as int?) ?? 0;
      return bm.compareTo(am);
    });

    return out;
  }

  // ----------------------------
  // Resolve channelId (UC...)
  // ----------------------------
  Future<String> _resolveChannelId(String channelUrl) async {
    // Caso já venha com /channel/UCxxxx
    final m = RegExp(r'/channel/(UC[\w-]+)', caseSensitive: false).firstMatch(channelUrl);
    if (m != null) return m.group(1)!;

    // Tenta baixar HTML do canal e extrair "channelId":"UC..."
    final u = Uri.parse(channelUrl);
    final r = await http.get(u, headers: _headers());

    if (r.statusCode != 200) {
      throw Exception('Falha ao abrir canal (${r.statusCode}).');
    }

    final html = utf8.decode(r.bodyBytes);

    // Vários padrões possíveis (YouTube muda)
    final patterns = <RegExp>[
      RegExp(r'"channelId"\s*:\s*"(UC[\w-]+)"'),
      RegExp(r'"externalId"\s*:\s*"(UC[\w-]+)"'),
      RegExp(r'channel_id=(UC[\w-]+)'),
    ];

    for (final p in patterns) {
      final mm = p.firstMatch(html);
      if (mm != null) return mm.group(1)!;
    }

    throw Exception('Não foi possível resolver o channel_id (UC...) a partir deste canal.');
  }

  String _normalizeChannelUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;

    // Se veio só "UCxxxx"
    if (s.startsWith('UC') && s.length > 10) {
      return 'https://www.youtube.com/channel/$s';
    }

    // Se veio só "@handle"
    if (s.startsWith('@')) {
      return 'https://www.youtube.com/$s';
    }

    // Se não é URL, tenta como handle
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://www.youtube.com/$s';
    }

    return s;
  }

  Map<String, String> _headers() => const {
    'User-Agent':
    'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  String _textOf(XmlElement e, String tag) {
    final el = e.findElements(tag).toList();
    if (el.isEmpty) return '';
    return el.first.innerText.trim();
  }

  String _textOfWithNs(XmlElement e, String tag, {required String ns}) {
    // xml package usa namespaceUri, então buscamos pelo localName + namespaceUri conhecido do yt:
    const ytNs = 'http://www.youtube.com/xml/schemas/2015';
    final el = e.findAllElements(tag, namespace: ytNs).toList();
    if (el.isEmpty) return '';
    return el.first.innerText.trim();
  }
}
