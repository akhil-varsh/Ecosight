/// EcoSight — WebSocket Service
/// Manages the connection to the Python server and streams incoming data.
/// Uses dart:io WebSocket directly for reliable Android connectivity.
///
/// Guardian Safety:
///   Sends GPS location with every ping so the server always has a recent
///   position.  If the connection drops, the server-side watchdog starts
///   counting failures and after 3 consecutive missed windows it fires
///   an SMS to the guardian via Twilio.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// Data class for Phase 1 hazard alerts
class HazardAlert {
  final String? hazard;
  final String? direction;
  final double? distance;
  final double? confidence;
  final int totalHazards;

  HazardAlert({
    this.hazard,
    this.direction,
    this.distance,
    this.confidence,
    required this.totalHazards,
  });

  factory HazardAlert.fromJson(Map<String, dynamic> json) {
    return HazardAlert(
      hazard: json['hazard'] as String?,
      direction: json['direction'] as String?,
      distance: (json['distance'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      totalHazards: json['total_hazards'] as int? ?? 0,
    );
  }

  bool get hasHazard => hazard != null;
}

/// Data class for Phase 2 scene descriptions
class SceneDescription {
  final String status; // "processing" | "done"
  final String? description;

  SceneDescription({required this.status, this.description});

  factory SceneDescription.fromJson(Map<String, dynamic> json) {
    return SceneDescription(
      status: json['status'] as String,
      description: json['description'] as String?,
    );
  }

  bool get isDone => status == 'done';
}

/// WebSocket service using dart:io WebSocket for reliable Android connectivity
class WebSocketService {
  WebSocket? _socket;
  final String serverUrl;

  // Stream controllers for different message types
  final _hazardController = StreamController<HazardAlert>.broadcast();
  final _sceneController = StreamController<SceneDescription>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<HazardAlert> get hazardStream => _hazardController.stream;
  Stream<SceneDescription> get sceneStream => _sceneController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _locationTimer;

  /// Number of consecutive failed reconnection attempts since last good connection
  int _reconnectAttempts = 0;
  int get reconnectAttempts => _reconnectAttempts;

  /// Maximum reconnect attempts before we consider the connection critically lost
  static const int maxReconnectAttempts = 3;

  /// Last known GPS position (sent with every ping for server-side watchdog)
  double? _lastLatitude;
  double? _lastLongitude;

  WebSocketService({required this.serverUrl});

  /// Connect to the EcoSight server using dart:io WebSocket
  Future<void> connect() async {
    try {
      print('[WS] Connecting to $serverUrl ... (attempt ${_reconnectAttempts + 1})');
      _socket = await WebSocket.connect(serverUrl)
          .timeout(const Duration(seconds: 5));

      _isConnected = true;
      _reconnectAttempts = 0; // reset on successful connection
      _connectionController.add(true);
      print('[WS] ✓ Connected to $serverUrl');

      // Listen for messages
      _socket!.listen(
        (data) {
          _onMessage(data);
        },
        onError: (error) {
          print('[WS] Stream error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('[WS] Stream done (code=${_socket?.closeCode})');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // Start ping every 5s — includes GPS for the server-side watchdog
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendPingWithLocation();
      });

      // Start a background GPS updater every 10s so we always have fresh coords
      _startLocationUpdates();

    } catch (e) {
      print('[WS] ✗ Connection FAILED: $e');
      _handleDisconnect();
    }
  }

  /// Send Phase 2 trigger to the server
  void triggerPhase2() {
    _send({'type': 'trigger_phase2'});
  }

  void _send(Map<String, dynamic> data) {
    if (_isConnected && _socket != null) {
      try {
        _socket!.add(jsonEncode(data));
      } catch (e) {
        print('[WS] Send error: $e');
      }
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'phase_1') {
        _hazardController.add(HazardAlert.fromJson(data));
      } else if (type == 'phase_2') {
        _sceneController.add(SceneDescription.fromJson(data));
      }
      // ignore pong — but it confirms connection is alive
    } catch (e) {
      print('[WS] Parse error: $e');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionController.add(false);
    _pingTimer?.cancel();
    _locationTimer?.cancel();
    _socket = null;

    _reconnectAttempts++;
    print('[WS] Reconnect attempt $_reconnectAttempts / $maxReconnectAttempts');

    if (_reconnectAttempts >= maxReconnectAttempts) {
      // At this point the server-side watchdog will also fire the SMS.
      // On the client we just log — the server handles the Twilio alert.
      print('[WS] ⚠️  Max reconnect attempts reached — server will alert guardian');
    }

    // Keep trying to reconnect (exponential back-off capped at 15s)
    final delay = Duration(
      seconds: (_reconnectAttempts <= 3) ? 3 * _reconnectAttempts : 15,
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      print('[WS] Attempting reconnect...');
      connect();
    });
  }

  // ── GPS helpers ───────────────────────────────────────────────

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _refreshLocation();
    });
    // Also grab location immediately
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // can't get location — server will note "unavailable"
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lastLatitude = pos.latitude;
      _lastLongitude = pos.longitude;
    } catch (e) {
      // Silently ignore — previous coords remain valid
    }
  }

  void _sendPingWithLocation() {
    final payload = <String, dynamic>{'type': 'ping'};
    if (_lastLatitude != null && _lastLongitude != null) {
      payload['latitude'] = _lastLatitude;
      payload['longitude'] = _lastLongitude;
    }
    _send(payload);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _locationTimer?.cancel();
    _socket?.close();
    _hazardController.close();
    _sceneController.close();
    _connectionController.close();
  }
}
