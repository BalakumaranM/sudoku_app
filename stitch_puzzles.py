#!/usr/bin/env python3
import os

CLASSIC_PUZZLES_PATH = "lib/data/classic_puzzles.dart"
GENERATED_PUZZLES_PATH = "generated_puzzles.txt"

def main():
    with open(CLASSIC_PUZZLES_PATH, "r") as f:
        classic_lines = f.readlines()
    
    with open(GENERATED_PUZZLES_PATH, "r") as f:
        gen_lines = f.readlines()
    
    # Find the split points
    # Start of Mini section
    start_idx = -1
    for i, line in enumerate(classic_lines):
        if "  // MINI EASY - 50 puzzles" in line:
            start_idx = i
            break
    
    if start_idx == -1:
        print("Error: Could not find start of MINI EASY puzzles")
        return

    # Start of Standard section (end of Mini section)
    end_idx = -1
    for i, line in enumerate(classic_lines):
        if "  // STANDARD EASY - 50 puzzles" in line:
            end_idx = i
            break
            
    if end_idx == -1:
        print("Error: Could not find start of STANDARD EASY puzzles")
        return

    print(f"Replacing lines {start_idx} to {end_idx}...")
    
    # Construct new content
    new_content = classic_lines[:start_idx] + gen_lines + classic_lines[end_idx:]
    
    with open(CLASSIC_PUZZLES_PATH, "w") as f:
        f.writelines(new_content)
        
    print(f"Successfully updated {CLASSIC_PUZZLES_PATH}")

if __name__ == "__main__":
    main()
