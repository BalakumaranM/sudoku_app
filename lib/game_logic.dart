import 'dart:math';

// Import Difficulty from main.dart - will be moved to a shared file later
// For now, using int: 0=easy, 1=medium, 2=hard, 3=veryHard (reserved)

enum ElementType { shape, color, number }

class CombinedCell {
  static const Object _sentinel = Object();

  CombinedCell({
    this.shapeId,
    this.colorId,
    this.numberId,
    this.isFixed = false,
  });

  int? shapeId; // 1-gridSize
  int? colorId; // 1-gridSize
  int? numberId; // 1-gridSize
  bool isFixed;

  CombinedCell copyWith({
    Object? shapeId = _sentinel,
    Object? colorId = _sentinel,
    Object? numberId = _sentinel,
    bool? isFixed,
  }) {
    return CombinedCell(
      shapeId: identical(shapeId, _sentinel)
          ? this.shapeId
          : shapeId as int?,
      colorId: identical(colorId, _sentinel)
          ? this.colorId
          : colorId as int?,
      numberId: identical(numberId, _sentinel)
          ? this.numberId
          : numberId as int?,
      isFixed: isFixed ?? this.isFixed,
    );
  }
}

class CombinedPuzzle {
  CombinedPuzzle({
    required this.solution,
    required this.initialBoard,
    required this.selectedElement,
    required this.gridSize,
  });

  final List<List<CombinedCell>> solution;
  final List<List<CombinedCell>> initialBoard;
  final ElementType selectedElement;
  final int gridSize;
}

/// Wraps the generated puzzle and its solved counterpart.
class SudokuPuzzle {
  SudokuPuzzle({
    required this.solution,
    required this.initialBoard,
    required this.gridSize,
  });

  /// Completed grid without zeros.
  final List<List<int>> solution;

  /// Playable grid containing zeros for empty cells.
  final List<List<int>> initialBoard;
  final int gridSize;
}

/// Simple theme model used to associate shape IDs with custom assets.
class ThemeModel {
  ThemeModel({required this.shapeAssetPaths});

  factory ThemeModel.defaultTheme(int gridSize) {
    // Provide enough shapes for up to 9x9
    const allShapes = [
      'assets/shapes/triangle.png',
      'assets/shapes/square.png',
      'assets/shapes/rectangle.png',
      'assets/shapes/line.png',
      'assets/shapes/circle.png',
      'assets/shapes/diamond.png',
      'assets/shapes/pentagon.png',
      'assets/shapes/hexagon.png',
      'assets/shapes/star.png',
    ];
    // Fallback if we requested more than we have (though currently max is 9)
    if (gridSize > allShapes.length) {
       // Just repeat or handle error. For now, we assume max 9.
       return ThemeModel(shapeAssetPaths: allShapes); 
    }
    return ThemeModel(shapeAssetPaths: allShapes.sublist(0, gridSize));
  }

  final List<String> shapeAssetPaths;
}

/// Deterministic Sudoku generator keyed by [levelNumber] and [modeIndex].
/// modeIndex: 0=shapes, 1=colors, 2=numbers, 3=custom
class LevelGenerator {
  LevelGenerator(
    this.levelNumber, 
    this.modeIndex, 
    {
      this.gridSize = 6, 
      this.subgridRowSize = 2, 
      this.subgridColSize = 3
    }
  ) : _random = Random(_calculateSeed(levelNumber, modeIndex));

  final int levelNumber;
  final int modeIndex;
  final int gridSize;
  final int subgridRowSize;
  final int subgridColSize;
  final Random _random;

  static int _calculateSeed(int levelNumber, int modeIndex) {
    // Combine level and mode to ensure different puzzles for each mode
    return levelNumber * 1000 + modeIndex;
  }

  SudokuPuzzle generate() {
    final List<List<int>> solution = _buildSolvedBoard();
    final List<List<int>> puzzle = _removeCells(solution);
    return SudokuPuzzle(
      solution: _copyGrid(solution), 
      initialBoard: puzzle,
      gridSize: gridSize,
    );
  }

  List<List<int>> _buildSolvedBoard() {
    final List<List<int>> grid = List<List<int>>.generate(
      gridSize,
      (_) => List<int>.filled(gridSize, 0),
    );
    _fillGrid(grid, 0, 0);
    return grid;
  }

  bool _fillGrid(List<List<int>> grid, int row, int col) {
    if (row == gridSize) return true;
    final int nextRow = col == gridSize - 1 ? row + 1 : row;
    final int nextCol = (col + 1) % gridSize;

    final List<int> numbers = List<int>.generate(
      gridSize,
      (index) => index + 1,
    );
    numbers.shuffle(_random);

    for (final int number in numbers) {
      if (_isSafe(grid, row, col, number)) {
        grid[row][col] = number;
        if (_fillGrid(grid, nextRow, nextCol)) {
          return true;
        }
        grid[row][col] = 0;
      }
    }
    return false;
  }

