
import sys
import os
import json
import random
import copy
from typing import List, Tuple, Optional, Set

# Add current directory to path
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

from core.grid import SudokuGrid, create_grid
from core.solver import SudokuSolver, has_unique_solution
from core.generator import SudokuGenerator, GeneratorResult

class JointSuperimposedGenerator:
    """
    Generates superimposed puzzles where Clue Positions are shared across all layers.
    Strategy: Joint Reduction.
    1. Generate L fully solved grids.
    2. Start with ALL cells as clues.
    3. Iteratively remove clues (from ALL layers at once).
    4. Check uniqueness for EACH layer separately.
    5. If ALL layers still have unique solutions, commit removal. Else revert.
    """
    
    def __init__(self, size: int = 6, layers: int = 2):
        self.size = size
        self.layers = layers
        self.base_generator = SudokuGenerator(size=size)
        self.solver = SudokuSolver(max_level=5, allow_backtracking=True)

    def generate_batch(self, count: int, difficulty_name: str, min_clues: int, max_clues: int) -> List[dict]:
        results = []
        print(f"Generating {count} {difficulty_name} levels ({self.size}x{self.size}, {self.layers} layers)...")
        
        needed = count
        while len(results) < needed:
            # Generate one puzzle
            res = self._generate_single(min_clues, max_clues)
            if res:
                results.append(res)
                print(f"  [{len(results)}/{needed}] Generated {difficulty_name} - Clues: {res['clue_count']}")
            else:
                # print(".", end="", flush=True)
                pass
                
        return results

    def _generate_single(self, min_clues: int, max_clues: int) -> Optional[dict]:
        # 1. Generate L solved grids
        solved_layers = []
        for _ in range(self.layers):
            # Generate a solved grid
            # We use the existing generator's method
            grid = self.base_generator.generate_solved_grid()
            solved_layers.append(grid)
            
        # 2. Start with all cells as clues (full grids)
        # We will maintain current state of puzzle layers
        puzzle_layers = [grid.copy() for grid in solved_layers]
        
        # 3. List all positions and shuffle
        positions = [(r, c) for r in range(self.size) for c in range(self.size)]
        random.shuffle(positions)
        
        current_clues = self.size * self.size
        
        # 4. Joint Reduction
        for r, c in positions:
            if current_clues <= min_clues:
                break
                
            # Try removing (r,c) from all layers
            backups = [layer.get_value(r, c) for layer in puzzle_layers]
            
            # Remove
            for layer in puzzle_layers:
                layer.set_value(r, c, 0)
                
            # Check uniqueness for ALL layers
            all_unique = True
            for layer in puzzle_layers:
                # We need a quick uniqueness check. 
                # has_unique_solution uses backtracking solver which checks for 2 solutions.
                if not has_unique_solution(layer):
                    all_unique = False
                    break
            
            if all_unique:
                # Keep removal
                current_clues -= 1
            else:
                # Revert
                for i, layer in enumerate(puzzle_layers):
                    layer.set_value(r, c, backups[i])
        
        # 5. Final validation against max_clues (and min_clues)
        if min_clues <= current_clues <= max_clues:
            # Format result
            layers_data = []
            for i in range(self.layers):
                layers_data.append({
                    "initial": puzzle_layers[i].grid,
                    "solution": solved_layers[i].grid
                })
                
            return {
                "layers": layers_data,
                "clue_count": current_clues,
                "size": self.size
            }
        
        return None

def main():
    os.makedirs("assets/levels", exist_ok=True)
    
    # 1. Medium (6x6, 2 Layers)
    # Target Clues: 14-20
    gen_medium = JointSuperimposedGenerator(size=6, layers=2)
    medium_levels = gen_medium.generate_batch(50, "Medium", 12, 20)
    with open("assets/levels/crazy_medium.json", "w") as f:
        json.dump(medium_levels, f)
        
    # 2. Hard (6x6, 3 Layers)
    # Target Clues: 12-18
    gen_hard = JointSuperimposedGenerator(size=6, layers=3)
    hard_levels = gen_hard.generate_batch(50, "Hard", 12, 18)
    with open("assets/levels/crazy_hard.json", "w") as f:
        json.dump(hard_levels, f)

    # 3. Expert (9x9, 3 Layers)
    # Target Clues: 30-45 (Relaxed slightly for 3 layers, it's hard to get very low clues with intersection constraint)
    gen_expert = JointSuperimposedGenerator(size=9, layers=3)
    expert_levels = gen_expert.generate_batch(50, "Expert", 25, 45) 
    with open("assets/levels/crazy_expert.json", "w") as f:
        json.dump(expert_levels, f)

    # 4. Master (9x9, 3 Layers - Harder)
    # Target Clues: 25-35
    gen_master = JointSuperimposedGenerator(size=9, layers=3)
    master_levels = gen_master.generate_batch(50, "Master", 22, 35)
    with open("assets/levels/crazy_master.json", "w") as f:
        json.dump(master_levels, f)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nGeneration Interrupted. Saving partial progress if handled...")
