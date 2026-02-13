/// EcoSight — Spatial Audio Manager
/// Plays directional warning beeps — left, center, or right.
library;

import 'package:audioplayers/audioplayers.dart';

class SpatialAudioManager {
  // We use separate players for left/right panning
  final AudioPlayer _player = AudioPlayer();

  Future<void> init() async {
    try {
      // Configure global audio context for notifications/accessibility
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
      ));
    } catch (e) {
      print('[AUDIO] AudioContext config failed (non-fatal): $e');
    }

    // Pre-configure player
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1.0);
  }

  /// Play a warning beep with directional panning.
  /// direction: "left", "center", or "right"
  Future<void> playWarningBeep(String direction) async {
    try {
      // Set stereo balance: -1.0 = full left, 0.0 = center, 1.0 = full right
      double balance = 0.0;
      switch (direction) {
        case 'left':
          balance = -1.0;
          break;
        case 'right':
          balance = 1.0;
          break;
        case 'center':
        default:
          balance = 0.0;
      }

      await _player.setBalance(balance);

      // Generate a short beep using a tone frequency
      // Using a bundled asset or a generated tone URL
      await _player.play(
        AssetSource('beep.wav'),
        volume: 0.8,
      );
    } catch (e) {
      print('[AUDIO] Error playing beep: $e');
    }
  }

  /// Play a softer notification sound for Phase 2 ready
  Future<void> playNotification() async {
    try {
      await _player.setBalance(0.0);
      await _player.play(AssetSource('notification.wav'), volume: 0.5);
    } catch (e) {
      print('[AUDIO] Error playing notification: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
