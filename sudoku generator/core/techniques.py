"""
Sudoku Solving Techniques
Organized by difficulty level for technique-based puzzle generation.
"""

from typing import List, Set, Tuple, Optional, Dict
from itertools import combinations


# ============================================================================
# TECHNIQUE RESULTS
# ============================================================================

class TechniqueResult:
    """Result of applying a technique."""
    
    def __init__(self, name: str, level: int, placements: List[Tuple[int, int, int]] = None,
                 eliminations: List[Tuple[int, int, int]] = None):
        self.name = name
        self.level = level  # 1-5 difficulty level
        self.placements = placements or []  # [(row, col, value), ...]
        self.eliminations = eliminations or []  # [(row, col, candidate), ...]
    
    def __bool__(self):
        return bool(self.placements or self.eliminations)
    
    def __repr__(self):
        return f"TechniqueResult({self.name}, level={self.level}, placements={len(self.placements)}, eliminations={len(self.eliminations)})"


# ============================================================================
# LEVEL 1: BASIC TECHNIQUES
# ============================================================================

def naked_singles(grid) -> TechniqueResult:
    """Find cells with only one candidate."""
    placements = []
    
    for r in range(grid.size):
        for c in range(grid.size):
            if grid.is_empty(r, c):
                candidates = grid.get_candidates(r, c)
                if len(candidates) == 1:
                    value = list(candidates)[0]
                    placements.append((r, c, value))
    
    return TechniqueResult("naked_singles", 1, placements=placements)


def hidden_singles(grid) -> TechniqueResult:
    """Find candidate that appears only once in a row/col/box."""
    placements = []
    
    # Check rows
    for r in range(grid.size):
        for num in range(1, grid.size + 1):
            positions = []
            for c in range(grid.size):
                if grid.is_empty(r, c) and num in grid.get_candidates(r, c):
                    positions.append((r, c))
            
            if len(positions) == 1:
                row, col = positions[0]
                placements.append((row, col, num))
    
    # Check columns
    for c in range(grid.size):
        for num in range(1, grid.size + 1):
            positions = []
            for r in range(grid.size):
                if grid.is_empty(r, c) and num in grid.get_candidates(r, c):
                    positions.append((r, c))
            
            if len(positions) == 1:
                row, col = positions[0]
                if (row, col, num) not in placements:
                    placements.append((row, col, num))
    
    # Check boxes
    for box_r in range(0, grid.size, grid.box_rows):
        for box_c in range(0, grid.size, grid.box_cols):
            for num in range(1, grid.size + 1):
                positions = []
                for r in range(box_r, box_r + grid.box_rows):
                    for c in range(box_c, box_c + grid.box_cols):
                        if grid.is_empty(r, c) and num in grid.get_candidates(r, c):
                            positions.append((r, c))
                
                if len(positions) == 1:
                    row, col = positions[0]
                    if (row, col, num) not in placements:
                        placements.append((row, col, num))
    
    return TechniqueResult("hidden_singles", 1, placements=placements)


# ============================================================================
# LEVEL 2: PAIR TECHNIQUES
# ============================================================================

def naked_pairs(grid) -> TechniqueResult:
    """Find two cells in a unit with the same two candidates."""
    eliminations = []
    
    # Check each unit type
    for unit_cells in _get_all_units(grid):
        # Find cells with exactly 2 candidates
        pair_cells = [(r, c) for r, c in unit_cells 
                      if grid.is_empty(r, c) and len(grid.get_candidates(r, c)) == 2]
        
        # Check each combination of 2 cells
        for (r1, c1), (r2, c2) in combinations(pair_cells, 2):
            cands1 = grid.get_candidates(r1, c1)
            cands2 = grid.get_candidates(r2, c2)
            
            if cands1 == cands2:
                # Found a naked pair - eliminate from other cells in unit
                for r, c in unit_cells:
                    if (r, c) != (r1, c1) and (r, c) != (r2, c2) and grid.is_empty(r, c):
                        for val in cands1:
                            if val in grid.get_candidates(r, c):
                                eliminations.append((r, c, val))
    
    return TechniqueResult("naked_pairs", 2, eliminations=eliminations)


