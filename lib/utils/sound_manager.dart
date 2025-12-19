import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages sound effects and ambient music for the app
class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('sound_effects') ?? true;
    } catch (e) {
      debugPrint('Error initializing SoundManager: $e');
    }
  }

  final AudioPlayer _player = AudioPlayer(); // For general effects
  final AudioPlayer _clickPlayer = AudioPlayer(); // Dedicated for clicks
  
  bool _enabled = true;

  SoundManager._internal() {
    // Initialize players
    _player.setReleaseMode(ReleaseMode.stop);
    
    // Optimize click player for low latency
    _clickPlayer.setPlayerMode(PlayerMode.lowLatency);
    _clickPlayer.setReleaseMode(ReleaseMode.stop);
    // Preload click sound
    _clickPlayer.setSource(AssetSource('sounds/click.mp3'));
  }

  /// Enable or disable sound effects
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Play a button click sound
  void playClick() {
    if (!_enabled) return;
    
    // Fire and forget - instant playback
    if (_clickPlayer.state == PlayerState.playing) {
      _clickPlayer.stop().then((_) => _clickPlayer.resume());
    } else {
      _clickPlayer.resume();
    }
  }

  /// Play a locked level sound
  void playLocked() {
    if (!_enabled) return;
    _player.play(AssetSource('sounds/locked.mp3')).catchError((e) {});
  }

  /// Play a game start sound
  void playGameStart() {
    if (!_enabled) return;
    _player.play(AssetSource('sounds/game_start.mp3')).catchError((e) {});
  }

  /// Play a win sound
  void playWinSound() {
    if (!_enabled) return;
    _player.play(AssetSource('sounds/win.mp3')).catchError((e) {});
  }

  /// Play a success sound (correct input)
  void playSuccessSound() {
    if (!_enabled) return;
    _player.play(AssetSource('sounds/success.mp3')).catchError((e) {});
  }

  /// Play a completion sound
  void playCompletionSound() {
    if (!_enabled) return;
    _player.play(AssetSource('sounds/completion.mp3')).catchError((e) {});
  }

  /// Play an error sound (reusing locked sound for now)
  void playErrorSound() {
    if (!_enabled) return;
    _player.play(AssetSource('sounds/locked.mp3')).catchError((e) {});
  }
}
