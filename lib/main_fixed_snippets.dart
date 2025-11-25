// Note: Uncomment the following imports when using the code snippets below:
// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'game_logic.dart';
// import 'shapes.dart';

// Snippets for restoring and fixing the UI in lib/main.dart

// 1. Fixed _buildBoard (Flat, no 3D tilt, no glow)
/*
  Widget _buildBoard(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boardLength = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: boardLength,
            height: boardLength,
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              children: List<Widget>.generate(boardSize, (int row) {
                return Expanded(
                  child: Row(
                    children: List<Widget>.generate(boardSize, (int col) {
                      final int value = _board[row][col];
                      final bool isEditable = _isEditable[row][col];
                      final bool isSelected =
                          _selectedRow == row && _selectedCol == col;
                      final bool isInvalid =
                          _invalidCell?.row == row && _invalidCell?.col == col;
                      final CellHighlight highlight = _cellHighlight(
                        row,
                        col,
                        value,
                      );
                      final int cellIndex = row * boardSize + col;
                      final bool isAnimated = _animatedCells.contains(
                        cellIndex,
                      );
                      CombinedCell? combinedCell;
                      if (widget.difficulty == Difficulty.medium ||
                          widget.difficulty == Difficulty.hard) {
                        combinedCell = _combinedPuzzle?.initialBoard[row][col];
                      }
                      return Expanded(
                        child: _SudokuCell(
                          value: value,
                          rotationAngle: widget.difficulty == Difficulty.hard
                              ? _computeRotationAngle(row, col)
                              : 0.0,
                          row: row,
                          col: col,
                          isEditable: isEditable,
                          isSelected: isSelected,
                          isInvalid: isInvalid,
                          highlight: highlight,
                          isAnimated: isAnimated,
                          gameMode: widget.mode,
                          difficulty: widget.difficulty,
                          combinedCell: combinedCell,
                          selectedElement: _combinedPuzzle?.selectedElement,
                          onTap: () => _selectCell(row, col),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
*/