def hidden_pairs(grid) -> TechniqueResult:
    """Find two candidates that appear only in two cells of a unit."""
    eliminations = []
    
    for unit_cells in _get_all_units(grid):
        # Map: candidate -> cells where it appears
        cand_positions: Dict[int, List[Tuple[int, int]]] = {}
        
        for r, c in unit_cells:
            if grid.is_empty(r, c):
                for cand in grid.get_candidates(r, c):
                    if cand not in cand_positions:
                        cand_positions[cand] = []
                    cand_positions[cand].append((r, c))
        
        # Find candidates that appear in exactly 2 cells
        cands_in_two = [cand for cand, positions in cand_positions.items() if len(positions) == 2]
        
        # Check pairs of such candidates
        for cand1, cand2 in combinations(cands_in_two, 2):
            if cand_positions[cand1] == cand_positions[cand2]:
                # Found hidden pair - keep only these two candidates in these cells
                for r, c in cand_positions[cand1]:
                    for val in grid.get_candidates(r, c):
                        if val not in (cand1, cand2):
                            eliminations.append((r, c, val))
    
    return TechniqueResult("hidden_pairs", 2, eliminations=eliminations)


# ============================================================================
# LEVEL 3: INTERMEDIATE TECHNIQUES
# ============================================================================

def naked_triples(grid) -> TechniqueResult:
    """Find three cells with three candidates that together have only 3 values."""
    eliminations = []
    
    for unit_cells in _get_all_units(grid):
        # Find cells with 2-3 candidates
        triple_candidates = [(r, c) for r, c in unit_cells 
                            if grid.is_empty(r, c) and 2 <= len(grid.get_candidates(r, c)) <= 3]
        
        for cells in combinations(triple_candidates, 3):
            # Union of all candidates in these 3 cells
            all_cands = set()
            for r, c in cells:
                all_cands |= grid.get_candidates(r, c)
            
            if len(all_cands) == 3:
                # Found naked triple - eliminate from other cells
                for r, c in unit_cells:
                    if (r, c) not in cells and grid.is_empty(r, c):
                        for val in all_cands:
                            if val in grid.get_candidates(r, c):
                                eliminations.append((r, c, val))
    
    return TechniqueResult("naked_triples", 3, eliminations=eliminations)


def hidden_triples(grid) -> TechniqueResult:
    """Find three candidates that appear only in three cells."""
    eliminations = []
    
    for unit_cells in _get_all_units(grid):
        cand_positions: Dict[int, List[Tuple[int, int]]] = {}
        
        for r, c in unit_cells:
            if grid.is_empty(r, c):
                for cand in grid.get_candidates(r, c):
                    if cand not in cand_positions:
                        cand_positions[cand] = []
                    cand_positions[cand].append((r, c))
        
        # Find candidates that appear in 2-3 cells
        eligible_cands = [cand for cand, pos in cand_positions.items() if 2 <= len(pos) <= 3]
        
        for cand_triple in combinations(eligible_cands, 3):
            # Union of all positions for these candidates
            all_positions = set()
            for cand in cand_triple:
                all_positions.update(cand_positions[cand])
            
            if len(all_positions) == 3:
                # Found hidden triple
                for r, c in all_positions:
                    for val in grid.get_candidates(r, c):
                        if val not in cand_triple:
                            eliminations.append((r, c, val))
    
    return TechniqueResult("hidden_triples", 3, eliminations=eliminations)


def pointing_pairs(grid) -> TechniqueResult:
    """If candidates in a box are confined to one row/col, eliminate from rest of row/col."""
    eliminations = []
    
    for box_r in range(0, grid.size, grid.box_rows):
        for box_c in range(0, grid.size, grid.box_cols):
            for num in range(1, grid.size + 1):
                positions = []
                for r in range(box_r, box_r + grid.box_rows):
                    for c in range(box_c, box_c + grid.box_cols):
                        if grid.is_empty(r, c) and num in grid.get_candidates(r, c):
                            positions.append((r, c))
                
                if len(positions) >= 2:
                    rows = set(r for r, c in positions)
                    cols = set(c for r, c in positions)
                    
                    # All in same row
                    if len(rows) == 1:
                        row = list(rows)[0]
                        for c in range(grid.size):
                            if c < box_c or c >= box_c + grid.box_cols:
                                if grid.is_empty(row, c) and num in grid.get_candidates(row, c):
                                    eliminations.append((row, c, num))
                    
                    # All in same column
                    if len(cols) == 1:
                        col = list(cols)[0]
                        for r in range(grid.size):
                            if r < box_r or r >= box_r + grid.box_rows:
                                if grid.is_empty(r, col) and num in grid.get_candidates(r, col):
                                    eliminations.append((r, col, num))
    
    return TechniqueResult("pointing_pairs", 3, eliminations=eliminations)


