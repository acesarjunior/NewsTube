import 'dart:async';
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Evita “abre e fecha” em release: captura erros não tratados e mantém o app vivo.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Erro ao renderizar a interface.\n\n'
            '${details.exception}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    ThemeMode initialMode = ThemeMode.dark;
    try {
      initialMode = await AppPrefs.loadThemeMode();
    } catch (_) {
      // fallback silencioso
      initialMode = ThemeMode.dark;
    }

    runApp(NewsTubeApp(initialThemeMode: initialMode));
  }, (error, stack) {
    // Se algo escapar, ainda assim não derruba silenciosamente
    runApp(_FatalApp(error: error));
  });
}

class _FatalApp extends StatelessWidget {
  final Object error;
  const _FatalApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('NewsTube')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Falha crítica ao iniciar o aplicativo.\n\n'
              'Detalhe: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class NewsTubeApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const NewsTubeApp({super.key, required this.initialThemeMode});

  @override
  State<NewsTubeApp> createState() => _NewsTubeAppState();
}

class _NewsTubeAppState extends State<NewsTubeApp> {
  late ThemeMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialThemeMode;
  }

  void _toggleTheme() {
    setState(() {
      _mode = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
    // persistência best-effort
    AppPrefs.saveThemeMode(_mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewsTube',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: HomePage(onToggleTheme: _toggleTheme),
    );
  }
}
