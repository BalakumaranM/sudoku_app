#!/usr/bin/env python3
"""
Batch Puzzle Generator Script
Generate 50 levels per difficulty for all game modes.

Usage:
    python generate_batch.py --mode numbers --difficulty easy
    python generate_batch.py --mode shapes --all
    python generate_batch.py --all  # Generate everything
"""

import argparse
import sys
import csv
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from core import (
    SudokuGenerator, SuperimposedGenerator, 
    LEVEL_NAMES, validate_puzzle
)

# ============================================================================
# MODE CONFIGURATIONS
# ============================================================================

# Map your game modes to generation parameters
MODE_CONFIGS = {
    'numbers': {
        'easy':   {'size': 6, 'layers': 1, 'level': 1, 'clues': (18, 22), 'count': 50},
        'medium': {'size': 9, 'layers': 1, 'level': 2, 'clues': (35, 45), 'count': 50},
        'hard':   {'size': 9, 'layers': 1, 'level': 3, 'clues': (30, 35), 'count': 50},
        'expert': {'size': 9, 'layers': 1, 'level': 4, 'clues': (25, 30), 'count': 50},
        'master': {'size': 9, 'layers': 1, 'level': 5, 'clues': (22, 26), 'count': 50},
    },
    'shapes': {
        'easy':   {'size': 6, 'layers': 1, 'level': 1, 'clues': (18, 22), 'count': 50},
        'medium': {'size': 6, 'layers': 2, 'level': 2, 'clues': (14, 18), 'count': 50},  # Shape + Color
        'hard':   {'size': 6, 'layers': 3, 'level': 3, 'clues': (12, 16), 'count': 50},  # Shape + Color + Number
        'expert': {'size': 9, 'layers': 3, 'level': 4, 'clues': (25, 30), 'count': 50},
        'master': {'size': 9, 'layers': 3, 'level': 5, 'clues': (22, 26), 'count': 50},
    },
    'colors': {
        'easy':   {'size': 6, 'layers': 1, 'level': 1, 'clues': (18, 22), 'count': 50},
        'medium': {'size': 6, 'layers': 2, 'level': 2, 'clues': (14, 18), 'count': 50},  # Color + Shape
        'hard':   {'size': 6, 'layers': 3, 'level': 3, 'clues': (12, 16), 'count': 50},
        'expert': {'size': 9, 'layers': 3, 'level': 4, 'clues': (25, 30), 'count': 50},
        'master': {'size': 9, 'layers': 3, 'level': 5, 'clues': (22, 26), 'count': 50},
    },
    'planets': {
        'easy':   {'size': 6, 'layers': 1, 'level': 1, 'clues': (18, 22), 'count': 50},
    },
    'cosmic': {
        'easy':   {'size': 6, 'layers': 1, 'level': 1, 'clues': (18, 22), 'count': 50},
    },
    'custom': {
        'easy':   {'size': 6, 'layers': 1, 'level': 1, 'clues': (18, 22), 'count': 50},
    },
}


def generate_single_level(config: dict, level_id: int) -> dict:
    """Generate a single level."""
    size = config['size']
    layers = config['layers']
    level = config['level']
    min_clues, max_clues = config['clues']
    
    if layers == 1:
        generator = SudokuGenerator(size)
        result = generator.generate_puzzle(
            target_level=level,
            min_clues=min_clues,
            max_clues=max_clues,
            max_attempts=200
        )
        
        if result:
            return {
                'id': level_id,
                'puzzle_data': result.puzzle.to_string(),
                'solution_data': result.solution.to_string(),
                'difficulty_level': result.technique_level,
                'techniques_used': ','.join(sorted(result.techniques_used)),
                'clue_count': result.clue_count,
            }
    else:
        generator = SuperimposedGenerator(size, layers)
        results = generator.generate(
            target_level=level,
            min_clues=min_clues,
            max_clues=max_clues,
            max_attempts=300
        )
        
        if results:
            row = {
                'id': level_id,
                'difficulty_level': results[0].technique_level,
                'techniques_used': ','.join(sorted(results[0].techniques_used)),
                'clue_count': results[0].clue_count,
            }
            
            for i, r in enumerate(results, 1):
                row[f'layer_{i}_puzzle'] = r.puzzle.to_string()
                row[f'layer_{i}_solution'] = r.solution.to_string()
            
            return row
    
    return None


