/// EcoSight — Maps & Navigation Screen (v1)
///
/// Full-screen Google Map with:
///  - Search bar (Google Places Autocomplete — direct API call)
///  - Current-location marker + auto-follow
///  - Route polyline drawn on the map
///  - Turn-by-turn step list & voice announcements
///  - Fully self-contained — no server dependency
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

import '../services/tts_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MapsNavigationV1Screen extends StatefulWidget {
  const MapsNavigationV1Screen({
    super.key,
    this.initialDestination,
  });

  final String? initialDestination;

  @override
  State<MapsNavigationV1Screen> createState() =>
      _MapsNavigationV1ScreenState();
}

class _MapsNavigationV1ScreenState extends State<MapsNavigationV1Screen> {
  // ── Google Maps API key ─────────────────────────────────────────────────
  static const String _apiKey = 'AIzaSyA43RpbHXS0rdlegp6XAgmrB-8RzC41uow';

  // ── Controllers ─────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  final TTSManager _tts = TTSManager();
  final http.Client _httpClient = http.Client();

  // ── Location state ──────────────────────────────────────────────────────
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionStream;

  // ── Search state ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;

  // ── Navigation state ────────────────────────────────────────────────────
  bool _isNavigating = false;
  bool _isFetchingRoute = false;
  String _destinationName = '';
  LatLng? _destinationLatLng;
  String _totalDistance = '';
  String _totalDuration = '';
  List<Map<String, dynamic>> _navSteps = [];
  int _currentStepIndex = 0;

  // ── Map drawing state ───────────────────────────────────────────────────
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  // ── TTS / step tracking ─────────────────────────────────────────────────
  DateTime _lastStepAnnounce = DateTime.fromMillisecondsSinceEpoch(0);
  static const double _stepArrivalMeters = 30.0;
  static const double _destArrivalMeters = 40.0;

