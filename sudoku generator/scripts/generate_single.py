#!/usr/bin/env python3
"""
Individual Puzzle Generator Script
Generate a single puzzle for testing with specific parameters.

Usage:
    python generate_single.py --size 9 --level 3 --clues 30-35
    python generate_single.py --size 6 --level 2 --layers 2  # Superimposed
"""

import argparse
import sys
import json
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from core import (
    SudokuGenerator, SuperimposedGenerator, 
    LEVEL_NAMES, TECHNIQUE_NAMES,
    validate_puzzle
)


def parse_clue_range(clue_str: str) -> tuple:
    """Parse clue range string like '30-35' or '30'."""
    if '-' in clue_str:
        parts = clue_str.split('-')
        return int(parts[0]), int(parts[1])
    else:
        val = int(clue_str)
        return val, val


def format_puzzle_output(result, layer_num: int = None) -> str:
    """Format puzzle result for display."""
    lines = []
    prefix = f"Layer {layer_num}: " if layer_num else ""
    
    lines.append(f"\n{prefix}Puzzle:")
    lines.append(str(result.puzzle))
    lines.append(f"\n{prefix}Solution:")
    lines.append(str(result.solution))
    lines.append(f"\n{prefix}Stats:")
    lines.append(f"  - Clue Count: {result.clue_count}")
    lines.append(f"  - Technique Level: {result.technique_level} ({LEVEL_NAMES.get(result.technique_level, 'Unknown')})")
    lines.append(f"  - Techniques Used: {', '.join(sorted(result.techniques_used))}")
    lines.append(f"\n{prefix}Data Strings:")
    lines.append(f"  - Puzzle: {result.puzzle.to_string()}")
    lines.append(f"  - Solution: {result.solution.to_string()}")
    
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Generate individual Sudoku puzzles for testing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate 9x9 Hard puzzle (Level 3) with 30-35 clues
  python generate_single.py --size 9 --level 3 --clues 30-35
  
  # Generate 6x6 Easy puzzle
  python generate_single.py --size 6 --level 1
  
  # Generate 2-layer superimposed puzzle (for Crazy Sudoku)
  python generate_single.py --size 6 --level 2 --layers 2
  
  # Generate 3-layer superimposed puzzle
  python generate_single.py --size 6 --level 3 --layers 3
  
Technique Levels:
  1 = Easy (Naked/Hidden Singles)
  2 = Medium (Naked/Hidden Pairs)
  3 = Hard (Triples, Pointing Pairs, Box/Line)
  4 = Expert (X-Wing, Y-Wing)
  5 = Master (Swordfish, XYZ-Wing)
        """
    )
    
    parser.add_argument('--size', type=int, choices=[6, 9], default=9,
                        help='Grid size (6 or 9, default: 9)')
    
    parser.add_argument('--level', type=int, choices=[1, 2, 3, 4, 5], default=1,
                        help='Technique level (1-5, default: 1)')
    
    parser.add_argument('--clues', type=str, default=None,
                        help='Clue count or range (e.g., 35 or 30-35)')
    
    parser.add_argument('--layers', type=int, choices=[1, 2, 3], default=1,
                        help='Number of superimposed layers (default: 1)')
    
    parser.add_argument('--attempts', type=int, default=100,
                        help='Maximum generation attempts (default: 100)')
    
    parser.add_argument('--json', action='store_true',
                        help='Output as JSON')
    
    parser.add_argument('--output', '-o', type=str, default=None,
                        help='Save output to file')
    
    args = parser.parse_args()
    
    # Parse clue range
    min_clues, max_clues = None, None
    if args.clues:
        min_clues, max_clues = parse_clue_range(args.clues)
    
    print("=" * 60)
    print("🧩 SUDOKU PUZZLE GENERATOR")
    print("=" * 60)
    print(f"Size: {args.size}×{args.size}")
    print(f"Level: {args.level} ({LEVEL_NAMES.get(args.level, 'Unknown')})")
    print(f"Clues: {min_clues or 'auto'}-{max_clues or 'auto'}")
    print(f"Layers: {args.layers}")
    print("=" * 60)
    print("\n⏳ Generating puzzle...")
    
    # Generate puzzle(s)
    if args.layers == 1:
        # Single puzzle
        generator = SudokuGenerator(args.size)
        result = generator.generate_puzzle(
            target_level=args.level,
            min_clues=min_clues,
            max_clues=max_clues,
            max_attempts=args.attempts
        )
        
        if result:
            print("\n✅ Puzzle generated successfully!")
            
            if args.json:
                output = json.dumps(result.to_dict(), indent=2)
            else:
                output = format_puzzle_output(result)
            
            print(output)
            
            # Validate
            valid, errors = validate_puzzle(result.puzzle)
            if valid:
                print("\n✓ Puzzle validation passed")
            else:
                print(f"\n✗ Validation errors: {errors}")
        else:
            print("\n❌ Failed to generate puzzle with requested constraints")
            print("   Try increasing --attempts or adjusting --level/--clues")
            sys.exit(1)
    
    else:
        # Superimposed puzzles
        generator = SuperimposedGenerator(args.size, args.layers)
        results = generator.generate(
            target_level=args.level,
            min_clues=min_clues,
            max_clues=max_clues,
            max_attempts=args.attempts
        )
        
        if results:
            print(f"\n✅ {args.layers}-layer superimposed puzzle generated!")
            
            if args.json:
                output_data = {
                    'layers': args.layers,
                    'technique_level': results[0].technique_level,
                    'clue_count': results[0].clue_count,
                    'puzzles': [r.to_dict() for r in results]
                }
                output = json.dumps(output_data, indent=2)
                print(output)
            else:
                for i, result in enumerate(results, 1):
                    print(format_puzzle_output(result, layer_num=i))
                
                print("\n" + "=" * 60)
                print("ℹ️  All layers share the same clue positions")
                print("   but have independent solutions!")
                print("=" * 60)
        else:
            print(f"\n❌ Failed to generate {args.layers}-layer puzzle")
            sys.exit(1)
    
    # Save to file if requested
    if args.output:
        with open(args.output, 'w') as f:
            f.write(output)
        print(f"\n💾 Saved to {args.output}")


if __name__ == '__main__':
    main()
