import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioFeedbackService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  DateTime? _lastVibrate;
  DateTime? _lastRotateWarning;
  bool _isDisposed = false;

  Future<void> _vibrateThreeTimes() async {
    for (int i = 0; i < 3; i++) {
      if (_isDisposed) return;
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _playSound(String fileName) async {
    if (_isDisposed) return;
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('audio/$fileName'));
  }

  Future<void> playIntro() async {
    try {
      if (_isDisposed) return;
      await Future.delayed(const Duration(milliseconds: 1300));

      if (_isDisposed) return;
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      // รอบ 1
      await _audioPlayer.play(AssetSource('audio/camera_is_ready.mp3'));
      await _audioPlayer.onPlayerComplete.first;

      await Future.delayed(const Duration(seconds: 2));
      if (_isDisposed) return;

      // รอบ 2
      await _audioPlayer.play(AssetSource('audio/camera_is_ready.mp3'));
    } catch (e) {
      debugPrint("Error playing intro audio: $e");
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  void triggerHapticLight() {
    HapticFeedback.selectionClick();
  }

  Future<void> playFoundDate() async {
    final now = DateTime.now();

    if (_lastVibrate == null || now.difference(_lastVibrate!).inSeconds >= 3) {
      debugPrint(">>> FOUND! VIBRATE RAPIDLY !!! <<<");

      await stop();

      await _vibrateThreeTimes();

      _lastVibrate = now;
    }
  }

  Future<void> playRotateWarning() async {
    final now = DateTime.now();
    if (_lastRotateWarning == null ||
        now.difference(_lastRotateWarning!).inSeconds >= 4) {
      await _vibrateThreeTimes();

      if (_audioPlayer.state != PlayerState.playing) {
        debugPrint(">>> WRONG ANGLE: Playing warning sound");
        await _audioPlayer.play(AssetSource('audio/rotate_warning.mp3'));
      }
      _lastRotateWarning = now;
    }
  }

  Future<void> playFlashOn() async {
    await _playSound('flashlight_on.mp3');
  }

  Future<void> playFlashOff() async {
    await _playSound('flashlight_off.mp3');
  }

  void dispose() {
    _isDisposed = true;
    _audioPlayer.dispose();
  }
}
