"""
Sudoku Solver with Technique Detection
Solves puzzles and tracks which techniques were needed.
"""

from typing import List, Set, Tuple, Optional, Dict
from .grid import SudokuGrid, create_grid
from .techniques import (
    TECHNIQUES, TechniqueResult, LEVEL_NAMES,
    naked_singles, hidden_singles
)


class SolveResult:
    """Result of solving a puzzle."""
    
    def __init__(self, solved: bool, grid: Optional[SudokuGrid] = None):
        self.solved = solved
        self.grid = grid
        self.techniques_used: Set[str] = set()
        self.max_technique_level: int = 0
        self.steps: List[Tuple[str, int, str]] = []  # [(technique_name, level, description), ...]
        self.used_backtracking: bool = False
    
    def add_technique(self, name: str, level: int, description: str = ""):
        """Record use of a technique."""
        self.techniques_used.add(name)
        self.max_technique_level = max(self.max_technique_level, level)
        self.steps.append((name, level, description))
    
    def get_difficulty_name(self) -> str:
        """Get human-readable difficulty name."""
        return LEVEL_NAMES.get(self.max_technique_level, "Unknown")
    
    def __bool__(self):
        return self.solved
    
    def __repr__(self):
        return f"SolveResult(solved={self.solved}, level={self.max_technique_level}, techniques={self.techniques_used})"


class SudokuSolver:
    """Solver with technique detection."""
    
    def __init__(self, max_level: int = 5, allow_backtracking: bool = True):
        """
        Initialize solver.
        
        Args:
            max_level: Maximum technique level to use (1-5)
            allow_backtracking: Whether to use backtracking if techniques fail
        """
        self.max_level = max_level
        self.allow_backtracking = allow_backtracking
    
    def solve(self, grid: SudokuGrid) -> SolveResult:
        """
        Solve the puzzle using techniques up to max_level.
        
        Returns:
            SolveResult with solved grid and techniques used
        """
        work_grid = grid.copy()
        result = SolveResult(False, work_grid)
        
        # Apply techniques iteratively
        changed = True
        while changed and not work_grid.is_complete():
            changed = False
            
            for technique_fn, level in TECHNIQUES:
                if level > self.max_level:
                    continue
                
                technique_result = technique_fn(work_grid)
                
                if technique_result:
                    # Apply placements
                    for r, c, val in technique_result.placements:
                        if work_grid.is_empty(r, c):
                            work_grid.set_value(r, c, val)
                            result.add_technique(
                                technique_result.name, 
                                technique_result.level,
                                f"R{r+1}C{c+1}={val}"
                            )
                            changed = True
                    
                    # Apply eliminations
                    for r, c, val in technique_result.eliminations:
                        if work_grid.remove_candidate(r, c, val):
                            result.add_technique(
                                technique_result.name,
                                technique_result.level,
                                f"R{r+1}C{c+1} remove {val}"
                            )
                            changed = True
                    
                    if changed:
                        break  # Restart from simpler techniques
        
        # Check if solved
        if work_grid.is_complete():
            result.solved = True
            result.grid = work_grid
            return result
        
        # Try backtracking if allowed
        if self.allow_backtracking:
            backtrack_result = self._backtrack_solve(work_grid)
            if backtrack_result:
                result.solved = True
                result.grid = backtrack_result
                result.used_backtracking = True
                result.add_technique("backtracking", 6, "Trial and error")
        
        return result
    
    def _backtrack_solve(self, grid: SudokuGrid) -> Optional[SudokuGrid]:
        """Solve using backtracking."""
        work_grid = grid.copy()
        
        # Find empty cell with fewest candidates
        empty_cells = work_grid.get_empty_cells()
        if not empty_cells:
            return work_grid if work_grid.is_valid() else None
        
        # Sort by number of candidates
        empty_cells.sort(key=lambda cell: len(work_grid.get_candidates(cell[0], cell[1])))
        row, col = empty_cells[0]
        candidates = list(work_grid.get_candidates(row, col))
        
        if not candidates:
            return None
        
        for value in candidates:
            test_grid = work_grid.copy()
            test_grid.set_value(row, col, value)
            
            if test_grid.is_valid():
                result = self._backtrack_solve(test_grid)
                if result:
                    return result
        
        return None
    
    def analyze_difficulty(self, grid: SudokuGrid) -> SolveResult:
        """
        Analyze what techniques are needed to solve this puzzle.
        Uses techniques starting from simplest and only advances when stuck.
        """
        work_grid = grid.copy()
        result = SolveResult(False, None)
        
        # Try solving with progressively harder techniques
        for max_lvl in range(1, 6):
            solver = SudokuSolver(max_level=max_lvl, allow_backtracking=False)
            attempt = solver.solve(work_grid)
            
            if attempt.solved:
                result.solved = True
                result.grid = attempt.grid
                result.techniques_used = attempt.techniques_used
                result.max_technique_level = attempt.max_technique_level
                result.steps = attempt.steps
                return result
            
            # Merge techniques used so far
            result.techniques_used |= attempt.techniques_used
            result.max_technique_level = max(result.max_technique_level, attempt.max_technique_level)
            result.steps.extend(attempt.steps)
            
            # Update work grid with progress
            if attempt.grid:
                work_grid = attempt.grid
        
        # Fall back to backtracking
        if self.allow_backtracking:
            backtrack_result = self._backtrack_solve(work_grid)
            if backtrack_result:
                result.solved = True
                result.grid = backtrack_result
                result.used_backtracking = True
                result.max_technique_level = 6
                result.add_technique("backtracking", 6, "Trial and error")
        
        return result


def count_solutions(grid: SudokuGrid, limit: int = 2) -> int:
    """Count solutions up to limit (for uniqueness checking)."""
    count = [0]
    
    def solve_count(g: SudokuGrid):
        if count[0] >= limit:
            return
        
        empty = g.get_empty_cells()
        if not empty:
            if g.is_valid():
                count[0] += 1
            return
        
        # Find cell with fewest candidates
        empty.sort(key=lambda cell: len(g.get_candidates(cell[0], cell[1])))
        row, col = empty[0]
        
        for val in list(g.get_candidates(row, col)):
            new_grid = g.copy()
            new_grid.set_value(row, col, val)
            if new_grid.is_valid():
                solve_count(new_grid)
    
    solve_count(grid.copy())
    return count[0]


def has_unique_solution(grid: SudokuGrid) -> bool:
    """Check if puzzle has exactly one solution."""
    return count_solutions(grid, limit=2) == 1
