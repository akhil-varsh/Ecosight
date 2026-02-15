/// EcoSight Remote Camera Streamer (v1)
/// Thin helper that throttles frame uploads and avoids request pile-up.
///
/// Guardian Safety:
///   Sends GPS location with every frame AND runs a 10-second background
///   heartbeat so the server-side watchdog always has a fresh timestamp.
///   If heartbeats stop arriving the server fires a Twilio SMS to the guardian.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';

import 'remote_camera_contract_v1_client.dart';

class RemoteCameraStreamerV1 {
  final RemoteCameraContractV1Client client;
  final Duration minInterval;

  bool _inFlight = false;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _heartbeatTimer;
  double? _lastLatitude;
  double? _lastLongitude;

  /// Number of consecutive heartbeat failures
  int _consecutiveHeartbeatFailures = 0;
  int get consecutiveHeartbeatFailures => _consecutiveHeartbeatFailures;

  RemoteCameraStreamerV1({
    required this.client,
    this.minInterval = const Duration(milliseconds: 160), // ~6 FPS
  });

  bool get isInFlight => _inFlight;

  /// Start a background heartbeat that sends GPS to the server every 10s.
  /// Call this once when streaming begins.
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _sendHeartbeat(),
    );
    // Also fire one immediately
    _sendHeartbeat();
  }

  /// Stop the background heartbeat (call when streaming stops).
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _refreshLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lastLatitude = pos.latitude;
      _lastLongitude = pos.longitude;
    } catch (_) {}
  }

  Future<void> _sendHeartbeat() async {
    await _refreshLocation();
    final ok = await client.sendHeartbeat(
      latitude: _lastLatitude,
      longitude: _lastLongitude,
    );
    if (ok) {
      _consecutiveHeartbeatFailures = 0;
    } else {
      _consecutiveHeartbeatFailures++;
      print(
        '[Streamer] Heartbeat failed '
        '($_consecutiveHeartbeatFailures consecutive)',
      );
    }
  }

  Future<RemoteAnalyzeFrameResponse?> submitFrame({
    required Uint8List jpegBytes,
    String? frameId,
    RemoteAnalyzeInclude include = const RemoteAnalyzeInclude(
      phase1: true,
      phase2: false,
    ),
    RemotePhase2Request? phase2,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastSentAt);

    if (_inFlight || elapsed < minInterval) {
      return null;
    }

    _inFlight = true;
    _lastSentAt = now;

    try {
      return await client.analyzeFrame(
        RemoteAnalyzeFrameRequest(
          frameId: frameId,
          jpegBytes: jpegBytes,
          include: include,
          phase2: phase2,
        ),
        timeout: timeout,
      );
    } finally {
      _inFlight = false;
    }
  }
}
