import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/ddac_theme.dart';
import '../providers/classic_canvas_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/classic/classic_grid.dart';
import '../widgets/classic/classic_minimap.dart';

class ClassicModeScreen extends ConsumerWidget {
  const ClassicModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(activeLocationProvider);
    final locationName = location?.name ?? 'Unknown';

    return Scaffold(
      backgroundColor: DDACTheme.chartBackground,
      body: SafeArea(
        child: GestureDetector(
          // Tap anywhere outside tooltip to dismiss
          onTap: () {
            ref.read(classicTooltipProvider.notifier).dismiss();
          },
          behavior: HitTestBehavior.translucent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Color(0xFFAAAAAA),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      locationName,
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Classic',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Minimap
              const ClassicMinimap(),
              // Divider
              Container(
                height: 1,
                color: DDACTheme.divider,
              ),
              // Interaction surface
              const Expanded(
                child: ClassicGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
