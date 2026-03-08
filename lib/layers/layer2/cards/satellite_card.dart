import 'package:flutter/material.dart';

import '../../../providers/goes_provider.dart';
import 'base_card.dart';

class SatelliteCard extends StatelessWidget {
  final double longitude;

  const SatelliteCard({
    super.key,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final satellite = GoesConfig.satelliteForLongitude(longitude);
    final label = GoesConfig.satelliteLabel(satellite);

    return BaseCard(
      parameterName: 'Satellite',
      verdict: label,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.satellite_alt,
              color: Colors.white.withValues(alpha: 0.3),
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'Nighttime RGB',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      context: 'Live cloud imagery \u00b7 5-min updates',
    );
  }
}
