import 'package:flutter/material.dart';
import 'prefs.dart';

class AppController extends ChangeNotifier {
  ThemeMode _themeMode;
  String _languageCode;

  AppController({required ThemeMode initialThemeMode, required String initialLanguageCode})
      : _themeMode = initialThemeMode,
        _languageCode = initialLanguageCode;

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await AppPrefs.saveThemeMode(mode);
  }

  Future<void> toggleTheme() async {
    await setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLanguageCode(String code) async {
    final v = code.trim().isEmpty ? 'en' : code.trim();
    if (_languageCode == v) return;
    _languageCode = v;
    notifyListeners();
    await AppPrefs.saveAppLanguage(v);
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required Widget child})
      : super(notifier: controller, child: child);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree.');
    return scope!.notifier!;
  }
}
