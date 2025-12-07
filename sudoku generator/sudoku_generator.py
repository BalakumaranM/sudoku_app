#!/usr/bin/env python3
"""
Sudoku Database Generator
Generates 500 Sudoku puzzles across 5 difficulty tiers:
- EASY: 100 6x6 puzzles (generated locally)
- MEDIUM: 100 9x9 puzzles (from API)
- HARD: 100 9x9 puzzles (from API)
- EXPERT: 100 9x9 puzzles (from API)
- MASTER: 100 9x9 puzzles (from API with ≤26 clues)
"""

import asyncio
import aiohttp
import pandas as pd
import random
import copy
from typing import List, Tuple, Optional, Dict
import time

# ============================================================================
# CONFIGURATION
# ============================================================================

# Sugoku API endpoint (primary source)
SUGOKU_API = "https://sugoku.onrender.com/board"

# Alternative: Dosuku API (uncomment if Sugoku is down)
# DOSUKU_API = "https://sudoku-api.vercel.app/api/dosuku"

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY = 1  # seconds
RATE_LIMIT_DELAY = 0.5  # seconds between requests

# Output configuration
OUTPUT_DIR = "."
CSV_FILES = {
    "EASY": "easy.csv",
    "MEDIUM": "medium.csv",
    "HARD": "hard.csv",
    "EXPERT": "expert.csv",
    "MASTER": "master.csv"
}

PUZZLES_PER_MODE = 100

# ============================================================================
# 6x6 SUDOKU GENERATOR (for EASY mode)
# ============================================================================