def generate_mode_difficulty(mode: str, difficulty: str, output_dir: Path) -> bool:
    """Generate all levels for a mode-difficulty combination."""
    config = MODE_CONFIGS.get(mode, {}).get(difficulty)
    if not config:
        print(f"  ⚠️  No config for {mode}/{difficulty}")
        return False
    
    count = config['count']
    layers = config['layers']
    
    print(f"\n🎯 Generating {mode.upper()} - {difficulty.upper()}")
    print(f"   Size: {config['size']}×{config['size']}, Layers: {layers}, Level: {config['level']}")
    print(f"   Clues: {config['clues'][0]}-{config['clues'][1]}, Count: {count}")
    
    levels = []
    failed = 0
    start_time = time.time()
    
    for i in range(1, count + 1):
        result = generate_single_level(config, i)
        
        if result:
            levels.append(result)
            if i % 10 == 0 or i == count:
                print(f"   ✓ Generated {i}/{count} levels")
        else:
            failed += 1
            print(f"   ✗ Failed to generate level {i}")
            # Try again with lower constraints
            if failed < 10:
                result = generate_single_level(config, i)
                if result:
                    levels.append(result)
                    failed -= 1
    
    elapsed = time.time() - start_time
    
    if not levels:
        print(f"   ❌ No levels generated!")
        return False
    
    # Determine CSV columns
    if layers == 1:
        fieldnames = ['id', 'puzzle_data', 'solution_data', 'difficulty_level', 'techniques_used', 'clue_count']
    else:
        fieldnames = ['id']
        for i in range(1, layers + 1):
            fieldnames.extend([f'layer_{i}_puzzle', f'layer_{i}_solution'])
        fieldnames.extend(['difficulty_level', 'techniques_used', 'clue_count'])
    
    # Save to CSV
    output_file = output_dir / f"{mode}_{difficulty}.csv"
    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(levels)
    
    print(f"   ✅ Saved {len(levels)} levels to {output_file}")
    print(f"   ⏱️  Time: {elapsed:.1f}s ({elapsed/len(levels):.2f}s per level)")
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description='Generate batch Sudoku puzzles for all game modes',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate Numbers mode - Easy difficulty (50 levels)
  python generate_batch.py --mode numbers --difficulty easy
  
  # Generate all difficulties for Shapes mode
  python generate_batch.py --mode shapes --all-difficulties
  
  # Generate everything (all modes, all difficulties)
  python generate_batch.py --all
  
Available Modes:
  numbers, shapes, colors, planets, cosmic, custom

Available Difficulties:
  easy, medium, hard, expert, master
  (Note: planets/cosmic/custom only have 'easy')
        """
    )
    
    parser.add_argument('--mode', type=str, choices=list(MODE_CONFIGS.keys()),
                        help='Game mode to generate')
    
    parser.add_argument('--difficulty', type=str, 
                        choices=['easy', 'medium', 'hard', 'expert', 'master'],
                        help='Difficulty level to generate')
    
    parser.add_argument('--all-difficulties', action='store_true',
                        help='Generate all difficulties for the specified mode')
    
    parser.add_argument('--all', action='store_true',
                        help='Generate all modes and difficulties')
    
    parser.add_argument('--output-dir', '-o', type=str, default='output',
                        help='Output directory (default: output)')
    
    args = parser.parse_args()
    
    # Validate arguments
    if not args.all and not args.mode:
        parser.error("Either --mode or --all is required")
    
    if args.mode and not args.difficulty and not args.all_difficulties:
        parser.error("Either --difficulty or --all-difficulties is required with --mode")
    
    # Setup output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    print("=" * 60)
    print("🧩 SUDOKU BATCH GENERATOR")
    print("=" * 60)
    
    start_time = time.time()
    success_count = 0
    total_count = 0
    
    if args.all:
        # Generate everything
        for mode in MODE_CONFIGS:
            for difficulty in MODE_CONFIGS[mode]:
                total_count += 1
                if generate_mode_difficulty(mode, difficulty, output_dir):
                    success_count += 1
    
    elif args.all_difficulties:
        # Generate all difficulties for one mode
        for difficulty in MODE_CONFIGS.get(args.mode, {}):
            total_count += 1
            if generate_mode_difficulty(args.mode, difficulty, output_dir):
                success_count += 1
    
    else:
        # Generate one mode-difficulty
        total_count = 1
        if generate_mode_difficulty(args.mode, args.difficulty, output_dir):
            success_count = 1
    
    elapsed = time.time() - start_time
    
    print("\n" + "=" * 60)
    print("✅ BATCH GENERATION COMPLETE")
    print("=" * 60)
    print(f"Success: {success_count}/{total_count} combinations")
    print(f"Total Time: {elapsed:.1f}s")
    print(f"Output: {output_dir.absolute()}")
    print("=" * 60)


if __name__ == '__main__':
    main()
