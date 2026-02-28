import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_provider.dart';
import 'home_screen.dart';

class CutsceneScreen extends ConsumerWidget {
  const CutsceneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Text(
                'Origin Cut Scene',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 32),
              // Integration point: VideoPlayerController initialization
              // will go here when the video asset is ready.
              IconButton(
                onPressed: () {
                  // Placeholder for video playback
                },
                icon: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white54,
                  size: 80,
                ),
              ),
              const Spacer(flex: 2),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(onboardingProvider.notifier)
                      .markCutsceneSeen();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
