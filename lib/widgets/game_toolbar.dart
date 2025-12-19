import 'package:flutter/material.dart';
import '../models/game_enums.dart';
import 'cosmic_button.dart';

class GameToolbar extends StatelessWidget {
  const GameToolbar({
    super.key,
    required this.gameMode,
    required this.difficulty,
    required this.gridSize,
    required this.onInput,
    required this.isValueCompleted,
  });
  
  final GameMode gameMode;
  final Difficulty difficulty;
  final int gridSize;
  final Function(int) onInput;
  final bool Function(int) isValueCompleted;

  // Cosmic Palette (matching main.dart)
  static const Color kCosmicPrimary = Color(0xFF00F0FF);
  static const Color kRetroHighlight = Color(0xFFE94560);
  static const Color kRetroText = Color(0xFFEEEEEE);
  static const Color kRetroSurface = Color(0xFF1A1A2E);
  static const Color kRetroAccent = Color(0xFF16213E);

  @override
  Widget build(BuildContext context) {
    // Standard Mode (Mini Sudoku Numbers)
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      decoration: BoxDecoration(
        color: kRetroSurface.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: kRetroAccent, width: 2)),
        boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.3),
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
          
          Widget content = Text(
            '$value',
            style: TextStyle(
              color: completed ? kRetroText.withValues(alpha: 0.3) : kRetroText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          );
          
          return _ToolbarButton(
            value: value,
            isCompleted: completed,
            onTap: () => onInput(value),
            child: content,
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: isCompleted ? null : [
             BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glass Background
             ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: isCompleted 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.white.withValues(alpha: 0.1),
                child: Center(child: child),
              ),
            ),
            
            // Bevel Border
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GlassBevelPainter(
                    borderRadius: BorderRadius.circular(12),
                    borderColor: isCompleted 
                        ? Colors.white.withValues(alpha: 0.1) 
                        : Colors.white.withValues(alpha: 0.2),
                    isPressed: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
