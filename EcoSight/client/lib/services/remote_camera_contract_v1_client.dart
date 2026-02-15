/// EcoSight Remote Camera Contract Client (v1)
/// Isolated HTTP client for server/contracts/remote_camera_server_v1.py.
/// This does not modify or replace the existing WebSocket runtime.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class RemoteContractException implements Exception {
  final String message;
  final int? statusCode;

  RemoteContractException(this.message, {this.statusCode});

  @override
  String toString() =>
      'RemoteContractException(statusCode: $statusCode, message: $message)';
}

class RemoteAnalyzeInclude {
  final bool phase1;
  final bool phase2;

  const RemoteAnalyzeInclude({this.phase1 = true, this.phase2 = false});

  Map<String, dynamic> toJson() => {'phase1': phase1, 'phase2': phase2};
}

class RemotePhase2Request {
  final String mode; // caption | ocr | vqa
  final String? question;

  const RemotePhase2Request({this.mode = 'caption', this.question});

  Map<String, dynamic> toJson() => {
    'mode': mode,
    if (question != null) 'question': question,
  };
}

class RemoteAnalyzeFrameRequest {
  final String? frameId;
  final Uint8List jpegBytes;
  final RemoteAnalyzeInclude include;
  final RemotePhase2Request? phase2;

  const RemoteAnalyzeFrameRequest({
    required this.jpegBytes,
    this.frameId,
    this.include = const RemoteAnalyzeInclude(),
    this.phase2,
  });

  Map<String, dynamic> toJson() => {
    if (frameId != null) 'frame_id': frameId,
    'frame_jpeg_base64': base64Encode(jpegBytes),
    'include': include.toJson(),
    if (phase2 != null) 'phase2': phase2!.toJson(),
  };
}

class RemotePhase1Detection {
  final String? hazard;
  final String? direction;
  final double? distance;
  final double? confidence;
  final List<int>? box;
  final int? trackId;
  final String? recommendedLane;
  final String? guidance;

  const RemotePhase1Detection({
    this.hazard,
    this.direction,
    this.distance,
    this.confidence,
    this.box,
    this.trackId,
    this.recommendedLane,
    this.guidance,
  });

