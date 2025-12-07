#!/usr/bin/env python3
"""
Quick test script for Sudoku Generator
Tests each component individually before running the full generation.
"""

import asyncio
import sys
sys.path.insert(0, '/Users/bala/Projects/sudoku generator')

from sudoku_generator import (
    Sudoku6x6Generator,
    SudokuAPIFetcher,
    validate_9x9_puzzle
)

async def test_6x6_generator():
    """Test the 6x6 generator."""
    print("=" * 60)
    print("Testing 6x6 Sudoku Generator")
    print("=" * 60)
    
    generator = Sudoku6x6Generator()
    
    # Generate 5 test puzzles
    for i in range(5):
        puzzle_str, solution_str, clue_count = generator.generate_puzzle()
        print(f"\n✅ Puzzle {i+1}:")
        print(f"   Puzzle: {puzzle_str}")
        print(f"   Solution: {solution_str}")
        print(f"   Clues: {clue_count} (target: 18-20)")
        
        # Validate clue count
        if 18 <= clue_count <= 20:
            print(f"   ✓ Clue count valid")
        else:
            print(f"   ❌ Clue count out of range!")
    
    print("\n✅ 6x6 generator test complete")

async def test_api_fetcher():
    """Test API fetching."""
    print("\n" + "=" * 60)
    print("Testing API Fetcher")
    print("=" * 60)
    
    async with SudokuAPIFetcher() as fetcher:
        print("\n🔍 Testing EASY difficulty (for MEDIUM mode)...")
        result = await fetcher.fetch_valid_puzzle("easy", min_clues=35, max_clues=45)
        if result:
            puzzle_str, solution_str, clue_count = result
            print(f"   ✅ Fetched puzzle with {clue_count} clues")
            print(f"   Puzzle preview: {puzzle_str[:27]}...")
        else:
            print("   ❌ Failed to fetch puzzle")
        
        print("\n🔍 Testing MEDIUM difficulty (for HARD mode)...")
        result = await fetcher.fetch_valid_puzzle("medium", min_clues=30, max_clues=35)
        if result:
            puzzle_str, solution_str, clue_count = result
            print(f"   ✅ Fetched puzzle with {clue_count} clues")
        else:
            print("   ❌ Failed to fetch puzzle")
        
        print("\n🔍 Testing HARD difficulty (for EXPERT mode)...")
        result = await fetcher.fetch_valid_puzzle("hard")
        if result:
            puzzle_str, solution_str, clue_count = result
            print(f"   ✅ Fetched puzzle with {clue_count} clues")
        else:
            print("   ❌ Failed to fetch puzzle")
        
        print("\n🔍 Testing HARD with ≤26 clues filter (for MASTER mode)...")
        attempts = 0
        max_attempts = 20
        while attempts < max_attempts:
            result = await fetcher.fetch_valid_puzzle("hard", max_clues=26)
            attempts += 1
            if result:
                puzzle_str, solution_str, clue_count = result
                print(f"   ✅ Found MASTER puzzle with {clue_count} clues (took {attempts} attempts)")
                break
        
        if attempts >= max_attempts:
            print(f"   ⚠️  No puzzle with ≤26 clues found in {max_attempts} attempts")
    
    print("\n✅ API fetcher test complete")

async def main():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("🧪 SUDOKU GENERATOR TEST SUITE")
    print("=" * 60)
    
    await test_6x6_generator()
    await test_api_fetcher()
    
    print("\n" + "=" * 60)
    print("✅ ALL TESTS COMPLETE")
    print("=" * 60)
    print("\nℹ️  To generate the full database, run:")
    print("   source venv/bin/activate && python3 sudoku_generator.py")
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(main())
