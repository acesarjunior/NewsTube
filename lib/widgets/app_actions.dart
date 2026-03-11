import 'package:flutter/material.dart';
import '../services/app_controller.dart';
import '../services/app_strings.dart';

class AppActions extends StatelessWidget {
  final List<Widget> extraActions;
  const AppActions({super.key, this.extraActions = const []});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...extraActions,
        PopupMenuButton<String>(
          tooltip: s.get('theme'),
          icon: const Icon(Icons.palette_outlined),
          onSelected: (v) {
            if (v == 'light') controller.setThemeMode(ThemeMode.light);
            if (v == 'dark') controller.setThemeMode(ThemeMode.dark);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'light', child: Text(s.get('light'))),
            PopupMenuItem(value: 'dark', child: Text(s.get('dark'))),
          ],
        ),
        PopupMenuButton<String>(
          tooltip: s.get('language'),
          icon: const Icon(Icons.language),
          onSelected: controller.setLanguageCode,
          itemBuilder: (_) => AppStrings.supportedLanguages
              .map((e) => PopupMenuItem<String>(
                    value: e['code']!,
                    child: Text(e['label']!),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