// 2. Fixed _SudokuCell (Clean, flat, no neon/extrusion, includes helpers)
/*
class _SudokuCell extends StatelessWidget {
  const _SudokuCell({
    required this.value,
    required this.rotationAngle,
    required this.row,
    required this.col,
    required this.isSelected,
    required this.isEditable,
    required this.isInvalid,
    required this.highlight,
    required this.isAnimated,
    required this.gameMode,
    required this.difficulty,
    this.combinedCell,
    this.selectedElement,
    required this.onTap,
  });

  final int value;
  final double rotationAngle;
  final int row;
  final int col;
  final bool isSelected;
  final bool isEditable;
  final bool isInvalid;
  final CellHighlight highlight;
  final bool isAnimated;
  final GameMode gameMode;
  final Difficulty difficulty;
  final CombinedCell? combinedCell;
  final ElementType? selectedElement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isFixed = !isEditable;
    final bool isEmpty = value == 0;

    Color background;
    Color shapeColor = isFixed ? scheme.onPrimaryContainer : scheme.primary;

    if (isAnimated) {
      background = const Color(0xFFF4B400); // Gold
      shapeColor = Colors.white;
    } else if (isInvalid) {
      background = scheme.errorContainer.withOpacity(0.3);
    } else if (isFixed) {
      background = scheme.primaryContainer.withOpacity(0.2);
    } else if (isEmpty) {
      background = Colors.white.withOpacity(0.05);
    } else {
      background = scheme.surfaceContainerHighest.withOpacity(0.3);
    }

    if (isSelected) {
      background = scheme.primaryContainer.withOpacity(0.5);
      shapeColor = scheme.onPrimaryContainer;
    }

    // Check combined empty
    final bool isSelectedElementEmpty = (difficulty == Difficulty.medium ||
            difficulty == Difficulty.hard) &&
        combinedCell != null &&
        selectedElement != null &&
        ((selectedElement == ElementType.shape && combinedCell!.shapeId == null) ||
            (selectedElement == ElementType.color && combinedCell!.colorId == null) ||
            (selectedElement == ElementType.number && combinedCell!.numberId == null));

    Widget content = (isEmpty || isSelectedElementEmpty)
        ? const SizedBox.expand()
        : Center(
            child: (difficulty == Difficulty.medium || difficulty == Difficulty.hard) &&
                    combinedCell != null
                ? _buildCombinedElement(combinedCell!, selectedElement, shapeColor)
                : _buildSingleElement(context, shapeColor),
          );

    // 3D Rotation for Hard Mode
    if (difficulty == Difficulty.hard && !isEmpty && !isSelectedElementEmpty) {
      content = _buildHardModeRotation(content);
    }

    final Color finalBackground = _applyHighlight(background, highlight);

    return GestureDetector(
      onTap: isEditable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: finalBackground,
          borderRadius: BorderRadius.circular(8),
          border: _buildBorder(scheme),
        ),
        child: content,
      ),
    );
  }

  Color _applyHighlight(Color base, CellHighlight highlight) {
    switch (highlight) {
      case CellHighlight.selected:
        return Color.alphaBlend(const Color.fromRGBO(11, 61, 145, 0.3), base);
      case CellHighlight.matching:
        return Color.alphaBlend(const Color.fromRGBO(11, 84, 180, 0.2), base);
      case CellHighlight.related:
        return Color.alphaBlend(const Color.fromRGBO(173, 204, 255, 0.1), base);
      case CellHighlight.none:
        return base;
    }
  }

  Border _buildBorder(ColorScheme scheme) {
    const double thickWidth = 2.2;
    const double thinWidth = 0.7;
    final BorderSide thick = const BorderSide(
      color: Colors.black,
      width: thickWidth,
    );
    final BorderSide thin = BorderSide(
      color: scheme.outlineVariant,
      width: thinWidth,
    );

    if (highlight == CellHighlight.selected) {
      return Border.all(color: scheme.primary, width: 3);
    }
    if (highlight == CellHighlight.matching) {
      return Border.all(color: Colors.green, width: 2);
    }

    BorderSide left = thin;
    BorderSide right = thin;
    BorderSide top = thin;
    BorderSide bottom = thin;

    if (col % subgridColSize == 0) {
      left = thick;
    }
    if (col == boardSize - 1) {
      right = thick;
    } else if ((col + 1) % subgridColSize == 0) {
      right = thick;
    }

    if (row % subgridRowSize == 0) {
      top = thick;
    }
    if (row == boardSize - 1) {
      bottom = thick;
    } else if ((row + 1) % subgridRowSize == 0) {
      bottom = thick;
    }

    return Border(left: left, right: right, top: top, bottom: bottom);
  }

  Widget _buildHardModeRotation(Widget content) {
     final int index = row * boardSize + col;
      final double base = rotationAngle;
      final double speedZ = 1.0 + (index % 3);
      final double speedX = 1.0 + ((index + 1) % 2);
      final double speedY = 1.0 + ((index + 2) % 2);
      final double phaseZ = (index % boardSize) * (2 * math.pi / boardSize);
      final double phaseX = (index % boardSize) * (2 * math.pi / (boardSize * 2));
      final double phaseY = (index % boardSize) * (2 * math.pi / (boardSize * 3));
      final double angleZ = base * speedZ + phaseZ;
      final double angleX = 0.25 * math.sin(base * speedX + phaseX);
      final double angleY = 0.25 * math.sin(base * speedY + phaseY);

      final Matrix4 transform = Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateX(angleX)
        ..rotateY(angleY)
        ..rotateZ(angleZ);

      return Transform(
        alignment: Alignment.center,
        transform: transform,
        child: content,
      );
  }

  Widget _buildSingleElement(BuildContext context, Color color) {
    if (gameMode == GameMode.colors) {
      return Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getColorForValue(value),
          boxShadow: [
             BoxShadow(
               color: _getColorForValue(value).withOpacity(0.5),
               blurRadius: 8,
               spreadRadius: 2,
             )
          ]
        ),
      );
    } else if (gameMode == GameMode.numbers) {
      return Text(
        value.toString(),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: color.withOpacity(0.5), blurRadius: 8),
          ],
        ),
      );
    } else if (gameMode == GameMode.custom) {
      return FutureBuilder<List<String?>>(
        future: CustomImageRepository.loadCustomImages(),
        builder: (context, snapshot) {
             if (snapshot.hasData && snapshot.data![value - 1] != null) {
               return Padding(
                 padding: const EdgeInsets.all(4),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(8),
                   child: Image.file(File(snapshot.data![value - 1]!), fit: BoxFit.cover),
                 ),
               );
             }
             return SudokuShape(id: value, color: color);
        },
      );
    }
    // Shapes
    return SudokuShape(id: value, color: color);
  }

  Widget _buildCombinedElement(
    CombinedCell cell,
    ElementType? selectedElement,
    Color defaultColor,
  ) {
    final int? shapeId = cell.shapeId;
    final int? colorId = cell.colorId;
    final int? numberId = cell.numberId;

    // If selected element is missing, don't show anything (even if other elements exist)
    if (selectedElement != null) {
      switch (selectedElement) {
        case ElementType.shape:
          if (shapeId == null) return const SizedBox.expand();
          break;
        case ElementType.color:
          if (colorId == null) return const SizedBox.expand();
          break;
        case ElementType.number:
          if (numberId == null) return const SizedBox.expand();
          break;
      }
    }

    // If all elements are missing, show empty
    if (shapeId == null && colorId == null && numberId == null) {
      return const SizedBox.expand();
    }

    // Get color (use default if colorId is null)
    final Color shapeColor = colorId != null
        ? _getColorForValue(colorId)
        : defaultColor;

    // Build the shape (if available)
    Widget? shapeWidget;
    if (shapeId != null) {
      shapeWidget = Padding(
        padding: const EdgeInsets.all(4),
        child: SudokuShape(id: shapeId, color: shapeColor),
      );
    } else if (colorId != null) {
      // If shape is missing but color exists, show a colored circle as placeholder
      shapeWidget = Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: shapeColor,
        ),
      );
    }

    // Build number display (integrated inside, like number mode)
    Widget? numberWidget;
    if (numberId != null) {
      numberWidget = Center(
        child: Text(
          numberId.toString(),
          style: TextStyle(
            fontSize: shapeId != null ? 16 : 20, // Smaller if shape is present
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        // Shape in color (or colored circle if shape is missing)
        if (shapeWidget != null) shapeWidget,
        // Number integrated inside (centered)
        if (numberWidget != null) numberWidget,
      ],
    );
  }
}
*/

