import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../data/db.dart';
import '../services/app_strings.dart';
import '../services/grammar_service.dart';
import '../services/html_entities.dart';
import '../services/prefs.dart';
import '../services/transcript_service.dart';
import '../services/translate_service.dart';
import '../widgets/app_shell_actions.dart';

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
  final _gsvc = GrammarService();

  bool _loading = true;
  String? _error;
  String _text = '';
  String _status = 'Loading...';

  String? _captionLang;
  String? _systemLang;
  bool _translateRemindEnabled = true;
  bool _hasBeenTranslated = false;
  String _targetLang = 'en';
  bool _targetLangChosen = false;
  String? _translatedText;
  String? _translatedTitle;
  String? _grammarText;
  bool _showingTranslated = false;
  bool _showingGrammar = false;
  bool _checkingOnDeviceRewrite = true;
  bool _onDeviceRewriteAvailable = false;

  bool _initialized = false;

  String get _displayText {
    if (_showingGrammar && _grammarText != null) return _grammarText!;
    if (_showingTranslated && _translatedText != null) return _translatedText!;
    return _text;
  }

  String get _displayTitle {
    if (_showingTranslated && _translatedTitle != null) {
      return _translatedTitle!;
    }
    return decodeHtmlEntities(widget.title);
  }

  @override
  void initState() {
    super.initState();
    _systemLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _refreshOnDeviceRewriteAvailability();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _run();
    }
  }

  String _currentDisplayLanguage() {
    if (_showingTranslated) {
      return _targetLang.trim().isEmpty ? 'auto' : _targetLang.trim();
    }

    final cap = (_captionLang ?? '').trim();
    if (cap.isNotEmpty) return cap;

    final sys = (_systemLang ?? '').trim();
    if (sys.isNotEmpty) return sys;

    return 'auto';
  }

  Future<void> _refreshOnDeviceRewriteAvailability() async {
    final supported = await _gsvc.isSupported(
      language: _currentDisplayLanguage(),
    );
    if (!mounted) return;

    setState(() {
      _onDeviceRewriteAvailable = supported;
      _checkingOnDeviceRewrite = false;
    });
  }

  String _prettyTranscript(String input) {
    var t = input.trim();
    if (t.isEmpty) return t;

    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');

    final hasLineBreaks = RegExp(r'\n').hasMatch(t);
    if (hasLineBreaks) {
      t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      t = t.replaceAll(RegExp(r' +\n'), '\n');
      return t.trim();
    }

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
    out = out.replaceAll(RegExp(r' +\n'), '\n');
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return out;
  }

  Future<void> _run() async {
    final s = AppStrings.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _text = '';
      _translatedText = null;
      _translatedTitle = null;
      _grammarText = null;
      _showingTranslated = false;
      _showingGrammar = false;
      _status = s.t('searching_captions');
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
        _status = s.t('failed');
      });
      return;
    }

    if (!mounted) return;

    if (!r.ok) {
      setState(() {
        _loading = false;
        _error = r.message;
        _status = s.t('failed');
      });
      return;
    }

    final formatted = _prettyTranscript(r.text);

    _captionLang = (r.captionLang ?? '').trim();
    await AppDb.markTranscribed(
      videoUrl: widget.videoUrl,
      captionLang: _captionLang,
    );

    _translateRemindEnabled = await AppPrefs.loadTranslateReminderEnabled();
    _hasBeenTranslated = await AppDb.hasBeenTranslated(widget.videoUrl);
    final saved = await AppPrefs.loadTranslateTargetLangNullable();
    _targetLangChosen = saved != null;
    _targetLang = saved ?? (_systemLang ?? 'en');

    setState(() {
      _loading = false;
      _text = formatted;
      _status = s.t(
        'status_caption',
        params: {'lang': (r.captionLang ?? '').trim()},
      );
    });

    await _refreshOnDeviceRewriteAvailability();
  }

  Future<void> _pickTargetLang() async {
    final s = AppStrings.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final langs = AppStrings.supportedLanguageCodes;
        return SafeArea(
          child: ListView(
            children: [
              ListTile(
                title: Text(s.t('translation_language')),
                subtitle: Text(s.t('choose_once_auto')),
              ),
              ...langs.map((k) {
                final label = AppStrings.languageLabels[k] ?? k;
                return ListTile(
                  leading: Radio<String>(
                    value: k,
                    groupValue: _targetLang,
                    onChanged: (v) => Navigator.pop(ctx, v),
                  ),
                  title: Text(label),
                  subtitle: Text(k),
                  onTap: () => Navigator.pop(ctx, k),
                );
              }),
            ],
          ),
        );
      },
    );

    if (!mounted || picked == null || picked.trim().isEmpty) return;

    setState(() {
      _targetLang = picked.trim();
      _targetLangChosen = true;
    });
    await AppPrefs.saveTranslateTargetLang(_targetLang);
  }

  Future<void> _doTranslate() async {
    final s = AppStrings.of(context);
    if (_text.trim().isEmpty) return;

    await AppDb.markTranslated(
      videoUrl: widget.videoUrl,
      targetLang: _targetLang,
    );
    final src = (_captionLang ?? '').trim().isEmpty
        ? 'auto'
        : (_captionLang ?? '').trim();

    setState(() {
      _status = s.t('translate');
      _showingGrammar = false;
    });

    try {
      final translatedTitle = await _tsvc.translate(
        text: decodeHtmlEntities(widget.title),
        sourceLang: 'auto',
        targetLang: _targetLang,
      );
      final translated = await _tsvc.translate(
        text: _text,
        sourceLang: src,
        targetLang: _targetLang,
      );

      if (!mounted) return;
      setState(() {
        _translatedTitle = translatedTitle;
        _translatedText = translated;
        _showingTranslated = true;
        _status = s.t('translation_done');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = s.t('translation_failed'));
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasBeenTranslated = true;
    });

    await _refreshOnDeviceRewriteAvailability();
  }

  Future<void> _translate() async {
    if (_text.trim().isEmpty) return;
    if (!_targetLangChosen) {
      await _pickTargetLang();
      if (!mounted || !_targetLangChosen) return;
    }
    await _doTranslate();
  }

  Future<void> _correctGrammar() async {
    final s = AppStrings.of(context);
    if (_displayText.trim().isEmpty) return;

    final lang = _currentDisplayLanguage();

    setState(() => _status = s.t('correcting_grammar'));
    try {
      final corrected = await _gsvc.correct(
        text: _displayText,
        language: lang,
      );
      if (!mounted) return;
      setState(() {
        _grammarText = corrected;
        _showingGrammar = true;
        _status = s.t('grammar_fixed');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '${s.t('grammar_failed')}: $e');
    }
  }

  String _normImgUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:$u';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('yt3.') ||
        u.startsWith('i.ytimg.') ||
        u.startsWith('lh3.')) {
      return 'https://$u';
    }
    return u;
  }

  Widget _thumb(BuildContext context, String url) {
    final u = _normImgUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 180,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: u.isEmpty
            ? const Center(child: Icon(Icons.play_circle_outline, size: 48))
            : Image.network(
          u,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Center(
            child: Icon(Icons.play_circle_outline, size: 48),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final safeChannel = decodeHtmlEntities(widget.channel);
    final canCopy = _displayText.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('transcript')),
        actions: [
          const AppShellActions(),
          IconButton(
            tooltip: s.t('reload'),
            icon: const Icon(Icons.refresh),
            onPressed: _run,
          ),
          if (canCopy)
            IconButton(
              tooltip: s.t('copy'),
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _displayText));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.t('copied'))),
                );
              },
            ),
          if (canCopy)
            IconButton(
              tooltip: s.t('language'),
              icon: const Icon(Icons.language),
              onPressed: _pickTargetLang,
            ),
          if (canCopy)
            IconButton(
              tooltip: s.t('translate'),
              icon: const Icon(Icons.translate),
              onPressed: _translate,
            ),
          if (canCopy)
            IconButton(
              tooltip: 'Revisar texto',
              icon: const Icon(Icons.auto_fix_high),
              onPressed: _checkingOnDeviceRewrite ? null : _correctGrammar,
            ),
          if (_translatedText != null)
            IconButton(
              tooltip: _showingTranslated
                  ? s.t('view_original')
                  : s.t('view_translation'),
              icon: Icon(
                _showingTranslated
                    ? Icons.article_outlined
                    : Icons.swap_horiz,
              ),
              onPressed: () {
                setState(() {
                  _showingTranslated = !_showingTranslated;
                  _showingGrammar = false;
                });
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _thumb(context, widget.thumb),
          const SizedBox(height: 12),
          Text(
            _displayTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            safeChannel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) ...[
            Text(_status),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ] else if (_error != null) ...[
            Text(
              '${s.t('error')}: $_error',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(s.t('captions_only_note')),
          ] else ...[
            Text(_status),
            const SizedBox(height: 12),
            SelectableText(
              _displayText,
              style: const TextStyle(height: 1.35, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }
}