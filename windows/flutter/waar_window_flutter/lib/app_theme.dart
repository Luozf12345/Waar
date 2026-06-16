import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kThemeTonePrefKey = 'app_theme_tone';

enum AppThemeTone { blue, pink, green, purple }

extension AppThemeToneExt on AppThemeTone {
  String get label {
    switch (this) {
      case AppThemeTone.blue:
        return '蓝色';
      case AppThemeTone.pink:
        return '粉色';
      case AppThemeTone.green:
        return '绿色';
      case AppThemeTone.purple:
        return '紫色';
    }
  }

  Color get seedColor {
    switch (this) {
      case AppThemeTone.blue:
        return Colors.blue;
      case AppThemeTone.pink:
        return const Color(0xFFFF8FAB);
      case AppThemeTone.green:
        return Colors.green;
      case AppThemeTone.purple:
        return Colors.deepPurple;
    }
  }

  static AppThemeTone fromName(String? name) {
    for (final t in AppThemeTone.values) {
      if (t.name == name) return t;
    }
    return AppThemeTone.blue;
  }
}

ThemeData buildAppTheme(AppThemeTone tone) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: tone.seedColor,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
}

Future<AppThemeTone> loadThemeTone() async {
  final prefs = await SharedPreferences.getInstance();
  return AppThemeToneExt.fromName(prefs.getString(kThemeTonePrefKey));
}

Future<void> saveThemeTone(AppThemeTone tone) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kThemeTonePrefKey, tone.name);
}
