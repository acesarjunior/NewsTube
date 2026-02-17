import 'package:flutter/material.dart';
import '../data/db.dart';
import 'channel_page.dart';
import 'video_transcript_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => FavoritesPageState();
}

class FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  List<Map<String, Object?>> _channels = [];
  List<Map<String, Object?>> _videos = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    final c = await AppDb.listFavChannels();
    final v = await AppDb.listFavVideos();
    if (!mounted) return;
    setState(() {
      _channels = c;
      _videos = v;
      _loading = false;
    });
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

Widget _thumb(BuildContext context, String url, {double w = 52, double h = 52, IconData fallback = Icons.image}) {
    final u = _normImgUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: w,
        height: h,
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: u.isEmpty
            ? Icon(fallback)
            : Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(fallback)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_channels.isNotEmpty) ...[
            const Text('Canais', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._channels.map((c) {
              final url = (c['channel_url'] ?? '').toString();
              final title = (c['title'] ?? '').toString();
              final thumb = (c['thumb'] ?? '').toString();

              return Card(
                child: ListTile(
                  leading: _thumb(context, thumb, fallback: Icons.person_outline),
                  title: Text(title),
                  subtitle: const Text('Canal favorito'),
                  trailing: IconButton(
                    icon: const Icon(Icons.star),
                    tooltip: 'Remover favorito',
                    onPressed: () async {
                      await AppDb.toggleFavChannel(channelUrl: url, title: title, thumb: thumb);
                      await reload();
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChannelPage(channelUrl: url, title: title, thumb: thumb),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          if (_videos.isNotEmpty) ...[
            const Text('Vídeos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._videos.map((v) {
              final url = (v['video_url'] ?? '').toString();
              final title = (v['title'] ?? '').toString();
              final channel = (v['channel'] ?? '').toString();
              final thumb = (v['thumb'] ?? '').toString();

              return FutureBuilder<bool>(
                future: AppDb.isTranscribed(url),
                builder: (context, snap) {
                  final read = snap.data ?? false;
                  return Card(
                    child: ListTile(
                      leading: _thumb(context, thumb, w: 96, h: 54, fallback: Icons.play_circle_outline),
                      title: Text(
                        title,
                        style: read
                            ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                            : null,
                      ),
                      subtitle: Text(read ? '$channel • Lido' : channel),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (read) const Icon(Icons.done_all),
                          IconButton(
                            icon: const Icon(Icons.star),
                            tooltip: 'Remover favorito',
                            onPressed: () async {
                              await AppDb.toggleFavVideo(videoUrl: url, title: title, channel: channel, thumb: thumb);
                              await reload();
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoTranscriptPage(videoUrl: url, title: title, channel: channel, thumb: thumb),
                          ),
                        );
                        await reload();
                      },
                    ),
                  );
                },
              );
            }),
          ],

          if (_channels.isEmpty && _videos.isEmpty) ...[
            const SizedBox(height: 24),
            const Center(child: Text('Nenhum favorito ainda.')),
          ],
        ],
      ),
    );
  }
}
