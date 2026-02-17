import 'dart:convert';
import 'package:http/http.dart' as http;
import 'html_entities.dart';

class YouTubeVideoSearchService {
    String _normalizeUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:' + u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://' + u;
  }

Future<List<VideoSearchResult>> searchVideos(String query, {int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final url = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}',
    );

    final resp = await http.get(url, headers: {
      'Accept': 'text/html,*/*',
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome Safari',
    });

    if (resp.statusCode != 200) {
      throw Exception('Falha ao buscar vídeos (HTTP ${resp.statusCode})');
    }

    final html = resp.body;
    final jsonStr = _extractYtInitialData(html);
    if (jsonStr == null) {
      throw Exception('Não foi possível extrair dados da busca (ytInitialData).');
    }

    final data = jsonDecode(jsonStr);

    final results = <VideoSearchResult>[];
    _walk(data, (node) {
      if (node is Map && node.containsKey('videoRenderer')) {
        final vr = node['videoRenderer'];
        if (vr is Map) {
          final videoId = (vr['videoId'] ?? '').toString();
          if (videoId.isEmpty) return;

          final title = _textFromRuns(vr['title']) ?? '';
          final channel = _textFromRuns(vr['ownerText']) ?? '';
          final publishedText = _textFromRuns(vr['publishedTimeText']) ?? '';
          final duration = _textFromRuns(vr['lengthText']) ?? '';

          String thumb = '';
          final thumbs = (((vr['thumbnail'] ?? {}) as Map)['thumbnails'] as List?) ?? const [];
          if (thumbs.isNotEmpty) {
            final last = thumbs.last;
            if (last is Map) thumb = _normalizeUrl((last['url'] ?? '').toString());
          }

          results.add(VideoSearchResult(
            videoUrl: 'https://www.youtube.com/watch?v=$videoId',
            title: decodeHtmlEntities(title),
            channel: decodeHtmlEntities(channel),
            thumb: thumb,
            publishedText: decodeHtmlEntities(publishedText),
            durationText: duration,
          ));
        }
      }
    });

    // remove duplicados e limita
    final seen = <String>{};
    final out = <VideoSearchResult>[];
    for (final r in results) {
      if (seen.add(r.videoUrl)) out.add(r);
      if (out.length >= limit) break;
    }
    return out;
  }

  // -------------------------
  // helpers (parecido com o service de canais)
  // -------------------------
  String? _extractYtInitialData(String html) {
    final idx = html.indexOf('var ytInitialData =');
    if (idx == -1) return null;
    final start = html.indexOf('{', idx);
    if (start == -1) return null;
    int depth = 0;
    for (int i = start; i < html.length; i++) {
      final ch = html[i];
      if (ch == '{') depth++;
      if (ch == '}') depth--;
      if (depth == 0) {
        return html.substring(start, i + 1);
      }
    }
    return null;
  }

  void _walk(dynamic node, void Function(dynamic n) fn) {
    fn(node);
    if (node is Map) {
      for (final v in node.values) {
        _walk(v, fn);
      }
    } else if (node is List) {
      for (final v in node) {
        _walk(v, fn);
      }
    }
  }

  String? _textFromRuns(dynamic obj) {
    if (obj is Map) {
      if (obj.containsKey('simpleText')) return obj['simpleText']?.toString();
      final runs = obj['runs'];
      if (runs is List) {
        return runs.map((e) => (e is Map ? (e['text'] ?? '') : '')).join();
      }
    }
    return null;
  }
}

class VideoSearchResult {
  final String videoUrl;
  final String title;
  final String channel;
  final String thumb;
  final String publishedText;
  final String durationText;

  VideoSearchResult({
    required this.videoUrl,
    required this.title,
    required this.channel,
    required this.thumb,
    required this.publishedText,
    required this.durationText,
  });

  Map<String, dynamic> toMap() => {
    'videoUrl': videoUrl,
    'title': title,
    'channel': channel,
    'thumb': thumb,
    'publishedText': publishedText,
    // mantemos publishedMillis ausente/0 (o SearchPage já faz fallback)
    'publishedMillis': 0,
    'durationText': durationText,
  };
}
