/// EcoSight — Home Screen
/// Main dashboard: shows connection status, live hazard feed,
/// and provides Phase 2 trigger via double-tap gesture.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/websocket_service.dart';
import '../services/tts_manager.dart';
import '../services/haptic_manager.dart';
import '../services/spatial_audio.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ─── Services ──────────────────────────────────────────────
  WebSocketService? _ws;
  final TTSManager _tts = TTSManager();
  final HapticManager _haptic = HapticManager();
  final SpatialAudioManager _audio = SpatialAudioManager();

  // ─── State ─────────────────────────────────────────────────
  bool _isConnected = false;
  String _currentMode = 'idle';
  HazardAlert? _lastHazard;
  String? _sceneDescription;
  bool _isProcessingPhase2 = false;
  int _msgCount = 0;  // DEBUG: count received messages
  String _lastRawMsg = 'No messages yet';  // DEBUG: last raw message

  // ─── Server Config [WS] Server listening on ws://0.0.0.0:8765
  // [WS] Connect app to: 172.16.29.236 : 8765─────────────────────────────────────────
  final TextEditingController _ipController =
      TextEditingController(text: '127.0.0.1');
  final TextEditingController _portController =
      TextEditingController(text: '8765');

  // ─── Animations ────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _hazardGlowController;

  // ─── Subscriptions ─────────────────────────────────────────
  StreamSubscription? _hazardSub;
  StreamSubscription? _sceneSub;
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    _initServices();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _hazardGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _initServices() async {
    await _tts.init();
    await _haptic.init();
    await _audio.init();
  }

  void _connectToServer() async {
    final url = 'ws://${_ipController.text}:${_portController.text}';
    print('[Home] Connecting to: $url');
    setState(() => _lastRawMsg = 'Connecting to $url ...');
    
    _ws = WebSocketService(serverUrl: url);

    _connSub = _ws!.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
        _lastRawMsg = connected 
            ? 'CONNECTED to $url — waiting for data...'
            : 'CONNECT FAILED — is server running? URL: $url';
      });
      if (connected) {
        _tts.speakStatus('Connected to EcoSight server');
        _haptic.pulseLight();
      } else {
        _tts.speakStatus('Connection failed.');
      }
    });

    _hazardSub = _ws!.hazardStream.listen(_onHazard);
    _sceneSub = _ws!.sceneStream.listen(_onScene);

    await _ws!.connect();
    setState(() => _currentMode = 'phase_1');
  }

  // ─── Phase 1 Handler ──────────────────────────────────────
  void _onHazard(HazardAlert alert) {
    _msgCount++;
    final raw = 'MSG#$_msgCount | ${alert.hazard ?? "clear"} | ${alert.direction ?? "-"} | ${alert.distance?.toStringAsFixed(1) ?? "-"}m';
    print('[Home] $raw');
    
    setState(() {
      _lastHazard = alert;
      _currentMode = 'phase_1';
      _lastRawMsg = raw;
    });

    if (alert.hasHazard) {
      // Animate the hazard glow
      _hazardGlowController.forward().then((_) {
        _hazardGlowController.reverse();
      });

      // Spatial audio beep in the correct direction
      print('[Home] Playing warning beep: ${alert.direction}'); // DEBUG LOG
      _audio.playWarningBeep(alert.direction ?? 'center');

      // Haptic feedback based on distance
      if (alert.distance != null) {
        _haptic.vibrateForDistance(alert.distance!);
      }

      // TTS: "Person. 1.5 meters. Left."
      _tts.speakAlert(
        alert.hazard!,
        alert.distance ?? 0,
        alert.direction ?? 'ahead',
      );
    }
  }

  // ─── Phase 2 Handler ──────────────────────────────────────
  void _onScene(SceneDescription scene) {
    setState(() {
      _currentMode = 'phase_2';
      _isProcessingPhase2 = scene.status == 'processing';
      if (scene.isDone && scene.description != null) {
        _sceneDescription = scene.description;
        _tts.speakDescription(scene.description!);
        _audio.playNotification();
      }
    });
  }

  void _triggerPhase2() {
    if (!_isConnected) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isProcessingPhase2 = true;
      _currentMode = 'phase_2';
    });
    _tts.speakStatus('Analyzing surroundings');
    _ws?.triggerPhase2();
  }

  @override
  void dispose() {
    _hazardSub?.cancel();
    _sceneSub?.cancel();
    _connSub?.cancel();
    _ws?.dispose();
    _tts.dispose();
    _audio.dispose();
    _pulseController.dispose();
    _hazardGlowController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isConnected ? _buildDashboard() : _buildConnectScreen(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CONNECTION SCREEN
  // ═══════════════════════════════════════════════════════════
  Widget _buildConnectScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.visibility,
                size: 80,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'EcoSight',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF00E676)],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assistive Vision System',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 48),

            // Server IP
            _buildTextField(_ipController, 'Server IP Address', Icons.wifi),
            const SizedBox(height: 16),
            _buildTextField(_portController, 'Port', Icons.numbers),
            const SizedBox(height: 32),

            // Connect button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _connectToServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF0A0E21),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
                child: const Text(
                  'CONNECT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: const Color(0xFF00E5FF)),
        filled: true,
        fillColor: const Color(0xFF1A1F36),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MAIN DASHBOARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildDashboard() {
    return GestureDetector(
      // Double tap anywhere → trigger Phase 2
      onDoubleTap: _triggerPhase2,
      child: Column(
        children: [
          _buildHeader(),
          // ── DEBUG BANNER ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFFFD600),
            child: Text(
              _lastRawMsg,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(child: _buildStatusArea()),
          _buildPhase2Button(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.visibility, color: Color(0xFF00E5FF), size: 28),
          const SizedBox(width: 12),
          const Text(
            'EcoSight',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Connection indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusArea() {
    if (_isProcessingPhase2) {
      return _buildPhase2Processing();
    }
    if (_currentMode == 'phase_2' && _sceneDescription != null) {
      return _buildPhase2Result();
    }
    return _buildPhase1Display();
  }

  // ─── Phase 1 Display ──────────────────────────────────────
  Widget _buildPhase1Display() {
    final hasHazard = _lastHazard?.hasHazard ?? false;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'PHASE 1 — REFLEX LAYER',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Main hazard display
          AnimatedBuilder(
            animation: _hazardGlowController,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: hasHazard
                        ? [
                            Color.lerp(
                                const Color(0xFFFF5252),
                                const Color(0xFFFF8A80),
                                _hazardGlowController.value)!,
                            Colors.transparent,
                          ]
                        : [
                            const Color(0xFF00E676).withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    hasHazard ? Icons.warning_rounded : Icons.check_circle,
                    size: 80,
                    color: hasHazard
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF00E676),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Hazard info
          if (hasHazard) ...[
            Text(
              _lastHazard!.hazard!.toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF5252),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(
                  Icons.straighten,
                  '${_lastHazard!.distance?.toStringAsFixed(1) ?? "?"} m',
                ),
                const SizedBox(width: 16),
                _buildInfoChip(
                  _directionIcon(_lastHazard!.direction),
                  _lastHazard!.direction?.toUpperCase() ?? 'AHEAD',
                ),
              ],
            ),
          ] else
            Text(
              'Path Clear',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),

          const Spacer(),

          // Hint text
          Text(
            'Double-tap anywhere for scene description',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _directionIcon(String? direction) {
    switch (direction) {
      case 'left':
        return Icons.arrow_back;
      case 'right':
        return Icons.arrow_forward;
      case 'center':
      default:
        return Icons.arrow_upward;
    }
  }

  // ─── Phase 2 Display ──────────────────────────────────────
  Widget _buildPhase2Processing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'PHASE 2 — CONTEXT LAYER',
              style: TextStyle(
                color: Color(0xFF7C4DFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                const Color(0xFF7C4DFF).withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Analyzing Environment...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase2Result() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'SCENE DESCRIPTION',
              style: TextStyle(
                color: Color(0xFF7C4DFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F36),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              _sceneDescription ?? '',
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentMode = 'phase_1';
                  _sceneDescription = null;
                });
              },
              icon: const Icon(Icons.arrow_back, color: Color(0xFF00E5FF)),
              label: const Text(
                'Back to Navigation',
                style: TextStyle(color: Color(0xFF00E5FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phase 2 Trigger Button ────────────────────────────────
  Widget _buildPhase2Button() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton.icon(
          onPressed: _isProcessingPhase2 ? null : _triggerPhase2,
          icon: const Icon(Icons.image_search, size: 28),
          label: Text(
            _isProcessingPhase2 ? 'ANALYZING...' : 'DESCRIBE SURROUNDINGS',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                const Color(0xFF7C4DFF).withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
