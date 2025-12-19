"""
Sudoku Grid Classes
Supports 6×6 (2×3 boxes) and 9×9 (3×3 boxes) grids with candidate tracking.
"""

from typing import List, Set, Tuple, Optional
from copy import deepcopy


class SudokuGrid:
    """Base class for Sudoku grid with candidate management."""
    
    def __init__(self, size: int, box_rows: int, box_cols: int):
        self.size = size
        self.box_rows = box_rows  # Rows per box
        self.box_cols = box_cols  # Columns per box
        self.grid: List[List[int]] = [[0] * size for _ in range(size)]
        self.candidates: List[List[Set[int]]] = [[set(range(1, size + 1)) for _ in range(size)] for _ in range(size)]
    
    def set_value(self, row: int, col: int, value: int) -> None:
        """Set a value and update candidates."""
        self.grid[row][col] = value
        
        if value > 0:
            self.candidates[row][col] = set()
            # Remove from row candidates
            for c in range(self.size):
                self.candidates[row][c].discard(value)
            
            # Remove from column candidates
            for r in range(self.size):
                self.candidates[r][col].discard(value)
            
            # Remove from box candidates
            box_start_row = (row // self.box_rows) * self.box_rows
            box_start_col = (col // self.box_cols) * self.box_cols
            for r in range(box_start_row, box_start_row + self.box_rows):
                for c in range(box_start_col, box_start_col + self.box_cols):
                    self.candidates[r][c].discard(value)
        else:
            # Value is 0 (clearing cell). We must recalculate all candidates
            # because checking which peers are now valid for the removed value is complex.
            self.recalculate_candidates()

    def recalculate_candidates(self) -> None:
        """Recalculate all candidates based on current grid."""
        # Reset all to full set
        self.candidates = [[set(range(1, self.size + 1)) for _ in range(self.size)] for _ in range(self.size)]
        
        # Apply constraints for all filled cells
        for r in range(self.size):
            for c in range(self.size):
                val = self.grid[r][c]
                if val > 0:
                    self.set_value(r, c, val)
    
    def get_value(self, row: int, col: int) -> int:
        """Get the value at a cell."""
        return self.grid[row][col]
    
    def get_candidates(self, row: int, col: int) -> Set[int]:
        """Get candidates for a cell."""
        return self.candidates[row][col].copy()
    
    def remove_candidate(self, row: int, col: int, value: int) -> bool:
        """Remove a candidate from a cell. Returns True if removed."""
        if value in self.candidates[row][col]:
            self.candidates[row][col].discard(value)
            return True
        return False
    
    def is_empty(self, row: int, col: int) -> bool:
        """Check if a cell is empty."""
        return self.grid[row][col] == 0
    
    def get_empty_cells(self) -> List[Tuple[int, int]]:
        """Get all empty cell positions."""
        return [(r, c) for r in range(self.size) for c in range(self.size) if self.grid[r][c] == 0]
    
    def get_row(self, row: int) -> List[int]:
        """Get all values in a row."""
        return self.grid[row][:]
    
    def get_col(self, col: int) -> List[int]:
        """Get all values in a column."""
        return [self.grid[r][col] for r in range(self.size)]
    
    def get_box(self, row: int, col: int) -> List[int]:
        """Get all values in the box containing (row, col)."""
        box_start_row = (row // self.box_rows) * self.box_rows
        box_start_col = (col // self.box_cols) * self.box_cols
        values = []
        for r in range(box_start_row, box_start_row + self.box_rows):
            for c in range(box_start_col, box_start_col + self.box_cols):
                values.append(self.grid[r][c])
        return values
    
    def get_box_cells(self, row: int, col: int) -> List[Tuple[int, int]]:
        """Get all cell positions in the box containing (row, col)."""
        box_start_row = (row // self.box_rows) * self.box_rows
        box_start_col = (col // self.box_cols) * self.box_cols
        return [(r, c) 
                for r in range(box_start_row, box_start_row + self.box_rows)
                for c in range(box_start_col, box_start_col + self.box_cols)]
    
    def get_peers(self, row: int, col: int) -> Set[Tuple[int, int]]:
        """Get all peer cells (same row, column, or box)."""
        peers = set()
        
        # Row peers
        for c in range(self.size):
            if c != col:
                peers.add((row, c))
        
        # Column peers
        for r in range(self.size):
            if r != row:
                peers.add((r, col))
        
        # Box peers
        for r, c in self.get_box_cells(row, col):
            if (r, c) != (row, col):
                peers.add((r, c))
        
        return peers
    
    def is_valid(self) -> bool:
        """Check if grid has no conflicts."""
        for r in range(self.size):
            for c in range(self.size):
                val = self.grid[r][c]
                if val == 0:
                    continue
                
                # Temporarily clear to check for duplicates
                self.grid[r][c] = 0
                
                # Check row
                if val in self.get_row(r):
                    self.grid[r][c] = val
                    return False
                
                # Check column
                if val in self.get_col(c):
                    self.grid[r][c] = val
                    return False
                
                # Check box
                if val in self.get_box(r, c):
                    self.grid[r][c] = val
                    return False
                
                self.grid[r][c] = val
        
        return True
    
    def is_complete(self) -> bool:
        """Check if grid is completely filled and valid."""
        return all(self.grid[r][c] != 0 for r in range(self.size) for c in range(self.size)) and self.is_valid()
    
    def count_clues(self) -> int:
        """Count non-zero cells."""
        return sum(1 for r in range(self.size) for c in range(self.size) if self.grid[r][c] != 0)
    
    def copy(self) -> 'SudokuGrid':
        """Create a deep copy of the grid."""
        new_grid = self.__class__.__new__(self.__class__)
        new_grid.size = self.size
        new_grid.box_rows = self.box_rows
        new_grid.box_cols = self.box_cols
        new_grid.grid = deepcopy(self.grid)
        new_grid.candidates = deepcopy(self.candidates)
        return new_grid
    
    def to_string(self) -> str:
        """Convert grid to flat string representation."""
        return ''.join(str(self.grid[r][c]) for r in range(self.size) for c in range(self.size))
    
    @classmethod
    def from_string(cls, s: str, size: int, box_rows: int, box_cols: int) -> 'SudokuGrid':
        """Create grid from flat string representation."""
        if size == 6:
            grid = Grid6x6()
        else:
            grid = Grid9x9()
        
        for i, char in enumerate(s):
            r, c = i // size, i % size
            val = int(char)
            if val > 0:
                grid.set_value(r, c, val)
        
        return grid
    
    def __str__(self) -> str:
        """Pretty print the grid."""
        lines = []
        for r in range(self.size):
            if r > 0 and r % self.box_rows == 0:
                lines.append('-' * (self.size * 2 + self.size // self.box_cols - 1))
            
            row_str = ''
            for c in range(self.size):
                if c > 0 and c % self.box_cols == 0:
                    row_str += '| '
                val = self.grid[r][c]
                row_str += (str(val) if val > 0 else '.') + ' '
            lines.append(row_str)
        
        return '\n'.join(lines)


class Grid6x6(SudokuGrid):
    """6×6 Sudoku grid with 2×3 boxes."""
    
    def __init__(self):
        super().__init__(size=6, box_rows=2, box_cols=3)


class Grid9x9(SudokuGrid):
    """9×9 Sudoku grid with 3×3 boxes."""
    
    def __init__(self):
        super().__init__(size=9, box_rows=3, box_cols=3)


def create_grid(size: int) -> SudokuGrid:
    """Factory function to create appropriate grid."""
    if size == 6:
        return Grid6x6()
    elif size == 9:
        return Grid9x9()
    else:
        raise ValueError(f"Unsupported grid size: {size}. Use 6 or 9.")
