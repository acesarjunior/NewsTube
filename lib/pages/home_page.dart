import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../widgets/app_shell_actions.dart';
import 'favorites_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
    final s = AppStrings.of(context);

    final pages = <Widget>[
      SearchPage(key: _searchKey),
      FavoritesPage(key: _favKey),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('app_title')),
        actions: const [AppShellActions()],
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
        destinations: [
          NavigationDestination(icon: const Icon(Icons.search), label: s.t('search')),
          NavigationDestination(icon: const Icon(Icons.star), label: s.t('favorites')),
        ],
      ),
    );
  }
}
