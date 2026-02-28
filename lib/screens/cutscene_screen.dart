import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/onboarding_provider.dart';
import 'home_screen.dart';

class CutsceneScreen extends ConsumerStatefulWidget {
  const CutsceneScreen({super.key});

  @override
  ConsumerState<CutsceneScreen> createState() => _CutsceneScreenState();
}

class _CutsceneScreenState extends ConsumerState<CutsceneScreen> {
  late final VideoPlayerController _controller;
  bool _transitioning = false;

  @override
  void initState() {
    super.initState();
    // Hide status bar for immersive video
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.asset('docs/atmosphere.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });

    _controller.addListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (_transitioning) return;
    final value = _controller.value;
    if (value.isInitialized &&
        value.position >= value.duration &&
        value.duration > Duration.zero) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_transitioning) return;
    _transitioning = true;

    await ref.read(onboardingProvider.notifier).markCutsceneSeen();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            if (_controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),

            // Subtle "Skip" label — top right
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
