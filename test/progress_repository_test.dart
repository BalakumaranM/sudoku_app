// Standalone test that simulates ProgressRepository logic
// Run with: flutter test test/progress_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

// Replicate the enums and logic from main.dart
enum GameMode { numbers, shapes, planets, cosmic }
enum Difficulty { easy, medium, hard, expert, master }
enum LevelStatus { locked, unlocked, completed }

// Replicate ProgressRepository logic exactly (WITH THE FIX)
String _prefix(GameMode mode, Difficulty difficulty) {
  return '${difficulty.name}_${mode.name}_level_';
}

Future<LevelStatus> getLevelStatus(int level, GameMode mode, Difficulty difficulty) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = '${_prefix(mode, difficulty)}$level';
  final String? status = prefs.getString(key);
  
  // First check if this level is completed
  if (status == 'completed') return LevelStatus.completed;
  
  // Level 1 is always unlocked (never locked) if not completed
  if (level == 1) return LevelStatus.unlocked;
  
  // For other levels, check if previous level is completed
  final String prevKey = '${_prefix(mode, difficulty)}${level - 1}';
  if (prefs.getString(prevKey) == 'completed') return LevelStatus.unlocked;
  
  return LevelStatus.locked;
}

Future<int> getLastUnlockedLevel(GameMode mode, Difficulty difficulty) async {
  for (int i = 1; i <= 50; i++) {
    final status = await getLevelStatus(i, mode, difficulty);
    if (status == LevelStatus.locked) return math.max(1, i - 1);
    if (status == LevelStatus.unlocked) return i;
  }
  return 50;
}

Future<void> completeLevel(int level, GameMode mode, Difficulty difficulty) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = '${_prefix(mode, difficulty)}$level';
  await prefs.setString(key, 'completed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressRepository Logic Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Key format is correct', () {
      expect(_prefix(GameMode.numbers, Difficulty.easy), 'easy_numbers_level_');
    });

    test('Initial state - Level 1 should be unlocked', () async {
      final status = await getLevelStatus(1, GameMode.numbers, Difficulty.easy);
      expect(status, LevelStatus.unlocked);
    });

    test('Initial state - Level 2 should be locked', () async {
      final status = await getLevelStatus(2, GameMode.numbers, Difficulty.easy);
      expect(status, LevelStatus.locked);
    });

    test('After completing Level 1, it should be marked completed', () async {
      await completeLevel(1, GameMode.numbers, Difficulty.easy);

      final level1Status = await getLevelStatus(1, GameMode.numbers, Difficulty.easy);
      expect(level1Status, LevelStatus.completed);
    });

    test('After completing Level 1, Level 2 should be unlocked', () async {
      await completeLevel(1, GameMode.numbers, Difficulty.easy);

      final level2Status = await getLevelStatus(2, GameMode.numbers, Difficulty.easy);
      expect(level2Status, LevelStatus.unlocked);
    });

    test('getLastUnlockedLevel returns 1 initially', () async {
      int unlocked = await getLastUnlockedLevel(GameMode.numbers, Difficulty.easy);
      expect(unlocked, 1);
    });

    test('getLastUnlockedLevel returns 2 after completing Level 1', () async {
      await completeLevel(1, GameMode.numbers, Difficulty.easy);
      int unlocked = await getLastUnlockedLevel(GameMode.numbers, Difficulty.easy);
      expect(unlocked, 2);
    });

    test('getLastUnlockedLevel returns 3 after completing Levels 1 and 2', () async {
      await completeLevel(1, GameMode.numbers, Difficulty.easy);
      await completeLevel(2, GameMode.numbers, Difficulty.easy);
      int unlocked = await getLastUnlockedLevel(GameMode.numbers, Difficulty.easy);
      expect(unlocked, 3);
    });

    test('SharedPreferences persists data correctly', () async {
      await completeLevel(1, GameMode.numbers, Difficulty.easy);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('easy_numbers_level_1'), 'completed');
    });
  });
}
