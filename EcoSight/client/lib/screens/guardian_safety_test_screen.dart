/// EcoSight — Guardian Safety Test Screen
/// UI for testing connection-loss detection and guardian SMS alerts.
///
/// Tests available:
///   1. Server Health Check
///   2. Send Test SMS to Guardian
///   3. Heartbeat Ping (single)
///   4. Simulate Connection Loss (starts heartbeats → stops → waits for SMS)
///   5. View Watchdog Status
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class GuardianSafetyTestScreen extends StatefulWidget {
  const GuardianSafetyTestScreen({super.key});

  @override
  State<GuardianSafetyTestScreen> createState() =>
      _GuardianSafetyTestScreenState();
}

class _GuardianSafetyTestScreenState extends State<GuardianSafetyTestScreen> {
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'http://10.100.9.8:8080',
  );

  final List<_LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();

  bool _isBusy = false;
  Timer? _heartbeatTimer;
  bool _isHeartbeating = false;
  int _heartbeatCount = 0;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _baseUrlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────

  String get _baseUrl {
    final url = _baseUrlController.text.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  void _log(String message, {_LogLevel level = _LogLevel.info}) {
    setState(() {
      _logs.add(_LogEntry(
        time: DateTime.now(),
        message: message,
        level: level,
      ));
    });
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _refreshLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log('Location permission denied', level: _LogLevel.warning);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _latitude = pos.latitude;
      _longitude = pos.longitude;
      _log('GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    } catch (e) {
      _log('GPS error: $e', level: _LogLevel.warning);
    }
  }

  // ── Test 1: Health Check ──────────────────────────────────────

  Future<void> _testHealthCheck() async {
    setState(() => _isBusy = true);
    _log('Testing server health...');

    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      final body = jsonDecode(resp.body);
      if (body['ok'] == true) {
        final guardianEnabled = body['guardian_alert_enabled'] == true;
        _log(
          'Server OK — guardian alerts ${guardianEnabled ? "ENABLED" : "DISABLED"}',
          level: guardianEnabled ? _LogLevel.success : _LogLevel.warning,
        );
      } else {
        _log('Server returned ok=false', level: _LogLevel.error);
      }
    } catch (e) {
      _log('Health check failed: $e', level: _LogLevel.error);
    }

    setState(() => _isBusy = false);
  }

  // ── Test 2: Send Test SMS ─────────────────────────────────────

  Future<void> _testSendSMS() async {
    setState(() => _isBusy = true);
    _log('Requesting server to send test SMS...');

    await _refreshLocation();

    try {
      final body = <String, dynamic>{
        'test': true,
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
      };

      final resp = await http
          .post(
            Uri.parse('$_baseUrl/v1/test-guardian-sms'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(resp.body);
      if (decoded['ok'] == true) {
        _log('Test SMS sent successfully!', level: _LogLevel.success);
      } else {
        _log(
          'SMS failed: ${decoded['message'] ?? decoded['error'] ?? 'unknown'}',
          level: _LogLevel.error,
        );
      }
    } catch (e) {
      _log('Test SMS request failed: $e', level: _LogLevel.error);
    }

    setState(() => _isBusy = false);
  }

  // ── Test 3: Single Heartbeat ──────────────────────────────────

  Future<void> _testSingleHeartbeat() async {
    setState(() => _isBusy = true);
    _log('Sending single heartbeat with GPS...');

    await _refreshLocation();

    try {
      final body = <String, dynamic>{
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
      };

      final resp = await http
          .post(
            Uri.parse('$_baseUrl/v1/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));

      final decoded = jsonDecode(resp.body);
      if (decoded['ok'] == true) {
        _log('Heartbeat acknowledged by server', level: _LogLevel.success);
      } else {
        _log('Heartbeat failed', level: _LogLevel.error);
      }
    } catch (e) {
      _log('Heartbeat error: $e', level: _LogLevel.error);
    }

    setState(() => _isBusy = false);
  }

  // ── Test 4: Simulate Connection Loss ──────────────────────────

  Future<void> _testConnectionLoss() async {
    if (_isHeartbeating) {
      // Stop early
      _heartbeatTimer?.cancel();
      setState(() => _isHeartbeating = false);
      _log('Heartbeats STOPPED — watchdog is now counting...', level: _LogLevel.warning);
      _log(
        'Server will send SMS after ~45s of silence (3 × 15s windows)',
        level: _LogLevel.info,
      );
      return;
    }

    _log('═══ CONNECTION LOSS SIMULATION ═══');
    _log('Step 1: Sending heartbeats with GPS for 15s...');
    await _refreshLocation();

    setState(() {
      _isHeartbeating = true;
      _heartbeatCount = 0;
    });

    // Send heartbeats every 3s for 15 seconds, then stop abruptly
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isHeartbeating) {
        timer.cancel();
        return;
      }

      _heartbeatCount++;

      try {
        final body = <String, dynamic>{
          if (_latitude != null) 'latitude': _latitude,
          if (_longitude != null) 'longitude': _longitude,
        };

        final resp = await http
            .post(
              Uri.parse('$_baseUrl/v1/heartbeat'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 5));

        final decoded = jsonDecode(resp.body);
        if (decoded['ok'] == true) {
          _log('Heartbeat #$_heartbeatCount OK');
        }
      } catch (e) {
        _log('Heartbeat #$_heartbeatCount failed: $e', level: _LogLevel.error);
      }

      // After 5 heartbeats (15s), stop to simulate connection loss
      if (_heartbeatCount >= 5) {
        timer.cancel();
        setState(() => _isHeartbeating = false);
        _log('');
        _log('Step 2: HEARTBEATS STOPPED — simulating connection loss',
            level: _LogLevel.warning);
        _log('Server watchdog will count 3 missed windows (15s each)...');
        _log('Expect guardian SMS in ~45 seconds', level: _LogLevel.warning);
      }
    });
  }

  // ── Test 5: Watchdog Status ───────────────────────────────────

  Future<void> _testWatchdogStatus() async {
    setState(() => _isBusy = true);
    _log('Checking watchdog status...');

    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/v1/watchdog-status'))
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 404) {
        _log(
          'Watchdog status endpoint not available (server may need update)',
          level: _LogLevel.warning,
        );
      } else {
        final decoded = jsonDecode(resp.body);
        if (decoded['ok'] == true) {
          final clients = decoded['clients'] as List? ?? [];
          if (clients.isEmpty) {
            _log('No clients tracked by watchdog');
          } else {
            for (final c in clients) {
              _log(
                'Client ${c['ip']}: '
                'last_seen=${c['seconds_ago']?.toStringAsFixed(0)}s ago, '
                'misses=${c['missed_windows']}, '
                'alert_sent=${c['alert_sent']}',
                level: (c['missed_windows'] ?? 0) > 0
                    ? _LogLevel.warning
                    : _LogLevel.success,
              );
            }
          }
        } else {
          _log('Watchdog status error', level: _LogLevel.error);
        }
      }
    } catch (e) {
      _log('Watchdog status error: $e', level: _LogLevel.error);
    }

    setState(() => _isBusy = false);
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Guardian Safety Tests',
          style: TextStyle(
            color: Color(0xFF1A1D2E),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
      ),
      body: Column(
        children: [
          // Server URL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'http://192.168.1.x:8080',
                prefixIcon: const Icon(Icons.dns_rounded, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Test buttons menu
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildTestChip(
                  icon: Icons.favorite_rounded,
                  label: 'Health',
                  color: const Color(0xFF00D9A6),
                  onTap: _isBusy ? null : _testHealthCheck,
                ),
                _buildTestChip(
                  icon: Icons.sms_rounded,
                  label: 'Test SMS',
                  color: const Color(0xFF6C63FF),
                  onTap: _isBusy ? null : _testSendSMS,
                ),
                _buildTestChip(
                  icon: Icons.monitor_heart_rounded,
                  label: 'Heartbeat',
                  color: const Color(0xFF00A870),
                  onTap: _isBusy ? null : _testSingleHeartbeat,
                ),
                _buildTestChip(
                  icon: _isHeartbeating
                      ? Icons.stop_circle_rounded
                      : Icons.wifi_off_rounded,
                  label: _isHeartbeating ? 'Stop' : 'Sim Loss',
                  color: const Color(0xFFFF6B6B),
                  onTap: _testConnectionLoss,
                ),
                _buildTestChip(
                  icon: Icons.visibility_rounded,
                  label: 'Status',
                  color: const Color(0xFFF59E0B),
                  onTap: _isBusy ? null : _testWatchdogStatus,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Live status bar
          if (_isHeartbeating)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Heartbeating... ($_heartbeatCount sent) — tap Stop to simulate loss',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Log console
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal_rounded,
                            color: Color(0xFF00D9A6), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Console',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _logs.clear()),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'Run a test to see output here',
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _logs.length,
                            itemBuilder: (_, i) => _buildLogLine(_logs[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        backgroundColor: onTap == null ? color.withValues(alpha: 0.4) : color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: BorderSide.none,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildLogLine(_LogEntry entry) {
    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}';

    Color textColor;
    String prefix;
    switch (entry.level) {
      case _LogLevel.success:
        textColor = const Color(0xFF00D9A6);
        prefix = '✓';
        break;
      case _LogLevel.warning:
        textColor = const Color(0xFFF59E0B);
        prefix = '⚠';
        break;
      case _LogLevel.error:
        textColor = const Color(0xFFFF6B6B);
        prefix = '✗';
        break;
      case _LogLevel.info:
      default:
        textColor = const Color(0xFFCBD5E1);
        prefix = '›';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$timeStr ',
              style: const TextStyle(color: Colors.white24),
            ),
            TextSpan(
              text: '$prefix ${entry.message}',
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Log model ─────────────────────────────────────────────────────

enum _LogLevel { info, success, warning, error }

class _LogEntry {
  final DateTime time;
  final String message;
  final _LogLevel level;

  _LogEntry({
    required this.time,
    required this.message,
    this.level = _LogLevel.info,
  });
}
