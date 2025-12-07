"""
Sudoku Puzzle Generator
Generates puzzles with specific technique requirements and clue counts.
"""

import random
from typing import List, Set, Tuple, Optional, Dict
from .grid import SudokuGrid, Grid6x6, Grid9x9, create_grid
from .solver import SudokuSolver, SolveResult, has_unique_solution, count_solutions


class GeneratorResult:
    """Result of generating a puzzle."""
    
    def __init__(self, puzzle: SudokuGrid, solution: SudokuGrid, 
                 technique_level: int, techniques_used: Set[str], clue_count: int):
        self.puzzle = puzzle
        self.solution = solution
        self.technique_level = technique_level
        self.techniques_used = techniques_used
        self.clue_count = clue_count
    
    def to_dict(self) -> dict:
        """Convert to dictionary for CSV export."""
        return {
            'puzzle_data': self.puzzle.to_string(),
            'solution_data': self.solution.to_string(),
            'difficulty_level': self.technique_level,
            'techniques_used': ','.join(sorted(self.techniques_used)),
            'clue_count': self.clue_count
        }


class SudokuGenerator:
    """Generate Sudoku puzzles with specific requirements."""
    
    def __init__(self, size: int = 9):
        """
        Initialize generator.
        
        Args:
            size: Grid size (6 or 9)
        """
        self.size = size
        if size == 6:
            self.box_rows, self.box_cols = 2, 3
        else:
            self.box_rows, self.box_cols = 3, 3
    
    def generate_solved_grid(self) -> SudokuGrid:
        """Generate a complete valid Sudoku grid."""
        grid = create_grid(self.size)
        self._fill_grid(grid)
        return grid
    
    def _fill_grid(self, grid: SudokuGrid) -> bool:
        """Fill grid using randomized backtracking."""
        empty = grid.get_empty_cells()
        if not empty:
            return True
        
        row, col = empty[0]
        candidates = list(range(1, self.size + 1))
        random.shuffle(candidates)
        
        for val in candidates:
            if self._is_valid_placement(grid, row, col, val):
                grid.set_value(row, col, val)
                if self._fill_grid(grid):
                    return True
                # Backtrack - need to reset
                grid.grid[row][col] = 0
                grid.candidates[row][col] = set(range(1, self.size + 1))
        
        return False
    
    def _is_valid_placement(self, grid: SudokuGrid, row: int, col: int, val: int) -> bool:
        """Check if placing val at (row, col) is valid."""
        # Check row
        if val in grid.get_row(row):
            return False
        
        # Check column
        if val in grid.get_col(col):
            return False
        
        # Check box
        if val in grid.get_box(row, col):
            return False
        
        return True
    
    def generate_puzzle(
        self,
        target_level: int = 1,
        min_clues: int = None,
        max_clues: int = None,
        max_attempts: int = 100
    ) -> Optional[GeneratorResult]:
        """
        Generate a puzzle with specific technique level and clue count.
        
        Args:
            target_level: Required technique level (1-5)
            min_clues: Minimum number of clues
            max_clues: Maximum number of clues
            max_attempts: Maximum generation attempts
            
        Returns:
            GeneratorResult or None if failed
        """
        # Set default clue ranges based on level
        if min_clues is None or max_clues is None:
            if self.size == 6:
                defaults = {
                    1: (18, 22),
                    2: (14, 18),
                    3: (12, 16),
                    4: (10, 14),
                    5: (8, 12),
                }
            else:
                defaults = {
                    1: (40, 50),
                    2: (35, 45),
                    3: (30, 35),
                    4: (25, 30),
                    5: (22, 26),
                }
            min_clues, max_clues = defaults.get(target_level, (30, 40))
        
        for attempt in range(max_attempts):
            # Generate solved grid
            solution = self.generate_solved_grid()
            
            # Create puzzle by removing cells
            puzzle = self._create_puzzle(solution, target_level, min_clues, max_clues)
            
            if puzzle:
                # Analyze the puzzle
                solver = SudokuSolver(max_level=5, allow_backtracking=False)
                result = solver.analyze_difficulty(puzzle)
                # print(f"Attempt {attempt}: Level {result.max_technique_level}, Clues {puzzle.count_clues()}")
                
                if result.solved and target_level <= result.max_technique_level <= target_level + 1:
                    clue_count = puzzle.count_clues()
                    if min_clues <= clue_count <= max_clues:
                        return GeneratorResult(
                            puzzle=puzzle,
                            solution=solution,
                            technique_level=result.max_technique_level,
                            techniques_used=result.techniques_used,
                            clue_count=clue_count
                        )
        
        return None
    
    def _create_puzzle(
        self,
        solution: SudokuGrid,
        target_level: int,
        min_clues: int,
        max_clues: int
    ) -> Optional[SudokuGrid]:
        """Create puzzle from solution by removing cells strategically."""
        puzzle = solution.copy()
        cells = [(r, c) for r in range(self.size) for c in range(self.size)]
        random.shuffle(cells)
        
        # Solver for checking
        solver = SudokuSolver(max_level=5, allow_backtracking=False)
        
        for row, col in cells:
            current_clues = puzzle.count_clues()
            
            # Hard stop if too few clues
            if current_clues <= 17:  # Absolute minimum for unique solution
                break
            
            # Stop if we reached target clues AND target level
            # But if level is too low, keep removing to force difficulty
            if current_clues <= min_clues:
                # Check if we already met the target level
                result = solver.analyze_difficulty(puzzle)
                if result.max_technique_level >= target_level:
                    break
            
            # Store value
            backup = puzzle.get_value(row, col)
            
            # Remove cell
            puzzle.grid[row][col] = 0
            puzzle.candidates[row][col] = set(range(1, self.size + 1))
            
            # Recalculate candidates
            puzzle = self._recalculate_candidates(puzzle)
            
            # Check uniqueness
            if not has_unique_solution(puzzle):
                # Restore
                puzzle.set_value(row, col, backup)
                continue
            
            # Check difficulty
            result = solver.analyze_difficulty(puzzle)
            
            if not result.solved:
                # Can't solve with techniques - too hard
                puzzle.set_value(row, col, backup)
            elif result.max_technique_level > target_level + 1:
                # Requires significantly harder techniques than allowed
                puzzle.set_value(row, col, backup)
            
            # If we are below min_clues but still haven't reached target level,
            # we kept the removal (good). 
            # If we reached target level, we might stop next iteration.
        
        return puzzle
    
    def _recalculate_candidates(self, grid: SudokuGrid) -> SudokuGrid:
        """Recalculate candidates for a grid."""
        new_grid = create_grid(self.size)
        
        # First copy all values
        for r in range(self.size):
            for c in range(self.size):
                val = grid.grid[r][c]
                if val > 0:
                    new_grid.set_value(r, c, val)
        
        return new_grid


