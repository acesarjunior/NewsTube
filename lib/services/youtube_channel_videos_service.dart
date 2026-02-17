import 'dart:convert';
import 'package:http/http.dart' as http;
import 'html_entities.dart';
import 'youtube_innertube_config.dart';

class YoutubeChannelVideosService {
  Map<String, String> _headers() => {
        'Accept': 'text/html,*/*',
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome Safari',
        'Accept-Language': 'en-US,en;q=0.9',
        // Ajuda a evitar telas de consentimento/região no YouTube sem cookies do usuário
        'Cookie': 'CONSENT=YES+1',
      };

  String _normalizeUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:' + u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://' + u;
  }

  String _ensureVideosTabUrl(String channelUrl) {
    final u = channelUrl.trim();
    if (u.isEmpty) return u;

    // Se já apontar para /videos, mantém.
    if (RegExp(r'/videos/?$', caseSensitive: false).hasMatch(u)) return u;

    // Se for /channel/UC... ou /@handle, anexamos /videos
    if (u.endsWith('/')) return u + 'videos';
    return u + '/videos';
  }

  /// Carrega uma "página" de vídeos do canal (aba Videos) com suporte a continuation.
  ///
  /// Observação: isto faz scraping do YouTube e pode falhar se eles mudarem o HTML/JSON.
  Future<ChannelVideosPage> fetchChannelVideosPage({
    required String channelUrl,
    String? continuation,
    YouTubeInnerTubeConfig? config,
  }) async {
    if (continuation == null) {
      final url = Uri.parse(_ensureVideosTabUrl(channelUrl));
      final resp = await http.get(url, headers: _headers());
      if (resp.statusCode != 200) {
        throw Exception('Falha ao abrir canal (HTTP ${resp.statusCode}).');
      }

      final html = utf8.decode(resp.bodyBytes);
      final cfg = _extractInnerTubeConfig(html);

      final jsonStr = _extractYtInitialData(html);
      if (jsonStr == null) {
        throw Exception('Não foi possível extrair dados do canal (ytInitialData).');
      }

      final data = jsonDecode(jsonStr);
      final vids = _parseVideoRenderers(data);

      final next = _findContinuationToken(data);

      return ChannelVideosPage(items: vids, nextContinuation: next, config: cfg);
    }

    final cfg = config;
    if (cfg == null || cfg.apiKey.isEmpty) {
      throw Exception('Configuração do InnerTube ausente para continuação do canal.');
    }

    final url = Uri.parse('https://www.youtube.com/youtubei/v1/browse?key=${cfg.apiKey}');
    final body = jsonEncode({
      'context': cfg.context,
      'continuation': continuation,
    });

    final resp = await http.post(url, headers: _youtubeiHeaders(cfg), body: body);
    if (resp.statusCode != 200) {
      throw Exception('Falha ao continuar canal (HTTP ${resp.statusCode}).');
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final vids = _parseVideoRenderers(data);
    final next = _findContinuationToken(data);

    return ChannelVideosPage(items: vids, nextContinuation: next, config: cfg);
  }

  // -------------------------
  // Parsing
  // -------------------------

  List<Map<String, dynamic>> _parseVideoRenderers(dynamic data) {
    final out = <Map<String, dynamic>>[];

    _walk(data, (node) {
      // Em algumas variantes de layout, o YouTube usa `gridVideoRenderer` em vez de `videoRenderer`.
      // Para suportar o máximo de canais, aceitamos ambos.
      if (node is Map && (node.containsKey('videoRenderer') || node.containsKey('gridVideoRenderer'))) {
        final vr = node['videoRenderer'] ?? node['gridVideoRenderer'];
        if (vr is! Map) return;

        final videoId = (vr['videoId'] ?? '').toString();
        if (videoId.isEmpty) return;

        final title = decodeHtmlEntities(_textFromRuns(vr['title']) ?? '');
        final channel = decodeHtmlEntities(_textFromRuns(vr['ownerText']) ?? '');

        // Published pode estar em `publishedTimeText` (mais comum).
        final publishedText = decodeHtmlEntities(_textFromRuns(vr['publishedTimeText']) ?? '');

        String thumb = '';
        final thumbs = (((vr['thumbnail'] ?? {}) as Map?)?['thumbnails'] as List?) ?? const [];
        if (thumbs.isNotEmpty) {
          final last = thumbs.last;
          if (last is Map) thumb = _normalizeUrl((last['url'] ?? '').toString());
        }

        out.add({
          'videoUrl': 'https://www.youtube.com/watch?v=$videoId',
          'title': title,
          'channel': channel,
          'thumb': thumb,
          'publishedText': publishedText,
          'durationText': decodeHtmlEntities(_textFromRuns(vr['lengthText']) ?? ''),
          'publishedMillis': 0,
        });
      }
    });

    // Dedup por URL
    final seen = <String>{};
    final dedup = <Map<String, dynamic>>[];
    for (final v in out) {
      final u = (v['videoUrl'] ?? '').toString();
      if (u.isEmpty) continue;
      if (seen.add(u)) dedup.add(v);
    }

    return dedup;
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
    String apiKey = '';
    final mKey = RegExp(r'"INNERTUBE_API_KEY"\s*:\s*"([^"]+)"').firstMatch(html);
    if (mKey != null) apiKey = mKey.group(1) ?? '';

    String clientName = '';
    String clientVersion = '';
    final mName = RegExp(r'"INNERTUBE_CLIENT_NAME"\s*:\s*"([^"]+)"').firstMatch(html);
    if (mName != null) clientName = mName.group(1) ?? '';
    final mVer = RegExp(r'"INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)"').firstMatch(html);
    if (mVer != null) clientVersion = mVer.group(1) ?? '';

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

  String? _extractYtInitialData(String html) {
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
      if (depth == 0) return html.substring(start, i + 1);
    }
    return null;
  }

  Map<String, String> _youtubeiHeaders(YouTubeInnerTubeConfig cfg) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': _headers()['User-Agent']!,
        if (cfg.clientName.isNotEmpty) 'X-Youtube-Client-Name': cfg.clientName,
        if (cfg.clientVersion.isNotEmpty) 'X-Youtube-Client-Version': cfg.clientVersion,
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
      };

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


class ChannelVideosPage {
  final List<Map<String, dynamic>> items;
  final String? nextContinuation;
  final YouTubeInnerTubeConfig? config;

  ChannelVideosPage({
    required this.items,
    required this.nextContinuation,
    required this.config,
  });
}