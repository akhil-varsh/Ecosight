/// EcoSight — WebSocket Service
/// Manages the connection to the Python server and streams incoming data.
/// Uses dart:io WebSocket directly for reliable Android connectivity.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  WebSocketService({required this.serverUrl});

  /// Connect to the EcoSight server using dart:io WebSocket
  Future<void> connect() async {
    try {
      print('[WS] Connecting to $serverUrl ...');
      _socket = await WebSocket.connect(serverUrl)
          .timeout(const Duration(seconds: 5));

      _isConnected = true;
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

      // Start ping every 5s to keep connection alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _send({'type': 'ping'});
      });
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
    _socket = null;

    // Auto-reconnect after 3 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      print('[WS] Attempting reconnect...');
      connect();
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _socket?.close();
    _hazardController.close();
    _sceneController.close();
    _connectionController.close();
  }
}
