# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Atmosphere is an astronomy weather forecast app for astrophotographers. Flutter/Dart, iOS-first, dark theme. Currently uses mock data with no backend — provider structure is ready for real API integration.

**Dart SDK**: ^3.10.0 | **State management**: flutter_riverpod ^2.6.1

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis (uses flutter_lints)
flutter test             # run all tests
flutter test test/widget_test.dart  # run a single test file
dart format lib/ test/   # format code
flutter run              # run on connected device/simulator
flutter build ipa        # release build (iOS)
```

## Architecture — Claritas Paradigm

The app uses a four-layer zoom navigation model. Users descend layers via tap (or pinch-out), ascend via double-tap (or pinch-in). All transitions route through `ClaritasShell` → `ClaritasTransitionController`.

| Layer | View | Content |
|-------|------|---------|
| Home | `home_screen.dart` | Location grid selector |
| 1 | `layer1_card.dart` | Tonight's glance card — headline + gradient |
| 2 | `layer2_view.dart` | Relevance-ordered card stack + 72-hour scrub timeline |
| 3 | `layer3_view.dart` | Deep detail (currently only SeeingColumnCard) |
| 4 | stub | Placeholder |

### Gesture system

`ClaritasShell` (in `lib/layers/`) handles all navigation gestures using raw `Listener` pointer events — not GestureDetector. Pinch uses absolute point-distance tracking (not scale ratios). Tuning constants are in `lib/core/constants.dart` (`AtmosphereConstants`).

### 72-hour scrub timeline

`ScrubState.position` is a single 0.0–1.0 float spanning all 3 nights (~30 hours). `GradientAnchor` shows the active night's gradient with pill indicators for night switching. All Layer 2 cards receive `allHours` + `nightBoundaryIndices` for drawing night-separator lines.

### Key providers (`lib/providers/`)

- `forecastProvider` → `List<NightForecast>` (3 nights for active location)
- `tonightForecastProvider` → first night only (Layer 1)
- `allHoursProvider` → flat list of all hours across 3 nights
- `nightBoundariesProvider` / `activeNightProvider` → night segmentation derived from scrub position
- `scrubProvider` → `ScrubState` (position + isScrubbing)
- `navigationProvider` → layer stack, transition progress, eyepiece state
- `activeLocationProvider` → current location (derived from `locationProvider` + `activeLocationIndexProvider`)
- `layer3EntryDomainProvider` → which card domain triggered Layer 3 descent

### Card system (`lib/layers/layer2/cards/`)

- `BaseCard` — standard layout: header (name + verdict), body (160px chart area), context line. Has scrub drag handling.
- `ChartCard` — extends BaseCard with generic area/line chart, scrub indicator, gust markers, segment colors, night boundary lines.
- Custom painter cards (DewPointCard, ImagingWindowCard, MoonCard, AuroraCard) use CustomPainter for specialized visualizations.
- Card relevance ordering is in `Layer2View._buildRelevanceStack()`. Some cards are conditional (aurora, dew point, smoke) via static `shouldShow()` methods.

### Adding a new Layer 2 card

1. Create `lib/layers/layer2/cards/my_card.dart` extending `BaseCard` or `ChartCard`.
2. Accept `List<HourlyForecast> hours` and `List<int> nightBoundaryIndices`.
3. Register in `Layer2View._buildRelevanceStack()`, wrapped with `_domainCard("my_domain", card, ref)` if it should allow Layer 3 descent.

## Mock data

Two locations in `lib/data/`: Pietown, NM (exceptional) and Charlotte, NC (marginal). 3 nights x 10 hours each, starting at 7pm local.

## Known state

- Cutscene onboarding in `onboarding_provider.dart` is **bypassed for testing** — `build()` always returns `false`. Restore by uncommenting the SharedPreferences check.
- Video asset: `docs/atmosphere.mp4` (registered in pubspec.yaml).
