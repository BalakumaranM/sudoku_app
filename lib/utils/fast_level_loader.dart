import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../game_logic.dart';

class CrazyLevelLoader {
  /// Loads a Crazy Sudoku level from assets.
  /// [difficultyMode] should be 'medium', 'hard', 'expert', or 'master'.
  /// [levelIndex] is 0-based.
  static Future<CombinedPuzzle> loadLevel(String difficultyMode, int levelIndex, {AssetBundle? bundle}) async {
    final String filename = 'assets/levels/crazy_${difficultyMode.toLowerCase()}.json';
    try {
      final AssetBundle assetBundle = bundle ?? rootBundle;
      final String jsonString = await assetBundle.loadString(filename);
      final List<dynamic> levelsJson = json.decode(jsonString);
      
      if (levelsJson.isEmpty) {
        throw Exception('No levels found in $filename');
      }

      // Wrap around index
      final Map<String, dynamic> levelData = levelsJson[levelIndex % levelsJson.length];
      
      return _parseLevel(levelData, difficultyMode);
    } catch (e) {
      debugPrint('Error loading crazy level: $e');
      // Fallback or rethrow. For now, we rely on the caller to handle or we fallback to generator?
      // But we want to enforce this loader.
      rethrow;
    }
  }

  static CombinedPuzzle _parseLevel(Map<String, dynamic> data, String mode) {
    final List<dynamic> layers = data['layers'];
    final int size = data['size'];
    
    // Identify layers
    // Layer 0: Shapes
    // Layer 1: Colors
    // Layer 2: Numbers (if present)
    
    final List<List<int>> shapeInitial = _gridFromDynamic(layers[0]['initial']);
    final List<List<int>> shapeSolution = _gridFromDynamic(layers[0]['solution']);
    
    final List<List<int>> colorInitial = _gridFromDynamic(layers[1]['initial']);
    final List<List<int>> colorSolution = _gridFromDynamic(layers[1]['solution']);
    
    List<List<int>>? numberInitial;
    List<List<int>>? numberSolution;
    
    if (layers.length > 2) {
      numberInitial = _gridFromDynamic(layers[2]['initial']);
      numberSolution = _gridFromDynamic(layers[2]['solution']);
    }

    // Build Solution Grid AND Initial Board
    // In Joint Superimposed, clues are shared. If shapeInitial[r][c] != 0, then ALL are clues.
    // If it is 0, ALL are empty (to be solved).
    
    final List<List<CombinedCell>> solution = List.generate(size, (r) {
      return List.generate(size, (c) {
        return CombinedCell(
          shapeId: shapeSolution[r][c],
          colorId: colorSolution[r][c],
          numberId: numberSolution?[r][c],
          isFixed: true // In solution grid, everything is conceptually "fixed" or just the values matter
        );
      });
    });

    final List<List<CombinedCell>> initialBoard = List.generate(size, (r) {
      return List.generate(size, (c) {
        // Check if this cell is a Fixed Clue
        // We can check any layer's initial grid since they share positions.
        final bool isClue = shapeInitial[r][c] != 0;
        
        if (isClue) {
           return CombinedCell(
            shapeId: shapeInitial[r][c],
            colorId: colorInitial[r][c],
            numberId: numberInitial?[r][c],
            isFixed: true,
          );
        } else {
          // Empty cell to be solved
          // combinedCell values should be null for "unfilled"
          // BUT CombinedCell constructor doesn't accept nulls easily if we want to show it's empty?
          // Actually CombinedCell fields are nullable: final int? shapeId;
          return CombinedCell(
            shapeId: null,
            colorId: null,
            numberId: null,
            isFixed: false,
          );
        }
      });
    });

    // Determine a dummy selectedElement, or pick one.
    // The current game logic might rely on it. Let's pick 'shape' or 'number' depending on mode.
    ElementType selected = ElementType.shape;
    if (mode == 'hard' || mode == 'expert' || mode == 'master') {
      // Maybe random? or just default to shape. 
      // The user interacts with the draft cell to set all 3 properties anyway.
    }

    return CombinedPuzzle(
      solution: solution,
      initialBoard: initialBoard,
      selectedElement: selected,
      gridSize: size,
    );
  }

  static List<List<int>> _gridFromDynamic(List<dynamic> list) {
    return list.map((row) => (row as List).map((val) => val as int).toList()).toList();
  }
}
