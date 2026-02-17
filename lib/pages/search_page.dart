import 'package:flutter/material.dart';
import '../data/db.dart';
import '../services/youtube_channel_search_service.dart';
import '../services/youtube_video_search_service.dart';
import 'channel_page.dart';
import 'video_transcript_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _channels = [];

  bool _loadingFavs = true;
  List<Map<String, Object?>> _favVideos = [];

  @override
  void initState() {
    super.initState();
    _loadFavVideos();
  }

  Future<void> _loadFavVideos() async {
    setState(() => _loadingFavs = true);
    final v = await AppDb.listFavVideos();
    if (!mounted) return;
    setState(() {
      _favVideos = v;
      _loadingFavs = false;
    });
  }

  // usado pelo HomePage para atualizar a seção de favoritos
  Future<void> reloadFavSection() => _loadFavVideos();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _millisOf(Map<String, dynamic> v) {
    final raw = v['publishedMillis'];
    if (raw == null) return 0;

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();

    if (raw is String) {
      // suporta "1700000000000" ou "1700000000000.0"
      final s = raw.trim();
      final i = int.tryParse(s);
      if (i != null) return i;
      final d = double.tryParse(s);
      if (d != null) return d.toInt();
    }

    return 0;
  }

  // tenta extrair número de “há X dias / X days ago / X weeks ago / X months ago”
  // retorna um "idade em minutos" (quanto maior, mais antigo). Se não conseguir, retorna null.
  int? _ageMinutesFromText(String t) {
    final s = t.toLowerCase().trim();
    if (s.isEmpty) return null;

    // pega o primeiro número
    final m = RegExp(r'(\d+)').firstMatch(s);
    if (m == null) return null;
    final n = int.tryParse(m.group(1) ?? '');
    if (n == null) return null;

    // inglês
    if (s.contains('minute')) return n;
    if (s.contains('hour')) return n * 60;
    if (s.contains('day')) return n * 24 * 60;
    if (s.contains('week')) return n * 7 * 24 * 60;
    if (s.contains('month')) return n * 30 * 24 * 60;
    if (s.contains('year')) return n * 365 * 24 * 60;

    // pt (bem básico)
    if (s.contains('minut')) return n;
    if (s.contains('hora')) return n * 60;
    if (s.contains('dia')) return n * 24 * 60;
    if (s.contains('seman')) return n * 7 * 24 * 60;
    if (s.contains('mês') || s.contains('mes')) return n * 30 * 24 * 60;
    if (s.contains('ano')) return n * 365 * 24 * 60;

    return null;
  }

  String _formatDateLabel(Map<String, dynamic> v) {
    final millis = _millisOf(v);
    final publishedText = (v['publishedText'] ?? '').toString().trim();

    if (millis > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString();
      return '$dd/$mm/$yy';
    }

    if (publishedText.isNotEmpty) return publishedText;
    return '';
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _videos = [];
      _channels = [];
    });

    try {
      final vidsObj = await YouTubeVideoSearchService().searchVideos(q);
      final chansObj = await YouTubeChannelSearchService().searchChannels(q);
      final vids = vidsObj.map((e) => e.toMap()).toList();
      final chans = chansObj.map((e) => e.toMap()).toList();

      // ✅ sort robusto:
      // 1) quem tem publishedMillis > 0 vem primeiro
      // 2) publishedMillis desc
      // 3) fallback por publishedText (“x days ago” / “há x dias”) se ambos não tiverem millis
      vids.sort((a, b) {
        final am = _millisOf(a);
        final bm = _millisOf(b);

        final aHas = am > 0;
        final bHas = bm > 0;

        if (aHas && !bHas) return -1;
        if (!aHas && bHas) return 1;

        if (aHas && bHas) {
          // mais recente primeiro
          return bm.compareTo(am);
        }

        // ambos sem millis: tenta ordenar por texto relativo (menor idade = mais recente)
        final at = (a['publishedText'] ?? '').toString();
        final bt = (b['publishedText'] ?? '').toString();
        final aAge = _ageMinutesFromText(at);
        final bAge = _ageMinutesFromText(bt);

        if (aAge != null && bAge != null) return aAge.compareTo(bAge);
        if (aAge != null && bAge == null) return -1; // quem tem idade conhecida vem primeiro
        if (aAge == null && bAge != null) return 1;

        return 0; // mantém ordem original
      });

      if (!mounted) return;
      setState(() {
        _videos = vids;
        _channels = chans;
        _loading = false;
      });
      // também atualiza favoritos em caso de mudanças recentes
      _loadFavVideos();
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
      {double w = 52, double h = 52, IconData fallback = Icons.image}) {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Buscar vídeos e canais',
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        // -----------------------
        // Favoritos recentes (cronológico)
        // -----------------------
        if (_loadingFavs) ...[
          const SizedBox(height: 4),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
        ] else if (_favVideos.isNotEmpty) ...[
          const Text('Favoritos recentes', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._favVideos.map((v) {
            final title = (v['title'] ?? '').toString();
            final channel = (v['channel'] ?? '').toString();
            final url = (v['video_url'] ?? '').toString();
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: read
                          ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                          : null,
                    ),
                    subtitle: Text(read ? '$channel • Lido' : channel),
                    trailing: read ? const Icon(Icons.done_all) : null,
                    onTap: () async {
                      if (url.trim().isEmpty) return;
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
                      _loadFavVideos();
                    },
                  ),
                );
              },
            );
          }).toList(),
          const SizedBox(height: 16),
        ],

        if (_loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],

        if (_error != null) ...[
          Text('Erro: $_error'),
          const SizedBox(height: 12),
        ],

        // -----------------------
        // Canais
        // -----------------------
        if (_channels.isNotEmpty) ...[
          const Text('Canais', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._channels.map((c) {
            final title = (c['title'] ?? '').toString();
            final url = (c['channelUrl'] ?? '').toString();
            final thumb = (c['thumb'] ?? '').toString();

            return FutureBuilder<bool>(
              future: AppDb.isFavChannel(url),
              builder: (context, snap) {
                final fav = snap.data ?? false;

                return Card(
                  child: ListTile(
                    leading: _thumb(context, thumb, fallback: Icons.person_outline),
                    title: Text(title),
                    subtitle: const Text('Canal'),
                    trailing: IconButton(
                      tooltip: fav ? 'Remover favorito' : 'Favoritar',
                      icon: Icon(fav ? Icons.star : Icons.star_border),
                      onPressed: () async {
                        if (url.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Canal sem URL válida.')),
                          );
                          return;
                        }
                        await AppDb.toggleFavChannel(channelUrl: url, title: title, thumb: thumb);
                        if (mounted) setState(() {});
                      },
                    ),
                    onTap: () {
                      if (url.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Canal sem URL válida.')),
                        );
                        return;
                      }
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
              },
            );
          }).toList(),
          const SizedBox(height: 16),
        ],

        // -----------------------
        // Vídeos
        // -----------------------
        if (_videos.isNotEmpty) ...[
          const Text('Vídeos', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._videos.map((v) {
            final title = (v['title'] ?? '').toString();
            final channel = (v['channel'] ?? '').toString();
            final url = (v['videoUrl'] ?? '').toString();
            final thumb = (v['thumb'] ?? '').toString();

            final dateLabel = _formatDateLabel(v);
            final subtitle = dateLabel.isEmpty ? channel : '$channel • $dateLabel';

            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                AppDb.isFavVideo(url),
                AppDb.isTranscribed(url),
              ]),
              builder: (context, snap) {
                final fav = (snap.data is List && (snap.data as List).isNotEmpty)
                    ? (snap.data as List)[0] as bool
                    : false;
                final read = (snap.data is List && (snap.data as List).length > 1)
                    ? (snap.data as List)[1] as bool
                    : false;

                return Card(
                  child: ListTile(
                    leading: _thumb(context, thumb, w: 96, h: 54, fallback: Icons.play_circle_outline),
                    title: Text(
                      title,
                      style: read
                          ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                          : null,
                    ),
                    subtitle: Text(subtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (read) const Icon(Icons.done_all),
                        IconButton(
                          tooltip: fav ? 'Remover favorito' : 'Favoritar',
                          icon: Icon(fav ? Icons.star : Icons.star_border),
                          onPressed: () async {
                            if (url.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vídeo sem URL válida.')),
                              );
                              return;
                            }
                            await AppDb.toggleFavVideo(videoUrl: url, title: title, channel: channel, thumb: thumb);
                            await _loadFavVideos();
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
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
                      ).then((_) => _loadFavVideos());
                    },
                  ),
                );
              },
            );
          }).toList(),
        ],

        if (!_loading && _channels.isEmpty && _videos.isEmpty && _ctrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          const Center(child: Text('Nenhum resultado.')),
        ],
      ],
    );
  }
}
