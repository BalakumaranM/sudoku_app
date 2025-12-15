// Test to verify Statistics data separation (After Fix)
// Run with: flutter test test/statistics_logic_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Replicate Enums
enum GameMode { numbers, shapes, planets, cosmic }
enum Difficulty { easy, medium, hard, expert, master }
enum SudokuSize { mini, standard }

/* Replicate FIXED Logic */

String _fixedPrefix(GameMode mode, Difficulty difficulty, {SudokuSize? size}) {
  if (size == SudokuSize.mini) {
    return '${difficulty.name}_${mode.name}_mini_level_';
  }
  return '${difficulty.name}_${mode.name}_level_';
}

Future<void> completeLevel(int level, GameMode mode, Difficulty difficulty, SudokuSize size) async {
  final prefs = await SharedPreferences.getInstance();
  final String key = '${_fixedPrefix(mode, difficulty, size: size)}$level';
  await prefs.setString(key, 'completed');
  await prefs.setInt('${key}_time', 60);
}

Future<int> getCompletedCount(GameMode mode, Difficulty difficulty, SudokuSize size) async {
  final prefs = await SharedPreferences.getInstance();
  final String prefix = _fixedPrefix(mode, difficulty, size: size);
  int count = 0;
  for (int i = 1; i <= 50; i++) {
    if (prefs.getString('${prefix}$i') == 'completed') {
      count++;
    }
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Statistics Logic Separation (Post-Fix)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Completing Mini Level 1 does NOT update Standard stats', () async {
      // Complete Level 1 in MINI mode
      await completeLevel(1, GameMode.numbers, Difficulty.easy, SudokuSize.mini);
      
      // Check count for MINI (should be 1)
      final miniCount = await getCompletedCount(GameMode.numbers, Difficulty.easy, SudokuSize.mini);
      expect(miniCount, 1, reason: "Mini count should be 1");

      // Check count for STANDARD (should be 0)
      final standardCount = await getCompletedCount(GameMode.numbers, Difficulty.easy, SudokuSize.standard);
      expect(standardCount, 0, reason: "Standard count should be 0 (correctly separated)");
    });

    test('Completing Standard Level 1 does NOT update Mini stats', () async {
      // Complete Level 1 in STANDARD mode
      await completeLevel(1, GameMode.numbers, Difficulty.easy, SudokuSize.standard);
      
      // Check count for STANDARD (should be 1)
      final standardCount = await getCompletedCount(GameMode.numbers, Difficulty.easy, SudokuSize.standard);
      expect(standardCount, 1, reason: "Standard count should be 1");

      // Check count for MINI (should be 0)
      final miniCount = await getCompletedCount(GameMode.numbers, Difficulty.easy, SudokuSize.mini);
      expect(miniCount, 0, reason: "Mini count should be 0");
    });
  });
}
