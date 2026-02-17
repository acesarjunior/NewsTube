import 'dart:convert';
import 'package:http/http.dart' as http;
import 'html_entities.dart';
import 'youtube_innertube_config.dart';

class YouTubeVideoSearchService {
  String _normalizeUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:' + u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://' + u;
  }

  /// Busca 1 "página" de resultados.
  ///
  /// - Se [continuation] for null: baixa o HTML inicial e extrai ytInitialData + ytcfg.
  /// - Se [continuation] não for null: usa o endpoint youtubei/v1/search para continuar.
  ///
  /// Retorna [VideoSearchPage] com lista + nextContinuation (se houver).
  Future<VideoSearchPage> searchVideosPage(
    String query, {
    String? continuation,
    YouTubeInnerTubeConfig? config,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return VideoSearchPage(items: const [], nextContinuation: null, config: config);
    }

    if (continuation == null) {
      final url = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}',
      );

      final resp = await http.get(url, headers: _headers());
      if (resp.statusCode != 200) {
        throw Exception('Falha ao buscar vídeos (HTTP ${resp.statusCode})');
      }

      final html = utf8.decode(resp.bodyBytes);

      final cfg = _extractInnerTubeConfig(html);
      final jsonStr = _extractYtInitialData(html);
      if (jsonStr == null) {
        throw Exception('Não foi possível extrair dados da busca (ytInitialData).');
      }
      final data = jsonDecode(jsonStr);

      final results = _parseVideoRenderers(data);
      final next = _findContinuationToken(data);

      // remove duplicados
      final seen = <String>{};
      final out = <VideoSearchResult>[];
      for (final r in results) {
        if (seen.add(r.videoUrl)) out.add(r);
      }

      return VideoSearchPage(items: out, nextContinuation: next, config: cfg);
    }

    // continuação via youtubei
    final cfg = config;
    if (cfg == null || cfg.apiKey.isEmpty) {
      throw Exception('Configuração do InnerTube ausente para continuação.');
    }

    final url = Uri.parse('https://www.youtube.com/youtubei/v1/search?key=${cfg.apiKey}');
    final body = jsonEncode({
      'context': cfg.context,
      'continuation': continuation,
    });

    final resp = await http.post(url, headers: _youtubeiHeaders(cfg), body: body);
    if (resp.statusCode != 200) {
      throw Exception('Falha ao continuar busca (HTTP ${resp.statusCode}).');
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final results = _parseVideoRenderers(data);
    final next = _findContinuationToken(data);

    // dedup (esta página pode repetir alguns itens)
    final seen = <String>{};
    final out = <VideoSearchResult>[];
    for (final r in results) {
      if (seen.add(r.videoUrl)) out.add(r);
    }

    return VideoSearchPage(items: out, nextContinuation: next, config: cfg);
  }

  /// Conveniência: baixa até [limit] vídeos, consumindo várias páginas (quando disponível).
  Future<List<VideoSearchResult>> searchVideos(String query, {int limit = 200}) async {
    final out = <VideoSearchResult>[];
    String? cont;
    YouTubeInnerTubeConfig? cfg;

    while (out.length < limit) {
      final page = await searchVideosPage(query, continuation: cont, config: cfg);
      cfg ??= page.config;
      cont = page.nextContinuation;

      if (page.items.isEmpty) break;

      // dedup global
      final seen = out.map((e) => e.videoUrl).toSet();
      for (final it in page.items) {
        if (out.length >= limit) break;
        if (seen.add(it.videoUrl)) out.add(it);
      }

      if (cont == null) break;
    }

    return out;
  }

  // -------------------------
  // Parsing
  // -------------------------

  List<VideoSearchResult> _parseVideoRenderers(dynamic data) {
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
    return results;
  }

  String? _findContinuationToken(dynamic data) {
    String? token;

    _walk(data, (node) {
      if (token != null) return;
      if (node is Map && node.containsKey('continuationItemRenderer')) {
        final cir = node['continuationItemRenderer'];
        if (cir is Map) {
          final endpoint = cir['continuationEndpoint'];
          if (endpoint is Map) {
            final cc = endpoint['continuationCommand'];
            if (cc is Map) {
              final t = (cc['token'] ?? '').toString();
              if (t.isNotEmpty) token = t;
            }
          }
        }
      }
    });

    return token;
  }

  // -------------------------
  // ytcfg / innertube config extraction
  // -------------------------

  YouTubeInnerTubeConfig _extractInnerTubeConfig(String html) {
    // api key
    String apiKey = '';
    final mKey = RegExp(r'"INNERTUBE_API_KEY"\s*:\s*"([^"]+)"').firstMatch(html);
    if (mKey != null) apiKey = mKey.group(1) ?? '';

    // client name + version
    String clientName = '';
    String clientVersion = '';
    final mName = RegExp(r'"INNERTUBE_CLIENT_NAME"\s*:\s*"([^"]+)"').firstMatch(html);
    if (mName != null) clientName = mName.group(1) ?? '';
    final mVer = RegExp(r'"INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)"').firstMatch(html);
    if (mVer != null) clientVersion = mVer.group(1) ?? '';

    // context: extraímos o objeto INNERTUBE_CONTEXT (é JSON)
    Map<String, dynamic> context = {};
    final idx = html.indexOf('"INNERTUBE_CONTEXT"');
    if (idx != -1) {
      final start = html.indexOf('{', idx);
      if (start != -1) {
        int depth = 0;
        for (int i = start; i < html.length; i++) {
          final ch = html[i];
          if (ch == '{') depth++;
          if (ch == '}') depth--;
          if (depth == 0) {
            final raw = html.substring(start, i + 1);
            try {
              context = jsonDecode(raw) as Map<String, dynamic>;
            } catch (_) {}
            break;
          }
        }
      }
    }

    return YouTubeInnerTubeConfig(
      apiKey: apiKey,
      clientName: clientName,
      clientVersion: clientVersion,
      context: context,
    );
  }

  // -------------------------
  // helpers
  // -------------------------

  Map<String, String> _headers() => {
        'Accept': 'text/html,*/*',
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome Safari',
      };

  Map<String, String> _youtubeiHeaders(YouTubeInnerTubeConfig cfg) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': _headers()['User-Agent']!,
        if (cfg.clientName.isNotEmpty) 'X-Youtube-Client-Name': cfg.clientName,
        if (cfg.clientVersion.isNotEmpty) 'X-Youtube-Client-Version': cfg.clientVersion,
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
      };

  String? _extractYtInitialData(String html) {
    // YouTube pode usar "var ytInitialData = ..." ou "ytInitialData = ..."
    final idx = html.indexOf('var ytInitialData =');
    final idx2 = html.indexOf('ytInitialData =');
    final use = (idx == -1) ? idx2 : idx;
    if (use == -1) return null;

    final start = html.indexOf('{', use);
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


class VideoSearchPage {
  final List<VideoSearchResult> items;
  final String? nextContinuation;
  final YouTubeInnerTubeConfig? config;

  VideoSearchPage({
    required this.items,
    required this.nextContinuation,
    required this.config,
  });
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
        'durationText': durationText,
      };
}