// 3. Fixed _buildInputBar
/*
  Widget _buildInputBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List<Widget>.generate(boardSize, (int index) {
          final int value = index + 1;
          final bool completed = _isValueCompleted(value);
          return _ShapePickerButton(
            value: value,
            isCompleted: completed,
            gameMode: widget.mode,
            difficulty: widget.difficulty,
            selectedElement: _combinedPuzzle?.selectedElement,
            onTap: () => _handleShapeInput(value),
          );
        }),
      ),
    );
  }
*/

// 4. Fixed _ShapePickerButton
/*
class _ShapePickerButton extends StatelessWidget {
  const _ShapePickerButton({
    required this.value,
    required this.isCompleted,
    required this.gameMode,
    required this.difficulty,
    this.selectedElement,
    required this.onTap,
  });

  final int value;
  final bool isCompleted;
  final GameMode gameMode;
  final Difficulty difficulty;
  final ElementType? selectedElement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool disabled = isCompleted;
    final Color shapeColor = disabled ? scheme.outline : scheme.primary;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: disabled 
              ? scheme.surfaceContainerHighest.withOpacity(0.2) 
              : scheme.surfaceContainerHighest.withOpacity(0.4),
          border: Border.all(
            color: disabled 
                ? Colors.white.withOpacity(0.1) 
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: (difficulty == Difficulty.medium || difficulty == Difficulty.hard) &&
                  selectedElement != null
              ? _buildCombinedInputButton(context, selectedElement!, value, shapeColor, disabled)
              : gameMode == GameMode.colors
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: disabled
                        ? _getColorForValue(value).withOpacity(0.3)
                        : _getColorForValue(value),
                  ),
                )
              : gameMode == GameMode.numbers
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: disabled
                        ? shapeColor.withOpacity(0.1)
                        : shapeColor.withOpacity(0.15),
                  ),
                  child: Center(
                    child: Text(
                      value.toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: shapeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : gameMode == GameMode.custom
              ? FutureBuilder<List<String?>>(
                  future: CustomImageRepository.loadCustomImages(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<String?>> snapshot,
                      ) {
                        if (snapshot.hasData &&
                            snapshot.data![value - 1] != null) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: disabled
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(
                                File(snapshot.data![value - 1]!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    value.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: shapeColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return SudokuShape(id: value, color: shapeColor);
                      },
                )
              : SudokuShape(id: value, color: shapeColor),
        ),
      ),
    );
  }

  Widget _buildCombinedInputButton(
    BuildContext context,
    ElementType selectedElement,
    int value,
    Color defaultColor,
    bool disabled,
  ) {
    switch (selectedElement) {
      case ElementType.shape:
        return SudokuShape(
          id: value,
          color: disabled ? defaultColor.withOpacity(0.3) : defaultColor,
        );
      case ElementType.color:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled
                ? _getColorForValue(value).withOpacity(0.3)
                : _getColorForValue(value),
          ),
        );
      case ElementType.number:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled
                ? defaultColor.withOpacity(0.1)
                : defaultColor.withOpacity(0.15),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: defaultColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
    }
  }
}
*/

