import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Audio service for chess sounds
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Use a single player and play different sources as needed
  final AudioPlayer _player = AudioPlayer();

  bool _isInitialized = false;
  bool _enabled = true;

  bool get isEnabled => _enabled;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
      debugPrint('AudioService initialized');
    } catch (e) {
      debugPrint('AudioService init error: $e');
    }
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  Future<void> _playSound(String soundFile) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      debugPrint('Error playing $soundFile: $e');
    }
  }

  Future<void> playMove() async {
    await _playSound('move.wav');
  }

  Future<void> playCapture() async {
    await _playSound('capture.wav');
  }

  Future<void> playCheck() async {
    await _playSound('check.wav');
  }

  Future<void> playCastle() async {
    await _playSound('castle.wav');
  }

  Future<void> playIllegal() async {
    await _playSound('illegal.wav');
  }

  Future<void> playEndLevel() async {
    await _playSound('end-level.wav');
  }

  /// Play appropriate sound based on move type
  Future<void> playMoveSound({
    required bool isCapture,
    required bool isCheck,
    required bool isCastle,
    required bool isCheckmate,
  }) async {
    if (isCheckmate) {
      await playEndLevel();
    } else if (isCheck) {
      await playCheck();
    } else if (isCastle) {
      await playCastle();
    } else if (isCapture) {
      await playCapture();
    } else {
      await playMove();
    }
  }

  void dispose() {
    _player.dispose();
  }
}

/// Provider for audio service
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.initialize();
  return service;
});
