# Medium Mode Specification

## Overview
Medium mode is a 6x6 Sudoku variant where each cell contains THREE combined elements:
1. **Shape** (Triangle, Square, Rectangle, Line, Circle, Diamond)
2. **Color** (Red, Black, Blue, Green, Brown, Orange)  
3. **Number** (1, 2, 3, 4, 5, 6)

## Visual Representation
Each cell displays:
- A shape (e.g., Triangle) 
- Colored in one of the 6 colors (e.g., Green)
- With a number inside it (e.g., 2)
- Example: "Green Triangle with number 2"

## Puzzle Generation Requirements

### Three Independent Sudoku Puzzles
The game must generate THREE separate, valid 6x6 Sudoku puzzles:
1. **Shape Sudoku**: Each row, column, and 2x3 subgrid contains each shape exactly once
2. **Color Sudoku**: Each row, column, and 2x3 subgrid contains each color exactly once
3. **Number Sudoku**: Each row, column, and 2x3 subgrid contains each number exactly once

### Combined Cell Data
Each cell at position (row, col) contains:
- `shapeId`: 1-6 (which shape)
- `colorId`: 1-6 (which color)
- `numberId`: 1-6 (which number)

All three values must be valid according to their respective Sudoku rules.

## Gameplay Flow

### 1. Random Element Selection
At game start, randomly select ONE element type to solve:
- **"Solve by Shapes"** - User places shapes, colors and numbers are fixed
- **"Solve by Colors"** - User places colors, shapes and numbers are fixed  
- **"Solve by Numbers"** - User places numbers, shapes and colors are fixed

This selection changes every round to keep the user engaged.

### 2. Initial Board Setup
- **ALL cells show all three elements** (shape, color, number) at all times
- Some cells are pre-filled (fixed) - all three elements are visible and cannot be changed
- Some cells are editable - user can only edit the **selected element type**
- The other two element types in editable cells are:
  - **Visible but fixed** (cannot be changed by user)
  - They are part of the puzzle solution and must remain valid

### 3. User Interaction
- At game start, a message shows: **"Solve by [Shapes/Colors/Numbers]"** (randomly selected)
- User taps a cell to select it
- Input bar shows options for the **selected element type only** (e.g., if solving by shapes, show 6 shapes)
- When user places a value:
  - Only the selected element type is updated
  - The other two element types remain **unchanged and visible** (they're part of the solution)
  - Validation checks all three Sudoku rules must remain valid

### 4. Validation Rules
For a move to be valid:
- The placed element must not violate its own Sudoku rules
- The other two elements in that cell must also remain valid
- All three Sudoku puzzles must remain solvable

### 5. Completion
Level is complete when:
- The selected element type is fully placed and correct
- All three Sudoku puzzles are valid and complete

## Technical Implementation

### Data Structure
```dart
class CombinedCell {
  int? shapeId;    // 1-6 or null
  int? colorId;    // 1-6 or null  
  int? numberId;   // 1-6 or null
  bool isFixed;    // Is this cell pre-filled?
}

class CombinedPuzzle {
  List<List<CombinedCell>> initialBoard;
  List<List<CombinedCell>> solution;
  ElementType selectedElement; // Which element to solve
}
```

### Puzzle Generation Algorithm
1. Generate three independent 6x6 Sudoku puzzles (shapes, colors, numbers)
2. Combine them into CombinedCell structure
3. Remove some cells based on difficulty level
4. Randomly select which element type to solve
5. Mark cells as fixed/editable based on selected element

### UI Rendering
- Each cell shows all three elements:
  - Shape rendered in the specified color
  - Number displayed inside/on the shape
- Input bar shows only the selected element type options
- Highlighting shows conflicts for the selected element type

## Example Scenario

**Selected Element: Shapes** (randomly chosen at start)

Initial board shows:
- Cell (0,0): **Green Triangle with 2** (FIXED - all three visible, cannot change)
- Cell (0,1): **Blue [Empty] with 4** (EDITABLE - user can place shape, color=Blue and number=4 are fixed/visible)
- Cell (0,2): **Red Square with 1** (FIXED - all three visible)

User places Triangle in cell (0,1):
- Shape: Triangle (user placed - selected element)
- Color: Blue (remains fixed/visible - not editable)
- Number: 4 (remains fixed/visible - not editable)
- Result: **Blue Triangle with 4**

The "confusion" factor: User sees all three elements but can only edit one type, and doesn't know which type until game starts!

## Key Challenges
1. Generating three valid Sudoku puzzles that can be combined
2. Ensuring all three remain valid when user makes a move
3. UI to clearly show all three elements in each cell
4. Random element selection that changes each round
5. Validation logic for all three puzzle types simultaneously

