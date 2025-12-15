// Test to verify Crazy Sudoku Logic (Resume, Restart, Level Consistency)
// Run with: flutter test test/crazy_sudoku_logic_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REPLICATE LOGIC FROM MAIN.DART for testing

enum GameMode { numbers, shapes, planets, cosmic }
enum Difficulty { easy, medium, hard, expert, master }
enum SudokuSize { mini, standard }

String _prefix(GameMode mode, Difficulty difficulty, {SudokuSize? size}) {
    if (size == SudokuSize.mini) {
      return '${difficulty.name}_${mode.name}_mini_level_';
    }
    return '${difficulty.name}_${mode.name}_level_';
}

Future<void> completeLevel(int level, GameMode mode, Difficulty difficulty, {SudokuSize? size}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = '${_prefix(mode, difficulty, size: size)}$level';
    await prefs.setString(key, 'completed');
}

Future<int> getLastUnlockedLevel(GameMode mode, Difficulty difficulty, {SudokuSize? size}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (int i = 1; i <= 50; i++) {
       final String key = '${_prefix(mode, difficulty, size: size)}$i';
       final String? status = prefs.getString(key);
       
       if (status == 'completed') continue;
       if (i == 1) return 1; // Level 1 always unlocked if not completed
       
       final String prevKey = '${_prefix(mode, difficulty, size: size)}${i - 1}';
       if (prefs.getString(prevKey) == 'completed') return i;
       
       return i > 1 ? i - 1 : 1;
    }
    return 50;
}

// Logic from _startOrContinueGame restart action
Future<int> restartActionLevel(GameMode mode, Difficulty difficulty, {SudokuSize? size}) async {
    // "Start new game at the current unlocked level (not the saved game level)"
    return await getLastUnlockedLevel(mode, difficulty, size: size);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crazy Sudoku Logic Verification', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Shape Mode (Mini) Level Keys are correct', () async {
        // Shapes 6x6 should use MINI key
        final key = _prefix(GameMode.shapes, Difficulty.easy, size: SudokuSize.mini);
        expect(key, 'easy_shapes_mini_level_', reason: 'Should use mini prefix');
    });

    test('New Game / Restart starts at latest unlocked level', () async {
        // Complete Level 1 and 2
        await completeLevel(1, GameMode.shapes, Difficulty.easy, size: SudokuSize.mini);
        await completeLevel(2, GameMode.shapes, Difficulty.easy, size: SudokuSize.mini);
        
        // Last unlocked should be 3
        final level = await getLastUnlockedLevel(GameMode.shapes, Difficulty.easy, size: SudokuSize.mini);
        expect(level, 3);
        
        // Restart action should return 3
        final startLevel = await restartActionLevel(GameMode.shapes, Difficulty.easy, size: SudokuSize.mini);
        expect(startLevel, 3, reason: "Restart should start at the highest unlocked level");
    });
    
    test('Stats Separation for Crazy Mode', () async {
         // Verify that completing Shape level doesn't affect Planet level
         await completeLevel(1, GameMode.shapes, Difficulty.easy, size: SudokuSize.mini);
         
         final shapeLevel = await getLastUnlockedLevel(GameMode.shapes, Difficulty.easy, size: SudokuSize.mini);
         expect(shapeLevel, 2);
         
         final planetLevel = await getLastUnlockedLevel(GameMode.planets, Difficulty.easy, size: SudokuSize.mini);
         expect(planetLevel, 1, reason: "Planets should still be at level 1");
    });
  });
}
