import 'dart:convert';
import 'package:http/http.dart' as http;
import 'html_entities.dart';

class YouTubeChannelSearchService {
    String _normalizeUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:' + u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://' + u;
  }

Future<List<ChannelSearchResult>> searchChannels(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // sp=EgIQAg== => filtra para "Canais"
    final url = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}&sp=EgIQAg%253D%253D',
    );

    final resp = await http.get(url, headers: {
      'Accept': 'text/html,*/*',
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome Safari',
    });

    if (resp.statusCode != 200) {
      throw Exception('Falha ao buscar canais (HTTP ${resp.statusCode})');
    }

    final html = resp.body;
    final jsonStr = _extractYtInitialData(html);
    if (jsonStr == null) {
      throw Exception('Não foi possível extrair dados da busca (ytInitialData).');
    }

    final data = jsonDecode(jsonStr);

    final results = <ChannelSearchResult>[];
    _walk(data, (node) {
      if (node is Map && node.containsKey('channelRenderer')) {
        final cr = node['channelRenderer'];
        if (cr is Map) {
          final channelId = (cr['channelId'] ?? '').toString();
          final title = decodeHtmlEntities(_pickText(cr['title']));
          final thumb = _pickThumbnail(cr['thumbnail']);
          if (channelId.isNotEmpty && title.isNotEmpty) {
            results.add(ChannelSearchResult(
              channelId: channelId,
              title: title,
              thumbnailUrl: thumb,
            ));
          }
        }
      }
    });

    final seen = <String>{};
    final dedup = <ChannelSearchResult>[];
    for (final r in results) {
      if (seen.add(r.channelId)) dedup.add(r);
    }
    return dedup.take(30).toList();
  }

  String? _extractYtInitialData(String html) {
    final re1 = RegExp(r'var ytInitialData\s*=\s*(\{.*?\});', dotAll: true);
    final m1 = re1.firstMatch(html);
    if (m1 != null) return m1.group(1);

    final re2 = RegExp(r'"ytInitialData"\s*:\s*(\{.*?\})\s*,\s*"ytInitialPlayerResponse"', dotAll: true);
    final m2 = re2.firstMatch(html);
    if (m2 != null) return m2.group(1);

    return null;
  }

  void _walk(dynamic node, void Function(dynamic) visit) {
    visit(node);
    if (node is Map) {
      for (final v in node.values) {
        _walk(v, visit);
      }
    } else if (node is List) {
      for (final it in node) {
        _walk(it, visit);
      }
    }
  }

  String _pickText(dynamic obj) {
    if (obj is Map) {
      final simple = obj['simpleText'];
      if (simple != null) return simple.toString();
      final runs = obj['runs'];
      if (runs is List && runs.isNotEmpty) {
        final first = runs.first;
        if (first is Map && first['text'] != null) return first['text'].toString();
      }
    }
    return '';
  }

  String? _pickThumbnail(dynamic obj) {
    if (obj is Map) {
      final thumbs = obj['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        final last = thumbs.last;
        if (last is Map && last['url'] != null) return _normalizeUrl(last['url']?.toString());
      }
    }
    return null;
  }
}

class ChannelSearchResult {
  final String channelId;
  final String title;
  final String? thumbnailUrl;

  ChannelSearchResult({
    required this.channelId,
    required this.title,
    required this.thumbnailUrl,
  });


Map<String, dynamic> toMap() => {
  'channelUrl': 'https://www.youtube.com/channel/$channelId',
  'title': title,
  'thumb': (thumbnailUrl ?? ''),
};

}