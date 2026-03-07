import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidGlass extends StatelessWidget {
  final double blur;
  final double borderRadius;
  final double tintOpacity;
  final EdgeInsets padding;
  final Color? accentColor;
  final Widget child;

  const LiquidGlass({
    super.key,
    this.blur = 12.0,
    this.borderRadius = 16.0,
    this.tintOpacity = 0.08,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: accentColor?.withValues(alpha: 0.6) ??
                  Colors.white.withValues(alpha: 0.15),
              width: accentColor != null ? 1.5 : 1,
            ),
            boxShadow: [
              if (accentColor != null)
                BoxShadow(
                  color: accentColor!.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // White highlight line at top
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
