import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Clipboard / ClipboardData

import '../data/db.dart';
import '../services/transcript_service.dart';
import '../services/translate_service.dart';
import '../services/prefs.dart';
import '../services/html_entities.dart';

class VideoTranscriptPage extends StatefulWidget {
final String videoUrl;
final String title;
final String channel;
final String thumb;

const VideoTranscriptPage({
super.key,
required this.videoUrl,
required this.title,
required this.channel,
required this.thumb,
});

@override
State<VideoTranscriptPage> createState() => _VideoTranscriptPageState();
}

class _VideoTranscriptPageState extends State<VideoTranscriptPage> {
final _svc = TranscriptService(debug: false);
final _tsvc = TranslateService();

bool _loading = true;
String? _error;
String _text = '';
String _status = 'Carregando...';

  bool _showTranslateBanner = false;
  String? _captionLang;
  String? _systemLang;
  bool _translateRemindEnabled = true;
  bool _hasBeenTranslated = false;
  String _targetLang = 'en';
  bool _targetLangChosen = false;
  String? _translatedText;
  bool _showingTranslated = false;

  String get _displayText => (_showingTranslated && _translatedText != null) ? _translatedText! : _text;

@override
void initState() {
super.initState();
  _systemLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
_run();
}

// ✅ Deixa a legenda/transcrição mais legível (parágrafos)
String _prettyTranscript(String input) {
var t = input.trim();
if (t.isEmpty) return t;

// Normaliza espaços/tabs
t = t.replaceAll(RegExp(r'[ \t]+'), ' ');

// Se já tem quebras de linha, só reduz excesso
final hasLineBreaks = RegExp(r'\n').hasMatch(t);
if (hasLineBreaks) {
t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
// remove espaços antes de quebra
t = t.replaceAll(RegExp(r' +\n'), '\n');
return t.trim();
}

// Quebra por pontuação comum e agrupa 2 frases por parágrafo
final parts = t.split(RegExp(r'(?<=[\.\!\?])\s+'));
final buf = StringBuffer();
var count = 0;

for (final p in parts) {
final s = p.trim();
if (s.isEmpty) continue;

buf.write(s);
buf.write(' ');

count++;
if (count >= 2) {
buf.write('\n\n');
count = 0;
}
}

var out = buf.toString().trim();

// Remove espaços antes de quebra
out = out.replaceAll(RegExp(r' +\n'), '\n');

// Evita muitos parágrafos vazios
out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');

return out;
}

Future<void> _run() async {
setState(() {
_loading = true;
_error = null;
_text = '';
_status = 'Buscando legendas...';
});

TranscriptResult r;
try {
r = await _svc.fetchTranscriptFromCaptions(
videoUrl: widget.videoUrl,
preferLang: 'pt',
);
} catch (e) {
if (!mounted) return;
setState(() {
_loading = false;
_error = e.toString();
_status = 'Falhou';
});
return;
}

if (!mounted) return;

if (!r.ok) {
setState(() {
_loading = false;
_error = r.message;
_status = 'Falhou';
});
return;
}

final formatted = _prettyTranscript(r.text);

  _captionLang = (r.captionLang ?? '').trim();
  await AppDb.markTranscribed(videoUrl: widget.videoUrl, captionLang: _captionLang);

  _translateRemindEnabled = await AppPrefs.loadTranslateReminderEnabled();
  _hasBeenTranslated = await AppDb.hasBeenTranslated(widget.videoUrl);
    final saved = await AppPrefs.loadTranslateTargetLangNullable();
  _targetLangChosen = saved != null;
  _targetLang = saved ?? (_systemLang ?? 'en');

  final cap = (_captionLang ?? '').toLowerCase();
  final sys = (_systemLang ?? '').toLowerCase();
  _showTranslateBanner =
      _translateRemindEnabled && !_hasBeenTranslated && cap.isNotEmpty && sys.isNotEmpty && cap != sys;

setState(() {
_loading = false;
_text = formatted;
_status = 'Legenda: ${(r.captionLang ?? "").trim()}'.trim();
});
}

  static const Map<String, String> _langLabel = {
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'cs': 'Čeština',
    'uk': 'Українська',
    'ja': '日本語',
    'zh-CN': '中文（简体）',
    'zh-TW': '中文（繁體）',
  };

