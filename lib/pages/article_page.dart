import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/html_entities.dart';

class ArticlePage extends StatelessWidget {
  final String title;
  final String source;
  final String content;

  const ArticlePage({
    super.key,
    required this.title,
    required this.source,
    required this.content,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto copiado.')));
  }

    @override
  Widget build(BuildContext context) {
    final safeTitle = decodeHtmlEntities(title);
    final safeSource = decodeHtmlEntities(source);
    final safeContent = decodeHtmlEntities(content);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artigo'),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(safeTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(safeSource, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          SelectableText(safeContent),
        ],
      ),
    );
  }
}
