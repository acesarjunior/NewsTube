import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_strings.dart';
import '../services/grammar_service.dart';
import '../services/html_entities.dart';
import '../services/prefs.dart';
import '../services/translate_service.dart';
import '../widgets/app_shell_actions.dart';

class ArticlePage extends StatefulWidget {
  final String title;
  final String source;
  final String content;

  const ArticlePage({
    super.key,
    required this.title,
    required this.source,
    required this.content,
  });

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final TranslateService _translateService = TranslateService();
  final GrammarService _grammarService = GrammarService();

  String? _translatedTitle;
  String? _translatedContent;
  String? _grammarFixedText;
  bool _showingTranslated = false;
  bool _showingGrammar = false;
  bool _busy = false;

  String _targetLang = 'en';
  bool _targetLangChosen = false;

  String get _safeTitle => decodeHtmlEntities(widget.title);
  String get _safeSource => decodeHtmlEntities(widget.source);
  String get _safeContent => decodeHtmlEntities(widget.content);

  String get _displayTitle => _showingTranslated && _translatedTitle != null ? _translatedTitle! : _safeTitle;

  String get _displayContent {
    if (_showingGrammar && _grammarFixedText != null) return _grammarFixedText!;
    if (_showingTranslated && _translatedContent != null) return _translatedContent!;
    return _safeContent;
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final saved = await AppPrefs.loadTranslateTargetLangNullable();
    if (!mounted) return;
    setState(() {
      _targetLang = saved ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _targetLangChosen = saved != null;
    });
  }

  Future<void> _copy(BuildContext context) async {
    final s = AppStrings.of(context);
    await Clipboard.setData(ClipboardData(text: _displayContent));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('copied'))));
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

  Future<void> _translate() async {
    final s = AppStrings.of(context);
    if (!_targetLangChosen) {
      await _pickTargetLang();
      if (!_targetLangChosen) return;
    }

    setState(() {
      _busy = true;
      _showingGrammar = false;
    });

    try {
      final target = _targetLang.trim().isEmpty ? 'en' : _targetLang.trim();
      final translatedTitle = await _translateService.translate(text: _safeTitle, sourceLang: 'auto', targetLang: target);
      final translatedContent = await _translateService.translate(text: _safeContent, sourceLang: 'auto', targetLang: target);
      if (!mounted) return;
      setState(() {
        _translatedTitle = translatedTitle;
        _translatedContent = translatedContent;
        _showingTranslated = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('translation_failed'))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _correctGrammar() async {
    final s = AppStrings.of(context);
    final lang = _showingTranslated ? _targetLang : AppControllerScope.of(context).locale.languageCode;

    setState(() {
      _busy = true;
      _showingGrammar = false;
    });

    try {
      final corrected = await _grammarService.correct(text: _displayContent, language: lang);
      if (!mounted) return;
      setState(() {
        _grammarFixedText = corrected;
        _showingGrammar = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('grammar_fixed'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('grammar_failed'))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('article')),
        actions: [
          const AppShellActions(),
          IconButton(
            tooltip: s.t('copy'),
            icon: const Icon(Icons.copy),
            onPressed: _busy ? null : () => _copy(context),
          ),
          IconButton(
            tooltip: s.t('language'),
            icon: const Icon(Icons.language),
            onPressed: _busy ? null : _pickTargetLang,
          ),
          IconButton(
            tooltip: s.t('translate'),
            icon: const Icon(Icons.translate),
            onPressed: _busy ? null : _translate,
          ),
          IconButton(
            tooltip: s.t('grammar_fix'),
            icon: const Icon(Icons.spellcheck),
            onPressed: _busy ? null : _correctGrammar,
          ),
          if (_translatedContent != null)
            IconButton(
              tooltip: _showingTranslated ? s.t('view_original') : s.t('view_translation'),
              icon: Icon(_showingTranslated ? Icons.article_outlined : Icons.swap_horiz),
              onPressed: _busy
                  ? null
                  : () {
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
          if (_busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          Text(
            _displayTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(_safeSource, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          SelectableText(_displayContent),
        ],
      ),
    );
  }
}
