#!/usr/bin/env python3
"""
Sudoku JSON Generator for Flutter App
Generates Mini (6x6) and Standard (9x9) puzzle sets, each with 5 difficulties.
Now includes TECHNIQUE DETECTION to validate puzzles match their difficulty level.
"""

import json
import random
import os
from typing import List, Tuple
from copy import deepcopy
from difficulty_analyzer import SudokuAnalyzer, get_difficulty_from_techniques, Technique

OUTPUT_DIR = "output"
PUZZLES_PER_MODE = 50

# Clue ranges for Mini Sudoku (6x6, 36 cells)
# Based on Sudoku Construction Workbook guidelines
MINI_CLUES = {
    "easy": (16, 20),      # Many naked singles available
    "medium": (12, 15),    # Pairs required
    "hard": (10, 12),      # Triples required
    "expert": (8, 10),     # Chains required
    "master": (7, 9),      # Deep chains required
}

# Clue ranges for Standard Sudoku (9x9, 81 cells)
# Based on Sudoku Construction Workbook guidelines
STANDARD_CLUES = {
    "easy": (32, 38),      # Naked singles abundant
    "medium": (27, 32),    # Pairs required
    "hard": (23, 27),      # X-wings possible
    "expert": (20, 24),    # Swordfish, XY-chains
    "master": (17, 21),    # Deep chains required
}


