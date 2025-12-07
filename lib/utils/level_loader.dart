import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/game_enums.dart';
import '../game_logic.dart';

/// Level data from JSON
class LevelData {
  final int id;
  final String puzzle;
  final String solution;
  final int clues;

  LevelData({
    required this.id,
    required this.puzzle,
    required this.solution,
    required this.clues,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    return LevelData(
      id: json['id'] as int,
      puzzle: json['puzzle'] as String,
      solution: json['solution'] as String,
      clues: json['clues'] as int,
    );
  }
}

/// Loads pre-generated Sudoku puzzles from assets
class LevelLoader {
  static final Map<String, List<LevelData>> _cache = {};

  /// Get asset path for difficulty
  static String _getAssetPath(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 'assets/levels/classic_easy.json';
      case Difficulty.medium:
        return 'assets/levels/classic_medium.json';
      case Difficulty.hard:
        return 'assets/levels/classic_hard.json';
      case Difficulty.expert:
        return 'assets/levels/classic_expert.json';
      case Difficulty.master:
        return 'assets/levels/classic_master.json';
    }
  }

  /// Load all levels for a difficulty
  static Future<List<LevelData>> loadLevels(Difficulty difficulty) async {
    final path = _getAssetPath(difficulty);
    
    // Check cache
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }
    
    try {
      final String jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> levelsJson = data['levels'] as List<dynamic>;
      
      final levels = levelsJson.map((l) => LevelData.fromJson(l as Map<String, dynamic>)).toList();
      _cache[path] = levels;
      return levels;
    } catch (e) {
      print('Error loading levels: $e');
      return [];
    }
  }

  /// Load a specific level
  static Future<LevelData?> loadLevel(Difficulty difficulty, int levelNumber) async {
    final levels = await loadLevels(difficulty);
    if (levelNumber < 1 || levelNumber > levels.length) {
      return null;
    }
    return levels[levelNumber - 1];
  }

  /// Convert LevelData to SudokuPuzzle for game
  static SudokuPuzzle toSudokuPuzzle(LevelData data, int gridSize) {
    final List<List<int>> initialBoard = _stringToGrid(data.puzzle, gridSize);
    final List<List<int>> solution = _stringToGrid(data.solution, gridSize);
    
    return SudokuPuzzle(
      solution: solution,
      initialBoard: initialBoard,
      gridSize: gridSize,
    );
  }

  /// Convert flat string to 2D grid
  static List<List<int>> _stringToGrid(String str, int size) {
    final List<List<int>> grid = [];
    for (int row = 0; row < size; row++) {
      final List<int> rowData = [];
      for (int col = 0; col < size; col++) {
        final index = row * size + col;
        rowData.add(int.parse(str[index]));
      }
      grid.add(rowData);
    }
    return grid;
  }

  /// Get grid size for difficulty
  static int getGridSize(Difficulty difficulty) {
    return difficulty == Difficulty.easy ? 6 : 9;
  }

  /// Clear cache (for testing)
  static void clearCache() {
    _cache.clear();
  }
}
