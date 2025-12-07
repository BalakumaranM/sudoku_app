#!/usr/bin/env python3
"""
Sudoku Difficulty Analyzer
Implements a human-style solver that detects which techniques are required.
Used to validate puzzle difficulty matches expectations.
"""

from typing import List, Set, Tuple, Optional, Dict
from copy import deepcopy
from dataclasses import dataclass
from enum import IntEnum


class Technique(IntEnum):
    """Solving techniques in order of difficulty."""
    NAKED_SINGLE = 1      # Only one candidate in a cell
    HIDDEN_SINGLE = 2     # Only place for a number in row/col/box
    NAKED_PAIR = 3        # Two cells with same two candidates
    HIDDEN_PAIR = 4       # Two numbers only appear in two cells
    POINTING_PAIR = 5     # Candidates in box point to row/col
    BOX_LINE = 6          # Candidates in row/col restricted to box
    NAKED_TRIPLE = 7      # Three cells with three candidates
    HIDDEN_TRIPLE = 8     # Three numbers in three cells
    X_WING = 9            # Two rows/cols with same candidate pattern
    SWORDFISH = 10        # Three rows/cols pattern
    XY_CHAIN = 11         # Chain of bivalue cells
    FORCING_CHAIN = 12    # Multi-step inference chain


@dataclass
class SolveResult:
    """Result of solving a puzzle with technique tracking."""
    solved: bool
    techniques_used: Set[Technique]
    max_technique: Technique
    steps: int


