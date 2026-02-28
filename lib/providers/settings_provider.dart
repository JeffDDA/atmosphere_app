import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DisplayMode { dark, light }

class SettingsNotifier extends Notifier<DisplayMode> {
  @override
  DisplayMode build() => DisplayMode.dark;

  void toggle() {
    state = state == DisplayMode.dark ? DisplayMode.light : DisplayMode.dark;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, DisplayMode>(
  SettingsNotifier.new,
);
