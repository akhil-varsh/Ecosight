library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class AgenticServerV1Client {
  AgenticServerV1Client({
    required this.baseUrl,
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String? apiKey;
  final http.Client _client;

  Uri _uri(String path) {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  Future<Map<String, dynamic>> executeCommand({
    required String text,
    Map<String, dynamic>? context,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    final body = <String, dynamic>{
      'text': text,
      if (context != null) 'context': context,
    };

    final response = await _client
        .post(
          _uri('/v1/agent/execute'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid agent response');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = decoded['message']?.toString() ?? 'Agent request failed';
      throw StateError(msg);
    }

    if (decoded['ok'] != true) {
      final msg = decoded['message']?.toString() ?? 'Agent returned ok=false';
      throw StateError(msg);
    }

    return decoded;
  }

  /// Fetch structured walking directions for in-app turn-by-turn navigation.
  ///
  /// Returns a map with:
  /// - `ok` (bool)
  /// - `found` (bool)
  /// - `destination` (String)
  /// - `total_distance` (String)
  /// - `total_duration` (String)
  /// - `dest_lat` / `dest_lng` (double)
  /// - `steps` (List): each step has `index`, `instruction`, `distance`,
  ///   `duration`, `start_lat`, `start_lng`, `end_lat`, `end_lng`
  Future<Map<String, dynamic>> fetchDirections({
    required double originLat,
    required double originLng,
    required String destination,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    final body = <String, dynamic>{
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination': destination,
    };

    final response = await _client
        .post(
          _uri('/v1/directions'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid directions response');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = decoded['message']?.toString() ?? 'Directions request failed';
      throw StateError(msg);
    }

    return decoded;
  }

  /// Search for places using Google Places Autocomplete via the agent server.
  Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    final body = <String, dynamic>{
      'query': query,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };

    final response = await _client
        .post(
          _uri('/v1/places/autocomplete'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return [];
    final predictions = decoded['predictions'];
    if (predictions is! List) return [];
    return predictions.map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  /// Get lat/lng for a place_id via Google Places Details.
  Future<Map<String, dynamic>> getPlaceDetails({
    required String placeId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    final body = <String, dynamic>{'place_id': placeId};

    final response = await _client
        .post(
          _uri('/v1/places/details'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid place details response');
    }
    return decoded;
  }

  void dispose() {
    _client.close();
  }
}
