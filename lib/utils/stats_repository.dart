import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_enums.dart';

/// Level details for graph visualization
class LevelDetail {
  final int level;
  final int timeSeconds;
  final int mistakes;
  final bool isCompleted;

  LevelDetail({
    required this.level,
    required this.timeSeconds,
    required this.mistakes,
    required this.isCompleted,
  });
}

/// Category stats for Classic or Crazy Sudoku
class CategoryStats {
  final int levelsCompleted;
  final int totalLevels;
  final List<LevelDetail> levelDetails;
  final int avgTimeSeconds;
  final int bestTimeSeconds;
  final double avgMistakes;
  final bool isUnlocked;

  CategoryStats({
    required this.levelsCompleted,
    required this.totalLevels,
    required this.levelDetails,
    required this.avgTimeSeconds,
    required this.bestTimeSeconds,
    required this.avgMistakes,
    required this.isUnlocked,
  });

  double get completionPercentage =>
      totalLevels > 0 ? (levelsCompleted / totalLevels) * 100 : 0;

  String get formattedAvgTime {
    if (avgTimeSeconds == 0) return '--:--';
    final minutes = avgTimeSeconds ~/ 60;
    final seconds = avgTimeSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  String get formattedBestTime {
    if (bestTimeSeconds == 0) return '--:--';
    final minutes = bestTimeSeconds ~/ 60;
    final seconds = bestTimeSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

/// Repository for aggregating statistics
class StatsRepository {
  static const int levelsPerDifficulty = 50;
  
  static const List<Difficulty> allDifficulties = [
    Difficulty.easy,
    Difficulty.medium,
    Difficulty.hard,
    Difficulty.expert,
    Difficulty.master,
  ];

  // Classic Sudoku = Numbers mode only
  static const GameMode classicMode = GameMode.numbers;
  
  // Crazy Sudoku = Shapes mode (which includes combinations for medium+)
  static const GameMode crazyMode = GameMode.shapes;

  /// Get stats for Classic Sudoku at a specific difficulty and size
  static Future<CategoryStats> getClassicStats(Difficulty difficulty, SudokuSize size) async {
    return _getCategoryStats(classicMode, difficulty, size);
  }

  /// Get stats for Crazy Sudoku at a specific difficulty (size is determined by difficulty: Med/Hard=6x6, Easy=4x4?)
  /// Actually, keeping it simple for Crazy mode as per existing logic, or pass optional size.
  /// Crazy mode currently has fixed sizes per difficulty in game logic.
  static Future<CategoryStats> getCrazyStats(Difficulty difficulty) async {
    return _getCategoryStats(crazyMode, difficulty, null);
  }

  /// Internal method to get category stats
  static Future<CategoryStats> _getCategoryStats(
    GameMode mode,
    Difficulty difficulty,
    SudokuSize? size, // Nullable for Crazy mode where size is implicit or not tracked separately yet
  ) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Prefix construction - MUST MATCH ProgressRepository._prefix() format
    // Key format: {Difficulty}_{Mode}_level_{Level}
    // Note: size parameter is kept for API compatibility but not used in key
    String prefix = '${difficulty.name}_${mode.name}_level_';
    
    List<LevelDetail> levelDetails = [];
    int totalTime = 0;
    int bestTime = 0;
    int totalMistakes = 0;
    int completedCount = 0;
    
    for (int level = 1; level <= levelsPerDifficulty; level++) {
      final key = '$prefix$level';
      final isCompleted = prefs.getString(key) == 'completed';
      final time = prefs.getInt('${key}_time') ?? 0;
      final mistakes = prefs.getInt('${key}_mistakes') ?? 0;
      
      levelDetails.add(LevelDetail(
        level: level,
        timeSeconds: time,
        mistakes: mistakes,
        isCompleted: isCompleted,
      ));
      
      if (isCompleted) {
        completedCount++;
        totalTime += time;
        totalMistakes += mistakes;
        
        if (time > 0 && (bestTime == 0 || time < bestTime)) {
          bestTime = time;
        }
      }
    }
    
    // Check if difficulty is unlocked
    bool isUnlocked = true;
    if (difficulty == Difficulty.master) {
      // For Master unlock check, we need to check Expert count.
      // Key format matches ProgressRepository._prefix() exactly
      String expertPrefix = '${Difficulty.expert.name}_${mode.name}_level_';

      int expertCount = 0;
      for (int i = 1; i <= levelsPerDifficulty; i++) {
        if (prefs.getString('$expertPrefix$i') == 'completed') expertCount++;
      }
      isUnlocked = expertCount >= 3;
    }
    
    return CategoryStats(
      levelsCompleted: completedCount,
      totalLevels: levelsPerDifficulty,
      levelDetails: levelDetails,
      avgTimeSeconds: completedCount > 0 ? totalTime ~/ completedCount : 0,
      bestTimeSeconds: bestTime,
      avgMistakes: completedCount > 0 ? totalMistakes / completedCount : 0,
      isUnlocked: isUnlocked,
    );
  }

  /// Get total completed levels for a category
  static Future<int> getTotalCompleted(GameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    int total = 0;
    
    for (final difficulty in allDifficulties) {
      final prefix = '${difficulty.name}_${mode.name}_level_';
      for (int i = 1; i <= levelsPerDifficulty; i++) {
        if (prefs.getString('$prefix$i') == 'completed') total++;
      }
    }
    
    return total;
  }

  /// Reset all progress (Dangerous!)
  static Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      // Clear level status, time, mistakes, and saved games
      if (key.contains('_level_') || key.contains('current_game_')) {
        await prefs.remove(key);
      }
    }
  }
}
