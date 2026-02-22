import 'dart:convert';
import 'package:http/http.dart' as http;
import 'native_extractor.dart';
import 'html_entities.dart';

class TranscriptResult {
  final bool ok;
  final String text;
  final String message;
  final String? captionLang;

  const TranscriptResult({
    required this.ok,
    required this.text,
    required this.message,
    this.captionLang,
  });
}

class TranscriptService {
  final bool debug;
  TranscriptService({this.debug = false});

  Future<TranscriptResult> fetchTranscriptFromCaptions({
    required String videoUrl,
    String preferLang = 'pt',
  }) async {
    try {
      final cap = await NativeExtractor.getCaptions(url: videoUrl, preferLang: preferLang);

      final has = cap['hasCaptions'] == true;
      if (!has) {
        final err = (cap['error'] ?? '').toString().trim();
        if (err.isNotEmpty && err != 'NO_TRACK_FOUND') {
          return TranscriptResult(ok: false, text: '', message: 'Extractor: $err');
        }
        return const TranscriptResult(
          ok: false,
          text: '',
          message: 'Não foi possível obter legendas via extractor (o YouTube pode ter mudado; atualize o extractor ou tente novamente).',
        );
      }

      final captionUrl = (cap['captionUrl'] ?? '').toString().trim();
      final captionLang = (cap['captionLang'] ?? '').toString().trim();

      if (captionUrl.isEmpty) {
        return const TranscriptResult(ok: false, text: '', message: 'Legenda encontrada, mas sem URL acessível.');
      }

      final r = await http.get(Uri.parse(captionUrl));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        return TranscriptResult(ok: false, text: '', message: 'Falha ao baixar legenda: HTTP ${r.statusCode}', captionLang: captionLang);
      }

      final body = _decodeBody(r);
      final text = _extractTextFromCaption(body);

      if (text.trim().isEmpty) {
        return TranscriptResult(ok: false, text: '', message: 'Legenda baixada, mas não foi possível extrair texto.', captionLang: captionLang);
      }

      return TranscriptResult(ok: true, text: text.trim(), message: 'OK', captionLang: captionLang);
    } catch (e) {
      return TranscriptResult(ok: false, text: '', message: 'Erro: $e');
    }
  }

  String _decodeBody(http.Response r) {
    // tenta utf8; se vier outra coisa, fallback para latin1
    try {
      return utf8.decode(r.bodyBytes);
    } catch (_) {
      return latin1.decode(r.bodyBytes);
    }
  }

  String _extractTextFromCaption(String raw) {
    final s = raw.trim();

    // VTT geralmente começa com "WEBVTT"
    if (s.startsWith('WEBVTT')) {
      return _parseVtt(s);
    }

    // TTML/XML: remove tags
    if (s.startsWith('<?xml') || s.contains('<tt')) {
      return _stripXmlTags(s);
    }

    // fallback: retorna “limpo”
    return _basicClean(s);
  }

  String _parseVtt(String vtt) {
    final lines = vtt.split(RegExp(r'\r?\n'));
    final out = StringBuffer();

    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      if (l.startsWith('WEBVTT')) continue;
      if (RegExp(r'^\d+$').hasMatch(l)) continue;
      if (RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}\s+-->').hasMatch(l)) continue;
      if (RegExp(r'^\d{2}:\d{2}\.\d{3}\s+-->').hasMatch(l)) continue;

      final cleaned = _basicClean(l);
      if (cleaned.isEmpty) continue;

      out.writeln(cleaned);
    }

    return _dedupeLines(out.toString());
  }

  String _stripXmlTags(String xml) {
    // remove tags e entidades mais comuns
    var s = xml.replaceAll(RegExp(r'<[^>]+>'), ' ');
    s = s.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    s = _basicClean(s);
    return _dedupeLines(s);
  }

  String _basicClean(String s) {
    var x = s;

    // remove tags simples
    x = x.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // remove marcas VTT tipo <c> etc.
    x = x.replaceAll(RegExp(r'\{\\.*?\}'), ' ');

        // decodifica entidades HTML (ex.: &#39;)
    x = decodeHtmlEntities(x);

    // normaliza espaços
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  String _dedupeLines(String text) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final out = <String>[];
    String? last;

    for (final l in lines) {
      if (last == null || l != last) out.add(l);
      last = l;
    }
    return out.join('\n');
  }
}
