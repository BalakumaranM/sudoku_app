import 'dart:io';
import 'package:flutter/material.dart';
import '../models/game_enums.dart';
import '../game_logic.dart';
import '../shapes.dart';
import '../utils/custom_image_repository.dart';
import 'glass_modal.dart';

class GameToolbar extends StatelessWidget {
  const GameToolbar({
    super.key,
    required this.gameMode,
    required this.difficulty,
    required this.gridSize,
    required this.onInput,
    this.draftCell,
    required this.shapeMap,
    required this.isValueCompleted,
    this.selectedElement,
  });

  final GameMode gameMode;
  final Difficulty difficulty;
  final int gridSize;
  final Function(int, ElementType?) onInput;
  final CombinedCell? draftCell;
  final List<int> shapeMap;
  final bool Function(int) isValueCompleted;
  final ElementType? selectedElement;

  // Cosmic Palette (matching main.dart)
  static const Color kCosmicPrimary = Color(0xFF00F0FF);
  static const Color kRetroHighlight = Color(0xFFE94560);
  static const Color kRetroText = Color(0xFFEEEEEE);
  static const Color kRetroSurface = Color(0xFF1A1A2E);
  static const Color kRetroAccent = Color(0xFF16213E);

  Color _getColorForValue(int value) {
    const colors = [
      Color(0xFFFF4757), // Bright Watermelon
      Color(0xFF2ED573), // Neon Green
      Color(0xFF1E90FF), // Dodger Blue
      Color(0xFFFFD32A), // Vibrant Yellow
      Color(0xFFA29BFE), // Periwinkle Purple (Bright)
      Color(0xFFFF7F50), // Coral
      Color(0xFF00D2D3), // Bright Cyan
      Color(0xFFFF6B81), // Pastel Red/Pink
      Color(0xFF747D8C), // Cool Grey
    ];
    return colors[(value - 1) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // Combined modes: Medium/Hard/Expert/Master
    if ((difficulty == Difficulty.medium || 
         difficulty == Difficulty.hard ||
         difficulty == Difficulty.expert ||
         difficulty == Difficulty.master) && gameMode != GameMode.numbers) {
       
       final bool isMedium = difficulty == Difficulty.medium;
       
       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
         decoration: BoxDecoration(
           color: kRetroSurface.withOpacity(0.8),
           border: Border(top: BorderSide(color: kRetroAccent, width: 2)),
           boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.3),
               blurRadius: 10,
               offset: const Offset(0, -5),
             ),
           ],
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             if (!isMedium) ...[
               _buildInputRow(ElementType.number),
               const SizedBox(height: 8),
             ],
             _buildInputRow(ElementType.color),
             const SizedBox(height: 8),
             _buildInputRow(ElementType.shape),
           ],
         ),
       );
    }
  
    // Standard Mode
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      decoration: BoxDecoration(
        color: kRetroSurface.withOpacity(0.9),
        border: Border(top: BorderSide(color: kRetroAccent, width: 2)),
        boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.3),
             blurRadius: 10,
             offset: const Offset(0, -5),
           ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List<Widget>.generate(gridSize, (int index) {
          final int value = index + 1;
          final bool completed = isValueCompleted(value);
          
          Widget content;
          final Color shapeColor = completed ? kRetroText.withOpacity(0.3) : kRetroText;
          
          if (gameMode == GameMode.colors) {
             content = Container(
               decoration: BoxDecoration(
                 color: _getColorForValue(value).withOpacity(completed ? 0.3 : 1.0), 
                 shape: BoxShape.circle
               ),
               width: 32, height: 32,
             );
          } else if (gameMode == GameMode.numbers) {
             content = Text(
               '$value',
               style: TextStyle(
                 color: completed ? kRetroText.withOpacity(0.3) : kRetroText,
                 fontSize: 20,
                 fontWeight: FontWeight.bold,
               ),
             );
          } else if (gameMode == GameMode.planets) {
             content = CustomPaint(painter: PlanetPainter(value), size: const Size(24,24));
          } else if (gameMode == GameMode.cosmic) {
             content = CustomPaint(painter: CosmicPainter(value), size: const Size(24, 24));
          } else if (gameMode == GameMode.custom) {
             content = FutureBuilder<List<String?>>(
               future: CustomImageRepository.loadCustomImages(),
               builder: (context, snapshot) {
                 if (snapshot.hasData && snapshot.data![value - 1] != null) {
                   return Container(
                     width: 32, height: 32,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle, 
                       image: DecorationImage(
                         image: FileImage(File(snapshot.data![value - 1]!)), 
                         colorFilter: completed ? ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken) : null, 
                         fit: BoxFit.cover
                       )
                     )
                   );
                 }
                 return SudokuShape(id: shapeMap[index], color: shapeColor);
               }
             );
          } else {
             // Shapes
             content = SudokuShape(id: shapeMap[index], color: shapeColor);
          }
          
          return _ToolbarButton(
            value: value,
            child: content,
            isCompleted: completed,
            onTap: () => onInput(value, null),
          );
        }),
      ),
    );
  }

  Widget _buildInputRow(ElementType type) {
     return SizedBox(
       height: 48,
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
         children: List.generate(gridSize, (index) {
            final val = index + 1;
            bool isSelected = false;
            if (draftCell != null) {
              switch(type) {
                case ElementType.number: isSelected = draftCell!.numberId == val; break;
                case ElementType.color: isSelected = draftCell!.colorId == val; break;
                case ElementType.shape: isSelected = draftCell!.shapeId == val; break;
              }
            }
            
            Widget content;
            if (type == ElementType.number) {
              content = Text(
                '$val', 
                style: TextStyle(
                  color: isSelected ? kRetroHighlight : kRetroText, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16
                )
              );
            } else if (type == ElementType.color) {
              content = Container(
                decoration: BoxDecoration(
                  color: _getColorForValue(val),
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: kRetroHighlight, width: 2) : null,
                  boxShadow: isSelected ? [
                    BoxShadow(color: _getColorForValue(val).withOpacity(0.6), blurRadius: 8)
                  ] : null,
                ),
                width: 24,
                height: 24,
              );
            } else {
              // Shape
              // Combined modes use val directly (1-gridSize) for shapes usually, 
              // but let's check how main.dart did it.
              // main.dart: (widget.mode == GameMode.shapes ? _shapeMap[index] : val)
              // In combined mode, shapeId corresponds to val directly usually.
              // Let's assume val is correct for combined mode.
              content = Padding(
                padding: const EdgeInsets.all(8.0),
                child: SudokuShape(
                  id: val, 
                  color: isSelected ? kRetroHighlight : kRetroText
                ),
              );
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => onInput(val, type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? kRetroHighlight.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      border: Border.all(
                        color: isSelected ? kRetroHighlight : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: kRetroHighlight.withOpacity(0.2),
                          blurRadius: 4,
                        )
                      ] : null,
                    ),
                    child: Center(child: content),
                  ),
                ),
              ),
            );
         }),
       ),
     );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.value,
    required this.child,
    required this.isCompleted,
    required this.onTap,
  });

  final int value;
  final Widget child;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isCompleted ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isCompleted ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
