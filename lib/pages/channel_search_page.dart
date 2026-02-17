import 'package:flutter/material.dart';

import '../services/youtube_channel_search_service.dart';
import 'channel_page.dart';

class ChannelSearchPage extends StatefulWidget {
  const ChannelSearchPage({super.key});

  @override
  State<ChannelSearchPage> createState() => _ChannelSearchPageState();
}

class _ChannelSearchPageState extends State<ChannelSearchPage> {
  final _ctrl = TextEditingController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _channels = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _channels = [];
    });

    try {
      final svc = YouTubeChannelSearchService();
      final resObj = await svc.searchChannels(q);
      final res = resObj.map((e) => e.toMap()).toList();
      if (!mounted) return;
      setState(() {
        _channels = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _thumb(BuildContext context, String url) {
    final u = url.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: u.isEmpty
            ? const Icon(Icons.person_outline)
            : Image.network(
          u,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar canais')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Digite o nome do canal',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],

          if (_error != null) ...[
            Text('Erro: $_error'),
            const SizedBox(height: 12),
          ],

          if (!_loading && _channels.isEmpty && _ctrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Center(child: Text('Nenhum canal encontrado.')),
          ],

          ..._channels.map((c) {
            final title = (c['title'] ?? '').toString();
            final url = (c['channelUrl'] ?? '').toString();
            final thumb = (c['thumb'] ?? '').toString();

            return Card(
              child: ListTile(
                leading: _thumb(context, thumb),
                title: Text(title),
                subtitle: const Text('Canal'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChannelPage(
                        channelUrl: url,
                        title: title,
                        thumb: thumb,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