class SudokuAnalyzer:
    """Human-style Sudoku solver with technique detection."""
    
    def __init__(self, size: int = 9):
        self.size = size
        if size == 6:
            self.box_height = 2
            self.box_width = 3
        else:
            self.box_height = 3
            self.box_width = 3
        self.values = set(range(1, size + 1))
    
    def get_candidates(self, grid: List[List[int]], row: int, col: int) -> Set[int]:
        """Get all valid candidates for a cell."""
        if grid[row][col] != 0:
            return set()
        
        candidates = set(self.values)
        
        # Remove row values
        candidates -= set(grid[row])
        
        # Remove column values
        candidates -= {grid[r][col] for r in range(self.size)}
        
        # Remove box values
        box_row = (row // self.box_height) * self.box_height
        box_col = (col // self.box_width) * self.box_width
        for r in range(box_row, box_row + self.box_height):
            for c in range(box_col, box_col + self.box_width):
                candidates.discard(grid[r][c])
        
        return candidates
    
    def init_candidates(self, grid: List[List[int]]) -> List[List[Set[int]]]:
        """Initialize candidate sets for all cells."""
        return [[self.get_candidates(grid, r, c) for c in range(self.size)] 
                for r in range(self.size)]
    
    def find_naked_single(self, grid: List[List[int]], 
                          candidates: List[List[Set[int]]]) -> Optional[Tuple[int, int, int]]:
        """Find a cell with only one candidate."""
        for r in range(self.size):
            for c in range(self.size):
                if grid[r][c] == 0 and len(candidates[r][c]) == 1:
                    return (r, c, list(candidates[r][c])[0])
        return None
    
    def find_hidden_single(self, grid: List[List[int]], 
                           candidates: List[List[Set[int]]]) -> Optional[Tuple[int, int, int]]:
        """Find a number that can only go in one place in a row/col/box."""
        # Check rows
        for r in range(self.size):
            for num in self.values:
                if num in grid[r]:
                    continue
                positions = [c for c in range(self.size) if num in candidates[r][c]]
                if len(positions) == 1:
                    return (r, positions[0], num)
        
        # Check columns
        for c in range(self.size):
            col_vals = [grid[r][c] for r in range(self.size)]
            for num in self.values:
                if num in col_vals:
                    continue
                positions = [r for r in range(self.size) if num in candidates[r][c]]
                if len(positions) == 1:
                    return (positions[0], c, num)
        
        # Check boxes
        for box_r in range(self.size // self.box_height):
            for box_c in range(self.size // self.box_width):
                start_r = box_r * self.box_height
                start_c = box_c * self.box_width
                
                for num in self.values:
                    positions = []
                    found = False
                    for r in range(start_r, start_r + self.box_height):
                        for c in range(start_c, start_c + self.box_width):
                            if grid[r][c] == num:
                                found = True
                                break
                            if num in candidates[r][c]:
                                positions.append((r, c))
                        if found:
                            break
                    if not found and len(positions) == 1:
                        return (positions[0][0], positions[0][1], num)
        
        return None
    
    def find_naked_pair(self, candidates: List[List[Set[int]]]) -> bool:
        """Find and eliminate naked pairs. Returns True if any elimination made."""
        eliminated = False
        
        # Check rows
        for r in range(self.size):
            cells = [(c, candidates[r][c]) for c in range(self.size) 
                     if len(candidates[r][c]) == 2]
            for i, (c1, cands1) in enumerate(cells):
                for c2, cands2 in cells[i+1:]:
                    if cands1 == cands2:
                        # Eliminate these candidates from other cells in row
                        for c in range(self.size):
                            if c != c1 and c != c2:
                                if candidates[r][c] & cands1:
                                    candidates[r][c] -= cands1
                                    eliminated = True
        
        # Check columns
        for c in range(self.size):
            cells = [(r, candidates[r][c]) for r in range(self.size) 
                     if len(candidates[r][c]) == 2]
            for i, (r1, cands1) in enumerate(cells):
                for r2, cands2 in cells[i+1:]:
                    if cands1 == cands2:
                        for r in range(self.size):
                            if r != r1 and r != r2:
                                if candidates[r][c] & cands1:
                                    candidates[r][c] -= cands1
                                    eliminated = True
        
        # Check boxes
        for box_r in range(self.size // self.box_height):
            for box_c in range(self.size // self.box_width):
                start_r = box_r * self.box_height
                start_c = box_c * self.box_width
                cells = []
                for r in range(start_r, start_r + self.box_height):
                    for c in range(start_c, start_c + self.box_width):
                        if len(candidates[r][c]) == 2:
                            cells.append(((r, c), candidates[r][c]))
                
                for i, ((r1, c1), cands1) in enumerate(cells):
                    for (r2, c2), cands2 in cells[i+1:]:
                        if cands1 == cands2:
                            for r in range(start_r, start_r + self.box_height):
                                for c in range(start_c, start_c + self.box_width):
                                    if (r, c) != (r1, c1) and (r, c) != (r2, c2):
                                        if candidates[r][c] & cands1:
                                            candidates[r][c] -= cands1
                                            eliminated = True
        
        return eliminated
    
    def find_x_wing(self, candidates: List[List[Set[int]]]) -> bool:
        """Find X-Wing pattern. Returns True if any elimination made."""
        if self.size < 9:
            return False
            
        eliminated = False
        
        for num in self.values:
            # Check rows for X-Wing
            rows_with_two = []
            for r in range(self.size):
                cols = [c for c in range(self.size) if num in candidates[r][c]]
                if len(cols) == 2:
                    rows_with_two.append((r, cols))
            
            for i, (r1, cols1) in enumerate(rows_with_two):
                for r2, cols2 in rows_with_two[i+1:]:
                    if cols1 == cols2:
                        # Found X-Wing - eliminate from other rows
                        for r in range(self.size):
                            if r != r1 and r != r2:
                                for c in cols1:
                                    if num in candidates[r][c]:
                                        candidates[r][c].discard(num)
                                        eliminated = True
        
        return eliminated
    
    def place_value(self, grid: List[List[int]], 
                    candidates: List[List[Set[int]]], 
                    row: int, col: int, value: int):
        """Place a value and update candidates."""
        grid[row][col] = value
        candidates[row][col] = set()
        
        # Remove from row
        for c in range(self.size):
            candidates[row][c].discard(value)
        
        # Remove from column
        for r in range(self.size):
            candidates[r][col].discard(value)
        
        # Remove from box
        box_row = (row // self.box_height) * self.box_height
        box_col = (col // self.box_width) * self.box_width
        for r in range(box_row, box_row + self.box_height):
            for c in range(box_col, box_col + self.box_width):
                candidates[r][c].discard(value)
    
    def analyze(self, puzzle: List[List[int]], max_steps: int = 1000) -> SolveResult:
        """
        Analyze a puzzle and return which techniques are required.
        """
        grid = deepcopy(puzzle)
        candidates = self.init_candidates(grid)
        techniques_used = set()
        steps = 0
        
        while steps < max_steps:
            # Count empty cells
            empty = sum(1 for r in range(self.size) for c in range(self.size) if grid[r][c] == 0)
            if empty == 0:
                return SolveResult(
                    solved=True,
                    techniques_used=techniques_used,
                    max_technique=max(techniques_used) if techniques_used else Technique.NAKED_SINGLE,
                    steps=steps
                )
            
            # Try techniques in order of difficulty
            
            # 1. Naked Single
            result = self.find_naked_single(grid, candidates)
            if result:
                techniques_used.add(Technique.NAKED_SINGLE)
                self.place_value(grid, candidates, result[0], result[1], result[2])
                steps += 1
                continue
            
            # 2. Hidden Single
            result = self.find_hidden_single(grid, candidates)
            if result:
                techniques_used.add(Technique.HIDDEN_SINGLE)
                self.place_value(grid, candidates, result[0], result[1], result[2])
                steps += 1
                continue
            
            # 3. Naked Pair (elimination only)
            if self.find_naked_pair(candidates):
                techniques_used.add(Technique.NAKED_PAIR)
                steps += 1
                continue
            
            # 4. X-Wing (for 9x9 only)
            if self.find_x_wing(candidates):
                techniques_used.add(Technique.X_WING)
                steps += 1
                continue
            
            # If no technique worked, puzzle requires more advanced techniques
            # Mark as requiring chains
            techniques_used.add(Technique.FORCING_CHAIN)
            break
        
        # Check if solved
        empty = sum(1 for r in range(self.size) for c in range(self.size) if grid[r][c] == 0)
        return SolveResult(
            solved=(empty == 0),
            techniques_used=techniques_used,
            max_technique=max(techniques_used) if techniques_used else Technique.NAKED_SINGLE,
            steps=steps
        )


def get_difficulty_from_techniques(result: SolveResult, size: int) -> str:
    """Map techniques used to difficulty level."""
    max_tech = result.max_technique
    
    if size == 6:
        if max_tech <= Technique.HIDDEN_SINGLE:
            return "easy"
        elif max_tech <= Technique.NAKED_PAIR:
            return "medium"
        elif max_tech <= Technique.NAKED_TRIPLE:
            return "hard"
        elif max_tech <= Technique.X_WING:
            return "expert"
        else:
            return "master"
    else:  # 9x9
        if max_tech <= Technique.HIDDEN_SINGLE:
            return "easy"
        elif max_tech <= Technique.HIDDEN_PAIR:
            return "medium"
        elif max_tech <= Technique.X_WING:
            return "hard"
        elif max_tech <= Technique.SWORDFISH:
            return "expert"
        else:
            return "master"


def validate_puzzle_difficulty(puzzle_str: str, expected_difficulty: str, size: int = 9) -> Tuple[bool, str]:
    """
    Validate that a puzzle matches its expected difficulty.
    Returns (is_valid, actual_difficulty)
    """
    # Convert string to grid
    grid = []
    for r in range(size):
        row = []
        for c in range(size):
            row.append(int(puzzle_str[r * size + c]))
        grid.append(row)
    
    analyzer = SudokuAnalyzer(size)
    result = analyzer.analyze(grid)
    
    if not result.solved:
        return (False, "unsolvable")
    
    actual_difficulty = get_difficulty_from_techniques(result, size)
    
    # Allow puzzles that are at or above the expected difficulty
    difficulty_order = ["easy", "medium", "hard", "expert", "master"]
    expected_idx = difficulty_order.index(expected_difficulty)
    actual_idx = difficulty_order.index(actual_difficulty)
    
    # Puzzle is valid if actual difficulty is at or above expected
    return (actual_idx >= expected_idx, actual_difficulty)


# Test the analyzer
if __name__ == "__main__":
    # Test with a simple puzzle
    test_6x6 = [
        [0, 0, 3, 0, 0, 6],
        [0, 0, 0, 0, 0, 0],
        [4, 0, 0, 0, 0, 2],
        [2, 0, 0, 0, 0, 4],
        [0, 0, 0, 0, 0, 0],
        [6, 0, 0, 3, 0, 0],
    ]
    
    analyzer = SudokuAnalyzer(6)
    result = analyzer.analyze(test_6x6)
    print(f"6x6 Test Puzzle:")
    print(f"  Solved: {result.solved}")
    print(f"  Techniques: {[t.name for t in result.techniques_used]}")
    print(f"  Max Technique: {result.max_technique.name}")
    print(f"  Steps: {result.steps}")
    print(f"  Difficulty: {get_difficulty_from_techniques(result, 6)}")