class Sudoku6x6Generator:
    """Generates valid 6x6 Sudoku puzzles."""
    
    def __init__(self):
        self.size = 6
        self.box_height = 2
        self.box_width = 3
    
    def is_valid(self, grid: List[List[int]], row: int, col: int, num: int) -> bool:
        if num in grid[row]:
            return False
        if num in [grid[r][col] for r in range(self.size)]:
            return False
        box_row = (row // self.box_height) * self.box_height
        box_col = (col // self.box_width) * self.box_width
        for r in range(box_row, box_row + self.box_height):
            for c in range(box_col, box_col + self.box_width):
                if grid[r][c] == num:
                    return False
        return True
    
    def solve(self, grid: List[List[int]]) -> bool:
        for row in range(self.size):
            for col in range(self.size):
                if grid[row][col] == 0:
                    numbers = list(range(1, self.size + 1))
                    random.shuffle(numbers)
                    for num in numbers:
                        if self.is_valid(grid, row, col, num):
                            grid[row][col] = num
                            if self.solve(grid):
                                return True
                            grid[row][col] = 0
                    return False
        return True
    
    def has_unique_solution(self, grid: List[List[int]]) -> bool:
        solutions = [0]
        def solve_count(g, limit=2):
            if solutions[0] >= limit:
                return
            for row in range(self.size):
                for col in range(self.size):
                    if g[row][col] == 0:
                        for num in range(1, self.size + 1):
                            if self.is_valid(g, row, col, num):
                                g[row][col] = num
                                solve_count(g, limit)
                                g[row][col] = 0
                        return
            solutions[0] += 1
        grid_copy = deepcopy(grid)
        solve_count(grid_copy)
        return solutions[0] == 1
    
    def generate_complete_grid(self) -> List[List[int]]:
        grid = [[0 for _ in range(self.size)] for _ in range(self.size)]
        self.solve(grid)
        return grid
    
    def remove_numbers(self, grid: List[List[int]], target_clues: int) -> List[List[int]]:
        puzzle = deepcopy(grid)
        cells = [(r, c) for r in range(self.size) for c in range(self.size)]
        random.shuffle(cells)
        
        current_clues = self.size * self.size
        for row, col in cells:
            if current_clues <= target_clues:
                break
            if puzzle[row][col] == 0:
                continue
            backup = puzzle[row][col]
            puzzle[row][col] = 0
            if not self.has_unique_solution(puzzle):
                puzzle[row][col] = backup
            else:
                current_clues -= 1
        return puzzle
    
    def generate_puzzle(self, level: int, difficulty: str, max_attempts: int = 20) -> Tuple[str, str, int]:
        """Generate a puzzle that requires techniques appropriate for its difficulty."""
        min_clues, max_clues = MINI_CLUES[difficulty]
        target_clues = max_clues - (level - 1) * (max_clues - min_clues) // 49
        target_clues = max(min_clues, min(max_clues, target_clues))
        
        analyzer = SudokuAnalyzer(6)
        
        for attempt in range(max_attempts):
            solution = self.generate_complete_grid()
            puzzle = self.remove_numbers(solution, target_clues)
            
            # Analyze what techniques are required
            result = analyzer.analyze(puzzle)
            if not result.solved:
                continue
            
            actual_difficulty = get_difficulty_from_techniques(result, 6)
            
            # Accept if actual difficulty matches or exceeds expected
            difficulty_order = ["easy", "medium", "hard", "expert", "master"]
            expected_idx = difficulty_order.index(difficulty)
            actual_idx = difficulty_order.index(actual_difficulty)
            
            # For Easy, we want puzzles that are genuinely easy (singles only)
            # For others, accept if same or harder
            if difficulty == "easy" and actual_difficulty == "easy":
                puzzle_str = ''.join(str(cell) for row in puzzle for cell in row)
                solution_str = ''.join(str(cell) for row in solution for cell in row)
                clue_count = sum(1 for char in puzzle_str if char != '0')
                return puzzle_str, solution_str, clue_count
            elif difficulty != "easy" and actual_idx >= expected_idx:
                puzzle_str = ''.join(str(cell) for row in puzzle for cell in row)
                solution_str = ''.join(str(cell) for row in solution for cell in row)
                clue_count = sum(1 for char in puzzle_str if char != '0')
                return puzzle_str, solution_str, clue_count
        
        # Fallback: return last generated (may not match difficulty perfectly)
        puzzle_str = ''.join(str(cell) for row in puzzle for cell in row)
        solution_str = ''.join(str(cell) for row in solution for cell in row)
        clue_count = sum(1 for char in puzzle_str if char != '0')
        return puzzle_str, solution_str, clue_count


class Sudoku9x9Generator:
    """Generates valid 9x9 Sudoku puzzles."""
    
    def __init__(self):
        self.size = 9
        self.box_size = 3
    
    def is_valid(self, grid: List[List[int]], row: int, col: int, num: int) -> bool:
        if num in grid[row]:
            return False
        if num in [grid[r][col] for r in range(self.size)]:
            return False
        box_row = (row // self.box_size) * self.box_size
        box_col = (col // self.box_size) * self.box_size
        for r in range(box_row, box_row + self.box_size):
            for c in range(box_col, box_col + self.box_size):
                if grid[r][c] == num:
                    return False
        return True
    
    def solve(self, grid: List[List[int]]) -> bool:
        for row in range(self.size):
            for col in range(self.size):
                if grid[row][col] == 0:
                    numbers = list(range(1, self.size + 1))
                    random.shuffle(numbers)
                    for num in numbers:
                        if self.is_valid(grid, row, col, num):
                            grid[row][col] = num
                            if self.solve(grid):
                                return True
                            grid[row][col] = 0
                    return False
        return True
    
    def has_unique_solution(self, grid: List[List[int]]) -> bool:
        solutions = [0]
        def solve_count(g):
            if solutions[0] >= 2:
                return
            for row in range(self.size):
                for col in range(self.size):
                    if g[row][col] == 0:
                        for num in range(1, self.size + 1):
                            if self.is_valid(g, row, col, num):
                                g[row][col] = num
                                solve_count(g)
                                g[row][col] = 0
                        return
            solutions[0] += 1
        grid_copy = deepcopy(grid)
        solve_count(grid_copy)
        return solutions[0] == 1
    
    def generate_complete_grid(self) -> List[List[int]]:
        grid = [[0 for _ in range(self.size)] for _ in range(self.size)]
        self.solve(grid)
        return grid
    
    def remove_numbers(self, grid: List[List[int]], target_clues: int) -> List[List[int]]:
        puzzle = deepcopy(grid)
        cells = [(r, c) for r in range(self.size) for c in range(self.size)]
        random.shuffle(cells)
        
        current_clues = self.size * self.size
        for row, col in cells:
            if current_clues <= target_clues:
                break
            if puzzle[row][col] == 0:
                continue
            backup = puzzle[row][col]
            puzzle[row][col] = 0
            if self.has_unique_solution(puzzle):
                current_clues -= 1
            else:
                puzzle[row][col] = backup
        return puzzle
    
    def generate_puzzle(self, level: int, difficulty: str, max_attempts: int = 20) -> Tuple[str, str, int]:
        """Generate a puzzle that requires techniques appropriate for its difficulty."""
        min_clues, max_clues = STANDARD_CLUES[difficulty]
        target_clues = max_clues - (level - 1) * (max_clues - min_clues) // 49
        target_clues = max(min_clues, min(max_clues, target_clues))
        
        analyzer = SudokuAnalyzer(9)
        
        for attempt in range(max_attempts):
            solution = self.generate_complete_grid()
            puzzle = self.remove_numbers(solution, target_clues)
            
            # Analyze what techniques are required
            result = analyzer.analyze(puzzle)
            if not result.solved:
                continue
            
            actual_difficulty = get_difficulty_from_techniques(result, 9)
            
            # Accept if actual difficulty matches or exceeds expected
            difficulty_order = ["easy", "medium", "hard", "expert", "master"]
            expected_idx = difficulty_order.index(difficulty)
            actual_idx = difficulty_order.index(actual_difficulty)
            
            # For Easy, we want puzzles that are genuinely easy (singles only)
            # For others, accept if same or harder
            if difficulty == "easy" and actual_difficulty == "easy":
                puzzle_str = ''.join(str(cell) for row in puzzle for cell in row)
                solution_str = ''.join(str(cell) for row in solution for cell in row)
                clue_count = sum(1 for char in puzzle_str if char != '0')
                return puzzle_str, solution_str, clue_count
            elif difficulty != "easy" and actual_idx >= expected_idx:
                puzzle_str = ''.join(str(cell) for row in puzzle for cell in row)
                solution_str = ''.join(str(cell) for row in solution for cell in row)
                clue_count = sum(1 for char in puzzle_str if char != '0')
                return puzzle_str, solution_str, clue_count
        
        # Fallback: return last generated (may not match difficulty perfectly)
        puzzle_str = ''.join(str(cell) for row in puzzle for cell in row)
        solution_str = ''.join(str(cell) for row in solution for cell in row)
        clue_count = sum(1 for char in puzzle_str if char != '0')
        return puzzle_str, solution_str, clue_count


def generate_all_levels():
    """Generate Mini and Standard puzzle sets."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    difficulties = ["easy", "medium", "hard", "expert", "master"]
    
    # Generate Mini Sudoku (6x6)
    print("=" * 60)
    print("🎯 GENERATING MINI SUDOKU (6x6)")
    print("=" * 60)
    gen6 = Sudoku6x6Generator()
    
    for difficulty in difficulties:
        print(f"\n🔹 Mini {difficulty.upper()} (6x6)...")
        print(f"   Target clues: {MINI_CLUES[difficulty][0]}-{MINI_CLUES[difficulty][1]}")
        levels = []
        for i in range(1, PUZZLES_PER_MODE + 1):
            puzzle_str, solution_str, clues = gen6.generate_puzzle(i, difficulty)
            levels.append({
                "id": i,
                "puzzle": puzzle_str,
                "solution": solution_str,
                "clues": clues
            })
            if i % 10 == 0:
                print(f"  ✓ Generated {i}/{PUZZLES_PER_MODE} (clues: {clues})")
        
        with open(f"{OUTPUT_DIR}/mini_{difficulty}.json", "w") as f:
            json.dump({"gridSize": 6, "levels": levels}, f, indent=2)
        avg_clues = sum(l["clues"] for l in levels) / len(levels)
        print(f"✅ Mini {difficulty}: avg {avg_clues:.1f} clues")
    
    # Generate Standard Sudoku (9x9)
    print("\n" + "=" * 60)
    print("🎯 GENERATING STANDARD SUDOKU (9x9)")
    print("=" * 60)
    gen9 = Sudoku9x9Generator()
    
    for difficulty in difficulties:
        print(f"\n🔹 Standard {difficulty.upper()} (9x9)...")
        print(f"   Target clues: {STANDARD_CLUES[difficulty][0]}-{STANDARD_CLUES[difficulty][1]}")
        levels = []
        for i in range(1, PUZZLES_PER_MODE + 1):
            puzzle_str, solution_str, clues = gen9.generate_puzzle(i, difficulty)
            levels.append({
                "id": i,
                "puzzle": puzzle_str,
                "solution": solution_str,
                "clues": clues
            })
            if i % 10 == 0:
                print(f"  ✓ Generated {i}/{PUZZLES_PER_MODE} (clues: {clues})")
        
        with open(f"{OUTPUT_DIR}/standard_{difficulty}.json", "w") as f:
            json.dump({"gridSize": 9, "levels": levels}, f, indent=2)
        avg_clues = sum(l["clues"] for l in levels) / len(levels)
        print(f"✅ Standard {difficulty}: avg {avg_clues:.1f} clues")
    
    print("\n" + "=" * 60)
    print("✅ ALL PUZZLES GENERATED!")
    print("=" * 60)
    print("\nFiles created in output/:")
    print("  Mini (6x6): mini_easy.json → mini_master.json")
    print("  Standard (9x9): standard_easy.json → standard_master.json")
    print(f"  Total: {PUZZLES_PER_MODE * 10} puzzles")


if __name__ == "__main__":
    generate_all_levels()
