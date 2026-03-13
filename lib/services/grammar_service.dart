import 'package:flutter/services.dart';

class GrammarService {
  static const MethodChannel _native = MethodChannel('newstube/rewriter');

  Future<bool> isSupported({String language = 'auto'}) async {
    final nativeLang = _nativeLanguageFor(_normalizeLang(language));
    if (nativeLang == null) return false;

    try {
      final res = await _native.invokeMethod(
        'getRewriteAvailability',
        {'language': nativeLang},
      );

      if (res is bool) return res;
      final map = Map<String, dynamic>.from(res as Map);
      return map['available'] == true ||
          map['downloadable'] == true ||
          map['downloading'] == true ||
          map['supported'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String> correct({
    required String text,
    String language = 'auto',
  }) async {
    final normalized = _normalizeLang(language);
    final prepared = _prepareForCorrection(text);
    if (prepared.trim().isEmpty) return '';

    final paragraphs = _splitPreservingParagraphs(prepared);
    final correctedParagraphs = <String>[];

    final nativeLang = _nativeLanguageFor(normalized);
    final nativePossible = nativeLang != null && await isSupported(language: nativeLang);

    for (final paragraph in paragraphs) {
      final p = paragraph.trim();
      if (p.isEmpty) continue;

      final chunks = _chunkSingleParagraph(
        p,
        maxChunkChars: nativePossible ? 850 : 2000,
      );

      final correctedChunks = <String>[];

      for (final chunk in chunks) {
        String corrected;
        if (nativePossible) {
          try {
            corrected = await _proofreadChunkNative(chunk, nativeLang!);
          } catch (_) {
            corrected = _simpleLocalCorrectParagraph(chunk);
          }
        } else {
          corrected = _simpleLocalCorrectParagraph(chunk);
        }
        correctedChunks.add(corrected.trim());
      }

      final rebuiltParagraph = correctedChunks
          .where((e) => e.trim().isNotEmpty)
          .join(' ')
          .trim();

      if (rebuiltParagraph.isNotEmpty) {
        correctedParagraphs.add(_postProcessCorrectedParagraph(rebuiltParagraph));
      }
    }

    return correctedParagraphs.join('\n\n').trim();
  }

  Future<String> _proofreadChunkNative(String text, String language) async {
    final res = await _native.invokeMethod(
      'rewriteTranscript',
      {
        'text': text,
        'language': language,
      },
    );

    final map = Map<String, dynamic>.from(res as Map);

    if (map['ok'] == true) {
      final rewritten = (map['text'] ?? '').toString().trim();
      if (rewritten.isNotEmpty) return rewritten;
    }

    throw Exception((map['reason'] ?? 'native_proofread_failed').toString());
  }

  String? _nativeLanguageFor(String language) {
    final l = language.trim().toLowerCase();

    if (l.startsWith('en')) return 'en';
    if (l.startsWith('ja')) return 'ja';
    if (l.startsWith('fr')) return 'fr';
    if (l.startsWith('de')) return 'de';
    if (l.startsWith('it')) return 'it';
    if (l.startsWith('es')) return 'es';
    if (l.startsWith('ko')) return 'ko';

    return null;
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
      case 'ko':
        return 'ko';
      default:
        return 'auto';
    }
  }

  String _prepareForCorrection(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;

    text = text.replaceAll('\r\n', '\n');
    text = text.replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'[\t\f\v]+'), ' ');
    text = text.replaceAll(RegExp(r'\u00A0'), ' ');
    text = text.replaceAll(RegExp(r'[ ]{2,}'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final paragraphs = _splitPreservingParagraphs(text);
    final cleanedParagraphs = <String>[];

    for (final paragraph in paragraphs) {
      var p = paragraph.trim();
      if (p.isEmpty) continue;

      p = _joinBrokenLinesInsideParagraph(p);
      p = _simpleLocalCorrectParagraph(p);
      p = p.trim();

      if (p.isNotEmpty) {
        cleanedParagraphs.add(p);
      }
    }

    return cleanedParagraphs.join('\n\n').trim();
  }

  String _simpleLocalCorrectParagraph(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;

    text = _removeRepeatedFillers(text);
    text = _removeImmediateDuplicateWords(text);
    text = _normalizePunctuationSpacing(text);
    text = _capitalizeSentenceStarts(text);
    text = text.replaceAll(RegExp(r'\s+\.'), '.');
    text = text.replaceAll(RegExp(r'\s+,') , ',');
    text = text.replaceAll(RegExp(r'\s+!'), '!');
    text = text.replaceAll(RegExp(r'\s+\?'), '?');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    return text.trim();
  }

  String _postProcessCorrectedParagraph(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;

    text = _removeRepeatedFillers(text);
    text = _removeImmediateDuplicateWords(text);
    text = _normalizePunctuationSpacing(text);
    text = _capitalizeSentenceStarts(text);
    return text.trim();
  }

  List<String> _splitPreservingParagraphs(String input) {
    return input
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _joinBrokenLinesInsideParagraph(String input) {
    final lines = input
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first;

    final out = StringBuffer(lines.first);

    for (var i = 1; i < lines.length; i++) {
      final current = lines[i];
      out.write(' ');
      out.write(current);
    }

    return out.toString().trim();
  }

  String _removeRepeatedFillers(String input) {
    var text = input;

    const singleWordFillers = <String>[
      'é',
      'eh',
      'ahn',
      'ah',
      'hum',
      'hmm',
      'uh',
      'um',
      'er',
      'emm',
      'tipo',
      'né',
      'bom',
    ];

    for (final filler in singleWordFillers) {
      final escaped = RegExp.escape(filler);
      final repeatedPattern = RegExp(
        '(?:(^)|([,;:\\-–—\\(\\[]|\\s))($escaped)(?:(\\s*[,;:\\-–—]?\\s*)($escaped)){1,}(?=\\b|[.!?…]|\\n|\$)',
        caseSensitive: false,
        unicode: true,
      );

      text = text.replaceAllMapped(repeatedPattern, (m) {
        final prefixA = m.group(1) ?? '';
        final prefixB = m.group(2) ?? '';
        final fillerValue = m.group(3) ?? filler;
        return '$prefixA$prefixB$fillerValue';
      });
    }

    text = text.replaceAllMapped(
      RegExp(
        r'\b([A-Za-zÀ-ÿ]{1,12})\b(?:\s*,\s*\1\b){1,}',
        caseSensitive: false,
        unicode: true,
      ),
      (m) => m.group(1) ?? '',
    );

    return text;
  }

  String _removeImmediateDuplicateWords(String input) {
    var text = input;

    final duplicateWord = RegExp(
      r'\b([A-Za-zÀ-ÿ0-9]+)\b(?:\s+\1\b)+',
      caseSensitive: false,
      unicode: true,
    );

    while (duplicateWord.hasMatch(text)) {
      text = text.replaceAllMapped(duplicateWord, (m) => m.group(1) ?? '');
    }

    final duplicateWithComma = RegExp(
      r'\b([A-Za-zÀ-ÿ0-9]+)\b(?:\s*,\s*\1\b)+',
      caseSensitive: false,
      unicode: true,
    );

    while (duplicateWithComma.hasMatch(text)) {
      text = text.replaceAllMapped(duplicateWithComma, (m) => m.group(1) ?? '');
    }

    return text;
  }

  String _normalizePunctuationSpacing(String input) {
    var text = input;
    text = text.replaceAll(RegExp(r'\s+([,.;:!?…])'), r'$1');
    text = text.replaceAll(RegExp(r'([,;:!?…])(?!\s|\n|$)'), r'$1 ');
    text = text.replaceAll(RegExp(r'\(\s+'), '(');
    text = text.replaceAll(RegExp(r'\s+\)'), ')');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    text = text.replaceAll(RegExp(r'([.!?…]){2,}'), r'$1');
    text = text.replaceAll(RegExp(r'([,;:]){2,}'), r'$1');
    return text.trim();
  }

  String _capitalizeSentenceStarts(String input) {
    final chars = input.split('');
    final out = StringBuffer();
    var shouldCapitalize = true;

    for (final ch in chars) {
      if (shouldCapitalize && RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(ch)) {
        out.write(ch.toUpperCase());
        shouldCapitalize = false;
        continue;
      }

      out.write(ch);

      if (RegExp(r'[.!?…\n]').hasMatch(ch)) {
        shouldCapitalize = true;
      } else if (!RegExp(r'\s').hasMatch(ch)) {
        shouldCapitalize = false;
      }
    }

    return out.toString();
  }

  List<String> _chunkSingleParagraph(String text, {required int maxChunkChars}) {
    final t = text.trim();
    if (t.length <= maxChunkChars) return [t];

    final chunks = <String>[];
    var buffer = StringBuffer();

    void flush() {
      final s = buffer.toString().trim();
      if (s.isNotEmpty) chunks.add(s);
      buffer = StringBuffer();
    }

    final sentences = t.split(RegExp(r'(?<=[\.\!?。！？])\s+'));

    for (final sentence in sentences) {
      final s = sentence.trim();
      if (s.isEmpty) continue;

      if (s.length > maxChunkChars) {
        if (buffer.isNotEmpty) flush();

        final words = s.split(RegExp(r'\s+'));
        var local = StringBuffer();

        for (final word in words) {
          if (local.length + word.length + 1 > maxChunkChars) {
            final piece = local.toString().trim();
            if (piece.isNotEmpty) chunks.add(piece);
            local = StringBuffer();
          }
          local.write(word);
          local.write(' ');
        }

        final last = local.toString().trim();
        if (last.isNotEmpty) chunks.add(last);
        continue;
      }

      if (buffer.length + s.length + 1 > maxChunkChars) {
        flush();
      }

      buffer.write(s);
      buffer.write(' ');
    }

    flush();
    return chunks.isEmpty ? [t] : chunks;
  }
}