class Sudoku6x6Generator:
    """Generates valid 6x6 Sudoku puzzles with 18-20 clues."""
    
    def __init__(self):
        self.size = 6
        self.box_height = 2
        self.box_width = 3
    
    def is_valid(self, grid: List[List[int]], row: int, col: int, num: int) -> bool:
        """Check if placing num at (row, col) is valid."""
        # Check row
        if num in grid[row]:
            return False
        
        # Check column
        if num in [grid[r][col] for r in range(self.size)]:
            return False
        
        # Check 2x3 box
        box_row, box_col = (row // self.box_height) * self.box_height, (col // self.box_width) * self.box_width
        for r in range(box_row, box_row + self.box_height):
            for c in range(box_col, box_col + self.box_width):
                if grid[r][c] == num:
                    return False
        
        return True
    
    def solve(self, grid: List[List[int]]) -> bool:
        """Solve the Sudoku using backtracking."""
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
    
    def count_solutions(self, grid: List[List[int]], limit: int = 2) -> int:
        """Count solutions (up to limit) to verify uniqueness."""
        count = [0]
        
        def solve_count(g):
            if count[0] >= limit:
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
            count[0] += 1
        
        grid_copy = [row[:] for row in grid]
        solve_count(grid_copy)
        return count[0]
    
    def generate_complete_grid(self) -> List[List[int]]:
        """Generate a complete valid 6x6 Sudoku grid."""
        grid = [[0 for _ in range(self.size)] for _ in range(self.size)]
        self.solve(grid)
        return grid
    
    def remove_numbers(self, grid: List[List[int]], target_clues: int = 19) -> List[List[int]]:
        """Remove numbers while maintaining unique solution."""
        puzzle = [row[:] for row in grid]
        cells = [(r, c) for r in range(self.size) for c in range(self.size)]
        random.shuffle(cells)
        
        for row, col in cells:
            if sum(row.count(0) for row in puzzle) >= (self.size * self.size - target_clues):
                break
            
            backup = puzzle[row][col]
            puzzle[row][col] = 0
            
            # Check if still has unique solution
            if self.count_solutions(puzzle, limit=2) != 1:
                puzzle[row][col] = backup
        
        return puzzle
    
    def generate_puzzle(self) -> Tuple[str, str, int]:
        """Generate a 6x6 puzzle with solution."""
        # Generate complete grid
        solution = self.generate_complete_grid()
        
        # Remove numbers to create puzzle (18-20 clues)
        target_clues = random.randint(18, 20)
        puzzle = self.remove_numbers(solution, target_clues)
        
        # Convert to strings
        puzzle_str = ''.join(str(cell) for row in puzzle for cell in row)
        solution_str = ''.join(str(cell) for row in solution for cell in row)
        
        clue_count = sum(1 for char in puzzle_str if char != '0')
        
        return puzzle_str, solution_str, clue_count

# ============================================================================
# 9x9 SUDOKU VALIDATOR
# ============================================================================

def validate_9x9_puzzle(board: List[List[int]]) -> bool:
    """Validate a 9x9 Sudoku puzzle (no duplicates in rows/cols/boxes)."""
    if len(board) != 9 or any(len(row) != 9 for row in board):
        return False
    
    # Check rows
    for row in board:
        non_zero = [x for x in row if x != 0]
        if len(non_zero) != len(set(non_zero)):
            return False
    
    # Check columns
    for col in range(9):
        column = [board[row][col] for row in range(9)]
        non_zero = [x for x in column if x != 0]
        if len(non_zero) != len(set(non_zero)):
            return False
    
    # Check 3x3 boxes
    for box_row in range(0, 9, 3):
        for box_col in range(0, 9, 3):
            box = []
            for r in range(box_row, box_row + 3):
                for c in range(box_col, box_col + 3):
                    box.append(board[r][c])
            non_zero = [x for x in box if x != 0]
            if len(non_zero) != len(set(non_zero)):
                return False
    
    return True

def count_clues(board: List[List[int]]) -> int:
    """Count non-zero cells (clues) in a puzzle."""
    return sum(1 for row in board for cell in row if cell != 0)

def board_to_string(board: List[List[int]]) -> str:
    """Convert 9x9 board to flat string."""
    return ''.join(str(cell) for row in board for cell in row)

# ============================================================================
# ASYNC API FETCHER
# ============================================================================

class SudokuAPIFetcher:
    """Async fetcher for Sudoku puzzles from Sugoku API."""
    
    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.semaphore = asyncio.Semaphore(10)  # Limit concurrent requests
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, *args):
        if self.session:
            await self.session.close()
    
    async def fetch_puzzle(self, difficulty: str, retry_count: int = 0) -> Optional[Dict]:
        """Fetch a single puzzle from Sugoku API with retry logic."""
        if retry_count >= MAX_RETRIES:
            print(f"❌ Max retries reached for difficulty={difficulty}")
            return None
        
        async with self.semaphore:
            try:
                url = f"{SUGOKU_API}?difficulty={difficulty}"
                async with self.session.get(url, timeout=10) as response:
                    if response.status == 200:
                        data = await response.json()
                        await asyncio.sleep(RATE_LIMIT_DELAY)
                        return data
                    else:
                        print(f"⚠️  API returned status {response.status}, retrying...")
                        await asyncio.sleep(RETRY_DELAY * (2 ** retry_count))
                        return await self.fetch_puzzle(difficulty, retry_count + 1)
            
            except asyncio.TimeoutError:
                print(f"⏱️  Timeout for difficulty={difficulty}, retrying...")
                await asyncio.sleep(RETRY_DELAY * (2 ** retry_count))
                return await self.fetch_puzzle(difficulty, retry_count + 1)
            
            except Exception as e:
                print(f"❌ Error fetching puzzle: {e}, retrying...")
                await asyncio.sleep(RETRY_DELAY * (2 ** retry_count))
                return await self.fetch_puzzle(difficulty, retry_count + 1)
    
    async def solve_puzzle(self, board: List[List[int]]) -> Optional[List[List[int]]]:
        """Solve puzzle using Sugoku API."""
        try:
            url = "https://sugoku.onrender.com/solve"
            data = {"board": board}
            async with self.session.post(url, json=data, timeout=10) as response:
                if response.status == 200:
                    result = await response.json()
                    if result.get("status") == "solved":
                        return result.get("solution")
            return None
        except Exception as e:
            print(f"⚠️  Error solving puzzle: {e}")
            return None
    
    async def fetch_valid_puzzle(
        self,
        difficulty: str,
        min_clues: Optional[int] = None,
        max_clues: Optional[int] = None
    ) -> Optional[Tuple[str, str, int]]:
        """Fetch and validate a puzzle with clue count constraints."""
        data = await self.fetch_puzzle(difficulty)
        
        if not data or "board" not in data:
            return None
        
        board = data["board"]
        
        # Validate puzzle
        if not validate_9x9_puzzle(board):
            print(f"⚠️  Invalid puzzle received, skipping...")
            return None
        
        clue_count = count_clues(board)
        
        # Check clue constraints
        if min_clues and clue_count < min_clues:
            return None
        if max_clues and clue_count > max_clues:
            return None
        
        # Get solution
        solution = await self.solve_puzzle(board)
        if not solution:
            print(f"⚠️  Could not solve puzzle, skipping...")
            return None
        
        puzzle_str = board_to_string(board)
        solution_str = board_to_string(solution)
        
        return puzzle_str, solution_str, clue_count

