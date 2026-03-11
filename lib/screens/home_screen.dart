import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/atmosphere_colors.dart';
import '../core/theme/atmosphere_theme.dart';
import '../layers/claritas_shell.dart';
import '../models/condition_state.dart';
import '../models/layer_id.dart';
import '../providers/forecast_provider.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/liquid_glass.dart';
import 'add_location_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);

    // When not at home, show the Claritas shell
    if (navState.currentLayer != LayerId.home) {
      return const ClaritasShell();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Atmosphere',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: const SafeArea(
        child: _LocationGrid(),
      ),
    );
  }
}

class _LocationGrid extends ConsumerWidget {
  const _LocationGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Your observing locations',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: locationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (locations) => _buildGrid(context, ref, locations),
            ),
          ),
          // DDA brand footer
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: TextButton.icon(
                onPressed: () {},
                icon: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AtmosphereTheme.dragonBurgundy,
                ),
                label: Text(
                  'Dark Dragons Astro',
                  style: TextStyle(
                    color: AtmosphereTheme.dragonBurgundy,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> locations,
  ) {
    // +1 for the "Add" card
    final itemCount = locations.length + 1;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Last item = "Add Location" card
        if (index == locations.length) {
          return _AddLocationCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AddLocationScreen(),
              ),
            ),
          );
        }

        final location = locations[index];
        final tonightAsync = ref.watch(
          locationTonightProvider((location.latitude, location.longitude)),
        );
        final tonight = tonightAsync.valueOrNull;
        final tonightCondition =
            tonight?.overallCondition ?? ConditionState.good;
        final conditionColor =
            AtmosphereColors.forCondition(tonightCondition);
        final headline =
            tonight?.headline ?? 'Loading forecast\u2026';

        return GestureDetector(
          onTap: () {
            ref
                .read(activeLocationIndexProvider.notifier)
                .select(index);
            ref
                .read(navigationProvider.notifier)
                .goToLayer(LayerId.layer1);
          },
          onLongPress: () => _showLocationActions(
            context,
            ref,
            location,
            index,
            locations.length,
          ),
          child: LiquidGlass(
            accentColor: AtmosphereColors.forBortle(location.bortleClass),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location name
                Text(
                  location.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                // Condition accent dot + headline
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: conditionColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Bortle class + SQM
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bortle ${location.bortleClass}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'SQM ${location.sqmValue.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLocationActions(
    BuildContext context,
    WidgetRef ref,
    dynamic location,
    int index,
    int totalLocations,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(location.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddLocationScreen(
                    editIndex: index,
                    existingLocation: location,
                  ),
                ),
              );
            },
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDelete(context, ref, location.name, index, totalLocations);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String name,
    int index,
    int totalLocations,
  ) {
    if (totalLocations <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot delete your last location')),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Location'),
        content: Text('Remove "$name" from your locations?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              await ref
                  .read(locationProvider.notifier)
                  .deleteLocation(index);
              // Clamp active index
              ref
                  .read(activeLocationIndexProvider.notifier)
                  .clampTo(totalLocations - 2);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddLocationCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddLocationCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        tintOpacity: 0.04,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_location_alt_outlined,
                size: 36,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Location',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
