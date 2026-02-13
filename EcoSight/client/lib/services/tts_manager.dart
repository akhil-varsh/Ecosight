/// EcoSight — TTS (Text-to-Speech) Manager
/// Handles spoken audio alerts for both Phase 1 and Phase 2.
library;

import 'package:flutter_tts/flutter_tts.dart';

class TTSManager {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.55); // Slightly fast for urgency
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      print('[TTS] Error: $msg');
    });
  }

  /// Speak a short urgent Phase 1 alert.
  /// Example: "Person. 2 meters. Left."
  Future<void> speakAlert(String hazard, double distance, String direction) async {
    // Log current state
    print('[TTS] speakAlert() called. isSpeaking=$_isSpeaking, hazard=$hazard, distance=$distance, direction=$direction');
    
    // Temporarily disabled guard to debug — allow overlapping speech
    // if (_isSpeaking) return;

    final distStr = distance.toStringAsFixed(1);
    final text = 'Detected $hazard towards your $direction at $distStr meters.';
    
    print('[TTS] >>> Calling _tts.speak("$text")');
    await _tts.stop(); // Stop any previous speech first
    await _tts.speak(text);
  }

  /// Speak a long Phase 2 scene description.
  /// Interrupts any current speech since user explicitly requested this.
  Future<void> speakDescription(String description) async {
    await _tts.stop(); // Interrupt Phase 1 alerts
    await _tts.setSpeechRate(0.45); // Slower for comprehension
    await _tts.speak(description);
    await _tts.setSpeechRate(0.55); // Restore alert speed
  }

  /// Speak a status message (e.g., "Processing scene")
  Future<void> speakStatus(String message) async {
    if (_isSpeaking) return;
    await _tts.speak(message);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  void dispose() {
    _tts.stop();
  }
}
