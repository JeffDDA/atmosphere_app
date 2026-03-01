class AtmosphereConstants {
  AtmosphereConstants._();

  // Claritas transition
  static const Duration transitionDuration = Duration(milliseconds: 600);
  static const double transitionThreshold = 0.50;
  static const double balloonOvershoot = 0.04;
  static const Duration doubleTapWindow = Duration(milliseconds: 400);

  // Pinch mapping — absolute point distances
  static const double pinchDeadZonePoints = 40.0;  // points before tracking begins
  static const double pinchCommitPoints = 220.0;   // points for 50% (commit threshold)

  // Eyepiece
  static const Duration eyepieceHoldDelay = Duration(milliseconds: 200);
  static const double eyepieceScaleDeltaThreshold = 0.01;

  // Depth indicator
  static const Duration depthIndicatorAutoHide = Duration(seconds: 3);

  // Canvas — infinite timeline
  static const double canvasPixelsPerHour = 80.0;
  static const double canvasReadingAnchorFraction = 0.33;

  // Sizes
  static const double cardBorderRadius = 24.0;
  static const double gradientBarHeight = 48.0;
  static const double gradientAnchorHeight = 32.0;
}
