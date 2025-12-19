
import sys
import os
import json

# Add the current directory to sys.path so we can import from core
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

from core.generator import SuperimposedGenerator

def serialize_puzzle(result):
    """Convert a generator result to a JSON-serializable format."""
    return {
        "grid": result.puzzle.grid,
        "solution": result.solution.grid,
        "clue_count": result.clue_count
    }

def main():
    print("Testing SuperimposedGenerator...")
    
    # Test Case 1: Medium (6x6, 2 Layers)
    print("\n--- Generating Medium (6x6, 2 Layers) ---")
    gen_medium = SuperimposedGenerator(size=6, layers=2)
    results_medium = gen_medium.generate(target_level=3, min_clues=12, max_clues=20, max_attempts=500)
    
    if results_medium:
        print(f"Success! Generated {len(results_medium)} layers.")
        for i, res in enumerate(results_medium):
            print(f"Layer {i+1} Clues: {res.clue_count}")
            # Verify clue positions match
            if i > 0:
                prev_grid = results_medium[i-1].puzzle.grid
                curr_grid = res.puzzle.grid
                matches = True
                for r in range(6):
                    for c in range(6):
                        if (prev_grid[r][c] != 0) != (curr_grid[r][c] != 0):
                            matches = False
                            print(f"Mismatch at ({r},{c}): Layer {i} has {prev_grid[r][c]}, Layer {i+1} has {curr_grid[r][c]}")
                print(f"Clue positions match Layer {i}: {matches}")
        
        # Output JSON for inspection
        output = {
            "mode": "medium_crazy",
            "layers": [serialize_puzzle(r) for r in results_medium]
        }
        print(json.dumps(output, indent=2))
        
    else:
        print("Failed to generate Medium puzzle.")

    # Test Case 2: Hard (6x6, 3 Layers)
    print("\n--- Generating Hard (6x6, 3 Layers) ---")
    gen_hard = SuperimposedGenerator(size=6, layers=3)
    results_hard = gen_hard.generate(target_level=4, min_clues=12, max_clues=18, max_attempts=500)
    
    if results_hard:
        print(f"Success! Generated {len(results_hard)} layers.")
        print(f"Layer 1 Clues: {results_hard[0].clue_count}")
    else:
        print("Failed to generate Hard puzzle.")

if __name__ == "__main__":
    main()
