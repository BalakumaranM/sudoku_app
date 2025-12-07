"""
Validator utilities for Sudoku puzzles.
"""

from typing import List, Tuple
from .grid import SudokuGrid


def validate_grid_structure(grid: SudokuGrid) -> Tuple[bool, str]:
    """Validate basic grid structure."""
    if grid.size not in (6, 9):
        return False, f"Invalid grid size: {grid.size}"
    
    if len(grid.grid) != grid.size:
        return False, f"Grid has {len(grid.grid)} rows, expected {grid.size}"
    
    for i, row in enumerate(grid.grid):
        if len(row) != grid.size:
            return False, f"Row {i} has {len(row)} cells, expected {grid.size}"
    
    return True, "Valid structure"


def validate_no_duplicates(grid: SudokuGrid) -> Tuple[bool, str]:
    """Check for duplicate values in rows, columns, and boxes."""
    # Check rows
    for r in range(grid.size):
        row = [v for v in grid.get_row(r) if v > 0]
        if len(row) != len(set(row)):
            return False, f"Duplicate in row {r+1}"
    
    # Check columns
    for c in range(grid.size):
        col = [v for v in grid.get_col(c) if v > 0]
        if len(col) != len(set(col)):
            return False, f"Duplicate in column {c+1}"
    
    # Check boxes
    for box_r in range(0, grid.size, grid.box_rows):
        for box_c in range(0, grid.size, grid.box_cols):
            box = [v for v in grid.get_box(box_r, box_c) if v > 0]
            if len(box) != len(set(box)):
                return False, f"Duplicate in box at ({box_r+1}, {box_c+1})"
    
    return True, "No duplicates"


def validate_values_in_range(grid: SudokuGrid) -> Tuple[bool, str]:
    """Check all values are in valid range."""
    for r in range(grid.size):
        for c in range(grid.size):
            val = grid.get_value(r, c)
            if val < 0 or val > grid.size:
                return False, f"Invalid value {val} at ({r+1}, {c+1})"
    
    return True, "All values in range"


def validate_puzzle(grid: SudokuGrid) -> Tuple[bool, List[str]]:
    """Run all validations on a puzzle."""
    errors = []
    
    valid, msg = validate_grid_structure(grid)
    if not valid:
        errors.append(msg)
    
    valid, msg = validate_no_duplicates(grid)
    if not valid:
        errors.append(msg)
    
    valid, msg = validate_values_in_range(grid)
    if not valid:
        errors.append(msg)
    
    return len(errors) == 0, errors


def validate_solution_matches(puzzle: SudokuGrid, solution: SudokuGrid) -> Tuple[bool, str]:
    """Verify solution is consistent with puzzle."""
    for r in range(puzzle.size):
        for c in range(puzzle.size):
            puzzle_val = puzzle.get_value(r, c)
            solution_val = solution.get_value(r, c)
            
            if puzzle_val > 0 and puzzle_val != solution_val:
                return False, f"Mismatch at ({r+1}, {c+1}): puzzle={puzzle_val}, solution={solution_val}"
    
    return True, "Solution matches puzzle"
