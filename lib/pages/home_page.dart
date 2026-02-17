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

  // Mantemos as keys, mas evitamos await em nullable Future (pode causar crash em algumas configs)
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
    try {
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

            // ✅ Recarregos sempre após o frame, sem await, e com mounted-check
            if (i == 1) {
              _postFrame(() {
                _favKey.currentState?.reload();
              });
            } else {
              _postFrame(() {
                _searchKey.currentState?.reloadFavSection();
              });
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
            NavigationDestination(icon: Icon(Icons.star), label: 'Favoritos'),
          ],
        ),
      );
    } catch (e) {
      // Fallback seguro: evita “abre e fecha” em release quando algo explode no build.
      return Scaffold(
        appBar: AppBar(title: const Text('NewsTube')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Ocorreu um erro ao carregar a tela inicial.\n\n'
              'Tente fechar e abrir novamente.\n\n'
              'Detalhe: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }
}