  bool _isSafe(List<List<int>> grid, int row, int col, int number) {
    for (int i = 0; i < gridSize; i++) {
      if (grid[row][i] == number || grid[i][col] == number) {
        return false;
      }
    }
    final int boxRow = (row ~/ subgridRowSize) * subgridRowSize;
    final int boxCol = (col ~/ subgridColSize) * subgridColSize;
    for (int r = 0; r < subgridRowSize; r++) {
      for (int c = 0; c < subgridColSize; c++) {
        if (grid[boxRow + r][boxCol + c] == number) return false;
      }
    }
    return true;
  }

  int _blockIndex(int row, int col) {
    final int boxRow = row ~/ subgridRowSize;
    final int boxCol = col ~/ subgridColSize;
    final int blocksPerRow = gridSize ~/ subgridColSize;
    return boxRow * blocksPerRow + boxCol;
  }

  int _removalCount(int level) {
    // Scale removals based on grid size
    final int totalCells = gridSize * gridSize;
    final int minRemovals = (totalCells * 0.3).round(); // 30%
    final int maxRemovals = (totalCells * 0.55).round(); // 55%
    
    final double t = ((level.clamp(1, 100) - 1) / 99).toDouble();
    return (minRemovals + (maxRemovals - minRemovals) * t).round();
  }

  List<List<int>> _removeCells(List<List<int>> solution) {
    final List<List<int>> puzzle = _copyGrid(solution);
    final int toRemove = _removalCount(levelNumber);

    // Ensure a healthier distribution of clues:
    // - At least 2 givens in every row, column and block.
    // This keeps puzzles solvable and avoids very empty regions.
    const int minPerRow = 2;
    const int minPerCol = 2;
    const int minPerBlock = 2;

    final List<int> rowCounts = List<int>.filled(gridSize, gridSize);
    final List<int> colCounts = List<int>.filled(gridSize, gridSize);
    final int blockCount =
        (gridSize ~/ subgridRowSize) * (gridSize ~/ subgridColSize);
    final List<int> blockCounts = List<int>.filled(
      blockCount,
      subgridRowSize * subgridColSize,
    );

    final List<({int row, int col})> positions = [];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        positions.add((row: r, col: c));
      }
    }
    positions.shuffle(_random);

    int removed = 0;
    for (final ({int row, int col}) pos in positions) {
      if (removed >= toRemove) break;

      final int r = pos.row;
      final int c = pos.col;
      if (puzzle[r][c] == 0) continue;

      final int b = _blockIndex(r, c);
      if (rowCounts[r] <= minPerRow ||
          colCounts[c] <= minPerCol ||
          blockCounts[b] <= minPerBlock) {
        // Skip this cell to keep minimum clues per structure.
        continue;
      }

      puzzle[r][c] = 0;
      rowCounts[r]--;
      colCounts[c]--;
      blockCounts[b]--;
      removed++;
    }
    return puzzle;
  }

  List<List<int>> _copyGrid(List<List<int>> source) {
    return source.map((List<int> row) => List<int>.from(row)).toList();
  }
}

class CombinedPuzzleGenerator {
  CombinedPuzzleGenerator(
    this.levelNumber, 
    this.difficultyIndex,
    {
      this.gridSize = 6, 
      this.subgridRowSize = 2, 
      this.subgridColSize = 3
    }
  ) : _random = Random(levelNumber * 10000 + difficultyIndex);

  final int levelNumber;
  final int difficultyIndex; // 0=easy, 1=medium, 2=hard
  final int gridSize;
  final int subgridRowSize;
  final int subgridColSize;
  final Random _random;

  // Use same removal count logic as Easy mode for consistent difficulty progression
  int _removalCountForLevel(int level) {
    final int totalCells = gridSize * gridSize;
    final int minRemovals = (totalCells * 0.3).round();
    final int maxRemovals = (totalCells * 0.55).round();
    final double t = ((level.clamp(1, 100) - 1) / 99).toDouble();
    return (minRemovals + (maxRemovals - minRemovals) * t).round();
  }

  CombinedPuzzle generateCombined() {
    // Generate puzzles based on difficulty
    // Medium: only shapes and colors (no numbers)
    // Hard, Expert, Master: all three (shapes, colors, numbers)
    final List<List<int>> shapePuzzle = _generateSinglePuzzle(1);
    final List<List<int>> colorPuzzle = _generateSinglePuzzle(2);
    final bool includeNumbers = difficultyIndex != 1; // Skip numbers for Medium (index 1)
    final List<List<int>>? numberPuzzle = includeNumbers ? _generateSinglePuzzle(3) : null;

    // Combine into CombinedCell structure
    final List<List<CombinedCell>> solution = List<List<CombinedCell>>.generate(
      gridSize,
      (int row) => List<CombinedCell>.generate(
        gridSize,
        (int col) => CombinedCell(
          shapeId: shapePuzzle[row][col],
          colorId: colorPuzzle[row][col],
          numberId: numberPuzzle != null ? numberPuzzle[row][col] : null,
          isFixed: true,
        ),
      ),
    );

    // Randomly select which element to solve.
    // Medium: only shapes or colors (no numbers)
    // Hard, Expert, Master: all three
    final Random elementRandom = Random();
    final ElementType selectedElement;
    if (!includeNumbers) {
      // Medium: choose between shapes and colors only
      selectedElement = ElementType.values[elementRandom.nextInt(2)]; // 0=shape, 1=color
    } else {
      // Hard, Expert, Master: choose from all three
      selectedElement = ElementType.values[elementRandom.nextInt(3)];
    }

    // Create initial board by removing some cells based on selected element
    final List<List<CombinedCell>> initialBoard = _createInitialBoard(
      solution,
      selectedElement,
    );

    return CombinedPuzzle(
      solution: solution,
      initialBoard: initialBoard,
      selectedElement: selectedElement,
      gridSize: gridSize,
    );
  }

