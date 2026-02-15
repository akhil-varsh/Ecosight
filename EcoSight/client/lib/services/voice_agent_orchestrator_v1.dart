library;

import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class VoiceAgentOutcome {
  final String intent;
  final String response;
  final bool success;

  const VoiceAgentOutcome({
    required this.intent,
    required this.response,
    required this.success,
  });
}

class VoiceAgentOrchestratorV1 {
  static const Map<String, String> _relativeNumbers = {
    'mom': 'tel:+911111111111',
    'mother': 'tel:+911111111111',
    'dad': 'tel:+922222222222',
    'father': 'tel:+922222222222',
    'brother': 'tel:+933333333333',
    'sister': 'tel:+944444444444',
  };

  Future<VoiceAgentOutcome> execute(String command) async {
    final normalized = command.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const VoiceAgentOutcome(
        intent: 'empty',
        response: 'Please say a command.',
        success: false,
      );
    }

    if (_matchesLocation(normalized)) {
      return _getCurrentLocation();
    }

    if (_matchesWeather(normalized)) {
      return _getWeather();
    }

    final relative = _extractRelative(normalized);
    if (relative != null) {
      return _callRelative(relative);
    }

    return const VoiceAgentOutcome(
      intent: 'unknown',
      response:
          'I can get current location, fetch weather, or call a relative like mom or dad.',
      success: false,
    );
  }

  bool _matchesLocation(String text) {
    return text.contains('location') ||
        text.contains('where am i') ||
        text.contains('where i am');
  }

  bool _matchesWeather(String text) {
    return text.contains('weather') || text.contains('temperature');
  }

  String? _extractRelative(String text) {
    if (!text.contains('call')) {
      return null;
    }
    for (final name in _relativeNumbers.keys) {
      if (text.contains(name)) {
        return name;
      }
    }
    return null;
  }

  Future<VoiceAgentOutcome> _getCurrentLocation() async {
    try {
      final permission = await _ensureLocationPermission();
      if (!permission) {
        return const VoiceAgentOutcome(
          intent: 'location',
          response: 'Location permission is not granted.',
          success: false,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

      return VoiceAgentOutcome(
        intent: 'location',
        response:
            'Your current location is latitude ${pos.latitude.toStringAsFixed(5)}, longitude ${pos.longitude.toStringAsFixed(5)}.',
        success: true,
      );
    } catch (_) {
      return const VoiceAgentOutcome(
        intent: 'location',
        response: 'I could not fetch your location right now.',
        success: false,
      );
    }
  }

  Future<VoiceAgentOutcome> _getWeather() async {
    try {
      final permission = await _ensureLocationPermission();
      if (!permission) {
        return const VoiceAgentOutcome(
          intent: 'weather',
          response: 'Location permission is needed to fetch weather.',
          success: false,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,weather_code,wind_speed_10m',
      );

      final response = await http.get(url);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const VoiceAgentOutcome(
          intent: 'weather',
          response: 'Weather service is unavailable right now.',
          success: false,
        );
      }

      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final current = (jsonMap['current'] as Map<String, dynamic>?) ?? {};
      final temp = (current['temperature_2m'] as num?)?.toDouble();
      final wind = (current['wind_speed_10m'] as num?)?.toDouble();

      if (temp == null) {
        return const VoiceAgentOutcome(
          intent: 'weather',
          response: 'I could not parse weather data right now.',
          success: false,
        );
      }

      final windText =
          wind == null ? '' : ' Wind speed is ${wind.toStringAsFixed(1)} kilometers per hour.';

      return VoiceAgentOutcome(
        intent: 'weather',
        response:
            'Current temperature is ${temp.toStringAsFixed(1)} degrees Celsius.$windText',
        success: true,
      );
    } catch (_) {
      return const VoiceAgentOutcome(
        intent: 'weather',
        response: 'I could not fetch weather right now.',
        success: false,
      );
    }
  }

  Future<VoiceAgentOutcome> _callRelative(String relative) async {
    final tel = _relativeNumbers[relative];
    if (tel == null) {
      return VoiceAgentOutcome(
        intent: 'call',
        response: 'I do not have contact details for $relative.',
        success: false,
      );
    }

    final uri = Uri.parse(tel);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      return VoiceAgentOutcome(
        intent: 'call',
        response: 'I could not open the dialer for $relative.',
        success: false,
      );
    }

    return VoiceAgentOutcome(
      intent: 'call',
      response: 'Opening dialer to call $relative.',
      success: true,
    );
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
