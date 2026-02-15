library;

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/agentic_server_v1_client.dart';
import '../services/haptic_manager.dart';
import '../services/firebase_event_logger_v1.dart';
import '../services/ondevice_yolo_v1_service.dart';
import '../services/remote_camera_contract_v1_client.dart';
import '../services/remote_camera_streamer_v1.dart';
import '../services/spatial_audio.dart';
import '../services/tts_manager.dart';

class RemoteCameraDemoV1Screen extends StatefulWidget {
  const RemoteCameraDemoV1Screen({super.key});

  @override
  State<RemoteCameraDemoV1Screen> createState() =>
      _RemoteCameraDemoV1ScreenState();
}

class _RemoteCameraDemoV1ScreenState extends State<RemoteCameraDemoV1Screen> {
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'http://10.100.9.8:8080',
  );
  final TextEditingController _agentUrlController = TextEditingController(
    text: 'http://10.100.9.8:8091',
  );
  final TextEditingController _apiKeyController = TextEditingController();

  CameraController? _cameraController;
  RemoteCameraContractV1Client? _client;
  RemoteCameraStreamerV1? _streamer;

  final HapticManager _haptic = HapticManager();
  final SpatialAudioManager _audio = SpatialAudioManager();
  final TTSManager _tts = TTSManager();
  final FirebaseEventLoggerV1 _firebaseLogger = FirebaseEventLoggerV1.instance;
  final OnDeviceYoloV1Service _onDeviceYolo = OnDeviceYoloV1Service();
  final SpeechToText _speech = SpeechToText();

  bool _speechReady = false;
  bool _continuousListening = false;
  bool _isListening = false;
  bool _isVoiceBusy = false;
  String _heardCommand = '';

  bool _useOnDeviceYolo = true;
  bool _onDeviceReady = false;
  String _onDeviceError = '';

  bool _isCameraReady = false;
  bool _isStreaming = false;
  bool _isFrameBusy = false;
  DateTime _lastFrameStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minOnDeviceFrameInterval = Duration(
    milliseconds: 350,
  );
  static const Duration _minRemoteFrameInterval = Duration(milliseconds: 220);

  String _status = 'Idle';
  int _sentFrames = 0;
  int _receivedFrames = 0;
  int? _lastLatencyMs;
  RemotePhase1Detection? _nearestHazard;
  String? _phase2Text;
  img.Image? _latestRgbFrame;
  bool _isDescribingScene = false;
  bool _isNarratingScene = false;
  DateTime _lastHazardFeedbackAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpeechFeedbackAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Navigation state ──────────────────────────────────────────────────
  bool _isNavigating = false;
  String _navDestination = '';
  String _navTotalDistance = '';
  String _navTotalDuration = '';
  double? _navDestLat;
  double? _navDestLng;
  List<Map<String, dynamic>> _navSteps = [];
  int _currentNavStepIndex = 0;
  Timer? _navGpsTimer;
  DateTime _lastNavAnnouncedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const double _navStepArrivalMeters = 30.0;
  static const double _navDestArrivalMeters = 40.0;
  static const Duration _navGpsPollInterval = Duration(seconds: 5);
  static const Duration _minNavAnnounceInterval = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _initFeedbackServices();
    _initOnDeviceYolo();
    _initCamera().then((_) {
      if (mounted) _autoBootSequence();
    });
  }

  /// Runs once after camera is ready: speaks welcome, starts stream, starts voice.
  Future<void> _autoBootSequence() async {
    // Wait for TTS + STT to be ready
    for (var i = 0; i < 20; i++) {
      if (_speechReady) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    await _tts.speakStatus(
      'Welcome to EcoSight. I am your voice assistant. '
      'You can ask me anything like, what\'s the weather, '
      'navigate me somewhere, describe the scene, or call someone. '
      'Starting camera and listening now.',
    );

    // Auto-start streaming
    if (_isCameraReady && mounted) {
      _startStreaming();
    }

    // Auto-start continuous voice listener
    if (_speechReady && mounted) {
      _continuousListening = true;
      _startListeningLoop();
    }
  }

  Future<void> _initOnDeviceYolo() async {
    setState(() {
      _status = 'Loading on-device YOLO model...';
    });

    try {
      await _onDeviceYolo.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _onDeviceReady = true;
        _onDeviceError = '';
        _status = 'On-device YOLO ready';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _onDeviceReady = false;
        _onDeviceError = e.toString();
        _status = 'On-device model not loaded';
      });
    }
  }

  Future<void> _initFeedbackServices() async {
    await _haptic.init();
    await _audio.init();
    await _tts.init();

    final speechReady = await _speech.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _speechReady = speechReady;
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = 'No camera available on this device';
        });
        return;
      }

      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _status = 'Camera ready';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Camera init failed: $e';
      });
    }
  }

  Future<void> _checkHealth() async {
    final client = RemoteCameraContractV1Client(
      baseUrl: _baseUrlController.text.trim(),
      apiKey:
          _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
    );

    setState(() {
      _status = 'Checking server health...';
    });

    try {
      final ok = await client.healthCheck();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = ok ? 'Server reachable' : 'Health check failed';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Health check error: $e';
      });
    } finally {
      client.dispose();
    }
  }

  void _startStreaming() {
    if (!_isCameraReady || _cameraController == null) {
      setState(() {
        _status = 'Camera is not ready';
      });
      return;
    }

    if (_useOnDeviceYolo && !_onDeviceReady) {
      setState(() {
        _status = 'On-device YOLO not ready. Check model asset.';
      });
      return;
    }

    if (!_useOnDeviceYolo) {
      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isEmpty) {
        setState(() {
          _status = 'Enter server base URL';
        });
        return;
      }

      _client?.dispose();
      _client = RemoteCameraContractV1Client(
        baseUrl: baseUrl,
        apiKey:
            _apiKeyController.text.trim().isEmpty
                ? null
                : _apiKeyController.text.trim(),
      );
      _streamer = RemoteCameraStreamerV1(client: _client!);
    }

    // Start guardian heartbeat (sends GPS every 10s so server knows we're alive)
    _streamer?.startHeartbeat();

    _cameraController!.startImageStream(_onCameraFrame);

    setState(() {
      _isStreaming = true;
      _status = 'Streaming started';
      _sentFrames = 0;
      _receivedFrames = 0;
      _lastLatencyMs = null;
      _nearestHazard = null;
      _phase2Text = null;
      _latestRgbFrame = null;
    });
    _lastHazardFeedbackAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastSpeechFeedbackAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _stopStreaming() {
    // Stop guardian heartbeat
    _streamer?.stopHeartbeat();

    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }

    setState(() {
      _isStreaming = false;
      _status = 'Streaming stopped';
    });
  }

  void _onCameraFrame(CameraImage cameraImage) {
    if (!_isStreaming || _isFrameBusy) {
      return;
    }
    unawaited(_processCameraFrame(cameraImage));
  }

  Future<void> _processCameraFrame(CameraImage cameraImage) async {
    if (!_isStreaming) {
      return;
    }
    if (_isFrameBusy) {
      return;
    }

    final now = DateTime.now();
    final activeInterval =
        _useOnDeviceYolo ? _minOnDeviceFrameInterval : _minRemoteFrameInterval;
    if (now.difference(_lastFrameStartedAt) < activeInterval) {
      return;
    }

    _isFrameBusy = true;
    _lastFrameStartedAt = now;

    final rgbImage = _cameraImageToRgbImage(cameraImage);
    if (rgbImage == null) {
      _isFrameBusy = false;
      return;
    }
    _latestRgbFrame = rgbImage;

    try {
      _sentFrames += 1;

      if (_useOnDeviceYolo) {
        final sw = Stopwatch()..start();
        final localDetections = await _onDeviceYolo.detectFromImage(rgbImage);
        sw.stop();

        final nearestLocal =
            localDetections.isNotEmpty ? localDetections.first : null;
        final nearest =
            nearestLocal == null
                ? null
                : RemotePhase1Detection(
                  hazard: nearestLocal.hazard,
                  direction: nearestLocal.direction,
                  distance: nearestLocal.distance,
                  confidence: nearestLocal.confidence,
                  box: nearestLocal.box,
                );

        if (!mounted) {
          return;
        }

        setState(() {
          _receivedFrames += 1;
          _lastLatencyMs = sw.elapsedMilliseconds;
          _nearestHazard = nearest;
          _phase2Text = null;
          _status = 'On-device YOLO inference active';
        });

        await _maybeTriggerHazardFeedback(nearest);
      } else {
        if (_streamer == null) {
          return;
        }

        final jpegBytes = _rgbImageToJpeg(rgbImage);
        if (jpegBytes == null) {
          return;
        }

        final response = await _streamer!.submitFrame(
          frameId: DateTime.now().millisecondsSinceEpoch.toString(),
          jpegBytes: jpegBytes,
          include: const RemoteAnalyzeInclude(phase1: true, phase2: false),
        );

        if (!mounted || response == null) {
          return;
        }

        final nearest =
            (response.phase1 != null && response.phase1!.isNotEmpty)
                ? response.phase1!.first
                : null;

        setState(() {
          _receivedFrames += 1;
          _lastLatencyMs = response.latencyMs;
          _nearestHazard = nearest;
          _phase2Text = response.phase2?.text ?? _phase2Text;
          _status = 'Streaming: server responded';
        });

        await _maybeTriggerHazardFeedback(nearest);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Frame send failed: $e';
      });
    } finally {
      _isFrameBusy = false;
    }
  }

  Future<void> _describeScene() async {
    debugPrint('[DescribeScene] Button pressed');
    if (_isDescribingScene) {
      debugPrint('[DescribeScene] Already in progress; ignoring');
      return;
    }

    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() {
        _status = 'Enter laptop server URL for scene description';
      });
      return;
    }

    final jpegBytes = await _captureDescribeJpegBytes();
    if (jpegBytes == null) {
      setState(() {
        _status = 'Failed to capture frame for description';
      });
      debugPrint('[DescribeScene] Frame capture failed');
      return;
    }

    final captionClient = RemoteCameraContractV1Client(
      baseUrl: baseUrl,
      apiKey:
          _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isDescribingScene = true;
        _status = 'Describing scene on laptop...';
      });
    }

    try {
      debugPrint('[DescribeScene] Sending request to $baseUrl/v1/describe-scene (${jpegBytes.length} bytes)');
      final response = await captionClient.describeScene(
        jpegBytes,
        mode: 'caption',
        timeout: const Duration(seconds: 25),
      );
      debugPrint('[DescribeScene] Response received. mode=${response.mode}, textLength=${response.text.length}');

      final text = response.text.trim();

      if (!mounted) {
        return;
      }

      setState(() {
        _phase2Text = text.isEmpty ? _phase2Text : text;
        _status = text.isEmpty ? 'No scene description returned' : 'Scene described';
      });

      unawaited(
        _firebaseLogger.logSceneDescription(
          text: text,
          baseUrl: baseUrl,
          success: text.isNotEmpty,
          imageBytes: jpegBytes,
          error: text.isEmpty ? 'empty_description' : null,
        ),
      );

      if (text.isNotEmpty) {
        _isNarratingScene = true;
        await _audio.stop();
        await _tts.stop();
        await _tts.speakDescription(text);
        _isNarratingScene = false;
      }
    } catch (e) {
      debugPrint('[DescribeScene] Request failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Describe scene failed: $e';
      });

      unawaited(
        _firebaseLogger.logSceneDescription(
          text: '',
          baseUrl: baseUrl,
          success: false,
          imageBytes: jpegBytes,
          error: e.toString(),
        ),
      );
    } finally {
      _isNarratingScene = false;
      captionClient.dispose();
      if (mounted) {
        setState(() {
          _isDescribingScene = false;
        });
      }
    }
  }

  Future<Uint8List?> _captureDescribeJpegBytes() async {
    final latest = _latestRgbFrame;
    if (latest != null) {
      return _rgbImageToJpeg(latest);
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }

    final wasStreaming =
        _isStreaming && controller.value.isStreamingImages;

    try {
      if (wasStreaming) {
        await controller.stopImageStream();
      }

      final shot = await controller.takePicture();
      return await shot.readAsBytes();
    } catch (e) {
      debugPrint('[DescribeScene] Snapshot capture error: $e');
      return null;
    } finally {
      if (wasStreaming && mounted) {
        try {
          await controller.startImageStream(_onCameraFrame);
        } catch (e) {
          debugPrint('[DescribeScene] Failed to resume image stream: $e');
        }
      }
    }
  }

  img.Image? _cameraImageToRgbImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.bgra8888 &&
          cameraImage.planes.isNotEmpty) {
        final plane = cameraImage.planes.first;
        return img.Image.fromBytes(
          width: cameraImage.width,
          height: cameraImage.height,
          bytes: plane.bytes.buffer,
          order: img.ChannelOrder.bgra,
          numChannels: 4,
        );
      }

      if (cameraImage.format.group != ImageFormatGroup.yuv420 ||
          cameraImage.planes.length < 3) {
        return null;
      }

      final width = cameraImage.width;
      final height = cameraImage.height;
      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      final image = img.Image(width: width, height: height);

      for (var y = 0; y < height; y++) {
        final yRow = y * yPlane.bytesPerRow;
        final uvRow = (y >> 1) * uPlane.bytesPerRow;
        for (var x = 0; x < width; x++) {
          final yValue = yPlane.bytes[yRow + x];
          final uvIndex = uvRow + (x >> 1) * (uPlane.bytesPerPixel ?? 1);
          final uValue = uPlane.bytes[uvIndex];
          final vValue = vPlane.bytes[uvIndex];

          final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          final g = (yValue -
                  0.344136 * (uValue - 128) -
                  0.714136 * (vValue - 128))
              .round()
              .clamp(0, 255);
          final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          image.setPixelRgb(x, y, r, g, b);
        }
      }

      return image;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _rgbImageToJpeg(img.Image image) {
    try {
      return Uint8List.fromList(img.encodeJpg(image, quality: 65));
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeTriggerHazardFeedback(
    RemotePhase1Detection? nearest,
  ) async {
    if (_isDescribingScene || _isNarratingScene) {
      return;
    }
    if (nearest == null || nearest.hazard == null) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastHazardFeedbackAt) <
        const Duration(milliseconds: 1200)) {
      return;
    }

    _lastHazardFeedbackAt = now;

    try {
      await _audio.playWarningBeep(nearest.direction ?? 'center');
      if (nearest.distance != null) {
        await _haptic.vibrateForDistance(nearest.distance!);
      } else {
        await _haptic.pulseWarning();
      }

      if (nearest.distance != null &&
          now.difference(_lastSpeechFeedbackAt) >=
              const Duration(milliseconds: 2500)) {
        _lastSpeechFeedbackAt = now;
        await _tts.speakAlert(
          nearest.hazard ?? 'hazard',
          nearest.distance!,
          nearest.direction ?? 'center',
        );
      }
    } catch (_) {}
  }

  Future<void> _mockSound() async {
    try {
      await _audio.playWarningBeep('center');
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Mock sound played';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Mock sound failed: $e';
      });
    }
  }

  Future<void> _mockTts() async {
    try {
      await _tts.speakAlert('person', 2.0, 'center');
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Mock TTS spoken';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Mock TTS failed: $e';
      });
    }
  }

  Future<void> _mockVibration() async {
    try {
      await _haptic.pulseWarning();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Mock vibration triggered';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Mock vibration failed: $e';
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // In-app turn-by-turn navigation engine (runs parallel with detection)
  // ══════════════════════════════════════════════════════════════════════

  /// Haversine distance between two GPS points, returns meters.
  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Start in-app navigation to [destination].
  /// Fetches structured directions from the server, stores steps, and begins
  /// GPS polling. Hazard detection continues running via camera stream.
  Future<void> _startNavigation(String destination) async {
    if (_isNavigating) {
      await _tts.speakStatus(
        'Navigation is already active to $_navDestination. '
        'Say stop navigation to cancel first.',
      );
      return;
    }

    final agentUrl = _agentUrlController.text.trim();
    if (agentUrl.isEmpty) return;

    // Fetch current GPS
    double? lat;
    double? lng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(const Duration(seconds: 6));
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    if (lat == null || lng == null) {
      await _tts.speakStatus(
        'I cannot start navigation because GPS is unavailable. '
        'Please enable location services.',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _status = 'Fetching route to $destination...';
      });
    }

    final client = AgenticServerV1Client(
      baseUrl: agentUrl,
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
    );

    try {
      final data = await client.fetchDirections(
        originLat: lat,
        originLng: lng,
        destination: destination,
      );

      if (data['found'] != true) {
        await _tts.speakStatus(
          'Sorry, I could not find a walking route to $destination.',
        );
        return;
      }

      final steps = (data['steps'] as List<dynamic>?) ?? [];
      if (steps.isEmpty) {
        await _tts.speakStatus(
          'The route to $destination has no steps. Please try again.',
        );
        return;
      }

      _navSteps = steps.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      _currentNavStepIndex = 0;
      _navDestination = (data['destination'] as String?) ?? destination;
      _navTotalDistance = (data['total_distance'] as String?) ?? '';
      _navTotalDuration = (data['total_duration'] as String?) ?? '';
      _navDestLat = (data['dest_lat'] as num?)?.toDouble();
      _navDestLng = (data['dest_lng'] as num?)?.toDouble();

      if (mounted) {
        setState(() {
          _isNavigating = true;
          _status = 'Navigating to $_navDestination';
        });
      }

      // Announce start
      final firstStep = _navSteps.first;
      await _tts.speakStatus(
        'Starting navigation to $_navDestination. '
        'Total distance: $_navTotalDistance, estimated time: $_navTotalDuration. '
        'First: ${firstStep['instruction']}. ${firstStep['distance']}.',
      );
      _lastNavAnnouncedAt = DateTime.now();

      // Start GPS polling (hazard detection keeps running via camera stream)
      _navGpsTimer?.cancel();
      _navGpsTimer = Timer.periodic(_navGpsPollInterval, (_) {
        if (_isNavigating && mounted) {
          unawaited(_navGpsTick());
        }
      });
    } catch (e) {
      await _tts.speakStatus(
        'Sorry, I failed to get directions. $e',
      );
      if (mounted) {
        setState(() {
          _status = 'Navigation failed: $e';
        });
      }
    } finally {
      client.dispose();
    }
  }

  /// Called every [_navGpsPollInterval] to check proximity to next waypoint.
  Future<void> _navGpsTick() async {
    if (!_isNavigating || _navSteps.isEmpty || !mounted) return;

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      return; // GPS hiccup — skip this tick
    }

    final lat = pos.latitude;
    final lng = pos.longitude;

    // Check if arrived at final destination
    if (_navDestLat != null && _navDestLng != null) {
      final distToDest = _haversineMeters(lat, lng, _navDestLat!, _navDestLng!);
      if (distToDest < _navDestArrivalMeters) {
        await _arriveAtDestination();
        return;
      }
    }

    // Check proximity to current step's end location
    if (_currentNavStepIndex < _navSteps.length) {
      final step = _navSteps[_currentNavStepIndex];
      final endLat = (step['end_lat'] as num?)?.toDouble();
      final endLng = (step['end_lng'] as num?)?.toDouble();

      if (endLat != null && endLng != null) {
        final dist = _haversineMeters(lat, lng, endLat, endLng);

        if (dist < _navStepArrivalMeters) {
          // Advance to next step
          _currentNavStepIndex++;
          if (_currentNavStepIndex >= _navSteps.length) {
            await _arriveAtDestination();
            return;
          }

          final nextStep = _navSteps[_currentNavStepIndex];
          final now = DateTime.now();
          if (now.difference(_lastNavAnnouncedAt) >= _minNavAnnounceInterval &&
              !_isVoiceBusy && !_isNarratingScene) {
            _lastNavAnnouncedAt = now;
            await _tts.speakStatus(
              'Step ${_currentNavStepIndex + 1}: '
              '${nextStep['instruction']}. ${nextStep['distance']}.',
            );
          }

          if (mounted) {
            setState(() {
              _status = 'Nav step ${_currentNavStepIndex + 1}/${_navSteps.length}';
            });
          }
        }
      }
    }
  }

  Future<void> _arriveAtDestination() async {
    _navGpsTimer?.cancel();
    _navGpsTimer = null;

    final dest = _navDestination;

    if (mounted) {
      setState(() {
        _isNavigating = false;
        _navSteps = [];
        _currentNavStepIndex = 0;
        _status = 'Arrived at $dest';
      });
    }

    await _tts.speakStatus(
      'You have arrived at $dest. Navigation complete. '
      'Hazard detection is still active. Stay safe!',
    );
  }

  Future<void> _stopNavigation() async {
    _navGpsTimer?.cancel();
    _navGpsTimer = null;

    if (mounted) {
      setState(() {
        _isNavigating = false;
        _navSteps = [];
        _currentNavStepIndex = 0;
        _status = 'Navigation cancelled';
      });
    }

    await _tts.speakStatus(
      'Navigation cancelled. Hazard detection is still running.',
    );
  }

  Future<void> _announceNavProgress() async {
    if (!_isNavigating || _navSteps.isEmpty) {
      await _tts.speakStatus('No navigation is active right now.');
      return;
    }

    // Fetch GPS for distance calculation
    double? distToDest;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(const Duration(seconds: 4));
      if (_navDestLat != null && _navDestLng != null) {
        distToDest = _haversineMeters(
          pos.latitude, pos.longitude, _navDestLat!, _navDestLng!,
        );
      }
    } catch (_) {}

    final step = _navSteps[_currentNavStepIndex];
    final remaining = _navSteps.length - _currentNavStepIndex;
    final distStr = distToDest != null
        ? '${(distToDest / 1000).toStringAsFixed(1)} kilometres'
        : 'unknown distance';

    await _tts.speakStatus(
      'Navigating to $_navDestination. '
      '$remaining steps remaining, approximately $distStr away. '
      'Current step: ${step['instruction']}. ${step['distance']}.',
    );
  }

  Future<void> _toggleVoiceCommand() async {
    if (!_speechReady || _isVoiceBusy) {
      return;
    }

    if (_continuousListening) {
      // Stop continuous mode
      _continuousListening = false;
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _status = 'Voice assistant stopped.';
      });
      return;
    }

    // Start continuous mode
    _continuousListening = true;
    _startListeningLoop();
  }

  Future<void> _startListeningLoop() async {
    if (!_continuousListening || !_speechReady || !mounted) return;

    // Wait if TTS is still speaking to avoid capturing own speech
    while (_isVoiceBusy || _isNarratingScene) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_continuousListening || !mounted) return;
    }

    setState(() {
      _isListening = true;
      _heardCommand = '';
      _status = 'Listening...';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _heardCommand = result.recognizedWords;
        });

        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          unawaited(_runAgentCommand(_heardCommand));
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
      ),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _runAgentCommand(String commandText) async {
    final text = commandText.trim();
    if (text.isEmpty || _isVoiceBusy) {
      return;
    }

    final lower = text.toLowerCase();

    // Local voice commands that don't need the server
    if (lower.contains('stop listening') ||
        lower.contains('stop assistant') ||
        lower.contains('goodbye') ||
        lower.contains('go to sleep')) {
      _continuousListening = false;
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _status = 'Voice assistant stopped.';
        });
      }
      await _tts.speakStatus('Voice assistant stopped. Goodbye.');
      return;
    }

    if (lower.contains('go back') || lower.contains('exit')) {
      _continuousListening = false;
      await _speech.stop();
      await _tts.speakStatus('Going back. Goodbye.');
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // ── Navigation voice commands ──────────────────────────────────────
    if (lower.contains('stop navigation') ||
        lower.contains('cancel navigation') ||
        lower.contains('cancel route') ||
        lower.contains('stop route')) {
      if (_isNavigating) {
        await _stopNavigation();
      } else {
        await _tts.speakStatus('No navigation is active.');
      }
      // Re-start listening
      if (_continuousListening && mounted) {
        Future.delayed(const Duration(milliseconds: 600), _startListeningLoop);
      }
      return;
    }

    if ((lower.contains('how far') || lower.contains('progress') ||
        lower.contains('navigation status') || lower.contains('where am i on')) &&
        _isNavigating) {
      await _announceNavProgress();
      if (_continuousListening && mounted) {
        Future.delayed(const Duration(milliseconds: 600), _startListeningLoop);
      }
      return;
    }

    if ((lower.contains('next step') || lower.contains('current step') ||
        lower.contains('what step')) &&
        _isNavigating) {
      if (_navSteps.isNotEmpty && _currentNavStepIndex < _navSteps.length) {
        final step = _navSteps[_currentNavStepIndex];
        await _tts.speakStatus(
          'Step ${_currentNavStepIndex + 1}: '
          '${step['instruction']}. ${step['distance']}.',
        );
      }
      if (_continuousListening && mounted) {
        Future.delayed(const Duration(milliseconds: 600), _startListeningLoop);
      }
      return;
    }

    final agentUrl = _agentUrlController.text.trim();
    if (agentUrl.isEmpty) {
      setState(() {
        _status = 'Enter agent server URL (port 8091)';
      });
      return;
    }

    final client = AgenticServerV1Client(
      baseUrl: agentUrl,
      apiKey:
          _apiKeyController.text.trim().isEmpty
              ? null
              : _apiKeyController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isVoiceBusy = true;
        _isListening = false;
        _status = 'Executing voice command...';
      });
    }

    try {
      // Fetch GPS to pass as context to the agent server
      Map<String, dynamic> gpsContext = {};
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
            ),
          ).timeout(const Duration(seconds: 5));
          gpsContext = {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          };
        } else {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.always ||
              requested == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
              ),
            ).timeout(const Duration(seconds: 5));
            gpsContext = {
              'latitude': pos.latitude,
              'longitude': pos.longitude,
            };
          }
        }
      } catch (_) {
        // GPS unavailable — proceed without it
      }

      final response = await client.executeCommand(
        text: text,
        context: gpsContext,
      );
      final result = (response['result'] as Map<String, dynamic>?) ?? {};
      final action = (result['action'] as String?) ?? 'none';
      final speakText =
          (result['speak_text'] as String?) ??
          'Command completed.';
      final params = (result['parameters'] as Map<String, dynamic>?) ?? {};

      switch (action) {
        case 'describe_scene':
          await _describeScene();
          break;
        case 'start_stream':
          _startStreaming();
          break;
        case 'stop_stream':
          _stopStreaming();
          break;
        case 'check_health':
          await _checkHealth();
          break;
        case 'call_relative':
          final tel = params['tel']?.toString();
          if (tel != null && tel.isNotEmpty) {
            await launchUrl(
              Uri.parse(tel),
              mode: LaunchMode.externalApplication,
            );
          }
          break;
        case 'navigate':
          final destination = params['destination']?.toString() ?? '';
          if (destination.isNotEmpty) {
            // In-app turn-by-turn navigation (runs parallel with detection)
            unawaited(_startNavigation(destination));
          }
          break;
        default:
          break;
      }

      await _tts.speakStatus(speakText);
      if (mounted) {
        setState(() {
          _isListening = false;
          _status = 'Voice command: $action';
        });
      }
    } catch (e) {
      await _tts.speakStatus('Sorry, that command failed. Please try again.');
      if (mounted) {
        setState(() {
          _status = 'Voice command failed: $e';
        });
      }
    } finally {
      client.dispose();
      if (mounted) {
        setState(() {
          _isVoiceBusy = false;
        });
      }
      // Re-start listening for next command
      if (_continuousListening && mounted) {
        Future.delayed(const Duration(milliseconds: 600), _startListeningLoop);
      }
    }
  }

  @override
  void dispose() {
    _continuousListening = false;
    _navGpsTimer?.cancel();
    _stopStreaming();
    _speech.stop();
    _client?.dispose();
    _cameraController?.dispose();
    _audio.dispose();
    _tts.dispose();
    _onDeviceYolo.dispose();
    _baseUrlController.dispose();
    _agentUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Camera Demo v1')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Use On-device YOLO (phone inference)'),
                subtitle: Text(
                  _onDeviceReady
                      ? 'Model ready'
                      : (_onDeviceError.isEmpty
                          ? 'Model loading...'
                          : 'Model missing or failed to load'),
                ),
                value: _useOnDeviceYolo,
                onChanged:
                    _isStreaming
                        ? null
                        : (value) {
                          setState(() {
                            _useOnDeviceYolo = value;
                            _status =
                                value
                                    ? 'On-device YOLO mode selected'
                                    : 'Remote laptop inference mode selected';
                          });
                        },
              ),
              if (_onDeviceError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _onDeviceError,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Laptop Server Base URL',
                  hintText:
                      'http://192.168.1.23:8080 or https://*.ngrok-free.app',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _agentUrlController,
                decoration: const InputDecoration(
                  labelText: 'Agent Server URL (voice commands)',
                  hintText: 'http://192.168.1.23:8091',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: ElevatedButton(
                          onPressed: _checkHealth,
                          child: const Text('Check Health'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: ElevatedButton(
                          onPressed:
                              _isStreaming ? _stopStreaming : _startStreaming,
                          child: Text(
                            _isStreaming ? 'Stop Stream' : 'Start Stream',
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: OutlinedButton(
                          onPressed: _isDescribingScene ? null : _describeScene,
                          child: Text(
                            _isDescribingScene
                                ? 'Describing...'
                                : 'Describe Scene',
                          ),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: OutlinedButton(
                          onPressed: _mockSound,
                          child: const Text('Mock Sound'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: OutlinedButton(
                          onPressed: _mockVibration,
                          child: const Text('Mock Vibration'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: OutlinedButton(
                          onPressed: _mockTts,
                          child: const Text('Mock TTS'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    (!_speechReady || _isVoiceBusy)
                        ? null
                        : _toggleVoiceCommand,
                icon: Icon(
                  _continuousListening
                      ? Icons.mic_off_rounded
                      : Icons.mic_rounded,
                ),
                label: Text(
                  _continuousListening
                      ? 'Stop Voice Assistant'
                      : 'Start Voice Assistant',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _heardCommand.isEmpty
                    ? 'Heard command: -'
                    : 'Heard command: $_heardCommand',
                style: const TextStyle(color: Color(0xFF8E95A9)),
              ),
              if (_isNavigating) ...[
                const SizedBox(height: 8),
                _buildNavigationCard(),
              ],
              const SizedBox(height: 12),
              Text('Status: $_status'),
              Text('Frames sent: $_sentFrames | responses: $_receivedFrames'),
              Text(
                'Latency: ${_lastLatencyMs == null ? '-' : '${_lastLatencyMs}ms'}',
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio:
                    _cameraController?.value.aspectRatio == null
                        ? 4 / 3
                        : _cameraController!.value.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black,
                    child:
                        _isCameraReady && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationCard() {
    final step = (_navSteps.isNotEmpty && _currentNavStepIndex < _navSteps.length)
        ? _navSteps[_currentNavStepIndex]
        : null;
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.navigation_rounded, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Navigating to $_navDestination',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => unawaited(_stopNavigation()),
                  tooltip: 'Stop navigation',
                ),
              ],
            ),
            Text('$_navTotalDistance  ~$_navTotalDuration'),
            const SizedBox(height: 4),
            Text(
              'Step ${_currentNavStepIndex + 1} / ${_navSteps.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (step != null) ...[
              Text(step['instruction']?.toString() ?? ''),
              Text(
                '${step['distance'] ?? ''} ${step['duration'] ?? ''}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final nearest = _nearestHazard;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest Server Output',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              nearest == null
                  ? 'Hazard: none'
                  : 'Hazard: ${nearest.hazard ?? '-'} | ${nearest.distance?.toStringAsFixed(1) ?? '-'}m | ${nearest.direction ?? '-'}',
            ),
            if (nearest?.guidance != null)
              Text('Guidance: ${nearest!.guidance}'),
            const SizedBox(height: 8),
            Text('Caption: ${_phase2Text ?? '-'}'),
          ],
        ),
      ),
    );
  }
}
