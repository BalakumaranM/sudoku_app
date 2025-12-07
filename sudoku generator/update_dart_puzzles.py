import json
import os

OUTPUT_DIR = "output"
DART_FILE = "../lib/data/classic_puzzles.dart"

def load_puzzles(filename):
    filepath = os.path.join(OUTPUT_DIR, filename)
    if not os.path.exists(filepath):
        print(f"Warning: {filename} not found, skipping.")
        return []
    with open(filepath, 'r') as f:
        data = json.load(f)
        return data['levels']

def format_puzzles(puzzles):
    dart_code = ""
    for p in puzzles:
        dart_code += f"    PuzzleData('{p['puzzle']}', '{p['solution']}'),\n"
    return dart_code

def main():
    # Load all puzzle data
    mini_easy = load_puzzles("mini_easy.json")
    mini_medium = load_puzzles("mini_medium.json")
    mini_hard = load_puzzles("mini_hard.json")
    mini_expert = load_puzzles("mini_expert.json")
    mini_master = load_puzzles("mini_master.json")
    
    std_easy = load_puzzles("standard_easy.json")
    std_medium = load_puzzles("standard_medium.json")
    std_hard = load_puzzles("standard_hard.json")
    std_expert = load_puzzles("standard_expert.json")
    std_master = load_puzzles("standard_master.json")

    dart_content = f"""import '../models/game_enums.dart';
import '../game_logic.dart';

/// Sudoku size: Mini (6x6) or Standard (9x9)
enum SudokuSize {{ mini, standard }}

class PuzzleData {{
  final String puzzle;
  final String solution;
  const PuzzleData(this.puzzle, this.solution);
}}

/// Pre-loaded puzzle data for Classic Sudoku
class ClassicPuzzles {{
  /// Get a puzzle for classic sudoku
  static SudokuPuzzle getPuzzle(SudokuSize size, Difficulty difficulty, int levelNumber) {{
    final data = _getPuzzleData(size, difficulty, levelNumber);
    final gridSize = size == SudokuSize.mini ? 6 : 9;
    return SudokuPuzzle(
      solution: _stringToGrid(data.solution, gridSize),
      initialBoard: _stringToGrid(data.puzzle, gridSize),
      gridSize: gridSize,
    );
  }}

  static PuzzleData _getPuzzleData(SudokuSize size, Difficulty difficulty, int levelNumber) {{
    final map = size == SudokuSize.mini ? _miniPuzzles : _standardPuzzles;
    final puzzles = map[difficulty]!;
    final index = (levelNumber - 1).clamp(0, puzzles.length - 1);
    return puzzles[index];
  }}

  static List<List<int>> _stringToGrid(String str, int size) {{
    return List.generate(size, (row) =>
      List.generate(size, (col) => int.parse(str[row * size + col])));
  }}

  static final Map<Difficulty, List<PuzzleData>> _miniPuzzles = {{
    Difficulty.easy: _miniEasyPuzzles,
    Difficulty.medium: _miniMediumPuzzles,
    Difficulty.hard: _miniHardPuzzles,
    Difficulty.expert: _miniExpertPuzzles,
    Difficulty.master: _miniMasterPuzzles,
  }};

  static final Map<Difficulty, List<PuzzleData>> _standardPuzzles = {{
    Difficulty.easy: _standardEasyPuzzles,
    Difficulty.medium: _standardMediumPuzzles,
    Difficulty.hard: _standardHardPuzzles,
    Difficulty.expert: _standardExpertPuzzles,
    Difficulty.master: _standardMasterPuzzles,
  }};

  // MINI EASY - {len(mini_easy)} puzzles (6x6)
  static const List<PuzzleData> _miniEasyPuzzles = [
{format_puzzles(mini_easy)}  ];

  // MINI MEDIUM - {len(mini_medium)} puzzles (6x6)
  static const List<PuzzleData> _miniMediumPuzzles = [
{format_puzzles(mini_medium)}  ];

  // MINI HARD - {len(mini_hard)} puzzles (6x6)
  static const List<PuzzleData> _miniHardPuzzles = [
{format_puzzles(mini_hard)}  ];

  // MINI EXPERT - {len(mini_expert)} puzzles (6x6)
  static const List<PuzzleData> _miniExpertPuzzles = [
{format_puzzles(mini_expert)}  ];

  // MINI MASTER - {len(mini_master)} puzzles (6x6)
  static const List<PuzzleData> _miniMasterPuzzles = [
{format_puzzles(mini_master)}  ];

  // STANDARD EASY - {len(std_easy)} puzzles (9x9)
  static const List<PuzzleData> _standardEasyPuzzles = [
{format_puzzles(std_easy)}  ];

  // STANDARD MEDIUM - {len(std_medium)} puzzles (9x9)
  static const List<PuzzleData> _standardMediumPuzzles = [
{format_puzzles(std_medium)}  ];

  // STANDARD HARD - {len(std_hard)} puzzles (9x9)
  static const List<PuzzleData> _standardHardPuzzles = [
{format_puzzles(std_hard)}  ];

  // STANDARD EXPERT - {len(std_expert)} puzzles (9x9)
  static const List<PuzzleData> _standardExpertPuzzles = [
{format_puzzles(std_expert)}  ];

  // STANDARD MASTER - {len(std_master)} puzzles (9x9)
  static const List<PuzzleData> _standardMasterPuzzles = [
{format_puzzles(std_master)}  ];

}}
"""
    
    with open(DART_FILE, 'w') as f:
        f.write(dart_content)
    print(f"Successfully updated {DART_FILE}")

if __name__ == "__main__":
    main()
