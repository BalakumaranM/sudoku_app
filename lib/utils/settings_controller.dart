import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static final SettingsController _instance = SettingsController._internal();
  factory SettingsController() => _instance;

  SettingsController._internal();

  String _animationSpeed = 'Normal';
  String _colorScheme = 'Default';
  bool _initialized = false;

  String get animationSpeed => _animationSpeed;
  String get colorScheme => _colorScheme;

  // Animation duration multiplier
  double get animationMultiplier {
    switch (_animationSpeed) {
      case 'Slow': return 1.5;
      case 'Fast': return 0.5;
      default: return 1.0;
    }
  }

  bool _hapticsEnabled = true;
  bool _debugToolsEnabled = false;

  bool get hapticsEnabled => _hapticsEnabled;
  bool get debugToolsEnabled => _debugToolsEnabled;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _animationSpeed = prefs.getString('animation_speed') ?? 'Normal';
    _colorScheme = prefs.getString('color_scheme') ?? 'Default';
    _hapticsEnabled = prefs.getBool('haptic_feedback') ?? true;
    _debugToolsEnabled = prefs.getBool('debug_tools_enabled') ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setAnimationSpeed(String speed) async {
    _animationSpeed = speed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('animation_speed', speed);
    notifyListeners();
  }

  Future<void> setColorScheme(String scheme) async {
    _colorScheme = scheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('color_scheme', scheme);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_feedback', enabled);
    notifyListeners();
  }

  Future<void> setDebugToolsEnabled(bool enabled) async {
    _debugToolsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_tools_enabled', enabled);
    notifyListeners();
  }
}
