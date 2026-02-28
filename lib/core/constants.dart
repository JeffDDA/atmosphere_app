class AtmosphereConstants {
  AtmosphereConstants._();

  // Claritas transition
  static const Duration transitionDuration = Duration(milliseconds: 600);
  static const double transitionThreshold = 0.50;
  static const double balloonOvershoot = 0.04;
  static const Duration doubleTapWindow = Duration(milliseconds: 400);

  // Pinch mapping
  static const double pinchMaxScale = 2.0;
  static const double pinchMinScale = 0.5;

  // Eyepiece
  static const Duration eyepieceHoldDelay = Duration(milliseconds: 200);
  static const double eyepieceScaleDeltaThreshold = 0.01;

  // Depth indicator
  static const Duration depthIndicatorAutoHide = Duration(seconds: 3);

  // Sizes
  static const double cardBorderRadius = 24.0;
  static const double gradientBarHeight = 48.0;
  static const double gradientAnchorHeight = 32.0;
}
