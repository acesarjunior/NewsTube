import 'package:flutter/material.dart';
import '../data/db.dart';
import '../services/youtube_channel_search_service.dart';
import '../services/youtube_channel_videos_service.dart';
import '../services/youtube_rss_channel_service.dart';
import '../services/youtube_video_search_service.dart';
import 'channel_page.dart';
import 'video_transcript_page.dart';
import '../services/youtube_innertube_config.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  // ✅ ordem desejada: canais primeiro, depois vídeos
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _videos = [];

  // Paginação real (YouTube continuation) para vídeos de busca
  String? _videoContinuation;
  YouTubeInnerTubeConfig? _videoCfg;
  bool _videoHasMore = true;

  bool _loadingFavs = true;
  List<Map<String, Object?>> _favVideos = [];
  // Cache local para refletir a estrela imediatamente (evita FutureBuilder por item)
  final Set<String> _favVideoIds = <String>{};

  // Cache local para favoritos de CANAIS (para a estrela mudar na hora na lista de canais)
  final Set<String> _favChannelUrls = <String>{};

  // Feed dos favoritos quando não há busca ativa
  final _chanSvc = YoutubeChannelVideosService();
  final _rssSvc = YoutubeRssChannelService();

  // Estado por canal para feed misturado (k-way merge)
  final List<_FeedChannelState> _feedChannels = [];
  bool _loadingFeed = false;
  String? _feedError;

  // Itens já "materializados" (misturados e ordenados) e itens visíveis (paginação UI)
  final List<Map<String, dynamic>> _feedAll = [];
  List<Map<String, dynamic>> _feedVisible = [];

  bool _feedHasMore = true;
  static const int _feedPageSize = 20;

  @override
  void initState() {
    super.initState();

    _loadFavVideos();
    _loadFavChannels();
    _ensureFeedLoaded(force: true);

    _scrollCtrl.addListener(_onScroll);

    _ctrl.addListener(() {
      if (_ctrl.text.trim().isEmpty) {
        // limpa resultados de busca e volta ao feed
        if (_videos.isNotEmpty || _channels.isNotEmpty || _error != null) {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _error = null;
            _channels = [];
            _videos = [];
            _videoContinuation = null;
            _videoCfg = null;
            _videoHasMore = true;
          });
        }
        _ensureFeedLoaded();
      }
    });
  }

  void _onScroll() {
    final hasQuery = _ctrl.text.trim().isNotEmpty;

    if (hasQuery) {
      // Infinite scroll da BUSCA (vídeos)
      if (_loading || _loadingMore) return;
      if (!_videoHasMore) return;

      final pos = _scrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 400) {
        _loadMoreSearchVideos();
      }
      return;
    }

    // Infinite scroll do FEED (favoritos)
    if (!_feedHasMore || _loadingFeed) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _appendFeedPage();
    }
  }

  void scrollToTop() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _videoIdFromUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return '';
    final m1 = RegExp(r'[?&]v=([A-Za-z0-9_-]{6,})').firstMatch(u);
    if (m1 != null) return m1.group(1) ?? '';
    final m2 = RegExp(r'youtu\.be/([A-Za-z0-9_-]{6,})').firstMatch(u);
    if (m2 != null) return m2.group(1) ?? '';
    if (!u.contains('/') && !u.contains('?') && u.length >= 6) return u;
    return '';
  }

  Future<void> _loadFavVideos() async {
    setState(() => _loadingFavs = true);
    final v = await AppDb.listFavVideos();
    if (!mounted) return;
    setState(() {
      _favVideos = v;
      _favVideoIds
        ..clear()
        ..addAll(
          v.map((e) => _videoIdFromUrl((e['video_url'] ?? '').toString()))
              .where((id) => id.trim().isNotEmpty),
        );
      _loadingFavs = false;
    });
  }

  Future<void> _loadFavChannels() async {
    final chans = await AppDb.listFavChannels();
    if (!mounted) return;
    setState(() {
      _favChannelUrls
        ..clear()
        ..addAll(chans.map((e) => (e['channel_url'] ?? '').toString()).where((u) => u.trim().isNotEmpty));
    });
  }

    bool _isFavVideo(String url) {
    final id = _videoIdFromUrl(url);
    final key = id.isEmpty ? url : id;
    return _favVideoIds.contains(key);
  }

  Future<void> reloadFavSection() => _loadFavVideos();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // -----------------------
  // Feed: últimos vídeos dos canais favoritados (misturados por ordem cronológica)
  // Abordagem: k-way merge entre buffers por canal.
  // -----------------------
  int _ageMinutesFromText(String t) {
    final sRaw = t.trim();
    if (sRaw.isEmpty) return 1 << 30;

    // Mantém uma versão minúscula (boa para pt/en), mas preserva a original para CJK.
    final s = sRaw.toLowerCase();

    final m = RegExp(r'(\d+)').firstMatch(sRaw);
    if (m == null) return 1 << 30;
    final n = int.tryParse(m.group(1) ?? '');
    if (n == null) return 1 << 30;

    // Inglês
    if (s.contains('minute')) return n;
    if (s.contains('hour')) return n * 60;
    if (s.contains('day')) return n * 24 * 60;
    if (s.contains('week')) return n * 7 * 24 * 60;
    if (s.contains('month')) return n * 30 * 24 * 60;
    if (s.contains('year')) return n * 365 * 24 * 60;

    // Português (básico)
    if (s.contains('minut')) return n;
    if (s.contains('hora')) return n * 60;
    if (s.contains('dia')) return n * 24 * 60;
    if (s.contains('seman')) return n * 7 * 24 * 60;
    if (s.contains('mês') || s.contains('mes')) return n * 30 * 24 * 60;
    if (s.contains('ano')) return n * 365 * 24 * 60;

    // Japonês
    if (sRaw.contains('分前')) return n;
    if (sRaw.contains('時間前')) return n * 60;
    if (sRaw.contains('日前')) return n * 24 * 60;
    if (sRaw.contains('週間前')) return n * 7 * 24 * 60;
    if (sRaw.contains('か月前') || sRaw.contains('ヶ月前')) return n * 30 * 24 * 60;
    if (sRaw.contains('年前')) return n * 365 * 24 * 60;

    // Chinês (simplificado/tradicional - comum no YouTube)
    if (sRaw.contains('分钟') || sRaw.contains('分鐘')) return n;
    if (sRaw.contains('小时') || sRaw.contains('小時')) return n * 60;
    if (sRaw.contains('天前')) return n * 24 * 60;
    if (sRaw.contains('周前') || sRaw.contains('週前')) return n * 7 * 24 * 60;
    if (sRaw.contains('个月前') || sRaw.contains('個月前')) return n * 30 * 24 * 60;
    if (sRaw.contains('年前')) return n * 365 * 24 * 60;

    return 1 << 30;
  }

  // Quanto menor, mais recente.
  int _feedSortKey(Map<String, dynamic> v) {
    final millis = v['publishedMillis'];
    if (millis is int && millis > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - millis;
      if (diff <= 0) return 0;
      return (diff / 60000).floor();
    }
    return _ageMinutesFromText((v['publishedText'] ?? '').toString());
  }

  Future<void> _ensureFeedLoaded({bool force = false}) async {
    if (_ctrl.text.trim().isNotEmpty) return;
    if (!force && (_feedAll.isNotEmpty || _loadingFeed)) return;

    setState(() {
      _loadingFeed = true;
      _feedError = null;
      _feedAll.clear();
      _feedVisible = [];
      _feedHasMore = true;
    });

    _feedChannels.clear();

    try {
      final favChannels = await AppDb.listFavChannels();
      if (favChannels.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingFeed = false;
          _feedError = 'Nenhum canal nos favoritos.';
        });
        return;
      }

      // cache de favoritos (estrela de canais na busca)
      if (mounted) {
        setState(() {
          _favChannelUrls
            ..clear()
            ..addAll(favChannels.map((e) => (e['channel_url'] ?? '').toString()).where((u) => u.trim().isNotEmpty));
        });
      }

      // 1) cria estados por canal
      for (final c in favChannels) {
        final url = (c['channel_url'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        _feedChannels.add(_FeedChannelState(
          channelUrl: url,
          channelTitle: (c['title'] ?? '').toString(),
        ));
      }

      // 2) pré-carrega a primeira página de TODOS os canais (com fallback RSS se necessário)
      for (final ch in _feedChannels) {
        await _fillChannelBuffer(ch, minItems: 10);
      }

      // 3) materializa um lote inicial já misturado/ordenado
      await _buildMoreFeed(targetAdd: 60);

      if (!mounted) return;
      setState(() {
        _loadingFeed = false;
      });

      _appendFeedPage(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.toString();
        _loadingFeed = false;
      });
    }
  }

  Future<void> _fillChannelBuffer(_FeedChannelState ch, {int minItems = 10}) async {
    if (ch.loading || ch.exhausted) return;
    ch.loading = true;

    try {
      // Se é a primeira carga e ainda não temos config/continuation, buscamos a página inicial.
      if (!ch.initialLoaded) {
        ch.initialLoaded = true;
        final page = await _chanSvc.fetchChannelVideosPage(channelUrl: ch.channelUrl);
        ch.cfg = page.config;
        ch.continuation = page.nextContinuation;
        ch.buffer.addAll(_injectChannelTitleIfMissing(page.items, ch.channelTitle));

        // fallback: alguns canais/layouts podem voltar vazio na aba /videos sem cookies.
        if (ch.buffer.isEmpty) {
          final rss = await _rssSvc.fetchLatestVideos(channelUrl: ch.channelUrl, limit: 50);
          ch.buffer.addAll(_injectChannelTitleIfMissing(rss, ch.channelTitle));
          ch.exhausted = true; // RSS não tem continuation confiável para histórico completo
        }
        return;
      }

      // Continuação (se houver)
      if (ch.continuation == null || ch.continuation!.trim().isEmpty) {
        ch.exhausted = true;
        return;
      }

      final page = await _chanSvc.fetchChannelVideosPage(
        channelUrl: ch.channelUrl,
        continuation: ch.continuation,
        config: ch.cfg,
      );

      ch.cfg = page.config;
      ch.continuation = page.nextContinuation;
      final items = _injectChannelTitleIfMissing(page.items, ch.channelTitle);

      if (items.isEmpty) {
        // se a continuação vier vazia, consideramos esgotado para evitar loop
        ch.exhausted = true;
        ch.continuation = null;
      } else {
        ch.buffer.addAll(items);
      }
    } catch (_) {
      // Se falhar (muito comum por página de consentimento/bloqueio), fazemos fallback para RSS
      // para pelo menos exibir vídeos recentes misturados entre os favoritos.
      try {
        final rss = await _rssSvc.fetchLatestVideos(channelUrl: ch.channelUrl, limit: 50);
        ch.buffer.addAll(_injectChannelTitleIfMissing(rss, ch.channelTitle));
      } catch (_) {
        // ignore
      }
      ch.exhausted = true;
      ch.continuation = null;
    } finally {
      ch.loading = false;
    }
  }

  List<Map<String, dynamic>> _injectChannelTitleIfMissing(List<Map<String, dynamic>> items, String title) {
    for (final it in items) {
      final ch = (it['channel'] ?? '').toString().trim();
      if (ch.isEmpty) it['channel'] = title;
    }
    return items;
  }

  Future<void> _buildMoreFeed({required int targetAdd}) async {
    if (_ctrl.text.trim().isNotEmpty) return;
    if (_loadingFeed) return;

    final seen = _feedAll.map((e) => (e['videoUrl'] ?? '').toString()).toSet();
    int added = 0;
    int guard = 0;

    while (added < targetAdd && guard < 1000) {
      guard++;

      // garante que canais com buffer vazio tentem carregar mais, se possível
      for (final ch in _feedChannels) {
        if (ch.buffer.isEmpty && !ch.exhausted && !ch.loading) {
          await _fillChannelBuffer(ch, minItems: 10);
        }
      }

      // escolhe o canal cujo "head" é mais recente (menor sortKey)
      _FeedChannelState? best;
      int bestKey = 1 << 30;

      for (final ch in _feedChannels) {
        if (ch.buffer.isEmpty) continue;
        final k = _feedSortKey(ch.buffer.first);
        if (k < bestKey) {
          bestKey = k;
          best = ch;
        }
      }

      if (best == null) {
        // não há mais itens em nenhum canal
        break;
      }

      final item = best.buffer.removeAt(0);
      final u = (item['videoUrl'] ?? '').toString();
      if (u.isEmpty) continue;
      if (!seen.add(u)) continue;

      _feedAll.add(item);
      added++;
    }

    // mantém ordenado por cronologia (mais recente primeiro => menor sortKey)
    _feedAll.sort((a, b) => _feedSortKey(a).compareTo(_feedSortKey(b)));

    if (!mounted) return;
    setState(() {
      _feedHasMore = _feedVisible.length < _feedAll.length || _feedChannels.any((c) => !c.exhausted);
    });
  }

  void _appendFeedPage({bool reset = false}) {
    if (_loadingFeed) return;

    final current = reset ? 0 : _feedVisible.length;

    // Se a UI já consumiu tudo o que temos materializado, tenta materializar mais.
    if (current >= _feedAll.length) {
      // dispara mais materialização (sem bloquear o scroll)
      _buildMoreFeed(targetAdd: 40).then((_) {
        if (!mounted) return;
        setState(() {
          final next = (_feedVisible.length + _feedPageSize).clamp(0, _feedAll.length);
          _feedVisible = _feedAll.sublist(0, next);
          _feedHasMore = next < _feedAll.length || _feedChannels.any((c) => !c.exhausted);
        });
      });
      return;
    }

    final next = (current + _feedPageSize).clamp(0, _feedAll.length);
    setState(() {
      _feedVisible = _feedAll.sublist(0, next);
      _feedHasMore = next < _feedAll.length || _feedChannels.any((c) => !c.exhausted);
    });

    // Se estamos perto do fim do materializado, já prepara mais.
    if (_feedAll.length - next < 20) {
      _buildMoreFeed(targetAdd: 40);
    }
  }

  // -----------------------
  // BUSCA com pagination real (continuation)
  // -----------------------
  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _channels = [];
      _videos = [];
      _videoContinuation = null;
      _videoCfg = null;
      _videoHasMore = true;
    });

    try {
      final chansObj = await YouTubeChannelSearchService().searchChannels(q);
      final chans = chansObj.map((e) => e.toMap()).toList();

      final svc = YouTubeVideoSearchService();
      final page = await svc.searchVideosPage(q);

      final vids = page.items.map((e) => e.toMap()).toList();

      if (!mounted) return;
      setState(() {
        _channels = chans;
        _videos = vids;
        _videoContinuation = page.nextContinuation;
        _videoCfg = page.config;
        _videoHasMore = page.nextContinuation != null;
        _loading = false;
      });

      _loadFavVideos();
      scrollToTop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreSearchVideos() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    if (_videoContinuation == null || _videoCfg == null) {
      setState(() => _videoHasMore = false);
      return;
    }

    setState(() => _loadingMore = true);

    try {
      final svc = YouTubeVideoSearchService();
      final page = await svc.searchVideosPage(
        q,
        continuation: _videoContinuation,
        config: _videoCfg,
      );

      if (!mounted) return;

      final seen = _videos.map((e) => (e['videoUrl'] ?? '').toString()).toSet();
      final add = <Map<String, dynamic>>[];
      for (final it in page.items) {
        final m = it.toMap();
        final u = (m['videoUrl'] ?? '').toString();
        if (u.isEmpty) continue;
        if (seen.add(u)) add.add(m);
      }

      setState(() {
        _videos.addAll(add);
        _videoContinuation = page.nextContinuation;
        _videoHasMore = page.nextContinuation != null && add.isNotEmpty;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _videoHasMore = false;
        _error = 'Não foi possível carregar mais resultados: $e';
      });
    }
  }

  // -----------------------
  // UI helpers
  // -----------------------
  String _normImgUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) return 'https:' + u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
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

  SliverToBoxAdapter _sliverBox(Widget child) => SliverToBoxAdapter(child: child);

  @override
  Widget build(BuildContext context) {
    final hasQuery = _ctrl.text.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        if (_ctrl.text.trim().isNotEmpty) {
          await _search();
        } else {
          await _ensureFeedLoaded(force: true);
        }
      },
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: _sliverBox(
            Column(
              children: [
                TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Buscar vídeos e canais',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Atualizar',
                          icon: const Icon(Icons.refresh),
                          onPressed: () async {
                            if (_ctrl.text.trim().isNotEmpty) {
                              await _search();
                            } else {
                              await _ensureFeedLoaded(force: true);
                              scrollToTop();
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Buscar',
                          icon: const Icon(Icons.search),
                          onPressed: _search,
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Favoritos recentes (sempre no topo)
        if (_loadingFavs)
          _sliverBox(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(height: 4),
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                ],
              ),
            ),
          )
        else if (_favVideos.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: _sliverBox(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              style: read ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
                            ),
                            subtitle: Text(read ? '$channel • Lido' : channel),
                            trailing: read ? const Icon(Icons.done_all) : null,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoTranscriptPage(videoUrl: url, title: title, channel: channel, thumb: thumb),
                                ),
                              );
                              _loadFavVideos();
                            },
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ),

        // -----------------------
        // BUSCA
        // -----------------------
        if (hasQuery) ...[
          if (_loading)
            _sliverBox(
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(),
              ),
            ),

          if (_error != null)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _sliverBox(Text(_error!)),
            ),

          if (!_loading && _error == null && _channels.isEmpty && _videos.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _sliverBox(const Text('Nenhum resultado.')),
            ),

          // ✅ Canais primeiro
          if (_channels.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: _sliverBox(const Text('Canais', style: TextStyle(fontWeight: FontWeight.w700))),
            ),

          if (_channels.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final c = _channels[i];
                  final url = (c['channelUrl'] ?? '').toString();
                  final title = (c['title'] ?? '').toString();
                  final thumb = (c['thumb'] ?? '').toString();

                  final isFav = _favChannelUrls.contains(url);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: _thumb(context, thumb, fallback: Icons.person_outline),
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(isFav ? 'Canal favorito' : 'Canal'),
                      trailing: IconButton(
                        icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : null),
                        tooltip: isFav ? 'Remover favorito' : 'Favoritar',
                        onPressed: () async {
                          // atualização otimista para feedback imediato
                          setState(() {
                            if (isFav) {
                              _favChannelUrls.remove(url);
                            } else {
                              _favChannelUrls.add(url);
                            }
                          });
                          await AppDb.toggleFavChannel(channelUrl: url, title: title, thumb: thumb);
                          if (!mounted) return;
                          await _loadFavChannels();
                          await _ensureFeedLoaded(force: true);
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
                },
                childCount: _channels.length,
              ),
            ),

          // Depois vídeos
          if (_videos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: _sliverBox(const Text('Vídeos', style: TextStyle(fontWeight: FontWeight.w700))),
            ),

          if (_videos.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
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
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: _thumb(context, thumb, w: 96, h: 54, fallback: Icons.play_circle_outline),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (read) const Icon(Icons.done_all),
                              IconButton(
                                icon: Icon(
                                  _isFavVideo(url) ? Icons.star : Icons.star_border,
                                  color: _isFavVideo(url) ? Colors.amber : null,
                                ),
                                tooltip: _isFavVideo(url) ? 'Remover favorito' : 'Favoritar',
                                onPressed: () async {
                              final vid = _videoIdFromUrl(url);
                              final key = vid.isEmpty ? url : vid;
                              // atualização otimista para feedback imediato
                              setState(() {
                                if (_favVideoIds.contains(key)) {
                                  _favVideoIds.remove(key);
                                } else {
                                  _favVideoIds.add(key);
                                }
                              });
                              await AppDb.toggleFavVideo(
                                videoUrl: url,
                                title: title,
                                channel: channel,
                                thumb: thumb,
                              );
                              if (!mounted) return;
                              await _loadFavVideos();
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
                            _loadFavVideos();
                          },
                        ),
                      );
                    },
                  );
                },
                childCount: _videos.length + (_loadingMore ? 1 : 0),
              ),
            ),
        ] else ...[
          // -----------------------
          // FEED (sem busca ativa)
          // -----------------------
          if (_loadingFeed)
            _sliverBox(
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(),
              ),
            ),

          if (!_loadingFeed && _feedError != null)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _sliverBox(Text(_feedError!)),
            ),

          if (!_loadingFeed && _feedError == null && _feedVisible.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: _sliverBox(const Text('Últimos vídeos dos favoritos', style: TextStyle(fontWeight: FontWeight.w700))),
            ),

          if (!_loadingFeed && _feedError == null && _feedVisible.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i >= _feedVisible.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final v = _feedVisible[i];
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
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: _thumb(context, thumb, w: 96, h: 54, fallback: Icons.play_circle_outline),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (read) const Icon(Icons.done_all),
                              IconButton(
                                icon: Icon(
                                  _isFavVideo(url) ? Icons.star : Icons.star_border,
                                  color: _isFavVideo(url) ? Colors.amber : null,
                                ),
                                tooltip: _isFavVideo(url) ? 'Remover favorito' : 'Favoritar',
                                onPressed: () async {
                              final vid = _videoIdFromUrl(url);
                              final key = vid.isEmpty ? url : vid;
                              setState(() {
                                if (_favVideoIds.contains(key)) {
                                  _favVideoIds.remove(key);
                                } else {
                                  _favVideoIds.add(key);
                                }
                              });
                              await AppDb.toggleFavVideo(
                                videoUrl: url,
                                title: title,
                                channel: channel,
                                thumb: thumb,
                              );
                              if (!mounted) return;
                              await _loadFavVideos();
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
                            _loadFavVideos();
                          },
                        ),
                      );
                    },
                  );
                },
                childCount: _feedVisible.length + (_feedHasMore ? 1 : 0),
              ),
            ),

          if (!_loadingFeed && _feedError == null && _feedVisible.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _sliverBox(const Text('Nenhum vídeo para exibir.')),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
      ),
    );
  }
}


class _FeedChannelState {
  final String channelUrl;
  final String channelTitle;

  bool initialLoaded = false;
  bool exhausted = false;
  bool loading = false;

  String? continuation;
  YouTubeInnerTubeConfig? cfg;

  final List<Map<String, dynamic>> buffer = [];

  _FeedChannelState({
    required this.channelUrl,
    required this.channelTitle,
  });
}