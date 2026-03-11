import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../services/app_strings.dart';
import '../services/prefs.dart';

class AppShellActions extends StatelessWidget {
  const AppShellActions({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final s = AppStrings.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          tooltip: s.t('language'),
          icon: const Icon(Icons.public),
          onSelected: (value) async {
            controller.setLocale(Locale(value));
            await AppPrefs.saveAppLanguage(value);
          },
          itemBuilder: (context) => [
            for (final code in AppStrings.supportedLanguageCodes)
              PopupMenuItem<String>(
                value: code,
                child: Row(
                  children: [
                    Expanded(child: Text(AppStrings.languageLabels[code] ?? code)),
                    if (controller.locale.languageCode == code) const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
          ],
        ),
        PopupMenuButton<ThemeMode>(
          tooltip: s.t('theme'),
          icon: const Icon(Icons.brightness_6_outlined),
          onSelected: (value) async {
            controller.setThemeMode(value);
            await AppPrefs.saveThemeMode(value);
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: ThemeMode.light, child: Text(s.t('theme_light'))),
            PopupMenuItem(value: ThemeMode.dark, child: Text(s.t('theme_dark'))),
            PopupMenuItem(value: ThemeMode.system, child: Text(s.t('theme_system'))),
          ],
        ),
      ],
    );
  }
}
