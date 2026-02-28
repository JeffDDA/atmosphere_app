import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/atmosphere_theme.dart';
import 'providers/onboarding_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/cutscene_screen.dart';
import 'screens/home_screen.dart';

class AtmosphereApp extends ConsumerWidget {
  const AtmosphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = ref.watch(settingsProvider);
    final onboarding = ref.watch(onboardingProvider);

    return MaterialApp(
      title: 'Atmosphere',
      debugShowCheckedModeBanner: false,
      theme: displayMode == DisplayMode.dark
          ? AtmosphereTheme.dark
          : AtmosphereTheme.light,
      home: onboarding.when(
        data: (hasSeenCutscene) =>
            hasSeenCutscene ? const HomeScreen() : const CutsceneScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const HomeScreen(),
      ),
    );
  }
}
