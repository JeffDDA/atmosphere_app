import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kHasSeenCutscene = 'has_seen_cutscene';

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // TODO: restore preference check after testing
    // final prefs = await SharedPreferences.getInstance();
    // return prefs.getBool(_kHasSeenCutscene) ?? false;
    return false; // Always show cutscene during testing
  }

  Future<void> markCutsceneSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSeenCutscene, true);
    state = const AsyncData(true);
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
