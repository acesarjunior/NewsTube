import 'package:flutter/material.dart';
import 'search_page.dart';
import 'favorites_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  const HomePage({super.key, this.onToggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _idx = 0;

  final _favKey = GlobalKey<FavoritesPageState>();
  final _searchKey = GlobalKey<SearchPageState>();

  void _postFrame(void Function() fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      SearchPage(key: _searchKey),
      FavoritesPage(key: _favKey),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('NewsTube'),
        actions: [
          if (widget.onToggleTheme != null)
            IconButton(
              tooltip: 'Alternar tema',
              icon: const Icon(Icons.dark_mode_outlined),
              onPressed: widget.onToggleTheme,
            ),
        ],
      ),
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) {
          setState(() => _idx = i);

          if (i == 1) {
            _postFrame(() => _favKey.currentState?.reload());
          } else {
            _postFrame(() {
              _searchKey.currentState?.reloadFavSection();
              _searchKey.currentState?.scrollToTop();
            });
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Favoritos'),
        ],
      ),
    );
  }
}
