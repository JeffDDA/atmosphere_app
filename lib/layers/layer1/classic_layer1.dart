import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/ddac_theme.dart';
import '../../models/layer_id.dart';
import '../../providers/location_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/classic/classic_grid.dart';
import '../../widgets/classic/classic_minimap.dart';
import '../../widgets/lp_globe/lp_globe_widget.dart';

class ClassicLayer1 extends ConsumerWidget {
  const ClassicLayer1({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(activeLocationProvider);
    final locationName = location?.name ?? 'Unknown';

    return Container(
      color: DDACTheme.chartBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — absorbs taps so they don't descend to Layer 2
          GestureDetector(
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.of(context).viewPadding.top + 8, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ref
                        .read(navigationProvider.notifier)
                        .goToLayer(LayerId.home),
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
          ),
          // Minimap
          const ClassicMinimap(),
          // Divider
          Container(
            height: 1,
            color: DDACTheme.divider,
          ),
          // Grid
          const Expanded(
            flex: 2,
            child: ClassicGrid(),
          ),
          // LP Cylinder
          const Expanded(
            flex: 3,
            child: LPGlobeWidget(),
          ),
        ],
      ),
    );
  }
}
