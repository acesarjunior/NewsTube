import 'dart:convert';
import 'package:http/http.dart' as http;

class GrammarService {
  final http.Client _client;
  GrammarService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> correct({
    required String text,
    required String language,
  }) async {
    final normalized = _normalizeLang(language);
    final chunks = _chunkText(text, maxChunkChars: 3500);
    final out = StringBuffer();

    for (var i = 0; i < chunks.length; i++) {
      final corrected = await _correctChunk(chunks[i], normalized);
      out.write(corrected);
      if (i != chunks.length - 1) {
        out.write('\n\n');
      }
    }

    return out.toString();
  }

  Future<String> _correctChunk(String text, String language) async {
    final uri = Uri.parse('https://api.languagetool.org/v2/check');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'text': text,
        'language': language,
        'enabledOnly': 'false',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Falha ao corrigir gramática (HTTP ${response.statusCode}).');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final matches = (data['matches'] as List?) ?? const [];
    if (matches.isEmpty) return text;

    final sorted = matches.whereType<Map>().toList()
      ..sort((a, b) => ((b['offset'] ?? 0) as int).compareTo(((a['offset'] ?? 0) as int)));

    var result = text;
    for (final m in sorted) {
      final replacements = (m['replacements'] as List?) ?? const [];
      if (replacements.isEmpty) continue;
      final replacement = (replacements.first is Map) ? ((replacements.first['value'] ?? '').toString()) : '';
      if (replacement.isEmpty) continue;
      final offset = ((m['offset'] ?? 0) as int);
      final length = ((m['length'] ?? 0) as int);
      if (offset < 0 || length < 0 || offset + length > result.length) continue;
      result = result.replaceRange(offset, offset + length, replacement);
    }
    return result;
  }

  String _normalizeLang(String language) {
    final l = language.trim().toLowerCase();
    switch (l) {
      case 'pt':
      case 'pt-br':
        return 'pt-BR';
      case 'en':
        return 'en-US';
      case 'fr':
        return 'fr';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it';
      case 'cs':
        return 'cs';
      case 'es':
        return 'es';
      case 'ja':
        return 'ja';
      default:
        return 'auto';
    }
  }

  List<String> _chunkText(String text, {required int maxChunkChars}) {
    final t = text.trim();
    if (t.length <= maxChunkChars) return [t];

    final paras = t.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];
    var buffer = StringBuffer();

    void flush() {
      final s = buffer.toString().trim();
      if (s.isNotEmpty) chunks.add(s);
      buffer = StringBuffer();
    }

    for (final para in paras) {
      final p = para.trim();
      if (p.isEmpty) continue;

      if (p.length > maxChunkChars) {
        if (buffer.isNotEmpty) flush();
        final sentences = p.split(RegExp(r'(?<=[\.!?。！？])\s+'));
        var local = StringBuffer();
        for (final sentence in sentences) {
          if (local.length + sentence.length + 1 > maxChunkChars) {
            final s = local.toString().trim();
            if (s.isNotEmpty) chunks.add(s);
            local = StringBuffer();
          }
          local.write(sentence);
          local.write(' ');
        }
        final last = local.toString().trim();
        if (last.isNotEmpty) chunks.add(last);
        continue;
      }

      if (buffer.length + p.length + 2 > maxChunkChars) flush();
      buffer.write(p);
      buffer.write('\n\n');
    }

    flush();
    return chunks.isEmpty ? [t] : chunks;
  }
}