  factory RemotePhase1Detection.fromJson(Map<String, dynamic> json) {
    final boxRaw = json['box'];
    return RemotePhase1Detection(
      hazard: json['hazard'] as String?,
      direction: json['direction'] as String?,
      distance: (json['distance'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      box:
          boxRaw is List
              ? boxRaw.map((e) => (e as num).toInt()).toList()
              : null,
      trackId: (json['track_id'] as num?)?.toInt(),
      recommendedLane: json['recommended_lane'] as String?,
      guidance: json['guidance'] as String?,
    );
  }
}

class RemotePhase2Result {
  final String mode;
  final String text;

  const RemotePhase2Result({required this.mode, required this.text});

  factory RemotePhase2Result.fromJson(Map<String, dynamic> json) {
    return RemotePhase2Result(
      mode: (json['mode'] as String?) ?? 'caption',
      text: (json['text'] as String?) ?? '',
    );
  }
}

class RemoteAnalyzeFrameResponse {
  final bool ok;
  final String contractVersion;
  final String? frameId;
  final int latencyMs;
  final List<RemotePhase1Detection>? phase1;
  final RemotePhase2Result? phase2;
  final int? ts;

  const RemoteAnalyzeFrameResponse({
    required this.ok,
    required this.contractVersion,
    required this.frameId,
    required this.latencyMs,
    required this.phase1,
    required this.phase2,
    required this.ts,
  });

  factory RemoteAnalyzeFrameResponse.fromJson(Map<String, dynamic> json) {
    final phase1Raw = json['phase1'];
    final phase2Raw = json['phase2'];

    return RemoteAnalyzeFrameResponse(
      ok: json['ok'] as bool? ?? false,
      contractVersion: (json['contract_version'] as String?) ?? 'v1',
      frameId: json['frame_id'] as String?,
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      phase1:
          phase1Raw is List
              ? phase1Raw
                  .whereType<Map<String, dynamic>>()
                  .map(RemotePhase1Detection.fromJson)
                  .toList()
              : null,
      phase2:
          phase2Raw is Map<String, dynamic>
              ? RemotePhase2Result.fromJson(phase2Raw)
              : null,
      ts: (json['ts'] as num?)?.toInt(),
    );
  }
}

class RemoteCameraContractV1Client {
  final String baseUrl;
  final String? apiKey;
  final http.Client _client;

  RemoteCameraContractV1Client({
    required this.baseUrl,
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path) {
    final normalizedBase =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  Future<bool> healthCheck({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final response = await _client.get(_uri('/health')).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['ok'] == true;
    }
    return false;
  }

  Future<RemoteAnalyzeFrameResponse> analyzeFrame(
    RemoteAnalyzeFrameRequest request, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    late http.Response response;
    try {
      response = await _client
          .post(
            _uri('/v1/analyze-frame'),
            headers: headers,
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);
    } catch (e) {
      throw RemoteContractException('Network request failed: $e');
    }

    Map<String, dynamic>? decoded;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        decoded = parsed;
      }
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded?['message']?.toString() ?? 'Request failed';
      throw RemoteContractException(message, statusCode: response.statusCode);
    }

    if (decoded == null) {
      throw RemoteContractException(
        'Invalid server response (non-JSON)',
        statusCode: response.statusCode,
      );
    }

    if (decoded['ok'] != true) {
      final message =
          decoded['message']?.toString() ?? 'Server returned ok=false';
      throw RemoteContractException(message, statusCode: response.statusCode);
    }

    return RemoteAnalyzeFrameResponse.fromJson(decoded);
  }

  Future<RemotePhase2Result> describeScene(
    Uint8List jpegBytes, {
    String mode = 'caption',
    String? question,
    bool personalize = false,
    Map<String, dynamic>? userProfile,
    String? contextHint,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    final body = <String, dynamic>{
      'frame_jpeg_base64': base64Encode(jpegBytes),
      'mode': mode,
      if (question != null && question.trim().isNotEmpty)
        'question': question.trim(),
      if (personalize)
        'personalize': {
          'enabled': true,
          if (userProfile != null) 'user_profile': userProfile,
          if (contextHint != null && contextHint.trim().isNotEmpty)
            'context_hint': contextHint.trim(),
        },
    };

    late http.Response response;
    try {
      response = await _client
          .post(
            _uri('/v1/describe-scene'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (e) {
      throw RemoteContractException('Network request failed: $e');
    }

    Map<String, dynamic>? decoded;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        decoded = parsed;
      }
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded?['message']?.toString() ?? 'Describe request failed';
      throw RemoteContractException(message, statusCode: response.statusCode);
    }

    if (decoded == null) {
      throw RemoteContractException(
        'Invalid server response (non-JSON)',
        statusCode: response.statusCode,
      );
    }

    if (decoded['ok'] != true) {
      final message = decoded['message']?.toString() ?? 'Server returned ok=false';
      throw RemoteContractException(message, statusCode: response.statusCode);
    }

    if (decoded['phase2'] is Map<String, dynamic>) {
      return RemotePhase2Result.fromJson(decoded['phase2'] as Map<String, dynamic>);
    }

    return RemotePhase2Result(
      mode: (decoded['mode'] as String?) ?? mode,
      text: (decoded['text'] as String?) ?? '',
    );
  }

  void dispose() {
    _client.close();
  }

  /// Send a lightweight heartbeat with GPS so the server watchdog
  /// knows the phone is still alive even between frame submissions.
  Future<bool> sendHeartbeat({
    double? latitude,
    double? longitude,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    final body = <String, dynamic>{};
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    try {
      final response = await _client
          .post(_uri('/v1/heartbeat'), headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
