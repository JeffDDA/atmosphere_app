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

  // Classic Mode — chicklet grid
  static const double classicChickletWidth = 17.0;
  static const double classicChickletHeight = 17.0;
  static const double classicChickletGap = 1.0;
  static const double classicChickletRadius = 2.0; // liquid glass corners
  static const double classicRowLabelWidth = 100.0;
  static const double classicTimeAxisHeight = 48.0;
  static const double classicGroupLabelWidth = 14.0; // vertical Sky/Ground labels
  static const double classicGroupGap = 8.0; // sky/ground divider gap
  static const int classicSkyRowCount = 5; // rows above the gap
  static const int classicGroundRowCount = 4; // rows below the gap
  static const double classicVisibleHours = 8.0; // default visible window

  // Classic Mode — minimap
  static const double classicMinimapHeight = 92.0;
  static const double classicMinimapRowHeight = 5.0;
  static const double classicMinimapGroupGap = 3.0;
  static const double classicMinimapTimeAxisHeight = 12.0;
  static const double classicMinimapLabelWidth = 0.0; // no labels on minimap
  static const double classicSelectionBoxMinWidth = 30.0;

  // LP Globe (cylinder)
  static const double globeDefaultZoom = 4.5;
  static const double globeMinZoom = 2.0;
  static const double globeMaxZoom = 8.0;
  static const double globeRotationSensitivity = 0.006;
  static const double globeSpinDurationMs = 800;
  static const double globeZoomStep = 0.8; // multiplier per tap
  static const double globeFov = 50.0; // degrees — must match shader

  // LP Map (full-screen)
  static const double lpMapMinZoom = 1.2;
  static const double lpMapMaxZoom = 8.0;
}