class SuperimposedGenerator:
    """Generate superimposed puzzles for Crazy Sudoku combination modes."""
    
    def __init__(self, size: int = 6, layers: int = 2):
        """
        Initialize superimposed generator.
        
        Args:
            size: Grid size (6 or 9)
            layers: Number of superimposed layers (2 for shape+color, 3 for shape+color+number)
        """
        self.size = size
        self.layers = layers
        self.generator = SudokuGenerator(size)
    
    def generate(
        self,
        target_level: int = 1,
        min_clues: int = None,
        max_clues: int = None,
        max_attempts: int = 200
    ) -> Optional[List[GeneratorResult]]:
        """
        Generate superimposed puzzles with shared clue positions.
        
        Args:
            target_level: Required technique level (1-5)
            min_clues: Minimum number of clues
            max_clues: Maximum number of clues
            max_attempts: Maximum generation attempts
            
        Returns:
            List of GeneratorResults (one per layer) or None
        """
        # Set default clue ranges
        if min_clues is None or max_clues is None:
            if self.size == 6:
                if self.layers == 2:
                    min_clues, max_clues = 14, 18
                else:  # layers == 3
                    min_clues, max_clues = 12, 16
            else:
                if self.layers == 2:
                    min_clues, max_clues = 25, 30
                else:
                    min_clues, max_clues = 22, 26
        
        for attempt in range(max_attempts):
            # Generate first puzzle to determine clue positions
            result_1 = self.generator.generate_puzzle(
                target_level=target_level,
                min_clues=min_clues,
                max_clues=max_clues,
                max_attempts=50
            )
            
            if not result_1:
                continue
            
            # Get clue positions from first puzzle
            clue_positions = [
                (r, c) for r in range(self.size) for c in range(self.size)
                if result_1.puzzle.get_value(r, c) != 0
            ]
            
            # Generate remaining layers with same clue positions
            results = [result_1]
            success = True
            
            for layer in range(1, self.layers):
                layer_result = self._generate_with_positions(
                    clue_positions, target_level, max_attempts=50
                )
                
                if layer_result:
                    results.append(layer_result)
                else:
                    success = False
                    break
            
            if success and len(results) == self.layers:
                return results
        
        return None
    
    def _generate_with_positions(
        self,
        clue_positions: List[Tuple[int, int]],
        target_level: int,
        max_attempts: int = 50
    ) -> Optional[GeneratorResult]:
        """Generate a puzzle with given clue positions."""
        solver = SudokuSolver(max_level=5, allow_backtracking=False)
        
        for attempt in range(max_attempts):
            # Generate complete solution
            solution = self.generator.generate_solved_grid()
            
            # Create puzzle with given clue positions
            puzzle = create_grid(self.size)
            for r, c in clue_positions:
                puzzle.set_value(r, c, solution.get_value(r, c))
            
            # Check uniqueness
            if not has_unique_solution(puzzle):
                continue
            
            # Check difficulty
            result = solver.analyze_difficulty(puzzle)
            
            if result.solved and target_level <= result.max_technique_level <= target_level + 1:
                return GeneratorResult(
                    puzzle=puzzle,
                    solution=solution,
                    technique_level=result.max_technique_level,
                    techniques_used=result.techniques_used,
                    clue_count=puzzle.count_clues()
                )
        
        return None
