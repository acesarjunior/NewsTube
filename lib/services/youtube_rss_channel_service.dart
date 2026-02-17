import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'html_entities.dart';

class YoutubeRssChannelService {
  Future<List<Map<String, dynamic>>> fetchLatestVideos({
    required String channelUrl,
    int limit = 30,
  }) async {
    final normalized = _normalizeChannelUrl(channelUrl);

    // 1) resolve UC... a partir do HTML do canal
    final channelId = await _resolveChannelId(normalized);

    // 2) RSS oficial do YouTube (funciona sem API)
    final feed = Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');

    final r = await http.get(feed, headers: _headers());
    if (r.statusCode != 200) {
      throw Exception('Falha ao carregar feed do canal (HTTP ${r.statusCode}).');
    }

    final doc = XmlDocument.parse(r.body);
    final entries = doc.findAllElements('entry').toList();

    final out = <Map<String, dynamic>>[];
    for (final e in entries) {
      if (out.length >= limit) break;

      final title = decodeHtmlEntities(_textOf(e, 'title'));
      final publishedIso = _textOf(e, 'published'); // ISO 8601
      final videoId = _textOfNs(e, 'videoId', 'http://www.youtube.com/xml/schemas/2015');

      // Link
      String videoUrl = '';
      final links = e.findElements('link').toList();
      for (final l in links) {
        final href = l.getAttribute('href');
        if (href != null && href.isNotEmpty) {
          videoUrl = href;
          break;
        }
      }
      if (videoUrl.isEmpty && videoId.isNotEmpty) {
        videoUrl = 'https://www.youtube.com/watch?v=$videoId';
      }

      // Autor
      String channelName = '';
      final author = e.findElements('author').toList();
      if (author.isNotEmpty) {
        final nameEls = author.first.findElements('name').toList();
        if (nameEls.isNotEmpty) channelName = decodeHtmlEntities(nameEls.first.innerText.trim());
      }

      // Thumb (media:thumbnail) ou fallback i.ytimg
      String thumb = '';
      // namespace media RSS
      const mediaNs = 'http://search.yahoo.com/mrss/';
      final mediaGroups = e.findAllElements('group', namespace: mediaNs).toList();
      if (mediaGroups.isNotEmpty) {
        final thumbs = mediaGroups.first.findAllElements('thumbnail', namespace: mediaNs).toList();
        if (thumbs.isNotEmpty) thumb = thumbs.first.getAttribute('url') ?? '';
      }
      if (thumb.isEmpty && videoId.isNotEmpty) {
        thumb = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      }

      int publishedMillis = 0;
      try {
        if (publishedIso.isNotEmpty) {
          publishedMillis = DateTime.parse(publishedIso).millisecondsSinceEpoch;
        }
      } catch (_) {}

      out.add({
        'videoUrl': videoUrl,
        'title': title,
        'channel': channelName,
        'thumb': thumb,
        'publishedText': publishedIso, // ISO
        'publishedMillis': publishedMillis,
      });
    }

    // Sort: mais recente -> mais antigo
    out.sort((a, b) {
      final am = (a['publishedMillis'] as int?) ?? 0;
      final bm = (b['publishedMillis'] as int?) ?? 0;
      return bm.compareTo(am);
    });

    return out;
  }

  // -----------------------------
  // Resolve channel_id (UC...)
  // -----------------------------
  Future<String> _resolveChannelId(String channelUrl) async {
    // Se já for /channel/UC...
    final m = RegExp(r'/channel/(UC[\w-]+)', caseSensitive: false).firstMatch(channelUrl);
    if (m != null) return m.group(1)!;

    final u = Uri.parse(channelUrl);
    final r = await http.get(u, headers: _headers());

    if (r.statusCode != 200) {
      throw Exception('Falha ao abrir o canal (HTTP ${r.statusCode}).');
    }

    final html = utf8.decode(r.bodyBytes);

    // Padrões comuns no HTML do YouTube
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

  // -----------------------------
  // Normalização
  // -----------------------------
  String _normalizeChannelUrl(String input) {
    final s0 = input.trim();
    if (s0.isEmpty) return s0;

    // Se veio só UC...
    if (s0.startsWith('UC') && s0.length > 10) {
      return 'https://www.youtube.com/channel/$s0';
    }

    // Se veio @handle
    if (s0.startsWith('@')) {
      return 'https://www.youtube.com/$s0';
    }

    // Se já é URL
    if (s0.startsWith('http://') || s0.startsWith('https://')) return s0;

    // fallback: trata como handle
    return 'https://www.youtube.com/$s0';
  }

  Map<String, String> _headers() => const {
    'User-Agent':
    'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  String _textOf(XmlElement e, String tag) {
    final els = e.findElements(tag).toList();
    if (els.isEmpty) return '';
    return els.first.innerText.trim();
  }

  String _textOfNs(XmlElement e, String tag, String nsUri) {
    final els = e.findAllElements(tag, namespace: nsUri).toList();
    if (els.isEmpty) return '';
    return els.first.innerText.trim();
  }
}
