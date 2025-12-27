import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vibration/vibration.dart';

/// High-performance audio service using SoLoud engine
/// Provides instant, non-blocking sound playback for chess moves
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  SoLoud? _soloud;
  bool _isInitialized = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool? _hasVibrator;

  // Pre-loaded sound handles
  final Map<String, AudioSource> _sounds = {};

  // Sound file mappings
  static const _soundFiles = {
    'move': 'assets/sounds/move.wav',
    'capture': 'assets/sounds/capture.wav',
    'check': 'assets/sounds/check.wav',
    'castle': 'assets/sounds/castle.wav',
    'illegal': 'assets/sounds/illegal.wav',
    'end-level': 'assets/sounds/end-level.wav',
  };

  // Volume settings for each sound type
  static const _volumes = {
    'move': 0.7,
    'capture': 0.7,
    'check': 0.5,
    'castle': 0.7,
    'illegal': 0.5,
    'end-level': 0.6,
  };

  bool get isInitialized => _isInitialized;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// Initialize the audio engine and preload all sounds
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _soloud = SoLoud.instance;
      await _soloud!.init();

      // Preload all sounds
      for (final entry in _soundFiles.entries) {
        try {
          final source = await _soloud!.loadAsset(entry.value);
          _sounds[entry.key] = source;
        } catch (e) {
          debugPrint('Failed to load sound ${entry.key}: $e');
        }
      }

      // Check vibration capability once
      _hasVibrator = await Vibration.hasVibrator();

      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioService init error: $e');
      _isInitialized = false;
    }
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  /// Play a sound instantly - non-blocking, fire-and-forget
  void _playSound(String soundKey, {double? volumeOverride}) {
    if (!_soundEnabled || !_isInitialized) return;

    final source = _sounds[soundKey];
    if (source == null) return;

    final volume = volumeOverride ?? _volumes[soundKey] ?? 0.7;

    // SoLoud play is instant and non-blocking
    try {
      _soloud?.play(source, volume: volume);
    } catch (e) {
      debugPrint('Error playing $soundKey: $e');
    }
  }

  /// Trigger vibration - instant, non-blocking
  void _vibrate() {
    if (!_vibrationEnabled || _hasVibrator != true) return;

    // Short vibration for move feedback
    Vibration.vibrate(duration: 50, amplitude: 128);
  }

  // Public sound methods
  void playMove() => _playSound('move');
  void playCapture() => _playSound('capture');
  void playCheck() => _playSound('check');
  void playCastle() => _playSound('castle');
  void playIllegal() => _playSound('illegal');
  void playEndLevel() => _playSound('end-level');

  /// Play sound and vibrate for a move - instant feedback
  void playMoveWithHaptic({
    required bool isCapture,
    required bool isCheck,
    required bool isCastle,
    required bool isCheckmate,
  }) {
    // Vibrate first (fastest feedback)
    _vibrate();

    // Then play appropriate sound
    if (isCheckmate) {
      playEndLevel();
    } else if (isCheck) {
      playCheck();
    } else if (isCastle) {
      playCastle();
    } else if (isCapture) {
      playCapture();
    } else {
      playMove();
    }
  }

  /// Legacy method for compatibility
  void playMoveSound({
    required bool isCapture,
    required bool isCheck,
    required bool isCastle,
    required bool isCheckmate,
  }) {
    playMoveWithHaptic(
      isCapture: isCapture,
      isCheck: isCheck,
      isCastle: isCastle,
      isCheckmate: isCheckmate,
    );
  }

  /// Just vibrate without sound
  void vibrate() => _vibrate();

  void dispose() {
    for (final source in _sounds.values) {
      _soloud?.disposeSource(source);
    }
    _sounds.clear();
    _soloud?.deinit();
    _isInitialized = false;
  }
}

/// Provider for audio service
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.initialize();
  return service;
});