  List<List<int>> _generateSinglePuzzle(int seedOffset) {
    // Include difficultyIndex in the seed so Medium/Hard puzzles differ.
    final Random puzzleRandom =
        Random(levelNumber * 1000 + difficultyIndex * 10 + seedOffset);
    final List<List<int>> grid = List<List<int>>.generate(
      gridSize,
      (_) => List<int>.filled(gridSize, 0),
    );
    _fillCombinedGrid(grid, 0, 0, puzzleRandom);
    return grid;
  }

  bool _fillCombinedGrid(
    List<List<int>> grid,
    int row,
    int col,
    Random random,
  ) {
    if (row == gridSize) return true;
    if (col == gridSize) return _fillCombinedGrid(grid, row + 1, 0, random);
    if (grid[row][col] != 0) {
      return _fillCombinedGrid(grid, row, col + 1, random);
    }

    final List<int> numbers = List<int>.generate(gridSize, (int i) => i + 1);
    numbers.shuffle(random);

    for (final int num in numbers) {
      if (_isSafeCombined(grid, row, col, num)) {
        grid[row][col] = num;
        if (_fillCombinedGrid(grid, row, col + 1, random)) return true;
        grid[row][col] = 0;
      }
    }
    return false;
  }

  bool _isSafeCombined(List<List<int>> grid, int row, int col, int number) {
    // Check row
    for (int c = 0; c < gridSize; c++) {
      if (grid[row][c] == number) return false;
    }

    // Check column
    for (int r = 0; r < gridSize; r++) {
      if (grid[r][col] == number) return false;
    }

    // Check subgrid
    final int boxRow = (row ~/ subgridRowSize) * subgridRowSize;
    final int boxCol = (col ~/ subgridColSize) * subgridColSize;
    for (int r = 0; r < subgridRowSize; r++) {
      for (int c = 0; c < subgridColSize; c++) {
        if (grid[boxRow + r][boxCol + c] == number) return false;
      }
    }

    return true;
  }

  List<List<CombinedCell>> _createInitialBoard(
    List<List<CombinedCell>> solution,
    ElementType selectedElement,
  ) {
    // First, copy solution and ensure all cells start as fixed
    final List<List<CombinedCell>> board = solution.map((
      List<CombinedCell> row,
    ) {
      return row.map((CombinedCell cell) => cell.copyWith(isFixed: true)).toList();
    }).toList();

    final int cellsToRemove = _removalCountForLevel(levelNumber);

    // For Medium: enforce the same distribution constraints as Easy,
    // but only for the selected element type.
    const int minPerRow = 2;
    const int minPerCol = 2;
    const int minPerBlock = 2;

    final List<int> rowCounts = List<int>.filled(gridSize, gridSize);
    final List<int> colCounts = List<int>.filled(gridSize, gridSize);
    final int blockCount =
        (gridSize ~/ subgridRowSize) * (gridSize ~/ subgridColSize);
    final List<int> blockCounts = List<int>.filled(
      blockCount,
      subgridRowSize * subgridColSize,
    );

    final List<({int row, int col})> positions = [];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        positions.add((row: r, col: c));
      }
    }
    positions.shuffle(_random);

    int removed = 0;
    for (final ({int row, int col}) pos in positions) {
      if (removed >= cellsToRemove) break;

      final CombinedCell cell = board[pos.row][pos.col];
      final int r = pos.row;
      final int c = pos.col;
      final int b = (r ~/ subgridRowSize) * (gridSize ~/ subgridColSize) +
          (c ~/ subgridColSize);

      if (rowCounts[r] <= minPerRow ||
          colCounts[c] <= minPerCol ||
          blockCounts[b] <= minPerBlock) {
        continue;
      }

      switch (selectedElement) {
        case ElementType.shape:
          board[pos.row][pos.col] = cell.copyWith(
            shapeId: null,
            isFixed: false,
          );
          break;
        case ElementType.color:
          board[pos.row][pos.col] = cell.copyWith(
            colorId: null,
            isFixed: false,
          );
          break;
        case ElementType.number:
          board[pos.row][pos.col] = cell.copyWith(
            numberId: null,
            isFixed: false,
          );
          break;
      }
      rowCounts[r]--;
      colCounts[c]--;
      blockCounts[b]--;
      removed++;
    }

    return board;
  }
}
