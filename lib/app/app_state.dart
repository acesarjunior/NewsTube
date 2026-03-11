import 'package:flutter/material.dart';

class AppController extends ChangeNotifier {
  ThemeMode _themeMode;
  Locale _locale;

  AppController({required ThemeMode themeMode, required Locale locale})
      : _themeMode = themeMode,
        _locale = locale;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
  }
}

class AppControllerScope extends InheritedNotifier<AppController> {
  const AppControllerScope({
    super.key,
    required AppController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppControllerScope>();
    assert(scope != null, 'AppControllerScope não encontrado na árvore.');
    return scope!.notifier!;
  }
}