  @override
  void initState() {
    super.initState();
    _tts.init();
    _initLocation();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Location
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.best),
        ).timeout(const Duration(seconds: 8));
        _updateCurrentPosition(pos);
      } catch (_) {}

      // Continuous tracking
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_updateCurrentPosition);
    }
  }

  void _updateCurrentPosition(Position pos) {
    if (!mounted) return;
    final latlng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _currentLatLng = latlng;
    });

    if (_isNavigating) {
      _checkNavProgress(latlng);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Search — Google Places API (New) — Autocomplete
  // ══════════════════════════════════════════════════════════════════════════

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPredictions(value.trim());
    });
  }

  Future<void> _fetchPredictions(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      final uri =
          Uri.parse('https://places.googleapis.com/v1/places:autocomplete');

      final body = <String, dynamic>{'input': query};
      if (_currentLatLng != null) {
        body['locationBias'] = {
          'circle': {
            'center': {
              'latitude': _currentLatLng!.latitude,
              'longitude': _currentLatLng!.longitude,
            },
            'radius': 50000.0,
          },
        };
      }

      final resp = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        final errMsg = (data['error'] as Map?)?['message'] ?? 'Unknown error';
        debugPrint('[Maps] Autocomplete error: $errMsg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Search error: $errMsg'),
                duration: const Duration(seconds: 2)),
          );
        }
        return;
      }

      final suggestions = (data['suggestions'] as List<dynamic>?) ?? [];
      debugPrint('[Maps] Autocomplete suggestions=${suggestions.length}');

      final results = <Map<String, dynamic>>[];
      for (final s in suggestions.take(8)) {
        final pred =
            (s as Map<String, dynamic>)['placePrediction'] as Map<String, dynamic>?;
        if (pred == null) continue;
        final placeId = pred['placeId']?.toString() ?? '';
        final fullText =
            ((pred['text'] as Map?)?['text'] as String?) ?? '';
        final mainText =
            ((pred['structuredFormat'] as Map?)?['mainText'] as Map?)?['text']?.toString() ?? '';
        final secText =
            ((pred['structuredFormat'] as Map?)?['secondaryText'] as Map?)?['text']?.toString() ?? '';
        results.add({
          'place_id': placeId,
          'description': fullText,
          'main_text': mainText,
          'secondary_text': secText,
        });
      }

      if (mounted) setState(() => _predictions = results);
    } catch (e) {
      debugPrint('[Maps] Autocomplete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Search failed: $e'),
              duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Place Details — Places API (New) ─────────────────────────────────

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id']?.toString() ?? '';
    final description = prediction['description']?.toString() ?? '';
    _searchController.text = description;
    setState(() => _predictions = []);
    FocusScope.of(context).unfocus();

    if (placeId.isEmpty) return;

    try {
      final url = Uri.parse(
        'https://places.googleapis.com/v1/places/$placeId',
      );

      final resp = await _httpClient
          .get(url, headers: {
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'displayName,formattedAddress,location',
          })
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        final errMsg = (data['error'] as Map?)?['message'] ?? 'Unknown error';
        debugPrint('[Maps] Place details error: $errMsg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Place details error: $errMsg')),
          );
        }
        return;
      }

      final loc = data['location'] as Map<String, dynamic>?;
      final lat = (loc?['latitude'] as num?)?.toDouble();
      final lng = (loc?['longitude'] as num?)?.toDouble();
      final name = ((data['displayName'] as Map?)?['text'] as String?) ??
          description;

      debugPrint('[Maps] Place details: $name @ $lat,$lng');

      if (lat != null && lng != null && mounted) {
        setState(() {
          _destinationLatLng = LatLng(lat, lng);
          _destinationName = name;
        });

        _addDestinationMarker(LatLng(lat, lng), name);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
        );
      }
    } catch (e) {
      debugPrint('[Maps] Place details error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load place details: $e')),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Route / Navigation — Google Routes API (New)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startRoute() async {
    if (_currentLatLng == null || _destinationLatLng == null) return;
    if (_isFetchingRoute) return;

    setState(() => _isFetchingRoute = true);

    try {
      final uri = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );

      final requestBody = {
        'origin': {
          'location': {
            'latLng': {
              'latitude': _currentLatLng!.latitude,
              'longitude': _currentLatLng!.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': _destinationLatLng!.latitude,
              'longitude': _destinationLatLng!.longitude,
            },
          },
        },
        'travelMode': 'WALK',
        'computeAlternativeRoutes': false,
        'languageCode': 'en',
      };

      final resp = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask':
                  'routes.duration,routes.distanceMeters,'
                  'routes.polyline.encodedPolyline,'
                  'routes.legs.steps.navigationInstruction,'
                  'routes.legs.steps.localizedValues,'
                  'routes.legs.steps.startLocation,'
                  'routes.legs.steps.endLocation,'
                  'routes.legs.localizedValues',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        final errMsg = (data['error'] as Map?)?['message'] ?? 'Unknown error';
        debugPrint('[Maps] Routes error: $errMsg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Route error: $errMsg')),
          );
        }
        return;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No walking route found.')),
          );
        }
        return;
      }

      final route = routes[0] as Map<String, dynamic>;
      final legs = (route['legs'] as List<dynamic>?) ?? [];
      final leg = legs.isNotEmpty ? (legs[0] as Map<String, dynamic>) : <String, dynamic>{};

      // Distance & duration from route-level
      final distMeters = (route['distanceMeters'] as num?)?.toInt() ?? 0;
      final durationStr = (route['duration'] as String?) ?? '0s';
      final durationSecs =
          int.tryParse(durationStr.replaceAll('s', '')) ?? 0;
      final totalDist = distMeters >= 1000
          ? '${(distMeters / 1000).toStringAsFixed(1)} km'
          : '$distMeters m';
      final totalDur = durationSecs >= 3600
          ? '${durationSecs ~/ 3600} hr ${(durationSecs % 3600) ~/ 60} min'
          : '${(durationSecs / 60).ceil()} min';

      // Or use leg-level localizedValues if available
      final legLocalized = (leg['localizedValues'] as Map<String, dynamic>?) ?? {};
      final legDistText = ((legLocalized['distance'] as Map?)?['text'] as String?) ?? totalDist;
      final legDurText = ((legLocalized['duration'] as Map?)?['text'] as String?) ?? totalDur;

      debugPrint('[Maps] Route: $legDistText, $legDurText');

      // Parse steps
      final stepsRaw = (leg['steps'] as List<dynamic>?) ?? [];
      final steps = <Map<String, dynamic>>[];
      for (var i = 0; i < stepsRaw.length; i++) {
        final s = stepsRaw[i] as Map<String, dynamic>;
        final navInstr =
            (s['navigationInstruction'] as Map<String, dynamic>?) ?? {};
        final instruction =
            navInstr['instructions']?.toString() ?? 'Continue';
        final stepLocal =
            (s['localizedValues'] as Map<String, dynamic>?) ?? {};
        final stepDist =
            ((stepLocal['distance'] as Map?)?['text'] as String?) ?? '';
        final stepDur =
            ((stepLocal['duration'] as Map?)?['text'] as String?) ?? '';
        final startLoc =
            ((s['startLocation'] as Map?)?['latLng'] as Map?) ?? {};
        final endLoc =
            ((s['endLocation'] as Map?)?['latLng'] as Map?) ?? {};
        steps.add({
          'index': i + 1,
          'instruction': instruction,
          'distance': stepDist,
          'duration': stepDur,
          'start_lat': (startLoc['latitude'] as num?)?.toDouble(),
          'start_lng': (startLoc['longitude'] as num?)?.toDouble(),
          'end_lat': (endLoc['latitude'] as num?)?.toDouble(),
          'end_lng': (endLoc['longitude'] as num?)?.toDouble(),
        });
      }

      // Draw polyline
      final polyEncoded =
          (route['polyline'] as Map?)?['encodedPolyline']?.toString();
      if (polyEncoded != null) {
        final decoded = PolylinePoints.decodePolyline(polyEncoded);
        final coords =
            decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
        if (mounted) {
          setState(() {
            _polylines
              ..clear()
              ..add(
                Polyline(
                  polylineId: const PolylineId('nav_route'),
                  points: coords,
                  color: const Color(0xFF4285F4),
                  width: 6,
                ),
              );
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _isNavigating = true;
        _navSteps = steps;
        _currentStepIndex = 0;
        _totalDistance = legDistText;
        _totalDuration = legDurText;
      });

      _fitRouteBounds();

      if (steps.isNotEmpty) {
        await _tts.speakStatus(
          'Starting navigation to $_destinationName. '
          '$_totalDistance, about $_totalDuration. '
          'First: ${steps.first['instruction']}. ${steps.first['distance']}.',
        );
        _lastStepAnnounce = DateTime.now();
      }
    } catch (e) {
      debugPrint('[Maps] Routes error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  void _fitRouteBounds() {
    if (_currentLatLng == null || _destinationLatLng == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_currentLatLng!.latitude, _destinationLatLng!.latitude),
        math.min(_currentLatLng!.longitude, _destinationLatLng!.longitude),
      ),
      northeast: LatLng(
        math.max(_currentLatLng!.latitude, _destinationLatLng!.latitude),
        math.max(_currentLatLng!.longitude, _destinationLatLng!.longitude),
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _addDestinationMarker(LatLng pos, String title) {
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'destination')
        ..add(
          Marker(
            markerId: const MarkerId('destination'),
            position: pos,
            infoWindow: InfoWindow(title: title),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
    });
  }

  // ── Navigation progress (called from position stream) ──────────────────

  void _checkNavProgress(LatLng current) {
    if (!_isNavigating || _navSteps.isEmpty) return;

    if (_destinationLatLng != null) {
      final distDest = _haversine(
        current.latitude,
        current.longitude,
        _destinationLatLng!.latitude,
        _destinationLatLng!.longitude,
      );
      if (distDest < _destArrivalMeters) {
        _onArrived();
        return;
      }
    }

    if (_currentStepIndex < _navSteps.length) {
      final step = _navSteps[_currentStepIndex];
      final endLat = (step['end_lat'] as num?)?.toDouble();
      final endLng = (step['end_lng'] as num?)?.toDouble();

      if (endLat != null && endLng != null) {
        final dist = _haversine(
          current.latitude,
          current.longitude,
          endLat,
          endLng,
        );
        if (dist < _stepArrivalMeters) {
          _currentStepIndex++;
          if (_currentStepIndex >= _navSteps.length) {
            _onArrived();
            return;
          }
          _announceStep(_currentStepIndex);
          if (mounted) setState(() {});
        }
      }
    }
  }

  void _announceStep(int idx) {
    final now = DateTime.now();
    if (now.difference(_lastStepAnnounce) < const Duration(seconds: 6)) return;
    _lastStepAnnounce = now;

    if (idx < _navSteps.length) {
      final s = _navSteps[idx];
      _tts.speakStatus(
        'Step ${idx + 1}: ${s['instruction']}. ${s['distance']}.',
      );
    }
  }

  void _onArrived() {
    setState(() {
      _isNavigating = false;
    });
    _tts.speakStatus(
      'You have arrived at $_destinationName! Navigation complete.',
    );
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _navSteps = [];
      _currentStepIndex = 0;
      _polylines.clear();
      _markers.removeWhere((m) => m.markerId.value == 'destination');
    });
    _tts.speakStatus('Navigation cancelled.');
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double d) => d * (math.pi / 180);

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _positionStream?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    _httpClient.close();
    _tts.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng ?? const LatLng(17.385, 78.4867),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            polylines: _polylines,
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLatLng != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
                );
              }
            },
          ),

          // ── Search bar ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search a place...',
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _predictions = []);
                                  },
                                )
                              : const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 56),
                      itemBuilder: (context, i) {
                        final p = _predictions[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF6C63FF),
                          ),
                          title: Text(
                            p['main_text']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            p['secondary_text']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          dense: true,
                          onTap: () => _selectPrediction(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom sheet: destination info / navigation panel ───────────
          if (_destinationLatLng != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _isNavigating
                  ? _buildNavigationPanel()
                  : _buildDestinationPanel(),
            ),

          // ── My-location FAB ────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _destinationLatLng != null ? 220 : 32,
            child: FloatingActionButton.small(
              heroTag: 'myLoc',
              backgroundColor: Colors.white,
              onPressed: () {
                if (_currentLatLng != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pre-navigation: destination info + Start button ────────────────────
  Widget _buildDestinationPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.place, color: Color(0xFF6C63FF), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _destinationName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _destinationLatLng = null;
                    _destinationName = '';
                    _markers.removeWhere(
                      (m) => m.markerId.value == 'destination',
                    );
                    _polylines.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isFetchingRoute ? null : _startRoute,
              icon: _isFetchingRoute
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.directions_walk),
              label: Text(
                  _isFetchingRoute ? 'Getting route...' : 'Start Walking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active navigation panel ────────────────────────────────────────────
  Widget _buildNavigationPanel() {
    final step = (_navSteps.isNotEmpty && _currentStepIndex < _navSteps.length)
        ? _navSteps[_currentStepIndex]
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.navigation_rounded,
                  color: Color(0xFF4285F4), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _destinationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$_totalDistance  ~$_totalDuration',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _stopNavigation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
          const Divider(height: 24),
          if (step != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepIcon(step['instruction']?.toString() ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${_currentStepIndex + 1} of ${_navSteps.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step['instruction']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${step['distance'] ?? ''}  ${step['duration'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_currentStepIndex + 1 < _navSteps.length) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Then: ${_navSteps[_currentStepIndex + 1]['instruction']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepIcon(String instruction) {
    final lower = instruction.toLowerCase();
    IconData icon;
    if (lower.contains('left')) {
      icon = Icons.turn_left;
    } else if (lower.contains('right')) {
      icon = Icons.turn_right;
    } else if (lower.contains('u-turn') || lower.contains('uturn')) {
      icon = Icons.u_turn_left;
    } else {
      icon = Icons.straight;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF4285F4), size: 24),
    );
  }
}
