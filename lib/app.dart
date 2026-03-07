import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/atmosphere_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

class AtmosphereApp extends ConsumerWidget {
  const AtmosphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Atmosphere',
      debugShowCheckedModeBanner: false,
      theme: displayMode == DisplayMode.dark
          ? AtmosphereTheme.dark
          : AtmosphereTheme.light,
      home: const HomeScreen(),
    );
  }
}
