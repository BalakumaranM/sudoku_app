# Advanced Sudoku Generator System

A professional, technique-based Sudoku generator for creating high-quality puzzles across multiple game modes and difficulty tiers.

## 🚀 Features

- **Technique-Based Generation**: Puzzles are generated to require specific solving techniques (not just random hole removal).
- **Flexible Grid Sizes**: Supports 6×6 (2×3 boxes) and 9×9 (3×3 boxes).
- **Superimposed Puzzles**: Generates multi-layer puzzles for "Crazy Sudoku" modes (Shapes + Colors + Numbers) where layers share clue positions but have independent solutions.
- **Batch Generation**: Generate 50+ levels at once for all game modes.
- **Configurable**: Fine-tune clue counts, technique levels, and grid sizes.

## 🛠️ Installation

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## 🎮 Usage

### 1. Generate Individual Puzzles (Testing)

Use `generate_single.py` to test specific parameters:

```bash
# Generate 9x9 Hard puzzle (Level 3)
python scripts/generate_single.py --size 9 --level 3 --clues 30-35

# Generate 6x6 Easy puzzle
python scripts/generate_single.py --size 6 --level 1

# Generate 2-layer superimposed puzzle (Crazy Sudoku Medium)
python scripts/generate_single.py --size 6 --level 2 --layers 2
```

**Technique Levels:**
- **1 (Easy)**: Naked Singles, Hidden Singles
- **2 (Medium)**: + Naked Pairs, Hidden Pairs
- **3 (Hard)**: + Naked Triples, Pointing Pairs, Box/Line Reduction
- **4 (Expert)**: + X-Wing, Y-Wing
- **5 (Master)**: + Swordfish, XYZ-Wing

### 2. Batch Generation (Production)

Use `generate_batch.py` to generate full level sets defined in `config/modes.yaml`:

```bash
# Generate all 50 levels for Numbers Easy
python scripts/generate_batch.py --mode numbers --difficulty easy

# Generate all difficulties for Shapes mode
python scripts/generate_batch.py --mode shapes --all-difficulties

# Generate EVERYTHING (all modes, all difficulties)
python scripts/generate_batch.py --all
```

Output CSVs will be saved to `output/`.

## 📂 Project Structure

```
sudoku_generator/
├── core/                  # Core engine
│   ├── grid.py            # Grid classes (6x6, 9x9)
│   ├── solver.py          # Solver with technique detection
│   ├── generator.py       # Smart puzzle generator
│   ├── techniques.py      # Solving techniques implementation
│   └── validator.py       # Validation utilities
├── scripts/               # CLI scripts
│   ├── generate_single.py # Single puzzle generator
│   └── generate_batch.py  # Batch generator
├── config/
│   └── modes.yaml         # Game mode configurations
└── output/                # Generated CSV files
```

## 🧩 Game Modes Supported

| Mode | Description | Grid | Layers |
|------|-------------|------|--------|
| **Numbers** | Classic Sudoku | 6×6, 9×9 | 1 |
| **Shapes** | Geometric shapes | 6×6, 9×9 | 1-3 |
| **Colors** | Colored cells | 6×6, 9×9 | 1-3 |
| **Planets** | Planet themes | 6×6 | 1 |
| **Cosmic** | Cosmic themes | 6×6 | 1 |
| **Custom** | User images | 6×6 | 1 |

For **Shapes/Colors** modes:
- **Easy**: Single layer (1 element)
- **Medium**: 2 layers (Shape + Color)
- **Hard/Expert/Master**: 3 layers (Shape + Color + Number)

## 📝 License

Free to use for your game development!