  Future<void> _pickTargetLang() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final langs = _langLabel.keys.toList();
        return SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text('Idioma da tradução'),
                subtitle: Text('Escolha uma vez; depois a tradução será automática'),
              ),
              ...langs.map((k) {
                final label = _langLabel[k] ?? k;
                return RadioListTile<String>(
                  value: k,
                  groupValue: _targetLang,
                  title: Text(label),
                  subtitle: Text(k),
                  onChanged: (v) => Navigator.pop(ctx, v),
                );
              }),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (picked == null || picked.trim().isEmpty) return;

    setState(() {
      _targetLang = picked.trim();
      _targetLangChosen = true;
    });
    await AppPrefs.saveTranslateTargetLang(_targetLang);
  }

  Future<void> _doTranslate() async {
    if (_text.trim().isEmpty) return;

    await AppDb.markTranslated(videoUrl: widget.videoUrl, targetLang: _targetLang);

    final src = (_captionLang ?? '').trim().isEmpty ? 'auto' : (_captionLang ?? '').trim();

    setState(() {
      _status = 'Traduzindo...';
    });

    try {
      final translated = await _tsvc.translate(
        text: _text,
        sourceLang: src,
        targetLang: _targetLang,
      );

      if (!mounted) return;
      setState(() {
        _translatedText = translated;
        _showingTranslated = true;
        _status = 'Tradução concluída';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Falha ao traduzir');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível traduzir o texto agora.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasBeenTranslated = true;
      _showTranslateBanner = false;
    });
  }


  Future<void> _translate() async {
    if (_text.trim().isEmpty) return;

    // ✅ Se o usuário já escolheu um idioma antes, traduz direto.
    // Caso contrário, pergunta uma única vez e passa a ser automático.
    if (!_targetLangChosen) {
      await _pickTargetLang();
      if (!mounted) return;
      if (!_targetLangChosen) return;
    }

    await _doTranslate();
  }


  String _normImgUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:' + u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    // às vezes vem sem esquema
    if (u.startsWith('yt3.') || u.startsWith('i.ytimg.') || u.startsWith('lh3.')) return 'https://' + u;
    return u;
  }

Widget _thumb(BuildContext context, String url) {
final u = url.trim();
return ClipRRect(
borderRadius: BorderRadius.circular(12),
child: Container(
height: 180,
color: Theme.of(context).colorScheme.surfaceVariant,
child: u.isEmpty
? const Center(child: Icon(Icons.play_circle_outline, size: 48))
    : Image.network(
u,
fit: BoxFit.cover,
errorBuilder: (_, __, ___) =>
const Center(child: Icon(Icons.play_circle_outline, size: 48)),
),
),
);
}

@override
Widget build(BuildContext context) {
  final safeTitle = decodeHtmlEntities(widget.title);
  final safeChannel = decodeHtmlEntities(widget.channel);

final canCopy = _text.trim().isNotEmpty;
  final canTranslate = canCopy;

return Scaffold(
appBar: AppBar(
title: const Text('Transcrição'),
actions: [
IconButton(
tooltip: 'Recarregar',
icon: const Icon(Icons.refresh),
onPressed: _run,
),
if (canCopy)
IconButton(
tooltip: 'Copiar',
icon: const Icon(Icons.copy),
onPressed: () async {
await Clipboard.setData(ClipboardData(text: _displayText));
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Texto copiado.')),
);
},
),
if (canTranslate)
IconButton(
tooltip: 'Idioma',
icon: const Icon(Icons.language),
onPressed: _pickTargetLang,
),
if (canTranslate)
IconButton(
tooltip: 'Traduzir',
icon: const Icon(Icons.translate),
onPressed: _translate,
),
if (_translatedText != null)
IconButton(
tooltip: _showingTranslated ? 'Ver original' : 'Ver tradução',
icon: Icon(_showingTranslated ? Icons.article_outlined : Icons.swap_horiz),
onPressed: () {
  setState(() => _showingTranslated = !_showingTranslated);
},
),
],
),
body: ListView(
padding: const EdgeInsets.all(16),
children: [
if (_showTranslateBanner)
MaterialBanner(
content: Text(
  'A legenda parece estar em “${_captionLang ?? ''}”, diferente do idioma do sistema (“${_systemLang ?? ''}”).\n'
  'Deseja traduzir?',
),
leading: const Icon(Icons.info_outline),
actions: [
TextButton(
  onPressed: () {
    AppPrefs.setTranslateReminderEnabled(false);
    if (!mounted) return;
    setState(() {
      _translateRemindEnabled = false;
      _showTranslateBanner = false;
    });
  },
  child: const Text('Não lembrar'),
),
FilledButton(
  onPressed: _translate,
  child: const Text('Traduzir'),
),
],
),
_thumb(context, widget.thumb),
const SizedBox(height: 12),
Text(
safeTitle,
style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
),
const SizedBox(height: 4),
Text(
safeChannel,
style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
),
const SizedBox(height: 12),
if (_loading) ...[
Text(_status),
const SizedBox(height: 12),
const LinearProgressIndicator(),
] else if (_error != null) ...[
Text('Erro: $_error', style: const TextStyle(fontWeight: FontWeight.w700)),
const SizedBox(height: 8),
const Text(
'Observação: este modo usa apenas legendas do próprio vídeo. '
'Se o vídeo não tiver legendas, não é possível gerar texto sem transcrição offline.',
),
] else ...[
Text(_status),
const SizedBox(height: 12),
SelectableText(
_displayText,
style: const TextStyle(
height: 1.35, // ✅ melhora leitura
fontSize: 16,
),
),
],
],
),
);
}
}