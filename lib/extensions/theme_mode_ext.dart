import 'package:flutter/material.dart';

extension ThemeModeExt on ThemeMode {
  IconData get icon => switch (this) {
    ThemeMode.light => Icons.light_mode,
    ThemeMode.dark => Icons.dark_mode,
    ThemeMode.system => Icons.settings_system_daydream,
  };

  String get title => switch (this) {
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
    ThemeMode.system => 'Según el sistema',
  };
}
