import 'dart:convert';
import 'package:http/http.dart' as http;

/// Inline translation using Google's lightweight (unofficial) endpoint.
/// No browser is opened. Works without API keys, but may be rate-limited.
class TranslateService {
  final http.Client _client;

  TranslateService({http.Client? client}) : _client = client ?? http.Client();

  /// Translates [text] from [sourceLang] ('auto' allowed) to [targetLang].
  /// Splits large texts into smaller chunks to avoid URL length limits.
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final src = sourceLang.trim().isEmpty ? 'auto' : sourceLang.trim();
    final tl = targetLang.trim().isEmpty ? 'en' : targetLang.trim();

    final chunks = _chunkText(text, maxChunkChars: 2800);
    final out = StringBuffer();

    for (var i = 0; i < chunks.length; i++) {
      final piece = chunks[i];
      if (piece.trim().isEmpty) {
        out.write(piece);
        continue;
      }
      final translated = await _translateChunk(piece, src, tl);
      out.write(translated);

      // keep paragraph breaks between chunks when splitting by paragraphs
      if (i != chunks.length - 1) out.write('\n\n');
    }

    return out.toString();
  }

  Future<String> _translateChunk(String text, String sl, String tl) async {
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': sl,
      'tl': tl,
      'dt': 't',
      'q': text,
    });

    final resp = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao traduzir (HTTP ${resp.statusCode}).');
    }

    final dynamic data = json.decode(resp.body);
    // Expected: data[0] = list of segments, each segment[0] is translated text.
    if (data is! List || data.isEmpty || data[0] is! List) {
      throw Exception('Resposta inesperada do serviço de tradução.');
    }

    final segments = data[0] as List;
    final sb = StringBuffer();
    for (final seg in segments) {
      if (seg is List && seg.isNotEmpty && seg[0] is String) {
        sb.write(seg[0] as String);
      }
    }
    return sb.toString();
  }

  List<String> _chunkText(String text, {required int maxChunkChars}) {
    final t = text.trim();
    if (t.length <= maxChunkChars) return [t];

    // Prefer splitting by paragraphs first.
    final paras = t.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];
    var buf = StringBuffer();

    void flush() {
      final s = buf.toString().trim();
      if (s.isNotEmpty) chunks.add(s);
      buf = StringBuffer();
    }

    for (final p in paras) {
      final para = p.trim();
      if (para.isEmpty) continue;

      // If a single paragraph is too big, split by sentences.
      if (para.length > maxChunkChars) {
        if (buf.length > 0) flush();
        final sentences = para.split(RegExp(r'(?<=[\.\!\?])\s+'));
        var sb = StringBuffer();
        for (final s in sentences) {
          if (sb.length + s.length + 1 > maxChunkChars) {
            final piece = sb.toString().trim();
            if (piece.isNotEmpty) chunks.add(piece);
            sb = StringBuffer();
          }
          sb.write(s);
          sb.write(' ');
        }
        final last = sb.toString().trim();
        if (last.isNotEmpty) chunks.add(last);
        continue;
      }

      if (buf.length + para.length + 2 > maxChunkChars) {
        flush();
      }
      buf.write(para);
      buf.write('\n\n');
    }

    flush();
    return chunks.isEmpty ? [t] : chunks;
  }
}
