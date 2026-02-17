import 'package:flutter/material.dart';
import '../data/db.dart';
import '../services/youtube_channel_videos_service.dart';
import 'video_transcript_page.dart';
import '../services/youtube_innertube_config.dart';

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
  final _svc = YoutubeChannelVideosService();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  List<Map<String, dynamic>> _videos = [];

  String? _continuation;
  YouTubeInnerTubeConfig? _cfg;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadFirst();

    _scrollCtrl.addListener(() {
      if (!_hasMore || _loadingMore || _loading) return;
      if (!_scrollCtrl.hasClients) return;

      final pos = _scrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _videos = [];
      _continuation = null;
      _cfg = null;
      _hasMore = true;
    });

    try {
      final page = await _svc.fetchChannelVideosPage(channelUrl: widget.channelUrl);
      if (!mounted) return;

      setState(() {
        _videos = page.items;
        _continuation = page.nextContinuation;
        _cfg = page.config;
        _hasMore = page.nextContinuation != null;
        _loading = false;
      });

      if (_videos.isEmpty) {
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

  Future<void> _loadMore() async {
    if (_continuation == null || _cfg == null) {
      setState(() => _hasMore = false);
      return;
    }

    setState(() => _loadingMore = true);

    try {
      final page = await _svc.fetchChannelVideosPage(
        channelUrl: widget.channelUrl,
        continuation: _continuation,
        config: _cfg,
      );

      if (!mounted) return;

      // Dedup por URL
      final seen = _videos.map((e) => (e['videoUrl'] ?? '').toString()).toSet();
      final add = <Map<String, dynamic>>[];
      for (final v in page.items) {
        final u = (v['videoUrl'] ?? '').toString();
        if (u.isEmpty) continue;
        if (seen.add(u)) add.add(v);
      }

      setState(() {
        _videos.addAll(add);
        _continuation = page.nextContinuation;
        _hasMore = page.nextContinuation != null && add.isNotEmpty;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        // Não derruba a tela inteira: só marca que não tem mais, e mostra um aviso leve.
        _hasMore = false;
        _error = 'Não foi possível carregar mais vídeos: $e';
      });
    }
  }

  String _normImgUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:' + u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isNotEmpty ? widget.title : 'Canal'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: _loadFirst,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _videos.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(_error!),
                  ],
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _videos.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _videos.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final v = _videos[i];
                    final url = (v['videoUrl'] ?? '').toString();
                    final title = (v['title'] ?? '').toString();
                    final channel = (v['channel'] ?? '').toString();
                    final thumb = (v['thumb'] ?? '').toString();

                    final publishedText = (v['publishedText'] ?? '').toString();
                    final durationText = (v['durationText'] ?? '').toString();

                    return FutureBuilder<bool>(
                      future: AppDb.isTranscribed(url),
                      builder: (context, snap) {
                        final read = snap.data ?? false;
                        return Card(
                          child: ListTile(
                            leading: _thumb(context, thumb),
                            title: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: read ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                            ),
                            subtitle: Text([
                              channel,
                              if (publishedText.isNotEmpty) publishedText,
                              if (durationText.isNotEmpty) durationText,
                            ].where((e) => e.trim().isNotEmpty).join(' • ')),
                            trailing: read ? const Icon(Icons.done_all) : null,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoTranscriptPage(
                                    videoUrl: url,
                                    title: title,
                                    channel: channel,
                                    thumb: thumb,
                                  ),
                                ),
                              );
                              setState(() {});
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