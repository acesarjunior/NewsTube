import 'package:flutter/material.dart';
import '../data/db.dart';
import '../services/youtube_rss_channel_service.dart';
import 'video_transcript_page.dart';

class ChannelPage extends StatefulWidget {
  final String channelUrl;
  final String title;
  final String thumb;

  const ChannelPage({
    super.key,
    required this.channelUrl,
    required this.title,
    required this.thumb,
  });

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final _svc = YoutubeRssChannelService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _videos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _videos = [];
    });

    try {
      final vids = await _svc.fetchLatestVideos(
        channelUrl: widget.channelUrl,
        limit: 30,
      );

      if (!mounted) return;
      setState(() {
        _videos = vids;
        _loading = false;
      });

      if (vids.isEmpty) {
        setState(() => _error = 'Nenhum vídeo encontrado para este canal.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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

Widget _thumb(BuildContext context, String url,
      {double w = 96, double h = 54, IconData fallback = Icons.play_circle_outline}) {
    final u = _normImgUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: w,
        height: h,
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: u.isEmpty
            ? Icon(fallback)
            : Image.network(
          u,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(fallback),
        ),
      ),
    );
  }

  String _dateLabel(Map<String, dynamic> v) {
    final iso = (v['publishedText'] ?? '').toString().trim();
    if (iso.isEmpty) return '';
    // YYYY-MM-DD
    if (iso.length >= 10) return iso.substring(0, 10);
    return iso;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isNotEmpty ? widget.title : 'Canal'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Erro:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(_error!),
        ],
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _videos.length,
        itemBuilder: (_, i) {
          final v = _videos[i];
          final title = (v['title'] ?? '').toString();
          final channel = (v['channel'] ?? widget.title).toString();
          final url = (v['videoUrl'] ?? '').toString();
          final thumb = (v['thumb'] ?? '').toString();
          final date = _dateLabel(v);

          return FutureBuilder<bool>(
            future: AppDb.isTranscribed(url),
            builder: (context, snap) {
              final read = snap.data ?? false;
              final sub = date.isNotEmpty ? '$channel • $date' : channel;
              return Card(
                child: ListTile(
                  leading: _thumb(context, thumb),
                  title: Text(
                    title,
                    style: read
                        ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  subtitle: Text(read ? '$sub • Lido' : sub),
                  trailing: read ? const Icon(Icons.done_all) : null,
                  onTap: () {
                    if (url.trim().isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoTranscriptPage(
                          videoUrl: url,
                          title: title,
                          channel: channel,
                          thumb: thumb,
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
