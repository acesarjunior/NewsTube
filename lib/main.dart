import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/app_state.dart';
import 'pages/home_page.dart';
import 'services/app_strings.dart';
import 'services/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (context) {
              final s = AppStrings.of(context);
              return Text(
                '${s.t('render_error')}\n\n${details.exception}',
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    ThemeMode initialMode = ThemeMode.dark;
    String initialLanguage = 'en';

    try {
      initialMode = await AppPrefs.loadThemeMode();
    } catch (_) {
      initialMode = ThemeMode.dark;
    }

    try {
      initialLanguage = await AppPrefs.loadAppLanguage(fallback: 'en');
    } catch (_) {
      initialLanguage = 'en';
    }

    final controller = AppController(
      themeMode: initialMode,
      locale: Locale(initialLanguage),
    );

    runApp(NewsTubeApp(controller: controller));
  }, (error, stack) {
    runApp(_FatalApp(error: error));
  });
}

class _FatalApp extends StatelessWidget {
  final Object error;
  const _FatalApp({required this.error});

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings('en');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('NewsTube')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${strings.t('fatal_start_error')}\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class NewsTubeApp extends StatelessWidget {
  final AppController controller;
  const NewsTubeApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppControllerScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'NewsTube',
            debugShowCheckedModeBanner: false,
            locale: controller.locale,
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: controller.themeMode,
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
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