# ============================================================================
# MAIN GENERATION LOGIC
# ============================================================================

async def generate_easy_mode() -> List[Dict]:
    """Generate 100 6x6 puzzles for EASY mode."""
    print("\n🎯 Generating EASY mode (6x6 puzzles)...")
    generator = Sudoku6x6Generator()
    puzzles = []
    
    for i in range(PUZZLES_PER_MODE):
        puzzle_str, solution_str, clue_count = generator.generate_puzzle()
        puzzles.append({
            "id": i + 1,
            "puzzle_data": puzzle_str,
            "solution_data": solution_str,
            "difficulty_tag": "EASY",
            "clue_count": clue_count
        })
        
        if (i + 1) % 10 == 0:
            print(f"  ✓ Generated {i + 1}/{PUZZLES_PER_MODE} puzzles")
    
    print(f"✅ EASY mode complete: {len(puzzles)} puzzles")
    return puzzles

async def generate_medium_mode() -> List[Dict]:
    """Generate 100 9x9 MEDIUM puzzles (API easy → 35-45 clues)."""
    print("\n🎯 Generating MEDIUM mode (9x9 puzzles, 35-45 clues)...")
    puzzles = []
    
    async with SudokuAPIFetcher() as fetcher:
        while len(puzzles) < PUZZLES_PER_MODE:
            result = await fetcher.fetch_valid_puzzle("easy", min_clues=35, max_clues=45)
            
            if result:
                puzzle_str, solution_str, clue_count = result
                puzzles.append({
                    "id": len(puzzles) + 1,
                    "puzzle_data": puzzle_str,
                    "solution_data": solution_str,
                    "difficulty_tag": "MEDIUM",
                    "clue_count": clue_count
                })
                
                if len(puzzles) % 10 == 0:
                    print(f"  ✓ Generated {len(puzzles)}/{PUZZLES_PER_MODE} puzzles")
    
    print(f"✅ MEDIUM mode complete: {len(puzzles)} puzzles")
    return puzzles

async def generate_hard_mode() -> List[Dict]:
    """Generate 100 9x9 HARD puzzles (API medium → 30-35 clues)."""
    print("\n🎯 Generating HARD mode (9x9 puzzles, 30-35 clues)...")
    puzzles = []
    
    async with SudokuAPIFetcher() as fetcher:
        while len(puzzles) < PUZZLES_PER_MODE:
            result = await fetcher.fetch_valid_puzzle("medium", min_clues=30, max_clues=35)
            
            if result:
                puzzle_str, solution_str, clue_count = result
                puzzles.append({
                    "id": len(puzzles) + 1,
                    "puzzle_data": puzzle_str,
                    "solution_data": solution_str,
                    "difficulty_tag": "HARD",
                    "clue_count": clue_count
                })
                
                if len(puzzles) % 10 == 0:
                    print(f"  ✓ Generated {len(puzzles)}/{PUZZLES_PER_MODE} puzzles")
    
    print(f"✅ HARD mode complete: {len(puzzles)} puzzles")
    return puzzles

