import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../models/forecast.dart';
import '../../providers/goes_provider.dart';
import '../../providers/location_provider.dart';

/// Layer 3 GOES Nighttime Microphysics RGB satellite loop.
///
/// Auto-animates recent GOES frames at ~1.4 fps. Tap to pause/play,
/// swipe to jump ±1 frame.
class GoesMapView extends ConsumerStatefulWidget {
  final List<HourlyForecast> hours;

  const GoesMapView({super.key, required this.hours});

  @override
  ConsumerState<GoesMapView> createState() => _GoesMapViewState();
}

class _GoesMapViewState extends ConsumerState<GoesMapView> {
  final Map<int, ui.Image> _imageCache = {};
  ui.Image? _currentImage;
  bool _isLoading = true;
  String? _error;

  // Frame timestamps from discovery API
  List<int> _timestamps = [];
  String _satellite = 'goes-19';

  // Animation state
  static const int _maxFrames = 30; // ~2.5h of 5-min data
  static const List<Duration> _speeds = [
    Duration(milliseconds: 1500),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 700),
    Duration(milliseconds: 400),
    Duration(milliseconds: 200),
  ];
  static const List<String> _speedLabels = [
    '0.5x',
    '0.7x',
    '1x',
    '1.8x',
    '3.5x',
  ];
  int _speedIndex = 2;
  Duration get _frameInterval => _speeds[_speedIndex];
  Timer? _animTimer;
  bool _isPlaying = false;
  int _currentFrameIndex = 0;
  bool _prefetchDone = false;

  @override
  void initState() {
    super.initState();
    _initSatellite();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    for (final img in _imageCache.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _initSatellite() {
    final location = ref.read(activeLocationProvider);
    if (location != null) {
      _satellite = GoesConfig.satelliteForLongitude(location.longitude);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTimestamps();
    });
  }

  /// Fetch the latest available timestamps from the SLIDER discovery API.
  Future<void> _fetchTimestamps() async {
    final url = GoesConfig.buildLatestTimesUrl(_satellite);
    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rawTimestamps = json['timestamps_int'] as List<dynamic>;
        // Most recent first — take last N frames, then reverse to chronological
        final frames = rawTimestamps
            .take(_maxFrames)
            .map((e) => e as int)
            .toList()
            .reversed
            .toList();

        if (frames.isEmpty) {
          setState(() {
            _isLoading = false;
            _error = 'No satellite frames available';
          });
          return;
        }

        setState(() {
          _timestamps = frames;
          _currentFrameIndex = 0;
        });

        ref.read(goesFrameIndexProvider.notifier).state = 0;
        await _loadImage(0);
        _prefetchAll();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Satellite data unavailable (${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load satellite imagery';
        });
      }
    }
  }

  /// Prefetch all frames starting from current position outward.
  Future<void> _prefetchAll() async {
    if (_timestamps.isEmpty) return;

    final startIdx = _currentFrameIndex.clamp(0, _timestamps.length - 1);
    final ordered = <int>[
      ...List.generate(
          _timestamps.length - startIdx, (i) => startIdx + i),
      ...List.generate(startIdx, (i) => i),
    ];

    for (final idx in ordered) {
      if (!mounted) return;
      if (_imageCache.containsKey(idx)) continue;
      await _fetchImage(idx);

      // Auto-start playback once enough frames are cached
      if (_imageCache.length >= 3 && !_isPlaying && mounted) {
        _startPlaying();
      }
    }

    if (mounted) {
      setState(() => _prefetchDone = true);
    }
  }

  Future<void> _fetchImage(int frameIndex) async {
    if (frameIndex < 0 || frameIndex >= _timestamps.length) return;
    final ts = _timestamps[frameIndex];
    final url = GoesConfig.buildTileUrl(_satellite, ts);

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          _imageCache[frameIndex] = frame.image;
        }
      }
    } catch (_) {
      // Skip failed frames silently
    }
  }

  Future<void> _loadImage(int frameIndex) async {
    if (_imageCache.containsKey(frameIndex)) {
      setState(() {
        _currentImage = _imageCache[frameIndex];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _fetchImage(frameIndex);

    if (mounted) {
      if (_imageCache.containsKey(frameIndex)) {
        setState(() {
          _currentImage = _imageCache[frameIndex];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Frame unavailable';
        });
      }
    }
  }

  void _startPlaying() {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    _animTimer = Timer.periodic(_frameInterval, (_) => _advanceFrame());
  }

  void _stopPlaying() {
    _animTimer?.cancel();
    _animTimer = null;
    setState(() => _isPlaying = false);
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlaying();
    } else {
      _startPlaying();
    }
  }

  void _advanceFrame() {
    if (_timestamps.isEmpty) return;
    final nextIdx = (_currentFrameIndex + 1) % _timestamps.length;

    // Find next cached frame, wrapping around
    for (int i = 0; i < _timestamps.length; i++) {
      final tryIdx = (nextIdx + i) % _timestamps.length;
      if (_imageCache.containsKey(tryIdx)) {
        _setFrame(tryIdx);
        return;
      }
    }
  }

  void _setFrame(int frameIndex) {
    setState(() {
      _currentFrameIndex = frameIndex;
      _currentImage = _imageCache[frameIndex];
    });
    ref.read(goesFrameIndexProvider.notifier).state = frameIndex;
  }

  void _onSpeedChanged(double value) {
    final newIndex = value.round();
    if (newIndex == _speedIndex) return;
    setState(() => _speedIndex = newIndex);
    if (_isPlaying) {
      _animTimer?.cancel();
      _animTimer = Timer.periodic(_frameInterval, (_) => _advanceFrame());
    }
  }

  void _jumpFrame(int delta) {
    if (_timestamps.isEmpty) return;
    _stopPlaying();
    final nextIdx =
        (_currentFrameIndex + delta).clamp(0, _timestamps.length - 1);

    if (_imageCache.containsKey(nextIdx)) {
      _setFrame(nextIdx);
    } else {
      _setFrame(nextIdx);
      _loadImage(nextIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayback,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < AtmosphereConstants.cmcSwipeVelocityThreshold) {
          return;
        }
        _jumpFrame(velocity < 0 ? 1 : -1);
      },
      child: Container(
        color: const Color(0xFF0A0A1A),
        child: Column(
          children: [
            Expanded(child: _buildImageArea()),
            const SizedBox(height: 8),
            _buildTimeline(),
            const SizedBox(height: 4),
            _buildSpeedSlider(),
            const SizedBox(height: 4),
            _buildHourLabel(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    if (_isLoading && _currentImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF4FC3F7),
              strokeWidth: 2,
            ),
            const SizedBox(height: 12),
            Text(
              'Loading satellite imagery\u2026',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null && _currentImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt,
                color: Colors.white.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_currentImage == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _GoesImagePainter(image: _currentImage!),
            );
          },
        ),
        // Pause indicator
        if (!_isPlaying && _currentImage != null)
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.pause,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeline() {
    if (_timestamps.isEmpty) return const SizedBox.shrink();

    final progress = _timestamps.length <= 1
        ? 0.0
        : _currentFrameIndex / (_timestamps.length - 1);
    final cachedFrames = List.generate(
      _timestamps.length,
      (i) => _imageCache.containsKey(i),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            height: 4,
            child: CustomPaint(
              size: const Size(double.infinity, 4),
              painter: _TimelinePainter(
                progress: progress,
                cachedFrames: cachedFrames,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_timestamps.isNotEmpty)
                Text(
                  GoesConfig.formatTimestamp(_timestamps.first),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                ),
              if (!_prefetchDone)
                Text(
                  '${_imageCache.length}/${_timestamps.length} frames',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                ),
              if (_timestamps.isNotEmpty)
                Text(
                  GoesConfig.formatTimestamp(_timestamps.last),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            color: Colors.white.withValues(alpha: 0.4),
            size: 16,
          ),
          Expanded(
            child: CupertinoSlider(
              value: _speedIndex.toDouble(),
              min: 0,
              max: (_speeds.length - 1).toDouble(),
              divisions: _speeds.length - 1,
              activeColor: const Color(0xFF4FC3F7),
              onChanged: _onSpeedChanged,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              _speedLabels[_speedIndex],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourLabel() {
    String timeStr = '';
    if (_timestamps.isNotEmpty &&
        _currentFrameIndex < _timestamps.length) {
      timeStr = GoesConfig.formatTimestamp(_timestamps[_currentFrameIndex]);
    }

    final satLabel = GoesConfig.satelliteLabel(_satellite);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPlaying ? Icons.play_arrow : Icons.pause,
            color: Colors.white.withValues(alpha: 0.4),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Satellite \u00b7 $timeStr \u00b7 $satLabel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the GOES satellite image scaled to fill available space.
class _GoesImagePainter extends CustomPainter {
  final ui.Image image;

  _GoesImagePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scaleX = size.width / imgW;
    final scaleY = size.height / imgH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final destW = imgW * scale;
    final destH = imgH * scale;
    final dx = (size.width - destW) / 2;
    final dy = (size.height - destH) / 2;

    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final dst = Rect.fromLTWH(dx, dy, destW, destH);

    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_GoesImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}

/// Timeline progress bar with cached-frame indicators.
class _TimelinePainter extends CustomPainter {
  final double progress;
  final List<bool> cachedFrames;

  _TimelinePainter({required this.progress, required this.cachedFrames});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(2),
      ),
      bgPaint,
    );

    // Cached frame dots
    if (cachedFrames.isNotEmpty) {
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15);
      for (int i = 0; i < cachedFrames.length; i++) {
        if (!cachedFrames[i]) continue;
        final x = cachedFrames.length <= 1
            ? size.width / 2
            : (i / (cachedFrames.length - 1)) * size.width;
        canvas.drawCircle(Offset(x, size.height / 2), 1.5, dotPaint);
      }
    }

    // Progress indicator
    final progressPaint = Paint()..color = const Color(0xFF4FC3F7);
    final px = progress * size.width;
    canvas.drawCircle(Offset(px, size.height / 2), 3, progressPaint);
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cachedFrames != cachedFrames;
  }
}
