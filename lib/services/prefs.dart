import 'package:flutter/material.dart';
import '../data/db.dart';

class AppPrefs {
  static const _kThemeMode = 'theme_mode'; // 'light' | 'dark' | 'system'
  static const _kTranslateTarget = 'translate_target_lang';
  static const _kTranslateRemind = 'translate_remind_enabled';

  static Future<ThemeMode> loadThemeMode() async {
    final v = (await AppDb.getPrefString(_kThemeMode) ?? 'dark').toLowerCase().trim();
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await AppDb.setPrefString(_kThemeMode, v);
  }

  static Future<String> loadTranslateTargetLang({String fallback = 'en'}) async {
    final v = await AppDb.getPrefString(_kTranslateTarget);
    return (v ?? fallback).trim();
  }


  static Future<String?> loadTranslateTargetLangNullable() async {
    final v = await AppDb.getPrefString(_kTranslateTarget);
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static Future<void> saveTranslateTargetLang(String lang) async {
    await AppDb.setPrefString(_kTranslateTarget, lang.trim());
  }

  static Future<bool> loadTranslateReminderEnabled() async {
    final v = await AppDb.getPrefBool(_kTranslateRemind);
    return v ?? true;
  }

  static Future<void> setTranslateReminderEnabled(bool enabled) async {
    await AppDb.setPrefBool(_kTranslateRemind, enabled);
  }
}