async def generate_expert_mode() -> List[Dict]:
    """Generate 100 9x9 EXPERT puzzles (API hard)."""
    print("\n🎯 Generating EXPERT mode (9x9 puzzles)...")
    puzzles = []
    
    async with SudokuAPIFetcher() as fetcher:
        while len(puzzles) < PUZZLES_PER_MODE:
            result = await fetcher.fetch_valid_puzzle("hard")
            
            if result:
                puzzle_str, solution_str, clue_count = result
                puzzles.append({
                    "id": len(puzzles) + 1,
                    "puzzle_data": puzzle_str,
                    "solution_data": solution_str,
                    "difficulty_tag": "EXPERT",
                    "clue_count": clue_count
                })
                
                if len(puzzles) % 10 == 0:
                    print(f"  ✓ Generated {len(puzzles)}/{PUZZLES_PER_MODE} puzzles")
    
    print(f"✅ EXPERT mode complete: {len(puzzles)} puzzles")
    return puzzles

async def generate_master_mode() -> List[Dict]:
    """Generate 100 9x9 MASTER puzzles (API hard with ≤26 clues)."""
    print("\n🎯 Generating MASTER mode (9x9 puzzles, ≤26 clues)...")
    print("  ℹ️  Fetching HARD puzzles and filtering for ≤26 clues...")
    puzzles = []
    
    async with SudokuAPIFetcher() as fetcher:
        while len(puzzles) < PUZZLES_PER_MODE:
            result = await fetcher.fetch_valid_puzzle("hard", max_clues=26)
            
            if result:
                puzzle_str, solution_str, clue_count = result
                puzzles.append({
                    "id": len(puzzles) + 1,
                    "puzzle_data": puzzle_str,
                    "solution_data": solution_str,
                    "difficulty_tag": "MASTER",
                    "clue_count": clue_count
                })
                
                if len(puzzles) % 10 == 0:
                    print(f"  ✓ Generated {len(puzzles)}/{PUZZLES_PER_MODE} puzzles")
    
    print(f"✅ MASTER mode complete: {len(puzzles)} puzzles")
    return puzzles

# ============================================================================
# CSV EXPORT
# ============================================================================

def save_to_csv(puzzles: List[Dict], filename: str):
    """Save puzzles to CSV file."""
    df = pd.DataFrame(puzzles)
    filepath = f"{OUTPUT_DIR}/{filename}"
    df.to_csv(filepath, index=False)
    print(f"💾 Saved {len(puzzles)} puzzles to {filepath}")

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Main execution function."""
    print("=" * 60)
    print("🧩 SUDOKU DATABASE GENERATOR")
    print("=" * 60)
    print(f"Target: {PUZZLES_PER_MODE} puzzles per mode × 5 modes = {PUZZLES_PER_MODE * 5} total")
    print("=" * 60)
    
    start_time = time.time()
    
    # Generate all modes
    easy_puzzles = await generate_easy_mode()
    medium_puzzles = await generate_medium_mode()
    hard_puzzles = await generate_hard_mode()
    expert_puzzles = await generate_expert_mode()
    master_puzzles = await generate_master_mode()
    
    # Save to CSV files
    print("\n" + "=" * 60)
    print("💾 Saving to CSV files...")
    print("=" * 60)
    
    save_to_csv(easy_puzzles, CSV_FILES["EASY"])
    save_to_csv(medium_puzzles, CSV_FILES["MEDIUM"])
    save_to_csv(hard_puzzles, CSV_FILES["HARD"])
    save_to_csv(expert_puzzles, CSV_FILES["EXPERT"])
    save_to_csv(master_puzzles, CSV_FILES["MASTER"])
    
    elapsed_time = time.time() - start_time
    
    print("\n" + "=" * 60)
    print("✅ GENERATION COMPLETE!")
    print("=" * 60)
    print(f"Total puzzles: {len(easy_puzzles) + len(medium_puzzles) + len(hard_puzzles) + len(expert_puzzles) + len(master_puzzles)}")
    print(f"Time elapsed: {elapsed_time:.2f} seconds")
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(main())
