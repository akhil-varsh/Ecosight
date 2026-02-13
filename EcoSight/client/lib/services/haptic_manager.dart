/// EcoSight — Haptic Feedback Manager
/// Provides tactile warning patterns via phone vibration motor.
library;

import 'package:vibration/vibration.dart';

class HapticManager {
  bool _hasVibrator = false;

  Future<void> init() async {
    _hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!_hasVibrator) {
      print('[HAPTIC] No vibration motor detected');
    }
  }

  /// Single short pulse — general awareness
  Future<void> pulseLight() async {
    if (!_hasVibrator) return;
    await Vibration.vibrate(duration: 100);
  }

  /// Double pulse — hazard detected nearby
  Future<void> pulseWarning() async {
    if (!_hasVibrator) return;
    // Pattern: vibrate 200ms, pause 100ms, vibrate 200ms
    await Vibration.vibrate(pattern: [0, 200, 100, 200]);
  }

  /// Triple rapid pulse — DANGER, very close
  Future<void> pulseDanger() async {
    if (!_hasVibrator) return;
    await Vibration.vibrate(pattern: [0, 150, 80, 150, 80, 150]);
  }

  /// Long steady vibration — Phase 2 processing feedback
  Future<void> pulseProcessing() async {
    if (!_hasVibrator) return;
    await Vibration.vibrate(duration: 500);
  }

  /// Choose vibration intensity based on distance
  Future<void> vibrateForDistance(double distance) async {
    if (distance < 1.0) {
      await pulseDanger();      // Danger zone: < 1m
    } else if (distance < 2.5) {
      await pulseWarning();     // Warning zone: 1-2.5m
    } else {
      await pulseLight();       // Awareness zone: > 2.5m
    }
  }
}
