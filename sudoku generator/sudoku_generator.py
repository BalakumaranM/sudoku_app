#!/usr/bin/env python3
"""
Sudoku 6x6 Generator
Generates 1000 Mini Sudoku (6x6) puzzles across 5 difficulty tiers.
"""

import random
import time
from typing import List, Tuple, Dict

# Configuration
PUZZLES_PER_MODE = 200
OUTPUT_FILE = "lib/data/generated_puzzles.dart"

DIFFICULTIES = {
    "EASY": {"min": 18, "max": 22},
    "MEDIUM": {"min": 15, "max": 18},
    "HARD": {"min": 13, "max": 15},
    "EXPERT": {"min": 11, "max": 13},
    "MASTER": {"min": 8, "max": 11} # Very hard to find unique
}

class Sudoku6x6Generator:
    def __init__(self):
        self.size = 6
        self.box_height = 2
        self.box_width = 3
    
    def is_valid(self, grid: List[List[int]], row: int, col: int, num: int) -> bool:
        # Check row
        if num in grid[row]: return False
        # Check col
        if num in [grid[r][col] for r in range(self.size)]: return False
        # Check box
        box_row, box_col = (row // self.box_height) * self.box_height, (col // self.box_width) * self.box_width
        for r in range(box_row, box_row + self.box_height):
            for c in range(box_col, box_col + self.box_width):
                if grid[r][c] == num: return False
        return True
    
    def solve(self, grid: List[List[int]], randomize=True) -> bool:
        for row in range(self.size):
            for col in range(self.size):
                if grid[row][col] == 0:
                    numbers = list(range(1, self.size + 1))
                    if randomize: random.shuffle(numbers)
                    for num in numbers:
                        if self.is_valid(grid, row, col, num):
                            grid[row][col] = num
                            if self.solve(grid, randomize): return True
                            grid[row][col] = 0
                    return False
        return True
    
    def count_solutions(self, grid: List[List[int]], limit: int = 2) -> int:
        count = [0]
        def solve_count(g):
            if count[0] >= limit: return
            for row in range(self.size):
                for col in range(self.size):
                    if g[row][col] == 0:
                        for num in range(1, self.size + 1):
                            if self.is_valid(g, row, col, num):
                                g[row][col] = num
                                solve_count(g)
                                g[row][col] = 0
                        return
            count[0] += 1
        
        grid_copy = [row[:] for row in grid]
        solve_count(grid_copy)
        return count[0]
    
    def generate_complete_grid(self) -> List[List[int]]:
        grid = [[0]*6 for _ in range(6)]
        self.solve(grid)
        return grid
    
    def generate_puzzle(self, min_clues: int, max_clues: int) -> Tuple[str, str]:
        while True:
            solution = self.generate_complete_grid()
            puzzle = [row[:] for row in solution]
            
            cells = [(r, c) for r in range(6) for c in range(6)]
            random.shuffle(cells)
            
            removed_count = 0
            target_clues = random.randint(min_clues, max_clues)
            max_remove = 36 - target_clues
            
            for r, c in cells:
                if removed_count >= max_remove: break
                
                backup = puzzle[r][c]
                puzzle[r][c] = 0
                
                # Check uniqueness
                if self.count_solutions(puzzle) != 1:
                    puzzle[r][c] = backup # Put back if ambiguous
                else:
                    removed_count += 1
            
            current_clues = 36 - removed_count
            if current_clues <= max_clues and current_clues >= min_clues:
                p_str = "".join(str(cell) for row in puzzle for cell in row)
                s_str = "".join(str(cell) for row in solution for cell in row)
                return p_str, s_str
            # Else try again

def main():
    gen = Sudoku6x6Generator()
    print("Generating 1000 Mini Sudoku Levels...")
    
    dart_output = ""
    
    for diff_name, limits in DIFFICULTIES.items():
        print(f"Generating {diff_name} ({limits['min']}-{limits['max']} clues)...")
        puzzles = []
        for i in range(PUZZLES_PER_MODE):
            p, s = gen.generate_puzzle(limits['min'], limits['max'])
            puzzles.append(f"    PuzzleData('{p}', '{s}'),")
            if (i+1) % 50 == 0: print(f"  {i+1}/{PUZZLES_PER_MODE}")
            
        dart_output += f"  // MINI {diff_name} - {PUZZLES_PER_MODE} puzzles\n"
        dart_output += f"  static const List<PuzzleData> _mini{diff_name.capitalize()}Puzzles = [\n"
        dart_output += "\n".join(puzzles)
        dart_output += "\n  ];\n\n"

    # Write to a temporary file instead of overwriting valid code yet
    with open("generated_puzzles.txt", "w") as f:
        f.write(dart_output)
    print("Done! Saved to generated_puzzles.txt")

if __name__ == "__main__":
    main()
