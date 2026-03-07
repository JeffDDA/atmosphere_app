import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location_picker_flutter_map/location_picker_flutter_map.dart';

import '../core/coordinate_utils.dart';
import '../models/location.dart';
import '../providers/location_provider.dart';

class AddLocationScreen extends ConsumerStatefulWidget {
  /// If non-null, we're editing an existing location at this index.
  final int? editIndex;
  final ObservatoryLocation? existingLocation;

  const AddLocationScreen({super.key, this.editIndex, this.existingLocation});

  @override
  ConsumerState<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends ConsumerState<AddLocationScreen> {
  int _tabIndex = 0; // 0=Manual, 1=Map, 2=GPS

  // Shared fields
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _elevationController = TextEditingController();
  final _sqmController = TextEditingController();
  int _bortleClass = 4;
  bool _useDms = false;

  // DMS fields
  final _latDegController = TextEditingController();
  final _latMinController = TextEditingController();
  final _latSecController = TextEditingController();
  bool _latIsNorth = true;
  final _lonDegController = TextEditingController();
  final _lonMinController = TextEditingController();
  final _lonSecController = TextEditingController();
  bool _lonIsEast = false;

  // GPS state
  bool _gpsLoading = false;
  String? _gpsError;

  bool get _isEditing => widget.editIndex != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingLocation != null) {
      _populateFrom(widget.existingLocation!);
    } else {
      _sqmController.text =
          CoordinateUtils.sqmForBortle(_bortleClass).toStringAsFixed(1);
    }
  }

  void _populateFrom(ObservatoryLocation loc) {
    _nameController.text = loc.name;
    _latController.text = CoordinateUtils.formatDecimal(loc.latitude);
    _lonController.text = CoordinateUtils.formatDecimal(loc.longitude);
    _elevationController.text =
        loc.elevationM > 0 ? loc.elevationM.round().toString() : '';
    _bortleClass = loc.bortleClass;
    _sqmController.text = loc.sqmValue.toStringAsFixed(1);
    _updateDmsFromDecimal();
  }

  void _updateDmsFromDecimal() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat != null) {
      _latIsNorth = lat >= 0;
      final abs = lat.abs();
      _latDegController.text = abs.truncate().toString();
      final minFrac = (abs - abs.truncate()) * 60;
      _latMinController.text = minFrac.truncate().toString();
      _latSecController.text = ((minFrac - minFrac.truncate()) * 60).round().toString();
    }
    if (lon != null) {
      _lonIsEast = lon >= 0;
      final abs = lon.abs();
      _lonDegController.text = abs.truncate().toString();
      final minFrac = (abs - abs.truncate()) * 60;
      _lonMinController.text = minFrac.truncate().toString();
      _lonSecController.text = ((minFrac - minFrac.truncate()) * 60).round().toString();
    }
  }

  void _updateDecimalFromDms() {
    final latDeg = int.tryParse(_latDegController.text) ?? 0;
    final latMin = int.tryParse(_latMinController.text) ?? 0;
    final latSec = int.tryParse(_latSecController.text) ?? 0;
    var lat = latDeg + latMin / 60.0 + latSec / 3600.0;
    if (!_latIsNorth) lat = -lat;
    _latController.text = CoordinateUtils.formatDecimal(lat);

    final lonDeg = int.tryParse(_lonDegController.text) ?? 0;
    final lonMin = int.tryParse(_lonMinController.text) ?? 0;
    final lonSec = int.tryParse(_lonSecController.text) ?? 0;
    var lon = lonDeg + lonMin / 60.0 + lonSec / 3600.0;
    if (!_lonIsEast) lon = -lon;
    _lonController.text = CoordinateUtils.formatDecimal(lon);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _elevationController.dispose();
    _sqmController.dispose();
    _latDegController.dispose();
    _latMinController.dispose();
    _latSecController.dispose();
    _lonDegController.dispose();
    _lonMinController.dispose();
    _lonSecController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (name.isEmpty || lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and valid coordinates are required')),
      );
      return;
    }

    final elevation = double.tryParse(_elevationController.text) ?? 0;
    final sqm = double.tryParse(_sqmController.text) ??
        CoordinateUtils.sqmForBortle(_bortleClass);

    final sourceType = _tabIndex == 1
        ? LocationSourceType.map
        : _tabIndex == 2
            ? LocationSourceType.gps
            : LocationSourceType.manual;

    final location = ObservatoryLocation(
      name: name,
      latitude: lat,
      longitude: lon,
      elevationM: elevation,
      sourceType: sourceType,
      bortleClass: _bortleClass,
      sqmValue: sqm,
    );

    bool saved;
    if (_isEditing) {
      saved = await ref
          .read(locationProvider.notifier)
          .updateLocation(widget.editIndex!, location);
    } else {
      saved = await ref.read(locationProvider.notifier).addLocation(location);
    }

    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A location with these coordinates already exists'),
          ),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _getGpsLocation() async {
    setState(() {
      _gpsLoading = true;
      _gpsError = null;
    });

    try {
      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _gpsError = 'Location permission denied';
            _gpsLoading = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsError = 'Location permission permanently denied. '
              'Enable in Settings.';
          _gpsLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      _latController.text = CoordinateUtils.formatDecimal(position.latitude);
      _lonController.text = CoordinateUtils.formatDecimal(position.longitude);
      if (position.altitude > 0) {
        _elevationController.text = position.altitude.round().toString();
      }
      _updateDmsFromDecimal();

      // Reverse geocode for name
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [p.locality, p.administrativeArea]
              .where((s) => s != null && s.isNotEmpty);
          if (parts.isNotEmpty) {
            _nameController.text = parts.join(', ');
          }
        }
      } catch (_) {
        // Reverse geocode failed — provide fallback name
      }
      if (_nameController.text.isEmpty) {
        _nameController.text = 'GPS Location';
      }
    } catch (e) {
      _gpsError = 'Could not get location: $e';
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Location' : 'Add Location'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tabIndex,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                thumbColor: Colors.white.withValues(alpha: 0.15),
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Manual', style: TextStyle(fontSize: 13)),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Map', style: TextStyle(fontSize: 13)),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('GPS', style: TextStyle(fontSize: 13)),
                  ),
                },
                onValueChanged: (val) => setState(() => _tabIndex = val ?? 0),
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildManualTab(),
                  _buildMapTab(),
                  _buildGpsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Manual Tab ──────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Name', _nameController, hint: 'e.g. My Dark Site'),
          const SizedBox(height: 16),

          // Coordinate format toggle
          Row(
            children: [
              const Text('Coordinates', style: TextStyle(fontSize: 13)),
              const Spacer(),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: _useDms,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                thumbColor: Colors.white.withValues(alpha: 0.15),
                children: const {
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Decimal', style: TextStyle(fontSize: 12)),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('DMS', style: TextStyle(fontSize: 12)),
                  ),
                },
                onValueChanged: (val) {
                  setState(() {
                    _useDms = val ?? false;
                    if (_useDms) {
                      _updateDmsFromDecimal();
                    } else {
                      _updateDecimalFromDms();
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_useDms) ...[
            _buildDmsRow('Latitude', _latDegController, _latMinController,
                _latSecController, _latIsNorth, ['N', 'S'], (v) {
              setState(() => _latIsNorth = v == 'N');
            }),
            const SizedBox(height: 8),
            _buildDmsRow('Longitude', _lonDegController, _lonMinController,
                _lonSecController, _lonIsEast, ['E', 'W'], (v) {
              setState(() => _lonIsEast = v == 'E');
            }),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Latitude', _latController,
                      hint: '32.9000',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField('Longitude', _lonController,
                      hint: '-108.8800',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          _buildTextField('Elevation (m)', _elevationController,
              hint: 'Optional',
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),

          // Bortle class slider
          Row(
            children: [
              const Text('Bortle Class', style: TextStyle(fontSize: 13)),
              const Spacer(),
              Text('$_bortleClass',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: _bortleClass.toDouble(),
            min: 1,
            max: 9,
            divisions: 8,
            label: '$_bortleClass',
            onChanged: (v) {
              setState(() {
                _bortleClass = v.round();
                _sqmController.text = CoordinateUtils.sqmForBortle(_bortleClass)
                    .toStringAsFixed(1);
              });
            },
          ),
          const SizedBox(height: 8),

          _buildTextField('SQM (mag/arcsec\u00b2)', _sqmController,
              hint: '20.5',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Map Tab ─────────────────────────────────────────────────────────────────

  Widget _buildMapTab() {
    return FlutterLocationPicker(
      userAgent: 'com.darkdragonsastro.atmosphere',
      initZoom: 6,
      minZoomLevel: 2,
      maxZoomLevel: 18,
      trackMyPosition: false,
      selectLocationButtonText: 'Use This Location',
      selectLocationButtonStyle: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.primary,
        ),
      ),
      onPicked: (pickedData) {
        setState(() {
          _latController.text = CoordinateUtils.formatDecimal(
            pickedData.latLong.latitude,
          );
          _lonController.text = CoordinateUtils.formatDecimal(
            pickedData.latLong.longitude,
          );
          _updateDmsFromDecimal();

          // Use address for name if available
          final addr = pickedData.addressData;
          final parts = <String>[];
          if (addr['city'] != null && (addr['city'] as String).isNotEmpty) {
            parts.add(addr['city'] as String);
          } else if (addr['town'] != null &&
              (addr['town'] as String).isNotEmpty) {
            parts.add(addr['town'] as String);
          } else if (addr['village'] != null &&
              (addr['village'] as String).isNotEmpty) {
            parts.add(addr['village'] as String);
          }
          if (addr['state'] != null && (addr['state'] as String).isNotEmpty) {
            parts.add(addr['state'] as String);
          }
          if (parts.isNotEmpty && _nameController.text.isEmpty) {
            _nameController.text = parts.join(', ');
          }

          // Switch to manual tab to let user fill in remaining fields
          _tabIndex = 0;
        });
      },
    );
  }

  // ── GPS Tab ─────────────────────────────────────────────────────────────────

  Widget _buildGpsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.my_location,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Use your device\u2019s GPS to set coordinates for this location.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (_gpsLoading)
            const CircularProgressIndicator()
          else
            FilledButton.icon(
              onPressed: _getGpsLocation,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Get Current Location'),
            ),
          if (_gpsError != null) ...[
            const SizedBox(height: 16),
            Text(
              _gpsError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (_latController.text.isNotEmpty &&
              _lonController.text.isNotEmpty &&
              !_gpsLoading) ...[
            const SizedBox(height: 24),
            _buildTextField('Name', _nameController,
                hint: 'e.g. My Dark Site'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${_latController.text}, ${_lonController.text}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  if (_elevationController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Elevation: ${_elevationController.text} m',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap Save to add, or switch to Manual to adjust Bortle/SQM.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildDmsRow(
    String label,
    TextEditingController degCtrl,
    TextEditingController minCtrl,
    TextEditingController secCtrl,
    bool isPositive,
    List<String> directions,
    void Function(String) onDirectionChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ),
        SizedBox(
          width: 48,
          child: TextField(
            controller: degCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              suffixText: '\u00b0',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 42,
          child: TextField(
            controller: minCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              suffixText: '\'',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 42,
          child: TextField(
            controller: secCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              suffixText: '"',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: isPositive ? directions[0] : directions[1],
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          thumbColor: Colors.white.withValues(alpha: 0.15),
          children: {
            directions[0]: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(directions[0], style: const TextStyle(fontSize: 12)),
            ),
            directions[1]: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(directions[1], style: const TextStyle(fontSize: 12)),
            ),
          },
          onValueChanged: (val) {
            if (val != null) onDirectionChanged(val);
          },
        ),
      ],
    );
  }
}
