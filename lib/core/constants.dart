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

  // Now marker — visual constants
  static const double nowMarkerGlowRadiusIdle = 12.0;
  static const double nowMarkerGlowRadiusPanning = 20.0;
  static const double nowMarkerBlurSigmaIdle = 8.0;
  static const double nowMarkerBlurSigmaPanning = 14.0;
  static const double nowMarkerGlowAlphaIdle = 0.12;
  static const double nowMarkerGlowAlphaPanning = 0.25;
  static const double nowMarkerLineWidthIdle = 1.5;
  static const double nowMarkerLineWidthPanning = 2.5;
  static const double nowMarkerLineAlphaIdle = 0.5;
  static const double nowMarkerLineAlphaPanning = 0.9;
  static const double nowMarkerFadeStartPx = 160.0; // ~2 hours before fade
  static const double nowMarkerFadeEndPx = 400.0;   // ~5 hours, fully faded

  // Sizes
  static const double cardBorderRadius = 24.0;
  static const double gradientBarHeight = 48.0;
  static const double gradientAnchorHeight = 32.0;
}
