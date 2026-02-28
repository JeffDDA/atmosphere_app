import 'package:flutter/material.dart';

import '../../../core/constants.dart';

class BaseCard extends StatelessWidget {
  final String parameterName;
  final String verdict;
  final Widget body;
  final String? context;

  const BaseCard({
    super.key,
    required this.parameterName,
    required this.verdict,
    required this.body,
    this.context,
  });

  @override
  Widget build(BuildContext buildContext) {
    final theme = Theme.of(buildContext);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(AtmosphereConstants.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header zone
            Row(
              children: [
                Text(
                  parameterName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    verdict,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Body zone
            SizedBox(
              height: 160,
              child: body,
            ),

            // Context zone
            if (context != null) ...[
              const SizedBox(height: 16),
              Text(
                context!,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
