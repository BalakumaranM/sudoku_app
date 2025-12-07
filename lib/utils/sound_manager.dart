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
      _ambientEnabled = prefs.getBool('background_music') ?? true;
      _enabled = prefs.getBool('sound_effects') ?? true;
      
      if (_ambientEnabled) {
        // Don't await this, let it start in background
        playAmbientMusic();
      }
    } catch (e) {
      debugPrint('Error initializing SoundManager: $e');
    }
  }

  final AudioPlayer _player = AudioPlayer(); // For general effects
  final AudioPlayer _ambientPlayer = AudioPlayer(); // For music
  final AudioPlayer _clickPlayer = AudioPlayer(); // Dedicated for clicks
  
  bool _enabled = true;
  bool _ambientEnabled = true;
  bool _ambientPlaying = false;
  bool _ambientPaused = false; // Track if we paused it manually (e.g. lifecycle)
  
  // Volume control
  static const double _defaultAmbientVolume = 0.3;
  static const double _duckedAmbientVolume = 0.1;

  SoundManager._internal() {
    // Initialize players
    _player.setReleaseMode(ReleaseMode.stop);
    
    // Optimize click player for low latency
    _clickPlayer.setPlayerMode(PlayerMode.lowLatency);
    _clickPlayer.setReleaseMode(ReleaseMode.stop);
    // Preload click sound
    _clickPlayer.setSource(AssetSource('sounds/click.mp3'));
    
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    _ambientPlayer.setVolume(_defaultAmbientVolume);
  }

  /// Enable or disable sound effects
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Enable or disable ambient music
  void setAmbientEnabled(bool enabled) {
    _ambientEnabled = enabled;
    if (!enabled && _ambientPlaying) {
      stopAmbientMusic();
    }
  }

  /// Play ambient space drone music (looped)
  Future<void> playAmbientMusic() async {
    if (!_ambientEnabled) return;
    // If already playing, don't restart (prevents interruption)
    if (_ambientPlaying) return;
    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.setVolume(_defaultAmbientVolume);
      await _ambientPlayer.play(AssetSource('sounds/ambient.mp3'));
      _ambientPlaying = true;
      _ambientPaused = false;
    } catch (e) {
      // Sound file not found - silently fail
      _ambientPlaying = false;
    }
  }

  /// Stop ambient music completely
  Future<void> stopAmbientMusic() async {
    if (!_ambientPlaying) return;
    try {
      await _ambientPlayer.stop();
      _ambientPlaying = false;
      _ambientPaused = false;
    } catch (e) {
      // Ignore errors
    }
  }

  /// Pause ambient music (for app lifecycle - going to background)
  Future<void> pauseAmbientMusic() async {
    if (!_ambientPlaying || _ambientPaused) return;
    try {
      await _ambientPlayer.pause();
      _ambientPaused = true;
    } catch (e) {
      // Ignore errors
    }
  }

  /// Resume ambient music (for app lifecycle - returning to foreground)
  Future<void> resumeAmbientMusic() async {
    if (!_ambientPlaying || !_ambientPaused || !_ambientEnabled) return;
    try {
      await _ambientPlayer.resume();
      _ambientPaused = false;
    } catch (e) {
      // If resume fails, restart
      _ambientPlaying = false;
      _ambientPaused = false;
      await playAmbientMusic();
    }
  }

  /// Set ambient music volume (0.0 to 1.0) - non-blocking
  void _setAmbientVolumeNonBlocking(double volume) {
    if (!_ambientPlaying) return;
    try {
      _ambientPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      // Ignore errors
    }
  }

  /// Set ambient music volume (0.0 to 1.0)
  Future<void> setAmbientVolume(double volume) async {
    if (!_ambientPlaying) return;
    try {
      await _ambientPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      // Ignore errors
    }
  }

  /// Ensure ambient music is playing, resume if paused
  Future<void> ensureAmbientMusicPlaying() async {
    if (!_ambientEnabled) return;
    
    // If paused due to lifecycle, resume
    if (_ambientPaused) {
      await resumeAmbientMusic();
      return;
    }
    
    if (_ambientPlaying) {
      // Verify it's actually playing, resume if paused
      try {
        final state = _ambientPlayer.state;
        if (state != PlayerState.playing) {
          await _ambientPlayer.resume();
          // Wait a moment and verify resume actually worked
          await Future.delayed(const Duration(milliseconds: 100));
          final newState = _ambientPlayer.state;
          if (newState != PlayerState.playing) {
            // Resume failed, force restart
            _ambientPlaying = false;
            await playAmbientMusic();
            return;
          }
        }
        // Restore volume to default in case it was ducked
        await setAmbientVolume(_defaultAmbientVolume);
      } catch (e) {
        // If resume fails, restart
        _ambientPlaying = false;
        await playAmbientMusic();
      }
      return;
    }
    await playAmbientMusic();
  }

  /// Play a button click sound with ambient music ducking
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

  /// Play a row/column/block completion sound
  void playCompletionSound() {
    if (!_enabled) return;
    _player.play(AssetSource('sounds/completion.mp3')).catchError((e) {});
  }
}