def box_line_reduction(grid) -> TechniqueResult:
    """If candidates in a row/col are confined to one box, eliminate from rest of box."""
    eliminations = []
    
    # Check rows
    for row in range(grid.size):
        for num in range(1, grid.size + 1):
            positions = [(row, c) for c in range(grid.size) 
                        if grid.is_empty(row, c) and num in grid.get_candidates(row, c)]
            
            if len(positions) >= 2:
                # Check if all in same box
                boxes = set((row // grid.box_rows, c // grid.box_cols) for _, c in positions)
                
                if len(boxes) == 1:
                    box_r, box_c = list(boxes)[0]
                    box_start_r = box_r * grid.box_rows
                    box_start_c = box_c * grid.box_cols
                    
                    # Eliminate from other rows in this box
                    for r in range(box_start_r, box_start_r + grid.box_rows):
                        if r != row:
                            for c in range(box_start_c, box_start_c + grid.box_cols):
                                if grid.is_empty(r, c) and num in grid.get_candidates(r, c):
                                    eliminations.append((r, c, num))
    
    # Check columns
    for col in range(grid.size):
        for num in range(1, grid.size + 1):
            positions = [(r, col) for r in range(grid.size) 
                        if grid.is_empty(r, col) and num in grid.get_candidates(r, col)]
            
            if len(positions) >= 2:
                boxes = set((r // grid.box_rows, col // grid.box_cols) for r, _ in positions)
                
                if len(boxes) == 1:
                    box_r, box_c = list(boxes)[0]
                    box_start_r = box_r * grid.box_rows
                    box_start_c = box_c * grid.box_cols
                    
                    for r in range(box_start_r, box_start_r + grid.box_rows):
                        for c in range(box_start_c, box_start_c + grid.box_cols):
                            if c != col and grid.is_empty(r, c) and num in grid.get_candidates(r, c):
                                eliminations.append((r, c, num))
    
    return TechniqueResult("box_line_reduction", 3, eliminations=eliminations)


# ============================================================================
# LEVEL 4: ADVANCED TECHNIQUES
# ============================================================================

def x_wing(grid) -> TechniqueResult:
    """Find X-Wing pattern: candidate in exactly 2 cells in 2 rows forming rectangle."""
    eliminations = []
    
    for num in range(1, grid.size + 1):
        # Find rows where num appears exactly twice
        rows_with_two = []
        for r in range(grid.size):
            cols = [c for c in range(grid.size) 
                   if grid.is_empty(r, c) and num in grid.get_candidates(r, c)]
            if len(cols) == 2:
                rows_with_two.append((r, cols[0], cols[1]))
        
        # Check pairs of rows
        for (r1, c1a, c1b), (r2, c2a, c2b) in combinations(rows_with_two, 2):
            if c1a == c2a and c1b == c2b:
                # Found X-Wing in rows - eliminate from columns
                for r in range(grid.size):
                    if r != r1 and r != r2:
                        if grid.is_empty(r, c1a) and num in grid.get_candidates(r, c1a):
                            eliminations.append((r, c1a, num))
                        if grid.is_empty(r, c1b) and num in grid.get_candidates(r, c1b):
                            eliminations.append((r, c1b, num))
        
        # Find columns where num appears exactly twice
        cols_with_two = []
        for c in range(grid.size):
            rows = [r for r in range(grid.size) 
                   if grid.is_empty(r, c) and num in grid.get_candidates(r, c)]
            if len(rows) == 2:
                cols_with_two.append((c, rows[0], rows[1]))
        
        # Check pairs of columns
        for (c1, r1a, r1b), (c2, r2a, r2b) in combinations(cols_with_two, 2):
            if r1a == r2a and r1b == r2b:
                # Found X-Wing in columns - eliminate from rows
                for c in range(grid.size):
                    if c != c1 and c != c2:
                        if grid.is_empty(r1a, c) and num in grid.get_candidates(r1a, c):
                            eliminations.append((r1a, c, num))
                        if grid.is_empty(r1b, c) and num in grid.get_candidates(r1b, c):
                            eliminations.append((r1b, c, num))
    
    return TechniqueResult("x_wing", 4, eliminations=eliminations)


def y_wing(grid) -> TechniqueResult:
    """Find Y-Wing pattern: pivot with 2 candidates, 2 wings each sharing one candidate."""
    eliminations = []
    
    # Find cells with exactly 2 candidates
    bi_value_cells = [(r, c, grid.get_candidates(r, c)) 
                      for r in range(grid.size) for c in range(grid.size)
                      if grid.is_empty(r, c) and len(grid.get_candidates(r, c)) == 2]
    
    for pivot_r, pivot_c, pivot_cands in bi_value_cells:
        pivot_list = list(pivot_cands)
        X, Y = pivot_list[0], pivot_list[1]
        
        # Find potential wings
        pivot_peers = grid.get_peers(pivot_r, pivot_c)
        
        wings_xz = []  # Wings with X and some Z (not Y)
        wings_yz = []  # Wings with Y and some Z (not X)
        
        for wing_r, wing_c, wing_cands in bi_value_cells:
            if (wing_r, wing_c) in pivot_peers:
                wing_list = list(wing_cands)
                if X in wing_cands and Y not in wing_cands:
                    Z = wing_list[0] if wing_list[1] == X else wing_list[1]
                    wings_xz.append((wing_r, wing_c, Z))
                elif Y in wing_cands and X not in wing_cands:
                    Z = wing_list[0] if wing_list[1] == Y else wing_list[1]
                    wings_yz.append((wing_r, wing_c, Z))
        
        # Find matching pairs with same Z
        for w1_r, w1_c, z1 in wings_xz:
            for w2_r, w2_c, z2 in wings_yz:
                if z1 == z2:
                    Z = z1
                    # Eliminate Z from cells that see both wings
                    wing1_peers = grid.get_peers(w1_r, w1_c)
                    wing2_peers = grid.get_peers(w2_r, w2_c)
                    common_peers = wing1_peers & wing2_peers
                    
                    for r, c in common_peers:
                        if grid.is_empty(r, c) and Z in grid.get_candidates(r, c):
                            if (r, c, Z) not in eliminations:
                                eliminations.append((r, c, Z))
    
    return TechniqueResult("y_wing", 4, eliminations=eliminations)


# ============================================================================
# LEVEL 5: EXPERT TECHNIQUES
# ============================================================================

def swordfish(grid) -> TechniqueResult:
    """Find Swordfish pattern: 3x3 extension of X-Wing."""
    eliminations = []
    
    for num in range(1, grid.size + 1):
        # Find rows where num appears in 2-3 cells
        candidate_rows = []
        for r in range(grid.size):
            cols = [c for c in range(grid.size) 
                   if grid.is_empty(r, c) and num in grid.get_candidates(r, c)]
            if 2 <= len(cols) <= 3:
                candidate_rows.append((r, set(cols)))
        
        # Check triplets of rows
        for rows in combinations(candidate_rows, 3):
            all_cols = set()
            for _, cols in rows:
                all_cols |= cols
            
            if len(all_cols) == 3:
                # Found Swordfish - eliminate from columns
                row_set = set(r for r, _ in rows)
                for col in all_cols:
                    for r in range(grid.size):
                        if r not in row_set:
                            if grid.is_empty(r, col) and num in grid.get_candidates(r, col):
                                eliminations.append((r, col, num))
        
        # Find columns where num appears in 2-3 cells
        candidate_cols = []
        for c in range(grid.size):
            rows = [r for r in range(grid.size) 
                   if grid.is_empty(r, c) and num in grid.get_candidates(r, c)]
            if 2 <= len(rows) <= 3:
                candidate_cols.append((c, set(rows)))
        
        # Check triplets of columns
        for cols in combinations(candidate_cols, 3):
            all_rows = set()
            for _, rows in cols:
                all_rows |= rows
            
            if len(all_rows) == 3:
                col_set = set(c for c, _ in cols)
                for row in all_rows:
                    for c in range(grid.size):
                        if c not in col_set:
                            if grid.is_empty(row, c) and num in grid.get_candidates(row, c):
                                eliminations.append((row, c, num))
    
    return TechniqueResult("swordfish", 5, eliminations=eliminations)


def xyz_wing(grid) -> TechniqueResult:
    """Find XYZ-Wing pattern: pivot with XYZ, wings with XZ and YZ."""
    eliminations = []
    
    # Find cells with exactly 3 candidates (pivot)
    for pivot_r in range(grid.size):
        for pivot_c in range(grid.size):
            if not grid.is_empty(pivot_r, pivot_c):
                continue
            
            pivot_cands = grid.get_candidates(pivot_r, pivot_c)
            if len(pivot_cands) != 3:
                continue
            
            pivot_list = list(pivot_cands)
            pivot_peers = grid.get_peers(pivot_r, pivot_c)
            
            # Find bi-value cells that are peers
            peer_bivalues = []
            for pr, pc in pivot_peers:
                if grid.is_empty(pr, pc):
                    cands = grid.get_candidates(pr, pc)
                    if len(cands) == 2 and cands.issubset(pivot_cands):
                        peer_bivalues.append((pr, pc, cands))
            
            # Check pairs of wings
            for (w1_r, w1_c, w1_cands), (w2_r, w2_c, w2_cands) in combinations(peer_bivalues, 2):
                # Union of wing candidates should include all 3 pivot candidates
                if w1_cands | w2_cands == pivot_cands:
                    # Common candidate Z
                    Z = w1_cands & w2_cands
                    if len(Z) == 1:
                        z_val = list(Z)[0]
                        
                        # Eliminate Z from cells seen by pivot and both wings
                        common_peers = grid.get_peers(pivot_r, pivot_c) & \
                                       grid.get_peers(w1_r, w1_c) & \
                                       grid.get_peers(w2_r, w2_c)
                        
                        for r, c in common_peers:
                            if grid.is_empty(r, c) and z_val in grid.get_candidates(r, c):
                                if (r, c, z_val) not in eliminations:
                                    eliminations.append((r, c, z_val))
    
    return TechniqueResult("xyz_wing", 5, eliminations=eliminations)


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def _get_all_units(grid) -> List[List[Tuple[int, int]]]:
    """Get all rows, columns, and boxes as lists of cell positions."""
    units = []
    
    # Rows
    for r in range(grid.size):
        units.append([(r, c) for c in range(grid.size)])
    
    # Columns
    for c in range(grid.size):
        units.append([(r, c) for r in range(grid.size)])
    
    # Boxes
    for box_r in range(0, grid.size, grid.box_rows):
        for box_c in range(0, grid.size, grid.box_cols):
            box = []
            for r in range(box_r, box_r + grid.box_rows):
                for c in range(box_c, box_c + grid.box_cols):
                    box.append((r, c))
            units.append(box)
    
    return units


# ============================================================================
# TECHNIQUE REGISTRY
# ============================================================================

# Ordered list of techniques by difficulty level
TECHNIQUES = [
    # Level 1 - Basic
    (naked_singles, 1),
    (hidden_singles, 1),
    
    # Level 2 - Easy
    (naked_pairs, 2),
    (hidden_pairs, 2),
    
    # Level 3 - Medium
    (naked_triples, 3),
    (hidden_triples, 3),
    (pointing_pairs, 3),
    (box_line_reduction, 3),
    
    # Level 4 - Hard
    (x_wing, 4),
    (y_wing, 4),
    
    # Level 5 - Expert
    (swordfish, 5),
    (xyz_wing, 5),
]

TECHNIQUE_NAMES = {
    1: ["naked_singles", "hidden_singles"],
    2: ["naked_pairs", "hidden_pairs"],
    3: ["naked_triples", "hidden_triples", "pointing_pairs", "box_line_reduction"],
    4: ["x_wing", "y_wing"],
    5: ["swordfish", "xyz_wing"],
}

LEVEL_NAMES = {
    1: "Easy",
    2: "Medium", 
    3: "Hard",
    4: "Expert",
    5: "Master",
}
