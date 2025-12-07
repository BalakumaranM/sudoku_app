import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_logic.dart';
import 'models/game_enums.dart';
import 'shapes.dart';
import 'package:animate_do/animate_do.dart';
import 'widgets/animated_button.dart';
import 'widgets/glass_modal.dart';
import 'widgets/shake_animation.dart';
import 'widgets/cosmic_snackbar.dart';
import 'widgets/staggered_slide_fade.dart';
import 'utils/sound_manager.dart';
import 'utils/settings_controller.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'widgets/cosmic_button.dart';

import 'widgets/game_toolbar.dart';
import 'utils/custom_image_repository.dart';
import 'data/classic_puzzles.dart';

class CellPosition {
  final int row;
  final int col;
  const CellPosition({required this.row, required this.col});
}

class HintStep {
  final String description;
  final Set<int> highlights; // Cell indices to highlight
  final Set<int>? rowHighlights; // Row indices (optional)
  final Set<int>? colHighlights; // Column indices (optional)
  final Set<int>? boxHighlights; // Box cell indices (optional)
  final Set<int>? eliminatedCells; // Cells marked with X (optional)
  final Set<int>? numberInstances; // Cells containing target number (optional)
  final bool showTargetCell; // Whether to highlight target cell
  final bool showNumber; // Whether to show number in target cell
  // Visual element display support
  final int? elementValue; // The value (1-9) of the element to display
  final GameMode? gameMode; // Game mode for determining visual representation
  final ElementType? elementType; // Element type for combined modes
  
  HintStep({
    required this.description,
    required this.highlights,
    this.rowHighlights,
    this.colHighlights,
    this.boxHighlights,
    this.eliminatedCells,
    this.numberInstances,
    this.showTargetCell = true,
    this.showNumber = false,
    this.elementValue,
    this.gameMode,
    this.elementType,
  });
}

// Helper class to hold hint result
class _HintResult {
  final String hintType;
  final List<HintStep> steps;
  final int targetRow;
  final int targetCol;
  final int correctVal;
  
  _HintResult({
    required this.hintType,
    required this.steps,
    required this.targetRow,
    required this.targetCol,
    required this.correctVal,
  });
}

class HintInfo {
  final String title; // Consistent across all steps
  final List<HintStep> steps; // All steps for this hint
  final int currentStepIndex; // Current step (0-based)
  final int targetRow;
  final int targetCol;
  final int value;
  // Visual element support
  final GameMode? gameMode;
  final List<int>? shapeMap;
  final ElementType? elementType;
  
  HintInfo({
    required this.title,
    required this.steps,
    this.currentStepIndex = 0,
    required this.targetRow,
    required this.targetCol,
    required this.value,
    this.gameMode,
    this.shapeMap,
    this.elementType,
  });
  
  // Helper methods
  HintStep get currentStep => steps[currentStepIndex];
  bool get isFirstStep => currentStepIndex == 0;
  bool get isLastStep => currentStepIndex == steps.length - 1;
  bool canGoNext() => currentStepIndex < steps.length - 1;
  bool canGoPrevious() => currentStepIndex > 0;
  
  HintInfo copyWith({int? currentStepIndex}) {
    return HintInfo(
      title: title,
      steps: steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      targetRow: targetRow,
      targetCol: targetCol,
      value: value,
      gameMode: gameMode,
      shapeMap: shapeMap,
      elementType: elementType,
    );
  }
  
  // Legacy constructor for backward compatibility during migration
  HintInfo.legacy(this.title, String description, this.targetRow, this.targetCol, this.value, Set<int> highlights)
      : steps = [HintStep(description: description, highlights: highlights)],
        currentStepIndex = 0,
        gameMode = null,
        shapeMap = null,
        elementType = null;
}


// Cosmic Glass Palette
const Color kCosmicBackground = Color(0xFF0B0F19); // Deep Space
const Color kCosmicPrimary = Color(0xFF00F0FF); // Neon Cyan
const Color kCosmicSecondary = Color(0xFF7000FF); // Neon Purple
const Color kCosmicText = Color(0xFFFFFFFF); // White
const Color kCosmicTextSecondary = Color(0xFFB0B8C8); // Light Blue-Grey
const Color kCosmicLocked = Color(0xFF3A3F4F); // Translucent Grey

// Legacy Retro colors (kept for backward compatibility in game logic)
const Color kRetroBackground = Color(0xFF1A1A2E); // Deep Navy
const Color kRetroSurface = Color(0xFF16213E); // Dark Blue
const Color kRetroAccent = Color(0xFF0F3460); // Slate
const Color kRetroHighlight = Color(0xFFE94560); // Red/Pink
const Color kRetroText = Color(0xFFEEEEEE); // White-ish
const Color kRetroError = Color(0xFFFF0055); // Bright Red
const Color kRetroHint = Color(0xFF00FF55); // Green for Hint

  Color _getColorForValue(int value) {
    switch (value) {
      case 1: return const Color(0xFFFF4757); // Bright Watermelon
      case 2: return const Color(0xFF2ED573); // Neon Green
      case 3: return const Color(0xFF1E90FF); // Dodger Blue
      case 4: return const Color(0xFFFFD32A); // Vibrant Yellow
      case 5: return const Color(0xFFA29BFE); // Periwinkle Purple (Bright)
      case 6: return const Color(0xFFFF7F50); // Coral
      case 7: return const Color(0xFF00D2D3); // Bright Cyan
      case 8: return const Color(0xFFFF6B81); // Pastel Red/Pink
      case 9: return const Color(0xFF747D8C); // Cool Grey
      default: return Colors.grey;
    }
  }


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundManager().init();
  await SettingsController().init();
  runApp(const UnsudokuApp());
}

class UnsudokuApp extends StatefulWidget {
  const UnsudokuApp({super.key});

  @override
  State<UnsudokuApp> createState() => _UnsudokuAppState();
}

class _UnsudokuAppState extends State<UnsudokuApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App going to background - pause music
        SoundManager().pauseAmbientMusic();
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground - resume music
        SoundManager().resumeAmbientMusic();
        break;
      case AppLifecycleState.detached:
        // App being destroyed - stop music
        SoundManager().stopAmbientMusic();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsController(),
      builder: (context, child) {
        // Determine theme based on settings
        Color primary = kCosmicPrimary;
        Color secondary = kCosmicSecondary;
        
        if (SettingsController().colorScheme == 'High Contrast') {
          primary = const Color(0xFF00FF00);
          secondary = const Color(0xFFFF0000);
        } else if (SettingsController().colorScheme == 'Colorblind') {
          primary = const Color(0xFFE69F00); // Orange
          secondary = const Color(0xFF56B4E9); // Sky Blue
        }

        final ColorScheme scheme = ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          surface: kCosmicBackground,
          onSurface: kCosmicText,
          primary: primary,
          secondary: secondary,
        );

        return MaterialApp(
          title: 'Unsudoku',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: scheme,
            scaffoldBackgroundColor: kCosmicBackground,
            useMaterial3: true,
            fontFamily: 'Rajdhani',
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: kCosmicText),
              titleTextStyle: const TextStyle(
                color: kCosmicText,
                fontSize: 24,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            textTheme: TextTheme(
              displayLarge: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: kCosmicText,
              ),
              displayMedium: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: kCosmicText,
              ),
              headlineLarge: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kCosmicText,
              ),
              titleLarge: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kCosmicText,
              ),
              bodyLarge: const TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 16,
                color: kCosmicText,
              ),
              bodyMedium: const TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 14,
                color: kCosmicTextSecondary,
              ),
              bodySmall: const TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 12,
                color: kCosmicTextSecondary,
              ),
            ).apply(
              bodyColor: kCosmicText,
              displayColor: kCosmicText,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: kCosmicBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: kCosmicLocked.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: kCosmicLocked.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: primary, width: 1.5),
              ),
            ),
          ),
          home: const HomeScreenWrapper(),
        );
      },
    );
  }
}

class StarryBackground extends StatefulWidget {
  const StarryBackground({super.key, this.speedMultiplier = 1.0});

  final double speedMultiplier;

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didUpdateWidget(StarryBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedMultiplier != widget.speedMultiplier) {
      _controller.duration = Duration(milliseconds: (10000 / widget.speedMultiplier).round());
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Nebula gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    kCosmicBackground.withOpacity(0.3),
                    kCosmicBackground.withOpacity(0.6),
                    kCosmicBackground,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            CustomPaint(
              painter: _StarPainter(_controller.value * widget.speedMultiplier),
              size: Size.infinite,
            ),
          ],
        );
      },
    );
  }
}

class _StarPainter extends CustomPainter {
  final double animationValue;
  _StarPainter(this.animationValue);

  static final List<Offset> _stars = List.generate(
    100,
    (index) => Offset(
      math.Random().nextDouble(),
      math.Random().nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withOpacity(0.3);
    for (int i = 0; i < _stars.length; i++) {
      final offset = _stars[i];
      final double opacity = (math.sin((animationValue * 2 * math.pi) + i) + 1) / 2 * 0.5 + 0.1;
      paint.color = Colors.white.withOpacity(opacity);
      final double x = offset.dx * size.width;
      final double y = offset.dy * size.height;
      final double radius = i % 2 == 0 ? 1.5 : 1.0;
      canvas.drawRect(Rect.fromCircle(center: Offset(x, y), radius: radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => true;
}

/// Custom painter for animating grid lines drawing (Blueprint Effect)
class _GridDrawingPainter extends CustomPainter {
  _GridDrawingPainter({
    required this.gridSize,
    required this.blockRows,
    required this.blockCols,
    required this.progress,
  });

  final int gridSize;
  final int blockRows;
  final int blockCols;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final Paint linePaint = Paint()
      ..color = kCosmicPrimary.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final Paint blockPaint = Paint()
      ..color = kCosmicPrimary.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double cellWidth = size.width / gridSize;
    final double cellHeight = size.height / gridSize;

    // Calculate total lines to draw
    final int totalLines = (gridSize - 1) * 2; // Horizontal + vertical
    final int totalBlockLines = ((gridSize ~/ blockRows) - 1) + ((gridSize ~/ blockCols) - 1);
    final int totalDrawable = totalLines + totalBlockLines;
    final int linesToDraw = (totalDrawable * progress).round();

    int lineIndex = 0;

    // Draw horizontal lines
    for (int i = 1; i < gridSize; i++) {
      if (lineIndex >= linesToDraw) break;
      final double y = i * cellHeight;
      final bool isBlockLine = (i % blockRows == 0);
      final Paint paint = isBlockLine ? blockPaint : linePaint;
      
      final double drawProgress = (linesToDraw - lineIndex).clamp(0.0, 1.0).toDouble();
      final double startX = (size.width / 2) - ((size.width / 2) * drawProgress);
      final double endX = (size.width / 2) + ((size.width / 2) * drawProgress);
      
      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        paint,
      );
      lineIndex++;
    }

    // Draw vertical lines
    for (int i = 1; i < gridSize; i++) {
      if (lineIndex >= linesToDraw) break;
      final double x = i * cellWidth;
      final bool isBlockLine = (i % blockCols == 0);
      final Paint paint = isBlockLine ? blockPaint : linePaint;
      
      final double drawProgress = (linesToDraw - lineIndex).clamp(0.0, 1.0).toDouble();
      final double startY = (size.height / 2) - ((size.height / 2) * drawProgress);
      final double endY = (size.height / 2) + ((size.height / 2) * drawProgress);
      
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        paint,
      );
      lineIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant _GridDrawingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}



class _WaveCompletionPainter extends CustomPainter {
  _WaveCompletionPainter({
    required this.progress,
    required this.row,
    required this.col,
    required this.triggerRow,
    required this.triggerCol,
    required this.gridSize,
    this.triggerBlockRow,
    this.triggerBlockCol,
    this.blockRows,
    this.blockCols,
  });

  final double progress;
  final int? row;
  final int? col;
  final int? triggerRow;
  final int? triggerCol;
  final int gridSize;
  final int? triggerBlockRow;
  final int? triggerBlockCol;
  final int? blockRows;
  final int? blockCols;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final double cellWidth = size.width / gridSize;
    final double cellHeight = size.height / gridSize;
    
    // Wave parameters
    final double waveSpeed = 2.0; // How fast the wave travels
    final double waveWidth = 0.3; // Width of the "head" of the wave (in normalized time)
    
    // Draw Row Wave
    if (row != null && triggerCol != null) {
      for (int c = 0; c < gridSize; c++) {
        // Calculate distance from trigger
        int dist = (c - triggerCol!).abs();
        double normalizedDist = dist / gridSize;
        
        // Calculate activation time for this cell
        // Cells closer to trigger activate earlier
        double activationTime = normalizedDist * 0.5; // Wave takes 50% of animation to reach end
        
        // Calculate current intensity based on progress and activation time
        // We want a "head and tail" effect: starts at 0, goes to 1, then back to 0
        double cellProgress = (progress - activationTime) * waveSpeed;
        
        if (cellProgress > 0 && cellProgress < 1) {
           // Bell curve or sine wave for smooth fade in/out
           double intensity = math.sin(cellProgress * math.pi);
           
           // Draw glow
           final Rect rect = Rect.fromLTWH(c * cellWidth, row! * cellHeight, cellWidth, cellHeight);
           
           // Full cell fill with distinct color (Blue/Cosmic)
           final Paint paint = Paint()
             ..color = Colors.blueAccent.withOpacity(0.5 * intensity) // Distinct blue color
             ..style = PaintingStyle.fill;
           canvas.drawRect(rect, paint);
           
           // Border glow
           final Paint borderPaint = Paint()
             ..color = Colors.white.withOpacity(0.8 * intensity)
             ..style = PaintingStyle.stroke
             ..strokeWidth = 2;
           canvas.drawRect(rect, borderPaint);
        }
      }
    }

    // Draw Column Wave
    if (col != null && triggerRow != null) {
      for (int r = 0; r < gridSize; r++) {
        int dist = (r - triggerRow!).abs();
        double normalizedDist = dist / gridSize;
        double activationTime = normalizedDist * 0.5;
        double cellProgress = (progress - activationTime) * waveSpeed;
        
        if (cellProgress > 0 && cellProgress < 1) {
           double intensity = math.sin(cellProgress * math.pi);
           
           final Rect rect = Rect.fromLTWH(col! * cellWidth, r * cellHeight, cellWidth, cellHeight);
           
           final Paint paint = Paint()
             ..color = Colors.blueAccent.withOpacity(0.8 * intensity) // Increased opacity
             ..style = PaintingStyle.fill;
           canvas.drawRect(rect, paint);
           
           final Paint borderPaint = Paint()
             ..color = Colors.white.withOpacity(1.0 * intensity) // Full opacity
             ..style = PaintingStyle.stroke
             ..strokeWidth = 3; // Thicker border
           canvas.drawRect(rect, borderPaint);
        }
      }
    }

    // Draw Block Wave (Pulse effect)
    if (triggerBlockRow != null && triggerBlockCol != null && blockRows != null && blockCols != null) {
       // Calculate center of block
       double blockCenterX = (triggerBlockCol! + blockCols! / 2) * cellWidth;
       double blockCenterY = (triggerBlockRow! + blockRows! / 2) * cellHeight;
       
       // Pulse expands from center
       double pulseRadius = math.max(blockRows!, blockCols!) * cellWidth * progress;
       double maxRadius = math.max(blockRows!, blockCols!) * cellWidth * 1.5;
       
       if (pulseRadius < maxRadius) {
         final Paint blockPaint = Paint()
           ..color = Colors.purpleAccent.withOpacity(0.4 * (1.0 - progress))
           ..style = PaintingStyle.fill;
           
         // Draw rect for the whole block with fading opacity
         final Rect blockRect = Rect.fromLTWH(
           triggerBlockCol! * cellWidth, 
           triggerBlockRow! * cellHeight, 
           blockCols! * cellWidth, 
           blockRows! * cellHeight
         );
         canvas.drawRect(blockRect, blockPaint);
         
         // Draw expanding ring
         final Paint ringPaint = Paint()
           ..color = Colors.white.withOpacity(0.8 * (1.0 - progress))
           ..style = PaintingStyle.stroke
           ..strokeWidth = 6 * (1.0 - progress); // Thicker ring
           
         canvas.drawCircle(Offset(blockCenterX, blockCenterY), pulseRadius, ringPaint);
       }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveCompletionPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.row != row || 
           oldDelegate.col != col ||
           oldDelegate.triggerRow != triggerRow ||
           oldDelegate.triggerCol != triggerCol;
  }
}

class HomeScreenWrapper extends StatefulWidget {
  const HomeScreenWrapper({super.key});

  @override
  State<HomeScreenWrapper> createState() => _HomeScreenWrapperState();
}

class _HomeScreenWrapperState extends State<HomeScreenWrapper> {
  final PageController _pageController = PageController(initialPage: 1);
  double _currentPage = 1.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 1.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            children: [
              SettingsScreen(
                onBack: () => _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
              const HomeScreen(),
              StatsScreen(
                onBack: () => _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
          // Page indicator
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPageIndicator(0),
                    const SizedBox(width: 8),
                    _buildPageIndicator(1),
                    const SizedBox(width: 8),
                    _buildPageIndicator(2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    bool isActive = (_currentPage - index).abs() < 0.5;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive 
            ? const Color(0xFF64FFDA) 
            : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Start ambient music on home screen
    SoundManager().playAmbientMusic();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Don't stop ambient music here - let it continue or stop when app closes
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resume ambient music when returning to home screen
    SoundManager().playAmbientMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const StarryBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _pulseAnimation.value,
                          child: Text(
                            'UNSUDOKU',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: kCosmicText,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(
                                  color: kCosmicPrimary.withOpacity(0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 64),
                    _MenuButton(
                      title: 'SUDOKU',
                      subtitle: 'Classic Numbers',
                      color: kCosmicPrimary,
                      onTap: () {
                        SoundManager().playClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SudokuSectionScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _MenuButton(
                      title: 'CRAZY SUDOKU',
                      subtitle: 'Shapes, Colors & More',
                      color: kCosmicSecondary,
                      onTap: () {
                        SoundManager().playClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CrazySudokuSectionScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.title, required this.subtitle, required this.color, required this.onTap});
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kCosmicText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 14,
                    color: kCosmicTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SudokuSectionScreen extends StatefulWidget {
  const SudokuSectionScreen({super.key});

  @override
  State<SudokuSectionScreen> createState() => _SudokuSectionScreenState();
}

class _SudokuSectionScreenState extends State<SudokuSectionScreen> {
  final GameMode _mode = GameMode.numbers;
  SudokuSize _selectedSize = SudokuSize.mini; // Default to Mini (6x6)
  int? _easyLevel;
  int? _mediumLevel;
  int? _hardLevel;
  int? _expertLevel;
  int? _masterLevel;
  bool _expertUnlocked = false;
  bool _masterUnlocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLevelsAndUnlockStatus();
    // Start ambient music when entering difficulty selection screen
    SoundManager().playAmbientMusic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resume ambient music when returning to this screen
    SoundManager().ensureAmbientMusicPlaying();
  }

  void _showUnlockMessage(BuildContext context, String difficulty, String message) {
    showCosmicSnackbar(context, message);
  }

  void _startOrContinueGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final savedGame = await CurrentGameRepository.loadGame(mode, diff);
    if (savedGame != null && context.mounted) {
      GlassModal.show(
        context: context,
        title: 'RESUME GAME?',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Time: ${_formatTime(savedGame.elapsedSeconds)}',
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 18,
                  color: kCosmicText,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  CosmicButton(
                    text: 'CONTINUE',
                    icon: Icons.play_arrow,
                    onPressed: () {
                      Navigator.pop(context);
                      SoundManager().stopAmbientMusic();
                      SoundManager().playGameStart();
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen.resume(savedGame: savedGame, sudokuSize: _selectedSize)));
                    },
                  ),
                  const SizedBox(height: 12),
                  CosmicButton(
                    text: 'NEW GAME',
                    icon: Icons.refresh,
                    type: CosmicButtonType.secondary,
                    onPressed: () async {
                      Navigator.pop(context);
                      await CurrentGameRepository.clearGame(mode, diff);
                      if (context.mounted) {
                          SoundManager().stopAmbientMusic();
                        SoundManager().playGameStart();
                        HapticFeedback.mediumImpact();
                        _startNewGame(context, mode, diff);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (context.mounted) {
      SoundManager().stopAmbientMusic();
      SoundManager().playGameStart();
      HapticFeedback.mediumImpact();
      _startNewGame(context, mode, diff);
    }
  }

  void _startNewGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final int level = await ProgressRepository.getLastUnlockedLevel(mode, diff);
    if (context.mounted) {
      SoundManager().stopAmbientMusic();
      Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level, mode: mode, difficulty: diff, sudokuSize: _selectedSize)));
    }
  }

  Future<void> _loadLevelsAndUnlockStatus() async {
    final easyLevel = await ProgressRepository.getLastUnlockedLevel(_mode, Difficulty.easy);
    final mediumLevel = await ProgressRepository.getLastUnlockedLevel(_mode, Difficulty.medium);
    final hardLevel = await ProgressRepository.getLastUnlockedLevel(_mode, Difficulty.hard);
    final expertLevel = await ProgressRepository.getLastUnlockedLevel(_mode, Difficulty.expert);
    final masterLevel = await ProgressRepository.getLastUnlockedLevel(_mode, Difficulty.master);
    final expertUnlocked = await ProgressRepository.isDifficultyUnlocked(_mode, Difficulty.expert);
    final masterUnlocked = await ProgressRepository.isDifficultyUnlocked(_mode, Difficulty.master);
    
    if (mounted) {
      setState(() {
        _easyLevel = easyLevel;
        _mediumLevel = mediumLevel;
        _hardLevel = hardLevel;
        _expertLevel = expertLevel;
        _masterLevel = masterLevel;
        _expertUnlocked = expertUnlocked;
        _masterUnlocked = masterUnlocked;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMini = _selectedSize == SudokuSize.mini;
    final String gridLabel = isMini ? '6×6' : '9×9';
    
    return Scaffold(
      appBar: AppBar(title: const Text('CLASSIC SUDOKU')),
      body: Stack(
        children: [
          const StarryBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Mini/Standard Toggle
              _buildSizeToggle(),
              const SizedBox(height: 24),
              // Difficulty cards
              StaggeredSlideFade(
                key: ValueKey('sudoku_easy_${_selectedSize.name}_${_easyLevel ?? 0}'),
                delay: const Duration(milliseconds: 100),
                child: _DifficultyCard(
                  title: 'EASY',
                  description: '$gridLabel GRID',
                  difficulty: Difficulty.easy,
                  color: kCosmicPrimary,
                  currentLevel: _easyLevel,
                  isLocked: false,
                  onTap: () => _startOrContinueGame(context, _mode, Difficulty.easy),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('sudoku_medium_${_selectedSize.name}_${_mediumLevel ?? 0}'),
                delay: const Duration(milliseconds: 200),
                child: _DifficultyCard(
                  title: 'MEDIUM',
                  description: '$gridLabel GRID',
                  difficulty: Difficulty.medium,
                  color: kCosmicPrimary,
                  currentLevel: _mediumLevel,
                  isLocked: false,
                  onTap: () => _startOrContinueGame(context, _mode, Difficulty.medium),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('sudoku_hard_${_selectedSize.name}_${_hardLevel ?? 0}'),
                delay: const Duration(milliseconds: 300),
                child: _DifficultyCard(
                  title: 'HARD',
                  description: '$gridLabel GRID',
                  difficulty: Difficulty.hard,
                  color: kCosmicPrimary,
                  currentLevel: _hardLevel,
                  isLocked: false,
                  onTap: () => _startOrContinueGame(context, _mode, Difficulty.hard),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('sudoku_expert_${_selectedSize.name}_${_expertLevel ?? 0}'),
                delay: const Duration(milliseconds: 400),
                child: _DifficultyCard(
                  title: 'EXPERT',
                  description: '$gridLabel GRID',
                  difficulty: Difficulty.expert,
                  color: kCosmicPrimary,
                  currentLevel: _expertUnlocked ? _expertLevel : null,
                  isLocked: !_expertUnlocked,
                  onTap: _expertUnlocked
                      ? () => _startOrContinueGame(context, _mode, Difficulty.expert)
                      : () => _showUnlockMessage(context, 'Expert', 'Need to complete 3 levels of Hard to open this'),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('sudoku_master_${_selectedSize.name}_${_masterLevel ?? 0}'),
                delay: const Duration(milliseconds: 500),
                child: _DifficultyCard(
                  title: 'MASTER',
                  description: '$gridLabel GRID',
                  difficulty: Difficulty.master,
                  color: kCosmicPrimary,
                  currentLevel: _masterUnlocked ? _masterLevel : null,
                  isLocked: !_masterUnlocked,
                  onTap: _masterUnlocked
                      ? () => _startOrContinueGame(context, _mode, Difficulty.master)
                      : () => _showUnlockMessage(context, 'Master', 'Need to complete 3 levels of Expert to open this'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSizeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedSize != SudokuSize.mini) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSize = SudokuSize.mini);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedSize == SudokuSize.mini
                      ? kCosmicPrimary.withOpacity(0.8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'MINI',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _selectedSize == SudokuSize.mini
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '6×6',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 12,
                        color: _selectedSize == SudokuSize.mini
                            ? Colors.white.withOpacity(0.8)
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedSize != SudokuSize.standard) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSize = SudokuSize.standard);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedSize == SudokuSize.standard
                      ? kCosmicPrimary.withOpacity(0.8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'STANDARD',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _selectedSize == SudokuSize.standard
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '9×9',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 12,
                        color: _selectedSize == SudokuSize.standard
                            ? Colors.white.withOpacity(0.8)
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CrazySudokuSectionScreen extends StatefulWidget {
  const CrazySudokuSectionScreen({super.key});

  @override
  State<CrazySudokuSectionScreen> createState() => _CrazySudokuSectionScreenState();
}

class _CrazySudokuSectionScreenState extends State<CrazySudokuSectionScreen> {
  // Use shapes mode as default for level checking
  final GameMode _defaultMode = GameMode.shapes;
  int? _easyShapesLevel;
  int? _easyPlanetsLevel;
  int? _easyCosmicLevel;
  int? _mediumLevel;
  int? _hardLevel;
  int? _expertLevel;
  int? _masterLevel;
  bool _expertUnlocked = false;
  bool _masterUnlocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLevelsAndUnlockStatus();
    // Ensure ambient music is playing (resume if paused during navigation)
    SoundManager().ensureAmbientMusicPlaying();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resume ambient music when returning to this screen
    SoundManager().ensureAmbientMusicPlaying();
  }

  Future<void> _loadLevelsAndUnlockStatus() async {
    final easyShapesLevel = await ProgressRepository.getLastUnlockedLevel(GameMode.shapes, Difficulty.easy);
    final easyPlanetsLevel = await ProgressRepository.getLastUnlockedLevel(GameMode.planets, Difficulty.easy);
    final easyCosmicLevel = await ProgressRepository.getLastUnlockedLevel(GameMode.cosmic, Difficulty.easy);
    final mediumLevel = await ProgressRepository.getLastUnlockedLevel(_defaultMode, Difficulty.medium);
    final hardLevel = await ProgressRepository.getLastUnlockedLevel(_defaultMode, Difficulty.hard);
    final expertLevel = await ProgressRepository.getLastUnlockedLevel(_defaultMode, Difficulty.expert);
    final masterLevel = await ProgressRepository.getLastUnlockedLevel(_defaultMode, Difficulty.master);
    final bool expertUnlocked = true; // Expert is always unlocked
    final masterUnlocked = await ProgressRepository.isDifficultyUnlocked(_defaultMode, Difficulty.master);
    
    if (mounted) {
      setState(() {
        _easyShapesLevel = easyShapesLevel;
        _easyPlanetsLevel = easyPlanetsLevel;
        _easyCosmicLevel = easyCosmicLevel;
        _mediumLevel = mediumLevel;
        _hardLevel = hardLevel;
        _expertLevel = expertLevel;
        _masterLevel = masterLevel;
        _expertUnlocked = expertUnlocked;
        _masterUnlocked = masterUnlocked;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRAZY SUDOKU')),
      body: Stack(
        children: [
          const StarryBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              StaggeredSlideFade(
                key: const ValueKey('crazy_easy'),
                delay: const Duration(milliseconds: 100),
                child: _DifficultyCard(
                  title: 'EASY',
                  description: '6x6 - Shapes / Planets / Cosmic / Custom',
                  difficulty: Difficulty.easy,
                  color: kCosmicPrimary,
                  isLocked: false,
                  onTap: () {
                    SoundManager().playClick();
                    GlassModal.show(
                      context: context,
                      title: 'CHOOSE TYPE',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypeOption(
                            context,
                            'SHAPES (6x6)${_easyShapesLevel != null ? ' - Lv$_easyShapesLevel' : ''}',
                            () {
                              Navigator.pop(context);
                              _startOrContinueGame(context, GameMode.shapes, Difficulty.easy);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTypeOption(
                            context,
                            'PLANETS (6x6)${_easyPlanetsLevel != null ? ' - Lv$_easyPlanetsLevel' : ''}',
                            () {
                              Navigator.pop(context);
                              _startOrContinueGame(context, GameMode.planets, Difficulty.easy);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTypeOption(
                            context,
                            'COSMIC (6x6)${_easyCosmicLevel != null ? ' - Lv$_easyCosmicLevel' : ''}',
                            () {
                              Navigator.pop(context);
                              _startOrContinueGame(context, GameMode.cosmic, Difficulty.easy);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTypeOption(
                            context,
                            'CUSTOM (6x6)',
                            () async {
                              Navigator.pop(context);
                              final images = await CustomImageRepository.loadCustomImages();
                              final bool allSet = images.every((path) => path != null);
                              if (context.mounted) {
                                if (allSet) {
                                  _startOrContinueGame(context, GameMode.custom, Difficulty.easy);
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomImageSetupScreen()));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('crazy_medium_${_mediumLevel ?? 0}'),
                delay: const Duration(milliseconds: 200),
                child: _DifficultyCard(
                  title: 'MEDIUM',
                  description: '6x6 - Shapes & Colors',
                  difficulty: Difficulty.medium,
                  color: kCosmicPrimary,
                  currentLevel: _mediumLevel,
                  isLocked: false,
                  onTap: () => _startOrContinueGame(context, GameMode.shapes, Difficulty.medium),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('crazy_hard_${_hardLevel ?? 0}'),
                delay: const Duration(milliseconds: 300),
                child: _DifficultyCard(
                  title: 'HARD',
                  description: '6x6 - Shapes, Colors & Numbers',
                  difficulty: Difficulty.hard,
                  color: kCosmicPrimary,
                  currentLevel: _hardLevel,
                  isLocked: false,
                  onTap: () => _startOrContinueGame(context, GameMode.shapes, Difficulty.hard),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('crazy_expert_${_expertLevel ?? 0}'),
                delay: const Duration(milliseconds: 400),
                child: _DifficultyCard(
                  title: 'EXPERT',
                  description: '9x9 - Shapes, Colors & Numbers',
                  difficulty: Difficulty.expert,
                  color: kCosmicPrimary,
                  currentLevel: _expertLevel,
                  isLocked: false,
                  onTap: () => _startOrContinueGame(context, GameMode.shapes, Difficulty.expert),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredSlideFade(
                key: ValueKey('crazy_master_${_masterLevel ?? 0}'),
                delay: const Duration(milliseconds: 500),
                child: _DifficultyCard(
                  title: 'MASTER',
                  description: '9x9 - Shapes, Colors & Numbers',
                  difficulty: Difficulty.master,
                  color: kCosmicPrimary,
                  currentLevel: _masterUnlocked ? _masterLevel : null,
                  isLocked: !_masterUnlocked,
                  onTap: _masterUnlocked
                      ? () => _startOrContinueGame(context, GameMode.shapes, Difficulty.master)
                      : () => _showUnlockMessage(context, 'Master', 'Need to complete 3 levels of Expert to open this'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(BuildContext context, String label, VoidCallback onTap) {
    return AnimatedButton(
      onTap: () {
        SoundManager().playClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kCosmicPrimary.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kCosmicPrimary.withOpacity(0.4), width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 16,
            color: kCosmicText,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showUnlockMessage(BuildContext context, String difficulty, String message) {
    showCosmicSnackbar(context, message);
  }

  void _startOrContinueGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final savedGame = await CurrentGameRepository.loadGame(mode, diff);
    if (savedGame != null && context.mounted) {
      GlassModal.show(
        context: context,
        title: 'RESUME GAME?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Time: ${_formatTime(savedGame.elapsedSeconds)}',
              style: const TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 18,
                color: kCosmicText,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                CosmicButton(
                  text: 'CONTINUE',
                  icon: Icons.play_arrow,
                  onPressed: () {
                    Navigator.pop(context);
                    SoundManager().stopAmbientMusic();
                    SoundManager().playGameStart();
                    HapticFeedback.mediumImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen.resume(savedGame: savedGame)));
                  },
                ),
                const SizedBox(height: 12),
                CosmicButton(
                  text: 'NEW GAME',
                  icon: Icons.refresh,
                  type: CosmicButtonType.secondary,
                  onPressed: () async {
                    Navigator.pop(context);
                    await CurrentGameRepository.clearGame(mode, diff);
                    if (context.mounted) {
                        SoundManager().stopAmbientMusic();
                      SoundManager().playGameStart();
                      HapticFeedback.mediumImpact();
                      _startNewGame(context, mode, diff);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      if (context.mounted) {
          SoundManager().stopAmbientMusic();
        SoundManager().playGameStart();
        HapticFeedback.mediumImpact();
        _startNewGame(context, mode, diff);
      }
    }
  }

  void _startNewGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final int level = await ProgressRepository.getLastUnlockedLevel(mode, diff);
    if (context.mounted) {
      SoundManager().stopAmbientMusic();
      Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level, mode: mode, difficulty: diff)));
    }
  }
}

String _formatTime(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Returns cosmic progression icon for difficulty level
IconData _getDifficultyIcon(Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.easy:
      return Icons.nightlight_round; // Moon placeholder
    case Difficulty.medium:
      return Icons.circle; // Planet placeholder (will need custom ringed planet)
    case Difficulty.hard:
      return Icons.wb_sunny; // Star/Sun
    case Difficulty.expert:
      return Icons.blur_circular; // Galaxy placeholder (will need custom spiral)
    case Difficulty.master:
      return Icons.radio_button_checked; // Black Hole placeholder (will need custom)
  }
}

/// Builds an icon widget for difficulty level, using custom icon assets if available,
/// otherwise falls back to Material Icons
Widget _buildDifficultyIconWidget(Difficulty difficulty, Color color, double size) {
  // Map difficulty to custom icon asset path
  final String iconAssetPath;
  switch (difficulty) {
    case Difficulty.easy:
      iconAssetPath = 'assets/icons/moon.png';
      break;
    case Difficulty.medium:
      iconAssetPath = 'assets/icons/planet.png';
      break;
    case Difficulty.hard:
      // Hard uses star icon which works well, but can also use custom
      iconAssetPath = 'assets/icons/star.png';
      break;
    case Difficulty.expert:
      iconAssetPath = 'assets/icons/galaxy.png';
      break;
    case Difficulty.master:
      iconAssetPath = 'assets/icons/blackhole.png';
      break;
  }

  // Try to load custom icon, fall back to Material Icon if not available
  // Use Image.asset with errorBuilder to fall back to Material Icon
  return Image.asset(
    iconAssetPath,
    width: size,
    height: size,
    color: color,
    errorBuilder: (context, error, stackTrace) {
      // Fall back to Material Icon if custom icon doesn't exist
      return Icon(
        _getDifficultyIcon(difficulty),
        size: size,
        color: color,
      );
    },
  );
}

class _DifficultyCard extends StatefulWidget {
  const _DifficultyCard({
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.difficulty,
    this.icon,
    this.currentLevel,
    this.isLocked = false,
  }) : assert(difficulty != null || icon != null, 'Either difficulty or icon must be provided');

  final String title;
  final String description;
  final Difficulty? difficulty;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;
  final int? currentLevel;
  final bool isLocked;

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard> {
  bool _shouldShake = false;

  @override
  Widget build(BuildContext context) {
    final String displayTitle = widget.currentLevel != null ? '${widget.title} - Lv${widget.currentLevel}' : widget.title;
    
    final effectiveColor = widget.isLocked ? kCosmicLocked : kCosmicPrimary;
    final opacity = widget.isLocked ? 0.5 : 1.0;
    
    return ShakeAnimation(
      shouldShake: _shouldShake,
      child: AnimatedButton(
        onTap: widget.isLocked ? () {
        SoundManager().playLocked();
        HapticFeedback.mediumImpact();
          setState(() {
            _shouldShake = true;
          });
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() {
                _shouldShake = false;
              });
            }
          });
          // Call parent onTap to show snackbar message
          widget.onTap();
      } : () {
        SoundManager().playClick();
        HapticFeedback.lightImpact();
          widget.onTap();
      },
      enabled: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              effectiveColor.withOpacity(widget.isLocked ? 0.1 : 0.15),
              effectiveColor.withOpacity(widget.isLocked ? 0.05 : 0.1),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: effectiveColor.withOpacity(widget.isLocked ? 0.3 : 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: effectiveColor.withOpacity(widget.isLocked ? 0.1 : 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  widget.difficulty != null
                      ? _buildDifficultyIconWidget(widget.difficulty!, effectiveColor.withOpacity(opacity), 24)
                      : Icon(widget.icon!, size: 24, color: effectiveColor.withOpacity(opacity)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.isLocked ? kCosmicTextSecondary.withOpacity(0.7) : kCosmicText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 12,
                            color: widget.isLocked ? kCosmicTextSecondary.withOpacity(0.5) : kCosmicTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isLocked)
                    Icon(Icons.lock, color: effectiveColor.withOpacity(opacity), size: 20)
                  else
                    Icon(Icons.arrow_forward_ios, color: effectiveColor.withOpacity(opacity), size: 16),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ... CustomImageSetupScreen ...
class CustomImageSetupScreen extends StatefulWidget {
  const CustomImageSetupScreen({super.key});
  @override
  State<CustomImageSetupScreen> createState() => _CustomImageSetupScreenState();
}

class _CustomImageSetupScreenState extends State<CustomImageSetupScreen> {
  final List<String?> _imagePaths = List.filled(9, null); 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final loaded = await CustomImageRepository.loadCustomImages();
    setState(() {
      for(int i=0; i<loaded.length; i++) {
        if(i < 9) _imagePaths[i] = loaded[i];
      }
      _isLoading = false;
    });
  }

  Future<void> _pickImage(int index) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'custom_icon_${index + 1}.png';
      final File localImage = await File(image.path).copy('${appDir.path}/$fileName');
      setState(() { _imagePaths[index] = localImage.path; });
      await CustomImageRepository.saveCustomImage(index, localImage.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _imagePaths.every((p) => p != null);
    return Scaffold(
      appBar: AppBar(title: const Text("CUSTOM MODE SETUP")),
      body: Stack(
        children: [
          const StarryBackground(),
          _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Select an image for each number (1-9).", textAlign: TextAlign.center),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final path = _imagePaths[index];
                    return InkWell(
                      onTap: () => _pickImage(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kRetroSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: kRetroText.withOpacity(0.5)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: path != null
                            ? Image.file(File(path), fit: BoxFit.cover)
                            : const Center(child: Icon(Icons.add, color: kRetroText)),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: allSelected ? () => Navigator.pop(context) : null,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text("SAVE & CONTINUE"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class ProgressRepository {
  static Future<LevelStatus> getLevelStatus(int level, GameMode mode, Difficulty difficulty) async {
    if (level == 1) return LevelStatus.unlocked;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = '${_prefix(mode, difficulty)}$level';
    final String? status = prefs.getString(key);
    if (status == 'completed') return LevelStatus.completed;
    final String prevKey = '${_prefix(mode, difficulty)}${level - 1}';
    if (prefs.getString(prevKey) == 'completed') return LevelStatus.unlocked;
    return LevelStatus.locked;
  }

  static Future<int> getLastUnlockedLevel(GameMode mode, Difficulty difficulty) async {
    for (int i = 1; i <= 50; i++) {
      final status = await getLevelStatus(i, mode, difficulty);
      if (status == LevelStatus.locked) return math.max(1, i - 1);
      if (status == LevelStatus.unlocked) return i;
    }
    return 50;
  }

  static Future<void> completeLevel(int level, GameMode mode, Difficulty difficulty, int stars, int timeSeconds, int mistakes) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = '${_prefix(mode, difficulty)}$level';
    await prefs.setString(key, 'completed');
    await prefs.setInt('${key}_stars', stars);
    await prefs.setInt('${key}_time', timeSeconds);
    await prefs.setInt('${key}_mistakes', mistakes);
  }

  static String _prefix(GameMode mode, Difficulty difficulty) {
    return '${difficulty.name}_${mode.name}_level_';
  }
  
  static Future<int> getCompletedLevelsCount(GameMode mode, Difficulty difficulty) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (int i = 1; i <= 50; i++) {
      final String key = '${_prefix(mode, difficulty)}$i';
      if (prefs.getString(key) == 'completed') count++;
    }
    return count;
  }
  
  static Future<bool> isDifficultyUnlocked(GameMode mode, Difficulty difficulty) async {
    switch (difficulty) {
      case Difficulty.easy:
      case Difficulty.medium:
      case Difficulty.hard:
      case Difficulty.expert:
        return true; // Always unlocked
      case Difficulty.master:
        final expertCount = await getCompletedLevelsCount(mode, Difficulty.expert);
        return expertCount >= 3;
    }
  }
  
  static Future<void> resetAllProgress() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

enum LevelStatus { locked, unlocked, completed }

class GameStateData {
  final GameMode mode;
  final Difficulty difficulty;
  final int levelNumber;
  final List<List<int>> board;
  final List<List<Set<int>>> notes;
  final int mistakes;
  final int elapsedSeconds;
  // Combined mode notes (for medium/hard/expert/master)
  final List<List<Set<int>>>? shapeNotes;
  final List<List<Set<int>>>? colorNotes;
  final List<List<Set<int>>>? numberNotes;
  final List<List<ElementType?>>? pencilNoteType;

  GameStateData({
    required this.mode,
    required this.difficulty,
    required this.levelNumber,
    required this.board,
    required this.notes,
    required this.mistakes,
    required this.elapsedSeconds,
    this.shapeNotes,
    this.colorNotes,
    this.numberNotes,
    this.pencilNoteType,
  });

  Map<String, dynamic> toJson() => {
    'mode': mode.index,
    'difficulty': difficulty.index,
    'levelNumber': levelNumber,
    'board': board,
    'notes': notes.map((row) => row.map((set) => set.toList()).toList()).toList(),
    'mistakes': mistakes,
    'elapsedSeconds': elapsedSeconds,
  };

  static GameStateData fromJson(Map<String, dynamic> json) {
    return GameStateData(
      mode: GameMode.values[json['mode']],
      difficulty: Difficulty.values[json['difficulty']],
      levelNumber: json['levelNumber'],
      board: List<List<int>>.from(json['board'].map((x) => List<int>.from(x))),
      notes: List<List<Set<int>>>.from(json['notes'].map((row) => List<Set<int>>.from(row.map((x) => Set<int>.from(x))))),
      mistakes: json['mistakes'],
      elapsedSeconds: json['elapsedSeconds'],
    );
  }
}

class CurrentGameRepository {
  static Future<void> saveGame(GameStateData data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'current_game_${data.mode.name}_${data.difficulty.name}';
    await prefs.setString(key, jsonEncode(data.toJson()));
  }

  static Future<GameStateData?> loadGame(GameMode mode, Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'current_game_${mode.name}_${difficulty.name}';
    final String? jsonStr = prefs.getString(key);
    if (jsonStr == null) return null;
    return GameStateData.fromJson(jsonDecode(jsonStr));
  }

  static Future<void> clearGame(GameMode mode, Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'current_game_${mode.name}_${difficulty.name}';
    await prefs.remove(key);
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.levelNumber,
    required this.mode,
    required this.difficulty,
    this.initialState,
    this.sudokuSize,
  });

  final int levelNumber;
  final GameMode mode;
  final Difficulty difficulty;
  final GameStateData? initialState;
  final SudokuSize? sudokuSize; // For Classic Sudoku: mini (6x6) or standard (9x9)

  factory GameScreen.resume({required GameStateData savedGame, SudokuSize? sudokuSize}) {
    return GameScreen(
      levelNumber: savedGame.levelNumber,
      mode: savedGame.mode,
      difficulty: savedGame.difficulty,
      initialState: savedGame,
      sudokuSize: sudokuSize,
    );
  }

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<List<int>> _board;
  late List<List<bool>> _isEditable;
  late List<List<Set<int>>> _notes;
  // Medium mode separate notes
  late List<List<Set<int>>> _shapeNotes;
  late List<List<Set<int>>> _colorNotes;
  late List<List<Set<int>>> _numberNotes;
  // Track which element type has pencil notes per cell (null = no notes yet)
  late List<List<ElementType?>> _pencilNoteType;
  late SudokuPuzzle? _sudokuPuzzle;
  CombinedPuzzle? _combinedPuzzle;
  
  // Medium Combined Draft
  CombinedCell? _draftCell; 
  
  int? _selectedRow;
  int? _selectedCol;
  final Set<int> _animatedCells = {};
  final Set<int> _errorCells = {};
  
  late Stopwatch _stopwatch;
  late int _elapsed;
  late AnimationController _rotationController;
  late AnimationController _completionController;
  late AnimationController _groupCompletionController;
  late AnimationController _gridAnimationController;
  late AnimationController _numbersFadeController;
  late AnimationController _winAnimationController;
  late AnimationController _lineCompletionController;
  late AnimationController _glitterController;
  int? _completedRow;
  int? _completedCol;
  int? _triggerRow;
  int? _triggerCol;
  int? _triggerBlockRow;
  int? _triggerBlockCol;
  int? _highlightedNumber; // The number to highlight after correct input
  // final Set<int> _glitterCells = {}; // Removed as we animate numbers now
  
  // GlobalKey for board container to calculate column positions
  final GlobalKey _boardKey = GlobalKey();
  
  late int _gridSize;
  late int _blockRows;
  late int _blockCols;
  bool _showHighlights = true;
  
  bool _pencilMode = false;
  int _mistakes = 0;
  static const int _maxMistakes = 4;
  final List<GameStateData> _history = [];
  
  // Hint tracking for Crazy Sudoku
  int _hintsRemaining = 0;
  int _maxHints = 0;

  // Track which elements the user has filled per cell for combined modes
  // Key: "row_col", Value: Set of ElementTypes the user has filled
  Map<String, Set<ElementType>> _userFilledElements = {};

  late List<int> _shapeMap;
  HintInfo? _activeHint;
  // Store current hint element type for apply action
  ElementType? _activeHintElementType;

  // Debug toolbar state
  bool _showDebugToolbar = false;

  @override
  void initState() {
    super.initState();
    _initializeGridSize();
    _initializeHintCounter();
    _stopwatch = Stopwatch();
    _elapsed = widget.initialState?.elapsedSeconds ?? 0;
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _groupCompletionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _numbersFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _winAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _lineCompletionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Slower wave
    );
    
    _lineCompletionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _completedRow = null;
          _completedCol = null;
          _triggerBlockRow = null;
          _triggerBlockCol = null;
        });
        _lineCompletionController.reset();
      }
    });

    _glitterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // Longer, more visible
    );

    final allShapes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    if (_gridSize == 6) {
      allShapes.shuffle(math.Random(widget.levelNumber));
      _shapeMap = allShapes.take(6).toList();
    } else {
      _shapeMap = allShapes;
    }

    _initializeGame();
    
    // Check if the game is already completed (e.g. resumed from a finished state)
    // This handles the bug where resuming a finished game doesn't trigger win
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isBoardSolved()) {
        _onLevelComplete();
      }
    });
    
    // Start grid drawing animation
    _gridAnimationController.forward().then((_) {
      // After grid is drawn, fade in numbers
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _numbersFadeController.forward();
          
          // Start glitter animation
          _glitterController.forward().then((_) {
             if (mounted) {
               _stopwatch.start();
               // setState(() => _glitterCells.clear()); // No longer needed
             }
          });
          
          // No periodic timer needed for number scaling animation
          // The controller value itself will drive the scale/flash
        }
      });
    });
    
    // Timer starts after animation now
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_stopwatch.isRunning) {
        setState(() {
          _elapsed = (widget.initialState?.elapsedSeconds ?? 0) + _stopwatch.elapsed.inSeconds;
        });
        if (widget.difficulty != Difficulty.hard && widget.difficulty != Difficulty.expert && widget.difficulty != Difficulty.master) _saveGameState();
      }
    });
  }

  void _initializeGridSize() {
    // For Classic Sudoku (Numbers mode): use sudokuSize to determine grid
    if (widget.mode == GameMode.numbers && widget.sudokuSize != null) {
      if (widget.sudokuSize == SudokuSize.mini) {
        _gridSize = 6;
        _blockRows = 2;
        _blockCols = 3;
      } else {
        _gridSize = 9;
        _blockRows = 3;
        _blockCols = 3;
      }
      return;
    }
    
    // Determine if this is a Crazy Sudoku mode (combined shapes/colors)
    final bool isCrazySudoku = widget.mode != GameMode.numbers && 
                                widget.mode != GameMode.custom;
    
    if (widget.difficulty == Difficulty.easy) {
      // Easy: Always 6x6
      _gridSize = 6;
      _blockRows = 2;
      _blockCols = 3;
    } else if (isCrazySudoku && (widget.difficulty == Difficulty.medium || 
                                 widget.difficulty == Difficulty.hard)) {
      // Crazy Sudoku Medium & Hard: 6x6
      _gridSize = 6;
      _blockRows = 2;
      _blockCols = 3;
    } else {
      // Standard Sudoku Medium/Hard/Expert/Master OR Crazy Sudoku Expert/Master: 9x9
      _gridSize = 9;
      _blockRows = 3;
      _blockCols = 3;
    }
  }

  void _initializeHintCounter() {
    final bool isCrazySudoku = widget.mode != GameMode.numbers && 
                                widget.mode != GameMode.custom;
    
    if (!isCrazySudoku) {
      // Standard Sudoku: 3 hints per level
      _maxHints = 3;
    } else if (widget.difficulty == Difficulty.easy || widget.difficulty == Difficulty.medium) {
      // 2-element modes (shape + color): 6 hints
      _maxHints = 6;
    } else {
      // 3-element modes (shape + color + number): 9 hints
      _maxHints = 9;
    }
    _hintsRemaining = _maxHints;
  }

  void _initializeGame() {
    _generateLevelLogic();

    if (widget.initialState != null) {
      _board = List.generate(_gridSize, (r) => List.from(widget.initialState!.board[r]));
      _notes = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => Set<int>.from(widget.initialState!.notes[r][c])));
      _mistakes = widget.initialState!.mistakes;
    } else {
      _notes = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => {}));
      _mistakes = 0;
    }
    
    // Initialize Medium mode separate notes
    _shapeNotes = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => <int>{}));
    _colorNotes = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => <int>{}));
    _numberNotes = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => <int>{}));
    // Initialize pencil note type lock
    _pencilNoteType = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => null));
  }

  void _generateLevelLogic() {
    // Medium, Hard, Expert, and Master modes use CombinedPuzzleGenerator for shapes/colors modes
    if ((widget.difficulty == Difficulty.medium || 
         widget.difficulty == Difficulty.hard ||
         widget.difficulty == Difficulty.expert ||
         widget.difficulty == Difficulty.master) && 
        widget.mode != GameMode.numbers && 
        widget.mode != GameMode.planets &&
        widget.mode != GameMode.custom &&
        widget.mode != GameMode.cosmic) {
       
       final generator = CombinedPuzzleGenerator(
         widget.levelNumber, 
         widget.difficulty.index,
         gridSize: _gridSize,
         subgridRowSize: _blockRows,
         subgridColSize: _blockCols,
       );
       _combinedPuzzle = generator.generateCombined();
       
       if (widget.initialState == null) {
         _board = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => 0));
       }
       
       _isEditable = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => false));
       
       for (int r = 0; r < _gridSize; r++) {
         for (int c = 0; c < _gridSize; c++) {
            final cell = _combinedPuzzle!.initialBoard[r][c];
            bool isFixed = cell.isFixed;
               if (widget.initialState == null) {
                  _board[r][c] = isFixed ? 1 : 0; // Prefill fixed cells
               }
               _isEditable[r][c] = !isFixed; // Only non-fixed cells are editable
         }
       }
       _sudokuPuzzle = null;
    } else {
       // Easy mode, custom mode, and other non-combined modes
       
       // For Numbers mode (Classic Sudoku): use pre-generated puzzles from ClassicPuzzles
       if (widget.mode == GameMode.numbers) {
         final size = widget.sudokuSize ?? SudokuSize.mini;
         _sudokuPuzzle = ClassicPuzzles.getPuzzle(size, widget.difficulty, widget.levelNumber);
       } else {
         // For other modes: use LevelGenerator
         // For Easy mode: route odd levels to planets, even levels to cosmic
         int modeIndex = widget.mode.index;
         if (widget.difficulty == Difficulty.easy && 
             (widget.mode == GameMode.planets || widget.mode == GameMode.cosmic)) {
           // Use planets for odd levels, cosmic for even levels
           modeIndex = (widget.levelNumber % 2 == 1) ? GameMode.planets.index : GameMode.cosmic.index;
         }
         
         final generator = LevelGenerator(
           widget.levelNumber, 
           modeIndex,
           gridSize: _gridSize,
           subgridRowSize: _blockRows,
           subgridColSize: _blockCols,
         );
         _sudokuPuzzle = generator.generate();
       }
       
       // Initialize board with prefilled cells from the generated puzzle
       if (widget.initialState == null) {
         _board = List.generate(_gridSize, (i) => List.from(_sudokuPuzzle!.initialBoard[i]));
       }
       
       _isEditable = List.generate(
         _gridSize,
         (r) => List.generate(_gridSize, (c) => _sudokuPuzzle!.initialBoard[r][c] == 0),
       );
       _combinedPuzzle = null;
    }
  }

  Future<void> _saveGameState() async {
    // Skip save for Hard, Expert, Master modes (arcade style)
    if (widget.difficulty == Difficulty.hard || widget.difficulty == Difficulty.expert || widget.difficulty == Difficulty.master) return;
    
    final state = GameStateData(
      mode: widget.mode,
      difficulty: widget.difficulty,
      levelNumber: widget.levelNumber,
      board: _board,
      notes: _notes,
      mistakes: _mistakes,
      elapsedSeconds: _elapsed,
    );
    await CurrentGameRepository.saveGame(state);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _completionController.dispose();
    _groupCompletionController.dispose();
    _gridAnimationController.dispose();
    _numbersFadeController.dispose();
    _winAnimationController.dispose();
    _lineCompletionController.dispose();
    _glitterController.dispose();
    // Only resume ambient music if we're actually returning to menu
    // (not when going to next level - that's handled by completion dialog)
    // Check if we're being popped (returning to menu) vs replaced (going to next level)
    // Since we can't easily detect this, we'll let the completion dialog handle music resumption
    // Only resume here if there's no completion dialog showing
    super.dispose();
  }
  void _selectCell(int row, int col) {
    if (_winAnimationController.isAnimating) return;
    
    setState(() {
      // If moving to a different cell, clear the draft of the previous cell
      if (_selectedRow != row || _selectedCol != col) {
        if ((widget.difficulty == Difficulty.medium || 
             widget.difficulty == Difficulty.hard ||
             widget.difficulty == Difficulty.expert ||
             widget.difficulty == Difficulty.master) && widget.mode != GameMode.numbers) {
          _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
        }
      }

      _selectedRow = row;
      _selectedCol = col;
      _highlightedNumber = null; // Clear highlight on new selection
    });
    // SoundManager().playClick(); // Removed to prevent confusion with success haptic
  }
  void _pushHistory() {
    // Enable history for all modes and difficulties
    
    final bool isCombinedMode = (widget.difficulty == Difficulty.medium || 
                                  widget.difficulty == Difficulty.hard ||
                                  widget.difficulty == Difficulty.expert ||
                                  widget.difficulty == Difficulty.master) && 
                                 widget.mode != GameMode.numbers;
    
    _history.add(GameStateData(
      mode: widget.mode,
      difficulty: widget.difficulty,
      levelNumber: widget.levelNumber,
      board: List.generate(_gridSize, (i) => List.from(_board[i])),
      notes: List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(_notes[i][j]))),
      mistakes: _mistakes,
      elapsedSeconds: _elapsed,
      shapeNotes: isCombinedMode ? List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(_shapeNotes[i][j]))) : null,
      colorNotes: isCombinedMode ? List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(_colorNotes[i][j]))) : null,
      numberNotes: isCombinedMode ? List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(_numberNotes[i][j]))) : null,
      pencilNoteType: isCombinedMode ? List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => _pencilNoteType[i][j])) : null,
    ));
    if (_history.length > 20) _history.removeAt(0); 
  }

  
  void _handleMistake() {
    setState(() {
      _mistakes++;
      if (_mistakes >= _maxMistakes) _onGameOver();
    });
  }

  void _handleInput(int value, {ElementType? type}) {
    if (_selectedRow == null || _selectedCol == null) return;
    if (!_isEditable[_selectedRow!][_selectedCol!]) return;

    // Combined Mode Logic (Easy with shapes/colors, Medium, Hard, Expert, Master)
    final bool isEasyCombined = widget.difficulty == Difficulty.easy && 
                                widget.mode != GameMode.numbers && 
                                widget.mode != GameMode.custom &&
                                _combinedPuzzle != null;
    final bool isMediumPlus = (widget.difficulty == Difficulty.medium || 
                               widget.difficulty == Difficulty.hard ||
                               widget.difficulty == Difficulty.expert ||
                               widget.difficulty == Difficulty.master) && 
                              widget.mode != GameMode.numbers;
    
    if (isEasyCombined || isMediumPlus) {
       if (type == null) return;
       
       final bool isEasy = widget.difficulty == Difficulty.easy;
       final bool isMedium = widget.difficulty == Difficulty.medium;
       
       // Block number input for Easy and Medium
       if ((isEasy || isMedium) && type == ElementType.number) {
         return; // Block number input for Easy and Medium
       }
       
       // Pencil Mode
       if (_pencilMode) {
         _pushHistory();
         setState(() {
           // Get the appropriate notes set based on type
           final Set<int> notes;
           switch(type) {
             case ElementType.shape: notes = _shapeNotes[_selectedRow!][_selectedCol!]; break;
             case ElementType.color: notes = _colorNotes[_selectedRow!][_selectedCol!]; break;
             case ElementType.number: notes = _numberNotes[_selectedRow!][_selectedCol!]; break;
           }
           
           // Toggle the value (add or remove)
           if (notes.contains(value)) {
             notes.remove(value);
           } else {
             notes.add(value);
           }
         });
         return;
       }
       
       // Normal selection mode
       _pushHistory();
       setState(() {
         _draftCell ??= CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
         
         // Update draft based on type
         switch(type) {
           case ElementType.shape: _draftCell = _draftCell!.copyWith(shapeId: value); break;
           case ElementType.color: _draftCell = _draftCell!.copyWith(colorId: value); break;
           case ElementType.number: _draftCell = _draftCell!.copyWith(numberId: value); break;
         }
         
         // Clear pencil notes when making selection
         _shapeNotes[_selectedRow!][_selectedCol!].clear();
         _colorNotes[_selectedRow!][_selectedCol!].clear();
         _numberNotes[_selectedRow!][_selectedCol!].clear();
         
        // Validation logic differs by difficulty
        if (isEasy || isMedium) {
          // Easy and Medium: Only check shapes and colors (no numbers)
          if (_draftCell!.shapeId != null && _draftCell!.colorId != null) {
             final sol = _combinedPuzzle!.solution[_selectedRow!][_selectedCol!];
             if (_draftCell!.shapeId == sol.shapeId && _draftCell!.colorId == sol.colorId) {
                // Correct
                _combinedPuzzle!.initialBoard[_selectedRow!][_selectedCol!] = sol;
                _board[_selectedRow!][_selectedCol!] = 1; // Mark solved
                _animatedCells.add(_selectedRow! * _gridSize + _selectedCol!);
                
                // Mark all elements as user-filled
                _markElementFilled(_selectedRow!, _selectedCol!, ElementType.shape);
                _markElementFilled(_selectedRow!, _selectedCol!, ElementType.color);
                
                _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
                
                HapticFeedback.lightImpact();
                SoundManager().playSuccessSound();
                
                _checkGroupCompletion(_selectedRow!, _selectedCol!);
                 
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) setState(() => _animatedCells.remove(_selectedRow! * _gridSize + _selectedCol!));
                });

                if (_isBoardSolved()) _onLevelComplete();
             } else {
                _handleMistake();
                _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
                _errorCells.add(_selectedRow! * _gridSize + _selectedCol!);
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) setState(() => _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!));
                });
             }
          }
        } else {
          // Hard, Expert, Master: Check all three elements
          if (_draftCell!.shapeId != null && _draftCell!.colorId != null && _draftCell!.numberId != null) {
             final sol = _combinedPuzzle!.solution[_selectedRow!][_selectedCol!];
             if (_draftCell!.shapeId == sol.shapeId && _draftCell!.colorId == sol.colorId && _draftCell!.numberId == sol.numberId) {
                // Correct
                _combinedPuzzle!.initialBoard[_selectedRow!][_selectedCol!] = sol;
                _board[_selectedRow!][_selectedCol!] = 1; // Mark solved
                _animatedCells.add(_selectedRow! * _gridSize + _selectedCol!);
                
                // Mark all elements as user-filled
                _markElementFilled(_selectedRow!, _selectedCol!, ElementType.shape);
                _markElementFilled(_selectedRow!, _selectedCol!, ElementType.color);
                _markElementFilled(_selectedRow!, _selectedCol!, ElementType.number);
                
                _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
                
                HapticFeedback.lightImpact();
                SoundManager().playSuccessSound();
                
                _checkGroupCompletion(_selectedRow!, _selectedCol!);
                 
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) setState(() => _animatedCells.remove(_selectedRow! * _gridSize + _selectedCol!));
                });

                if (_isBoardSolved()) _onLevelComplete();
             } else {
                _handleMistake();
                _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
                _errorCells.add(_selectedRow! * _gridSize + _selectedCol!);
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) setState(() => _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!));
                });
             }
          }
        }
      });
       return;
    }

    // Pencil Mode
    if (_pencilMode) {
      // Standard Sudoku (Numbers only)
      if (widget.mode == GameMode.numbers) {
        _pushHistory();
        setState(() {
          if (_notes[_selectedRow!][_selectedCol!].contains(value)) {
            _notes[_selectedRow!][_selectedCol!].remove(value);
          } else {
            _notes[_selectedRow!][_selectedCol!].add(value);
          }
        });
        return;
      }
      
      // Easy Crazy Sudoku (shapes/colors only, no numbers)
      if (widget.difficulty == Difficulty.easy && 
          widget.mode != GameMode.numbers && 
          widget.mode != GameMode.custom) {
        _pushHistory();
        setState(() {
          if (type == ElementType.shape) {
            if (_shapeNotes[_selectedRow!][_selectedCol!].contains(value)) {
              _shapeNotes[_selectedRow!][_selectedCol!].remove(value);
            } else {
              _shapeNotes[_selectedRow!][_selectedCol!].add(value);
            }
          } else if (type == ElementType.color) {
            if (_colorNotes[_selectedRow!][_selectedCol!].contains(value)) {
              _colorNotes[_selectedRow!][_selectedCol!].remove(value);
            } else {
              _colorNotes[_selectedRow!][_selectedCol!].add(value);
            }
          }
          // Ignore number input for Easy Crazy Sudoku
        });
        return;
      }
      
      // Combined Mode (Shapes, Colors, Numbers)
      // Allow mixed notes - no blocking based on type
      _pushHistory();
      setState(() {
        if (type == ElementType.shape) {
           if (_shapeNotes[_selectedRow!][_selectedCol!].contains(value)) {
             _shapeNotes[_selectedRow!][_selectedCol!].remove(value);
           } else {
             _shapeNotes[_selectedRow!][_selectedCol!].add(value);
           }
        } else if (type == ElementType.color) {
           if (_colorNotes[_selectedRow!][_selectedCol!].contains(value)) {
             _colorNotes[_selectedRow!][_selectedCol!].remove(value);
           } else {
             _colorNotes[_selectedRow!][_selectedCol!].add(value);
           }
        } else {
           // Number notes
           if (_numberNotes[_selectedRow!][_selectedCol!].contains(value)) {
             _numberNotes[_selectedRow!][_selectedCol!].remove(value);
           } else {
             _numberNotes[_selectedRow!][_selectedCol!].add(value);
           }
        }
      });
      return;
    }

    // Standard Mode
    _pushHistory();
    int correctValue = _getCorrectValue(_selectedRow!, _selectedCol!);
    bool isCorrect = (value == correctValue);

    setState(() {
      if (isCorrect) {
        _board[_selectedRow!][_selectedCol!] = value;
        _notes[_selectedRow!][_selectedCol!].clear(); 
        _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!);
        _activeHint = null;
        _highlightedNumber = value;
        
        _checkGroupCompletion(_selectedRow!, _selectedCol!);

        if (_isBoardSolved()) {
          _onLevelComplete();
        }
      } else {
        _board[_selectedRow!][_selectedCol!] = value;
        _handleMistake();
        _errorCells.add(_selectedRow! * _gridSize + _selectedCol!);
      }
    });
    
    // Haptic and sound feedback (outside setState for immediate response)
    if (isCorrect) {
      HapticFeedback.lightImpact();
      SoundManager().playSuccessSound();
    }
    
    _saveGameState();
  }

  int _getCorrectValue(int r, int c) {
    if (_combinedPuzzle != null) {
        final s = _combinedPuzzle!.solution;
        return s[r][c].shapeId ?? 0;
    }
    return _sudokuPuzzle!.solution[r][c];
  }

  // Try to find a hint for a specific cell, returns null if no hint available
  _HintResult? _tryHintForCell(int r, int c) {
    // Check if cell is empty
    if (_board[r][c] != 0) {
      return null;
    }
    
    final correctVal = _getCorrectValue(r, c);
    final bRow = (r ~/ _blockRows) * _blockRows;
    final bCol = (c ~/ _blockCols) * _blockCols;
    
    // Priority 1: Try Last Digit in Block (only unfilled cell in block)
    int zerosBlock = 0;
    for(int i=0; i<_blockRows; i++) {
      for(int j=0; j<_blockCols; j++) {
        if(_board[bRow + i][bCol + j] == 0) {
          zerosBlock++;
        }
      }
    }
    final hintTypeName = _getHintTypeName();
    
    if (zerosBlock == 1) {
       return _HintResult(
         hintType: hintTypeName,
         steps: _generateLastMissingBlockSteps(r, c, correctVal),
         targetRow: r,
         targetCol: c,
         correctVal: correctVal,
       );
    }
    
    // Priority 2: Try Last Element in Row (only unfilled cell in row)
    int zerosRow = 0;
    Set<int> presentInRow = {};
    for(int k=0; k<_gridSize; k++) {
      if(_board[r][k] == 0) {
        zerosRow++;
      } else {
        presentInRow.add(_board[r][k]);
      }
    }
    if (zerosRow == 1) {
       return _HintResult(
         hintType: hintTypeName,
         steps: _generateLastMissingRowSteps(r, c, correctVal),
         targetRow: r,
         targetCol: c,
         correctVal: correctVal,
       );
    }
    
    // Priority 3: Try Last Element in Column (only unfilled cell in column)
    int zerosCol = 0;
    Set<int> presentInCol = {};
    for(int k=0; k<_gridSize; k++) {
      if(_board[k][c] == 0) {
        zerosCol++;
      } else {
        presentInCol.add(_board[k][c]);
      }
    }
    if (zerosCol == 1) {
       return _HintResult(
         hintType: hintTypeName,
         steps: _generateLastMissingColSteps(r, c, correctVal),
         targetRow: r,
         targetCol: c,
         correctVal: correctVal,
       );
    }
    
    // Priority 4: Try Naked Single (only one possible number - missing when combining block + row + column)
    Set<int> possibleValues = {};
    for(int val = 1; val <= _gridSize; val++) {
      bool canPlace = true;
      // Check row
      for(int k=0; k<_gridSize; k++) {
        if(_board[r][k] == val) canPlace = false;
      }
      // Check column
      for(int k=0; k<_gridSize; k++) {
        if(_board[k][c] == val) canPlace = false;
      }
      // Check block
      for(int i=0; i<_blockRows; i++) {
        for(int j=0; j<_blockCols; j++) {
          if(_board[bRow + i][bCol + j] == val) canPlace = false;
        }
      }
      if (canPlace) possibleValues.add(val);
    }
    
    if (possibleValues.length == 1 && possibleValues.contains(correctVal)) {
       return _HintResult(
         hintType: hintTypeName,
         steps: _generateNakedSingleSteps(r, c, correctVal),
         targetRow: r,
         targetCol: c,
         correctVal: correctVal,
       );
    }
    
    // Priority 5: Try Cross-Hatching technique (as fallback)
    bool hiddenSingle = true;
    Set<int> highlights = {};
    Set<int> rowHighlights = {};
    Set<int> colHighlights = {};
    List<int> blockingRows = [];
    List<int> blockingCols = [];
    
    // Calculate box boundaries
    final int boxRowStart = bRow;
    final int boxRowEnd = bRow + _blockRows - 1;
    final int boxColStart = bCol;
    final int boxColEnd = bCol + _blockCols - 1;
    
    // Find rows and columns that contain the target number AND intersect with the box
    for(int row = 0; row < _gridSize; row++) {
      for(int col = 0; col < _gridSize; col++) {
        if (_board[row][col] == correctVal) {
          // Only add row highlight if the row intersects with the box
          if (!blockingRows.contains(row) && row >= boxRowStart && row <= boxRowEnd) {
            blockingRows.add(row);
            rowHighlights.addAll(_getRowIndices(row));
          }
          // Only add column highlight if the column intersects with the box
          if (!blockingCols.contains(col) && col >= boxColStart && col <= boxColEnd) {
            blockingCols.add(col);
            colHighlights.addAll(_getColIndices(col));
          }
        }
      }
    }
    
    // Check all cells in the block
    for(int i=0; i<_blockRows; i++) {
      for(int j=0; j<_blockCols; j++) {
         int nr = bRow + i;
         int nc = bCol + j;
         if (nr == r && nc == c) continue;
         if (_board[nr][nc] != 0) continue;
         
         bool rowBlocked = false;
         for(int k=0; k<_gridSize; k++) {
           if (_board[nr][k] == correctVal) rowBlocked = true;
         }
         bool colBlocked = false;
         for(int k=0; k<_gridSize; k++) {
           if (_board[k][nc] == correctVal) colBlocked = true;
         }
         
         if (!rowBlocked && !colBlocked) {
            hiddenSingle = false;
         } else {
            if (rowBlocked) highlights.addAll(_getRowIndices(nr));
            if (colBlocked) highlights.addAll(_getColIndices(nc));
         }
      }
    }
    
    if (hiddenSingle) {
       // Use multi-step cross-hatching
       final Set<int> blockHighlights = _getBoxIndices(r, c);
       return _HintResult(
         hintType: "Cross-Hatching (Box)",
         steps: _generateCrossHatchingSteps(r, c, correctVal, rowHighlights, colHighlights, blockHighlights, bRow, bCol),
         targetRow: r,
         targetCol: c,
         correctVal: correctVal,
       );
    }
    
    // No hint available for this cell
    return null;
  }

  void _clearNotesFor(int val, int r, int c) {
    for(int i=0; i<_gridSize; i++) {
      _notes[r][i].remove(val);
      _notes[i][c].remove(val);
    }
    final bRow = (r ~/ _blockRows) * _blockRows;
    final bCol = (c ~/ _blockCols) * _blockCols;
    for(int i=0; i<_blockRows; i++) {
      for(int j=0; j<_blockCols; j++) {
        _notes[bRow+i][bCol+j].remove(val);
      }
    }
  }

  void _checkGroupCompletion(int r, int c) {
    // Check Row
    bool rowFull = true;
    for(int i=0; i<_gridSize; i++) {
      if(_board[r][i] == 0) rowFull = false;
    }
    
    // Check Column
    bool colFull = true;
    for(int i=0; i<_gridSize; i++) {
      if(_board[i][c] == 0) colFull = false;
    }

    // Check Block
    bool blockFull = true;
    int bRowStart = (r ~/ _blockRows) * _blockRows;
    int bColStart = (c ~/ _blockCols) * _blockCols;
    for(int i=0; i<_blockRows; i++) {
      for(int j=0; j<_blockCols; j++) {
        if(_board[bRowStart + i][bColStart + j] == 0) blockFull = false;
      }
    }

    if (rowFull || colFull || blockFull) {
      setState(() {
        if (rowFull) _completedRow = r;
        if (colFull) _completedCol = c;
        if (blockFull) {
          _triggerBlockRow = bRowStart;
          _triggerBlockCol = bColStart;
        }
        _triggerRow = r;
        _triggerCol = c;
        _lineCompletionController.forward(from: 0);
      });
      // Sound placeholder
      SoundManager().playCompletionSound();
      HapticFeedback.mediumImpact();
    }
    
    // Also trigger group completion pulse if needed
    if (rowFull || colFull || blockFull) {
      _groupCompletionController.forward(from: 0);
    }
  }

  bool _isBoardSolved() {
    // Combined mode validation (Medium, Hard, Expert, Master)
    if ((widget.difficulty == Difficulty.medium || 
         widget.difficulty == Difficulty.hard ||
         widget.difficulty == Difficulty.expert ||
         widget.difficulty == Difficulty.master) && 
        widget.mode != GameMode.numbers &&
        _combinedPuzzle != null) {
      
      // Since we mark _board[r][c] = 1 when a cell is correctly solved in combined mode,
      // we can simply check if the board has any zeros.
      for(int r=0; r<_gridSize; r++) {
        for(int c=0; c<_gridSize; c++) {
          if (_board[r][c] == 0) return false;
        }
      }
      return true;
    }
    
    // Standard mode validation
    for(int r=0; r<_gridSize; r++) {
      for(int c=0; c<_gridSize; c++) {
        if (_board[r][c] == 0) return false; 
        if (_board[r][c] != 0 && 
            widget.difficulty != Difficulty.medium && 
            widget.difficulty != Difficulty.hard &&
            widget.difficulty != Difficulty.expert &&
            widget.difficulty != Difficulty.master && 
            _board[r][c] != _getCorrectValue(r, c)) {
          return false;
        }
      }
    }
    return true;
  }

  void _onLevelComplete() {
    _stopwatch.stop();
    SoundManager().stopAmbientMusic(); // Stop music when level completes
    _playWinAnimation();
    CurrentGameRepository.clearGame(widget.mode, widget.difficulty);
    ProgressRepository.completeLevel(widget.levelNumber, widget.mode, widget.difficulty, 3, _elapsed, _mistakes);
    
    // Show completion dialog after win animation
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _showCompletionDialog();
    });
  }

  void _showCompletionDialog() {
    final stars = _calculateStars();
    final timeStr = _formatTime(_elapsed);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: LevelCompletionDialog(
          levelNumber: widget.levelNumber,
          starsEarned: stars,
          timeTaken: timeStr,
          onNextLevel: () {
            Navigator.pop(context);
            
            if (widget.levelNumber >= 50) {
              // Game Finished!
              Navigator.pop(context); // Go back to menu
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Congratulations! You completed all levels for this difficulty!')),
              );
              SoundManager().playAmbientMusic();
            } else {
              // Navigate to next level without ambient music
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
                levelNumber: widget.levelNumber + 1, 
                mode: widget.mode,
                difficulty: widget.difficulty,
                sudokuSize: widget.sudokuSize,
              )));
            }
          },
          onClose: () {
            Navigator.pop(context);
            // Return to menu and resume ambient music
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  int _calculateStars() {
    // Calculate stars based on time and mistakes
    // 3 stars: perfect (no mistakes, fast time)
    // 2 stars: good (few mistakes or reasonable time)
    // 1 star: completed (any completion)
    if (_mistakes == 0) {
      // Perfect - 3 stars
      return 3;
    } else if (_mistakes <= 2) {
      // Good - 2 stars
      return 2;
    } else {
      // Completed - 1 star
      return 1;
    }
  }

  void _playWinAnimation() {
    SoundManager().playWinSound();
    _winAnimationController.forward();
    _completionController.forward();
    // Accelerate star background animation for warp effect
    setState(() {
      _rotationController.duration = const Duration(milliseconds: 500);
      _rotationController.reset();
      _rotationController.repeat();
    });
  }

  void _onGameOver() {
    _stopwatch.stop();
    CurrentGameRepository.clearGame(widget.mode, widget.difficulty);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('GAME OVER', style: TextStyle(color: kRetroError)),
        content: const Text('Too many mistakes!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); 
            },
            child: const Text('MENU'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
                 levelNumber: widget.levelNumber, 
                 mode: widget.mode,
                 difficulty: widget.difficulty
              )));
            },
            child: const Text('RESTART'),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      final prev = _history.removeLast();
      _board = prev.board;
      _notes = prev.notes;
      _mistakes = prev.mistakes;
      _errorCells.clear();
      
      // Restore combined mode notes if present
      if (prev.shapeNotes != null) {
        _shapeNotes = List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(prev.shapeNotes![i][j])));
      }
      if (prev.colorNotes != null) {
        _colorNotes = List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(prev.colorNotes![i][j])));
      }
      if (prev.numberNotes != null) {
        _numberNotes = List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(prev.numberNotes![i][j])));
      }
      if (prev.pencilNoteType != null) {
        _pencilNoteType = List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => prev.pencilNoteType![i][j]));
      }
    });
  }

  void _erase() {
    if (_selectedRow == null || _selectedCol == null) return;
    if (!_isEditable[_selectedRow!][_selectedCol!]) return;
    _pushHistory();
    setState(() {
      _board[_selectedRow!][_selectedCol!] = 0;
      if ((widget.difficulty == Difficulty.medium || 
           widget.difficulty == Difficulty.hard ||
           widget.difficulty == Difficulty.expert ||
           widget.difficulty == Difficulty.master) && widget.mode != GameMode.numbers) {
         _draftCell = null;
         _combinedPuzzle!.initialBoard[_selectedRow!][_selectedCol!] = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
         // Clear all notes
         _shapeNotes[_selectedRow!][_selectedCol!].clear();
         _colorNotes[_selectedRow!][_selectedCol!].clear();
         _numberNotes[_selectedRow!][_selectedCol!].clear();
         // Clear type lock
         _pencilNoteType[_selectedRow!][_selectedCol!] = null;
      } else {
         _notes[_selectedRow!][_selectedCol!].clear();
      }
      _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!);
    });
  }

  void _hint() {
    if (_selectedRow == null || _selectedCol == null) {
      if (mounted) {
        showCosmicSnackbar(context, "Please select a cell first to get a hint.");
      }
      return;
    }
    
    final r = _selectedRow!;
    final c = _selectedCol!;
    
    // Check hint availability
    if (_hintsRemaining <= 0) {
      if (mounted) {
        showCosmicSnackbar(context, "No hints remaining for this level.");
      }
      return;
    }
    
    // Pause timer while hint is active
    _stopwatch.stop();
    
    // Check if selected cell is completely filled
    if (_board[r][c] != 0 && !_isCellPartiallyFilled(r, c)) {
      if (mounted) {
        _stopwatch.start();
        showCosmicSnackbar(context, "This cell is already filled. Select an empty cell for a hint.");
      }
      return;
    }
    
    // Determine if this is Crazy Sudoku combined mode
    final bool isCrazySudokuCombined = _isCrazySudokuCombinedMode();
    
    if (isCrazySudokuCombined) {
      // Show element selection dialog
      _showHintElementDialog(r, c);
    } else if (_isEasyCrazySudoku()) {
      // Easy Crazy Sudoku: hint for shape/color (no numbers)
      _showEasyCrazySudokuHint(r, c);
    } else {
      // Standard Sudoku: hint for number
      _showStandardHint(r, c);
    }
  }

  bool _isCrazySudokuCombinedMode() {
    return (widget.difficulty == Difficulty.medium || 
            widget.difficulty == Difficulty.hard ||
            widget.difficulty == Difficulty.expert ||
            widget.difficulty == Difficulty.master) && 
           widget.mode != GameMode.numbers && 
           widget.mode != GameMode.custom;
  }

  bool _isEasyCrazySudoku() {
    return widget.difficulty == Difficulty.easy && 
           widget.mode != GameMode.numbers && 
           widget.mode != GameMode.custom;
  }

  bool _isCellPartiallyFilled(int r, int c) {
    if (_combinedPuzzle == null) return false;
    
    // Check if user has filled all required elements
    final key = '${r}_$c';
    final filled = _userFilledElements[key] ?? <ElementType>{};
    
    final bool isMedium = widget.difficulty == Difficulty.medium;
    final bool isEasy = widget.difficulty == Difficulty.easy;
    
    if (isEasy || isMedium) {
      // Need shape and color
      return !filled.contains(ElementType.shape) || !filled.contains(ElementType.color);
    } else {
      // Need shape, color, and number
      return !filled.contains(ElementType.shape) || 
             !filled.contains(ElementType.color) || 
             !filled.contains(ElementType.number);
    }
  }
  
  // Check if a specific element has been user-filled for a cell
  bool _hasUserFilledElement(int r, int c, ElementType type) {
    final key = '${r}_$c';
    final filled = _userFilledElements[key] ?? <ElementType>{};
    return filled.contains(type);
  }
  
  // Mark an element as user-filled for a cell
  void _markElementFilled(int r, int c, ElementType type) {
    final key = '${r}_$c';
    _userFilledElements[key] ??= <ElementType>{};
    _userFilledElements[key]!.add(type);
  }
  
  // Get all element types that are part of the current game mode
  List<Map<String, dynamic>> _getElementTypesForMode() {
    final bool isMedium = widget.difficulty == Difficulty.medium;
    final bool isEasy = widget.difficulty == Difficulty.easy;
    
    List<Map<String, dynamic>> elements = [];
    
    // Shape and Color are always available for combination modes
    elements.add({
      'type': ElementType.shape,
      'label': 'Shape',
      'icon': Icons.category,
    });
    elements.add({
      'type': ElementType.color,
      'label': 'Color',
      'icon': Icons.palette,
    });
    
    // Number is available for Hard, Expert, Master
    if (!isEasy && !isMedium) {
      elements.add({
        'type': ElementType.number,
        'label': 'Number',
        'icon': Icons.pin,
      });
    }
    
    return elements;
  }

  void _showHintElementDialog(int r, int c) {
    // Get all element types for this game mode
    final allElements = _getElementTypesForMode();
    
    // Filter to elements that haven't been user-filled yet
    List<Map<String, dynamic>> availableHints = [];
    for (final element in allElements) {
      final type = element['type'] as ElementType;
      if (!_hasUserFilledElement(r, c, type)) {
        availableHints.add(element);
      }
    }
    
    if (availableHints.isEmpty) {
      _stopwatch.start();
      showCosmicSnackbar(context, "This cell is already complete.");
      return;
    }
    
    // Show dialog using GlassModal for cosmic theme consistency
    GlassModal.show(
      context: context,
      title: 'CHOOSE HINT TYPE',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hints remaining: $_hintsRemaining',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 16,
              color: kCosmicText.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          ...availableHints.map((hint) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHintTypeOption(
              icon: hint['icon'] as IconData,
              label: 'Hint for ${hint['label']}',
              onTap: () {
                Navigator.pop(context);
                _executeElementHint(r, c, hint['type'] as ElementType);
              },
            ),
          )),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopwatch.start();
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 16,
                color: kCosmicText.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _executeElementHint(int r, int c, ElementType elementType) {
    final sol = _combinedPuzzle!.solution[r][c];
    
    // Get the correct value for this element
    int correctVal;
    String elementName;
    switch (elementType) {
      case ElementType.color:
        correctVal = sol.colorId!;
        elementName = 'color';
        break;
      case ElementType.shape:
        correctVal = sol.shapeId!;
        elementName = 'shape';
        break;
      case ElementType.number:
        correctVal = sol.numberId!;
        elementName = 'number';
        break;
    }
    
    // Decrement hint counter
    setState(() {
      _hintsRemaining--;
    });
    
    // Generate hint steps for this element
    final steps = _generateElementHintSteps(r, c, correctVal, elementType, elementName);
    
    // Activate hint with element-specific apply action
    _activateElementHint(
      'Hint: $elementName',
      steps,
      r, c,
      correctVal,
      elementType,
    );
  }

  List<HintStep> _generateElementHintSteps(int r, int c, int val, ElementType type, String name) {
    final rowIndices = _getRowIndices(r);
    final colIndices = _getColIndices(c);
    final boxIndices = _getBoxIndices(r, c);
    final allRelated = Set<int>.from(rowIndices)..addAll(colIndices)..addAll(boxIndices);
    
    return [
      HintStep(
        description: "Observe this cell",
        highlights: {},
        showTargetCell: true,
        showNumber: false,
      ),
      HintStep(
        description: "Each $name can only appear once in each row, column, and box.",
        highlights: allRelated,
        showTargetCell: true,
        showNumber: false,
      ),
      HintStep(
        description: "This cell should have this $name:",
        highlights: boxIndices,
        showTargetCell: true,
        showNumber: true,
        elementValue: val,
        gameMode: widget.mode,
        elementType: type,
      ),
    ];
  }

  void _showEasyCrazySudokuHint(int r, int c) {
    // Easy Crazy Sudoku uses shapes/colors only
    // Check if the cell has a combined puzzle
    if (_combinedPuzzle != null) {
      // Get all element types for Easy mode (shape + color)
      List<Map<String, dynamic>> allElements = [
        {'type': ElementType.shape, 'label': 'Shape', 'icon': Icons.category},
        {'type': ElementType.color, 'label': 'Color', 'icon': Icons.palette},
      ];
      
      // Filter to elements that haven't been user-filled yet
      List<Map<String, dynamic>> availableHints = [];
      for (final element in allElements) {
        final type = element['type'] as ElementType;
        if (!_hasUserFilledElement(r, c, type)) {
          availableHints.add(element);
        }
      }
      
      if (availableHints.isEmpty) {
        _stopwatch.start();
        showCosmicSnackbar(context, "This cell is already complete.");
        return;
      }
      
      if (availableHints.length == 1) {
        // Auto-select the only remaining element
        _executeElementHint(r, c, availableHints.first['type'] as ElementType);
      } else {
        // Show selection dialog for multiple element types
        _showHintElementDialogForEasy(r, c, availableHints);
      }
    } else {
      // Fallback: use standard hint logic
      _HintResult? result = _tryHintForCell(r, c);
      
      if (result != null) {
        setState(() {
          _hintsRemaining--;
        });
        _activateMultiStepHint(result.hintType, result.steps, result.targetRow, result.targetCol, result.correctVal);
      } else {
        _stopwatch.start();
        showCosmicSnackbar(context, "No hint available for this cell.");
      }
    }
  }

  void _showHintElementDialogForEasy(int r, int c, List<Map<String, dynamic>> availableHints) {
    // Show dialog using GlassModal for consistency
    GlassModal.show(
      context: context,
      title: 'CHOOSE HINT TYPE',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hints remaining: $_hintsRemaining',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 16,
              color: kCosmicText.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          ...availableHints.map((hint) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHintTypeOption(
              icon: hint['icon'] as IconData,
              label: 'Hint for ${hint['label']}',
              onTap: () {
                Navigator.pop(context);
                _executeElementHint(r, c, hint['type'] as ElementType);
              },
            ),
          )),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopwatch.start();
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 16,
                color: kCosmicText.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintTypeOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        SoundManager().playClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kCosmicPrimary.withOpacity(0.15),
              kCosmicSecondary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCosmicPrimary.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: kCosmicPrimary, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kCosmicText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStandardHint(int r, int c) {
    _HintResult? result = _tryHintForCell(r, c);
    
    if (result != null) {
      setState(() {
        _hintsRemaining--;
      });
      _activateMultiStepHint(result.hintType, result.steps, result.targetRow, result.targetCol, result.correctVal);
    } else {
      // Try other cells in block (existing logic)
      final bRow = (r ~/ _blockRows) * _blockRows;
      final bCol = (c ~/ _blockCols) * _blockCols;
      
      for(int i=0; i<_blockRows; i++) {
        for(int j=0; j<_blockCols; j++) {
          int nr = bRow + i;
          int nc = bCol + j;
          if (nr == r && nc == c) continue;
          if (_board[nr][nc] != 0) continue;
          
          result = _tryHintForCell(nr, nc);
          if (result != null) {
            setState(() {
              _hintsRemaining--;
            });
            _activateMultiStepHint(result.hintType, result.steps, result.targetRow, result.targetCol, result.correctVal);
            return;
          }
        }
      }
      
      _stopwatch.start();
      showCosmicSnackbar(context, "No hint available. Try a different cell.");
    }
  }

  void _activateElementHint(String title, List<HintStep> steps, int r, int c, int val, ElementType elementType) {
    setState(() {
      _selectCell(r, c);
      _activeHintElementType = elementType;
      _activeHint = HintInfo(
        title: title,
        steps: steps,
        currentStepIndex: 0,
        targetRow: r,
        targetCol: c,
        value: val,
        gameMode: widget.mode,
        shapeMap: _shapeMap,
        elementType: elementType,
      );
    });
  }

  void _applyElementHint(int r, int c, int val, ElementType elementType) {
    // Ensure the hint cell is selected
    if (_selectedRow != r || _selectedCol != c) {
      _selectCell(r, c);
    }
    
    // Use the exact same input flow as clicking from the toolbar
    // This ensures draft system is used, toolbar reflects selection, 
    // and moving to another cell clears the draft (normal behavior)
    _handleInput(val, type: elementType);
  }

  void _applyEasyCrazySudokuHint(int r, int c, int val) {
    // For Easy Crazy Sudoku, the hint value corresponds to the shape/color combo
    // Apply the correct solution directly
    if (_combinedPuzzle != null) {
      final sol = _combinedPuzzle!.solution[r][c];
      setState(() {
        _combinedPuzzle!.initialBoard[r][c] = sol;
        _board[r][c] = 1;
        _checkGroupCompletion(r, c);
        if (_isBoardSolved()) {
          _onLevelComplete();
        }
      });
    } else if (_sudokuPuzzle != null) {
      // Fallback for non-combined puzzles
      _handleInput(val);
    }
    
    HapticFeedback.lightImpact();
    SoundManager().playSuccessSound();
  }

  // Helper methods for mode-appropriate terminology
  String _getElementNameSingular() {
    switch (widget.mode) {
      case GameMode.planets:
        return 'planet';
      case GameMode.shapes:
        return 'shape';
      case GameMode.colors:
        return 'color';
      case GameMode.cosmic:
        return 'element';
      default:
        return 'number';
    }
  }

  String _getElementNamePlural() {
    switch (widget.mode) {
      case GameMode.planets:
        return 'planets';
      case GameMode.shapes:
        return 'shapes';
      case GameMode.colors:
        return 'colors';
      case GameMode.cosmic:
        return 'elements';
      default:
        return 'numbers';
    }
  }

  String _getHintTypeName() {
    switch (widget.mode) {
      case GameMode.planets:
        return 'Last Planet';
      case GameMode.shapes:
        return 'Last Shape';
      case GameMode.colors:
        return 'Last Color';
      case GameMode.cosmic:
        return 'Last Element';
      default:
        return 'Last Digit';
    }
  }

  String _getRuleDescription() {
    final elementName = _getElementNamePlural();
    return 'Each $elementName can only appear once in the same row, column, or box. As shown, the $elementName that appear in the highlighted area cannot appear in this cell.';
  }

  Set<int> _getRowIndices(int r) {
    return List.generate(_gridSize, (c) => r * _gridSize + c).toSet();
  }
  Set<int> _getColIndices(int c) {
    return List.generate(_gridSize, (r) => r * _gridSize + c).toSet();
  }
  Set<int> _getBoxIndices(int row, int col) {
    final int boxRow = (row ~/ _blockRows) * _blockRows;
    final int boxCol = (col ~/ _blockCols) * _blockCols;
    final Set<int> boxIndices = {};
    for (int i = 0; i < _blockRows; i++) {
      for (int j = 0; j < _blockCols; j++) {
        boxIndices.add((boxRow + i) * _gridSize + (boxCol + j));
      }
    }
    return boxIndices;
  }
  Set<int> _getAllCellsWithValue(int value) {
    final Set<int> cells = {};
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        if (_board[row][col] == value) {
          cells.add(row * _gridSize + col);
        }
      }
    }
    return cells;
  }
  
  // Step generators for multi-step hints
  List<HintStep> _generateLastMissingBlockSteps(int r, int c, int val) {
    final rowIndices = _getRowIndices(r);
    final colIndices = _getColIndices(c);
    final boxIndices = _getBoxIndices(r, c);
    final allRelated = rowIndices..addAll(colIndices)..addAll(boxIndices);
    final elementPlural = _getElementNamePlural();
    final ruleDesc = _getRuleDescription();
    
    return [
      // Step 1: Observe this cell
      HintStep(
        description: "Observe this cell",
        highlights: {},
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 2: Explain rule with highlights
      HintStep(
        description: ruleDesc,
        highlights: allRelated,
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 3: Show solution
      HintStep(
        description: "The block of this cell contains all $elementPlural except this one. So this cell should be filled with:",
        highlights: boxIndices,
        showTargetCell: true,
        showNumber: true,
        elementValue: val,
        gameMode: widget.mode,
      ),
    ];
  }
  
  List<HintStep> _generateLastMissingRowSteps(int r, int c, int val) {
    final rowIndices = _getRowIndices(r);
    final colIndices = _getColIndices(c);
    final boxIndices = _getBoxIndices(r, c);
    final allRelated = rowIndices..addAll(colIndices)..addAll(boxIndices);
    final elementPlural = _getElementNamePlural();
    final ruleDesc = _getRuleDescription();
    
    return [
      // Step 1: Observe this cell
      HintStep(
        description: "Observe this cell",
        highlights: {},
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 2: Explain rule with highlights
      HintStep(
        description: ruleDesc,
        highlights: allRelated,
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 3: Show solution
      HintStep(
        description: "The row, column, and box of this cell contain all $elementPlural except this one. So this cell should be filled with:",
        highlights: rowIndices,
        showTargetCell: true,
        showNumber: true,
        elementValue: val,
        gameMode: widget.mode,
      ),
    ];
  }
  
  List<HintStep> _generateLastMissingColSteps(int r, int c, int val) {
    final rowIndices = _getRowIndices(r);
    final colIndices = _getColIndices(c);
    final boxIndices = _getBoxIndices(r, c);
    final allRelated = rowIndices..addAll(colIndices)..addAll(boxIndices);
    final elementPlural = _getElementNamePlural();
    final ruleDesc = _getRuleDescription();
    
    return [
      // Step 1: Observe this cell
      HintStep(
        description: "Observe this cell",
        highlights: {},
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 2: Explain rule with highlights
      HintStep(
        description: ruleDesc,
        highlights: allRelated,
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 3: Show solution
      HintStep(
        description: "The row, column, and box of this cell contain all $elementPlural except this one. So this cell should be filled with:",
        highlights: colIndices,
        showTargetCell: true,
        showNumber: true,
        elementValue: val,
        gameMode: widget.mode,
      ),
    ];
  }
  
  List<HintStep> _generateNakedSingleSteps(int r, int c, int val) {
    final rowIndices = _getRowIndices(r);
    final colIndices = _getColIndices(c);
    final boxIndices = _getBoxIndices(r, c);
    final allRelated = rowIndices..addAll(colIndices)..addAll(boxIndices);
    final elementPlural = _getElementNamePlural();
    final ruleDesc = _getRuleDescription();
    
    return [
      // Step 1: Observe this cell
      HintStep(
        description: "Observe this cell",
        highlights: {},
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 2: Explain rule with highlights
      HintStep(
        description: ruleDesc,
        highlights: allRelated,
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 3: Show solution
      HintStep(
        description: "This cell can only contain this ${_getElementNameSingular()} because all other $elementPlural are already present in this cell's row, column, or box. So this cell should be filled with:",
        highlights: allRelated,
        showTargetCell: true,
        showNumber: true,
        elementValue: val,
        gameMode: widget.mode,
      ),
    ];
  }
  
  List<HintStep> _generateCrossHatchingSteps(int r, int c, int val, Set<int> rowHighlights, Set<int> colHighlights, Set<int> blockHighlights, int bRow, int bCol) {
    final boxIndices = _getBoxIndices(r, c);
    
    // Calculate box boundaries
    final int boxRowStart = bRow;
    final int boxRowEnd = bRow + _blockRows - 1;
    final int boxColStart = bCol;
    final int boxColEnd = bCol + _blockCols - 1;
    
    // Filter number instances to only include those in rows/columns connected to the block
    final Set<int> numberInstances = {};
    final allNumberInstances = _getAllCellsWithValue(val);
    for (final idx in allNumberInstances) {
      final row = idx ~/ _gridSize;
      final col = idx % _gridSize;
      // Only include if the number is in a row or column that intersects with the block
      if ((row >= boxRowStart && row <= boxRowEnd) || (col >= boxColStart && col <= boxColEnd)) {
        numberInstances.add(idx);
      }
    }
    
    // Find which cells in the box are eliminated
    final Set<int> eliminatedCells = {};
    for (final idx in boxIndices) {
      final row = idx ~/ _gridSize;
      final col = idx % _gridSize;
      if (row == r && col == c) continue; // Skip target cell
      if (_board[row][col] != 0) continue; // Skip filled cells
      
      // Check if this cell is blocked by row or column
      bool rowBlocked = false;
      for (int k = 0; k < _gridSize; k++) {
        if (_board[row][k] == val) {
          rowBlocked = true;
          break;
        }
      }
      bool colBlocked = false;
      for (int k = 0; k < _gridSize; k++) {
        if (_board[k][col] == val) {
          colBlocked = true;
          break;
        }
      }
      
      if (rowBlocked || colBlocked) {
        eliminatedCells.add(idx);
      }
    }
    
    // Combine row/column highlights with box highlights for step 2
    final Set<int> combinedHighlights = Set<int>.from(rowHighlights)..addAll(colHighlights)..addAll(boxIndices);
    
    final elementSingular = _getElementNameSingular();
    
    return [
      // Step 1: Observe element
      HintStep(
        description: "Observe this $elementSingular:",
        highlights: {},
        numberInstances: numberInstances,
        showTargetCell: false,
        showNumber: false,
        elementValue: val,
        gameMode: widget.mode,
      ),
      // Step 2: Combined - show cross-hatching with eliminated cells
      HintStep(
        description: "Each $elementSingular can only appear once in the same row, column, or box. This $elementSingular cannot appear in the highlighted areas.",
        highlights: combinedHighlights,
        numberInstances: numberInstances,
        eliminatedCells: eliminatedCells,
        showTargetCell: true,
        showNumber: false,
      ),
      // Step 3: Solution
      HintStep(
        description: "So this cell should be filled with:",
        highlights: boxIndices,
        eliminatedCells: eliminatedCells,
        showTargetCell: true,
        showNumber: true,
        elementValue: val,
        gameMode: widget.mode,
      ),
    ];
  }

  void _activateHint(String title, String desc, int r, int c, int val, Set<int> highlights) {
    setState(() {
      _selectCell(r, c);
      _activeHint = HintInfo.legacy(title, desc, r, c, val, highlights);
    });
  }
  
  void _activateMultiStepHint(String title, List<HintStep> steps, int r, int c, int val) {
    setState(() {
      _selectCell(r, c);
      _activeHint = HintInfo(
        title: title,
        steps: steps,
        currentStepIndex: 0,
        targetRow: r,
        targetCol: c,
        value: val,
        gameMode: widget.mode,
        shapeMap: _shapeMap,
      );
    });
  }
  
  void _nextHintStep() {
    if (_activeHint != null && _activeHint!.canGoNext()) {
      setState(() {
        _activeHint = _activeHint!.copyWith(currentStepIndex: _activeHint!.currentStepIndex + 1);
      });
    }
  }
  
  void _previousHintStep() {
    if (_activeHint != null && _activeHint!.canGoPrevious()) {
      setState(() {
        _activeHint = _activeHint!.copyWith(currentStepIndex: _activeHint!.currentStepIndex - 1);
      });
    }
  }
  
  // ========== DEBUG/MOCK FUNCTIONS (Remove before production) ==========
  
  /// Mock: Instantly win the level by filling all empty cells correctly
  void _mockWinLevel() {
    setState(() {
      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (_board[r][c] == 0) {
            _board[r][c] = _getCorrectValue(r, c);
          }
        }
      }
    });
    // Trigger win check after a brief delay to allow UI to update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isBoardSolved()) {
        _onLevelComplete();
      }
    });
  }
  
  /// Mock: Fill a random incomplete row correctly
  void _mockFillRow() {
    // Find first incomplete row
    for (int r = 0; r < _gridSize; r++) {
      bool hasEmpty = false;
      for (int c = 0; c < _gridSize; c++) {
        if (_board[r][c] == 0) {
          hasEmpty = true;
          break;
        }
      }
      if (hasEmpty) {
        // Fill this row one cell at a time with animation
        _fillRowWithAnimation(r);
        return;
      }
    }
    if (mounted) {
      showCosmicSnackbar(context, "All rows are already complete!");
    }
  }
  
  /// Mock: Fill a random incomplete column correctly
  void _mockFillColumn() {
    // Find first incomplete column
    for (int c = 0; c < _gridSize; c++) {
      bool hasEmpty = false;
      for (int r = 0; r < _gridSize; r++) {
        if (_board[r][c] == 0) {
          hasEmpty = true;
          break;
        }
      }
      if (hasEmpty) {
        // Fill this column one cell at a time with animation
        _fillColumnWithAnimation(c);
        return;
      }
    }
    if (mounted) {
      showCosmicSnackbar(context, "All columns are already complete!");
    }
  }
  
  /// Mock: Fill a random incomplete block correctly
  void _mockFillBlock() {
    // Find first incomplete block
    for (int blockRow = 0; blockRow < _gridSize ~/ _blockRows; blockRow++) {
      for (int blockCol = 0; blockCol < _gridSize ~/ _blockCols; blockCol++) {
        bool hasEmpty = false;
        int startRow = blockRow * _blockRows;
        int startCol = blockCol * _blockCols;
        
        for (int r = startRow; r < startRow + _blockRows; r++) {
          for (int c = startCol; c < startCol + _blockCols; c++) {
            if (_board[r][c] == 0) {
              hasEmpty = true;
              break;
            }
          }
          if (hasEmpty) break;
        }
        
        if (hasEmpty) {
          _fillBlockWithAnimation(startRow, startCol);
          return;
        }
      }
    }
    if (mounted) {
      showCosmicSnackbar(context, "All blocks are already complete!");
    }
  }
  
  /// Helper: Fill row with animation
  void _fillRowWithAnimation(int row) async {
    List<int> emptyCols = [];
    for (int c = 0; c < _gridSize; c++) {
      if (_board[row][c] == 0) {
        emptyCols.add(c);
      }
    }
    
    for (int i = 0; i < emptyCols.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      
      int col = emptyCols[i];
      int correctValue = _getCorrectValue(row, col);
      
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
        _board[row][col] = correctValue;
        
        // Check if board is complete after filling
        if (i == emptyCols.length - 1 && _isBoardSolved()) {
          _onLevelComplete();
        }
      });
    }
  }
  
  /// Helper: Fill column with animation
  void _fillColumnWithAnimation(int col) async {
    List<int> emptyRows = [];
    for (int r = 0; r < _gridSize; r++) {
      if (_board[r][col] == 0) {
        emptyRows.add(r);
      }
    }
    
    for (int i = 0; i < emptyRows.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      
      int row = emptyRows[i];
      int correctValue = _getCorrectValue(row, col);
      
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
        _board[row][col] = correctValue;
        
        // Check if board is complete after filling
        if (i == emptyRows.length - 1 && _isBoardSolved()) {
          _onLevelComplete();
        }
      });
    }
  }
  
  /// Helper: Fill block with animation
  void _fillBlockWithAnimation(int startRow, int startCol) async {
    List<Map<String, int>> emptyCells = [];
    
    for (int r = startRow; r < startRow + _blockRows; r++) {
      for (int c = startCol; c < startCol + _blockCols; c++) {
        if (_board[r][c] == 0) {
          emptyCells.add({'row': r, 'col': c});
        }
      }
    }
    
    for (int i = 0; i < emptyCells.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      
      int row = emptyCells[i]['row']!;
      int col = emptyCells[i]['col']!;
      int correctValue = _getCorrectValue(row, col);
      
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
        _board[row][col] = correctValue;
        
        // Check if board is complete after filling
        if (i == emptyCells.length - 1 && _isBoardSolved()) {
          _onLevelComplete();
        }
      });
    }
  }
  
  // ========== END DEBUG/MOCK FUNCTIONS ==========
  

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _stopwatch.stop();
        GlassModal.show(
          context: context,
          title: 'PAUSE',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              CosmicButton(
                text: 'RESUME',
                icon: Icons.play_arrow,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              CosmicButton(
                text: 'RESTART',
                icon: Icons.refresh,
                type: CosmicButtonType.secondary,
                onPressed: () {
                   Navigator.pop(context);
                   CurrentGameRepository.clearGame(widget.mode, widget.difficulty);
                   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
                     levelNumber: widget.levelNumber, mode: widget.mode, difficulty: widget.difficulty
                   )));
                },
              ),
              const SizedBox(height: 16),
              CosmicButton(
                text: 'EXIT GAME',
                icon: Icons.exit_to_app,
                type: CosmicButtonType.destructive,
                onPressed: () {
                   Navigator.pop(context);
                   Navigator.pop(context);
                   SoundManager().ensureAmbientMusicPlaying();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ).then((_) => _stopwatch.start());
        return false;
      },
      child: Scaffold(
      appBar: AppBar(
          leading: IconButton(
             icon: const Icon(Icons.arrow_back),
             onPressed: () => Navigator.maybePop(context),
          ),
          title: Text('LEVEL ${widget.levelNumber}'), 
          actions: [
            IconButton(
              icon: Icon(_showHighlights ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showHighlights = !_showHighlights),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
          children: [
                  Text('Mistakes', style: TextStyle(fontSize: 10, color: kRetroText.withOpacity(0.7))),
                  Text('$_mistakes/$_maxMistakes', style: const TextStyle(fontWeight: FontWeight.bold, color: kRetroError)),
                ],
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Accelerated starry background during win animation
            AnimatedBuilder(
              animation: _winAnimationController,
              builder: (context, child) {
                return StarryBackground(
                  speedMultiplier: _winAnimationController.value > 0 ? 4.0 : 1.0,
                );
              },
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_formatTime(_elapsed), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildBoard(context),
                    ),
                  ),
                  _buildTools(context),
                  if (_showDebugToolbar) _buildDebugToolbar(context), // DEBUG: Remove before production
                  if (_activeHint == null) _buildInputBar(context),
                  if (_activeHint != null) Container(height: 120),
                ],
              ),
            ),
            // Debug floating button
            if (!_showDebugToolbar)
              Positioned(
                right: 16,
                bottom: 100,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.red.withOpacity(0.8),
                  onPressed: () => setState(() => _showDebugToolbar = true),
                  child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
                ),
              ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _completionController,
                builder: (context, child) {
                  if (_completionController.value == 0) return const SizedBox();
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.5 * _completionController.value),
                          Colors.transparent,
                        ],
                        stops: [
                          _completionController.value - 0.2,
                          _completionController.value,
                          _completionController.value + 0.2,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_activeHint != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _HintOverlay(
                  info: _activeHint!,
                  onApply: () {
                    _stopwatch.start();
                    
                    if (_activeHintElementType != null && _combinedPuzzle != null) {
                      // Element-specific hint for Crazy Sudoku
                      _applyElementHint(_activeHint!.targetRow, _activeHint!.targetCol, 
                                        _activeHint!.value, _activeHintElementType!);
                    } else if (_isEasyCrazySudoku()) {
                      // Easy Crazy Sudoku: fill with shape/color
                      _applyEasyCrazySudokuHint(_activeHint!.targetRow, _activeHint!.targetCol, _activeHint!.value);
                    } else {
                      // Standard: fill with number
                      _handleInput(_activeHint!.value);
                    }
                    
                    setState(() {
                      _activeHint = null;
                      _activeHintElementType = null;
                    });
                  },
                  onClose: () {
                    _stopwatch.start(); // Resume timer
                    setState(() => _activeHint = null);
                  },
                  onNext: _nextHintStep,
                  onPrevious: _previousHintStep,
                ),
              ),
            // Win animation particle effects
            AnimatedBuilder(
              animation: _winAnimationController,
              builder: (context, child) {
                if (_winAnimationController.value == 0) return const SizedBox();
                return const SizedBox.shrink(); // CosmicExplosion removed
              },
              ),
          ],
        ),
      ),
    );
  }
  

  Widget _buildTools(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(icon: Icons.undo, label: 'Undo', onTap: _undo),
          _ToolButton(
            icon: Icons.edit,
            label: 'Pencil',
            isActive: _pencilMode,
            onTap: () => setState(() => _pencilMode = !_pencilMode),
          ),
          _ToolButton(icon: Icons.delete, label: 'Erase', onTap: _erase),
          _ToolButton(
            icon: Icons.lightbulb, 
            label: 'Hint', 
            onTap: _hint,
            badge: _hintsRemaining > 0 ? _hintsRemaining : null,
          ),
        ],
      ),
    );
  }

  // DEBUG: Remove before production
  Widget _buildDebugToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DEBUG TOOLS', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _showDebugToolbar = false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _DebugButton(
                  label: 'Win',
                  icon: Icons.emoji_events,
                  onTap: _mockWinLevel,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _DebugButton(
                  label: 'Row',
                  icon: Icons.horizontal_rule,
                  onTap: _mockFillRow,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _DebugButton(
                  label: 'Col',
                  icon: Icons.more_vert,
                  onTap: _mockFillColumn,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _DebugButton(
                  label: 'Block',
                  icon: Icons.grid_3x3,
                  onTap: _mockFillBlock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boardLength = math.min(constraints.maxWidth, constraints.maxHeight);
        
        // Calculate center for ripple effect
        final double centerRow = (_gridSize - 1) / 2;
        final double centerCol = (_gridSize - 1) / 2;
        final double maxDist = math.sqrt(math.pow(centerRow, 2) + math.pow(centerCol, 2));

        return Align(
          alignment: Alignment.topCenter, 
          child: AnimatedBuilder(
            animation: _winAnimationController,
            builder: (context, child) {
              return Container(
            key: _boardKey,
            width: boardLength,
            height: boardLength,
            decoration: BoxDecoration(
              color: kRetroSurface.withOpacity(0.5),
                  border: Border.all(
                    color: _winAnimationController.value > 0
                        ? kCosmicPrimary.withOpacity(0.8 + 0.2 * math.sin(_winAnimationController.value * math.pi * 4))
                        : kCosmicPrimary.withOpacity(0.9), // Match block line brightness
                    width: 4 + (_winAnimationController.value * 2),
                  ),
                  boxShadow: _winAnimationController.value > 0
                      ? [
                          BoxShadow(
                            color: kCosmicPrimary.withOpacity(0.6 * _winAnimationController.value),
                            blurRadius: 20 * _winAnimationController.value,
                            spreadRadius: 5 * _winAnimationController.value,
                          ),
                        ]
                      : null,
            ),
            padding: const EdgeInsets.all(2),
            child: Stack(
              children: [
                // Board content with fade-in for numbers (cells go first so grid lines render on top)
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _rotationController,
                    _groupCompletionController,
                    _numbersFadeController,
                  ]),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _numbersFadeController.value,
                      child: Column(
                  children: List<Widget>.generate(_gridSize, (int row) {
                    return Expanded(
                      child: Row(
                        children: List<Widget>.generate(_gridSize, (int col) {
                          final int value = _board[row][col]; 
                          
                          final bool isEditable = _isEditable[row][col];
                          final bool isSelected = _selectedRow == row && _selectedCol == col;
                          final bool isInvalid = _errorCells.contains(row * _gridSize + col);
                          
                          CellHighlight highlight = _showHighlights ? _cellHighlight(row, col, value) : CellHighlight.none;
                          if (_activeHint != null) {
                             final idx = row * _gridSize + col;
                             final currentStep = _activeHint!.currentStep;
                             
                             // Check for eliminated cells (X marks)
                             if (currentStep.eliminatedCells != null && currentStep.eliminatedCells!.contains(idx)) {
                                highlight = CellHighlight.hintEliminated;
                             }
                             // Check for number instances (cells containing target number)
                             else if (currentStep.numberInstances != null && currentStep.numberInstances!.contains(idx)) {
                                highlight = CellHighlight.hintNumberInstance;
                             }
                             // Check for target cell
                             else if (currentStep.showTargetCell && row == _activeHint!.targetRow && col == _activeHint!.targetCol) {
                                highlight = CellHighlight.hintTarget;
                             }
                             // Check for related highlights (row/column/box)
                             else if (currentStep.highlights.contains(idx)) {
                                highlight = CellHighlight.hintRelated;
                             }
                          }

                          final int cellIndex = row * _gridSize + col;
                          final bool isAnimated = _animatedCells.contains(cellIndex);
                          // final bool isGlittering = _glitterCells.contains(cellIndex); // Removed
                          
                          CombinedCell? combinedCell;
                          if (_combinedPuzzle != null) {
                            // Only show initialBoard content if:
                            // 1. Cell is fixed (pre-filled clue), OR
                            // 2. Cell has been filled by user (_board > 0), OR
                            // 3. Cell has user-filled elements (from hints)
                            final bool isFixed = !_isEditable[row][col];
                            final bool isUserFilled = _board[row][col] > 0;
                            final String cellKey = '${row}_$col';
                            final bool hasUserFilledElements = _userFilledElements.containsKey(cellKey) && 
                                                             _userFilledElements[cellKey]!.isNotEmpty;
                            
                            if (isFixed || isUserFilled || hasUserFilledElements) {
                              combinedCell = _combinedPuzzle!.initialBoard[row][col];
                            } else {
                              // Empty editable cell - don't show anything from initialBoard
                              combinedCell = null;
                            }
                          }
                          
                          final bool rightBorder = (col + 1) % _blockCols == 0 && col != _gridSize - 1;
                          final bool bottomBorder = (row + 1) % _blockRows == 0 && row != _gridSize - 1;
                          final bool isCombinedMode = (widget.difficulty == Difficulty.medium || 
                                                       widget.difficulty == Difficulty.hard ||
                                                       widget.difficulty == Difficulty.expert ||
                                                       widget.difficulty == Difficulty.master) && widget.mode != GameMode.numbers;
                          
                          // Check if we should show hint number for this cell
                          bool hintShowNumber = false;
                          int? hintValue;
                          ElementType? hintElementType;
                          if (_activeHint != null && 
                              row == _activeHint!.targetRow && 
                              col == _activeHint!.targetCol &&
                              _activeHint!.currentStep.showNumber) {
                            hintShowNumber = true;
                            hintValue = _activeHint!.currentStep.elementValue ?? _activeHint!.value;
                            hintElementType = _activeHint!.currentStep.elementType ?? _activeHintElementType;
                          }
                          
                          // Calculate flip delay based on distance from center
                          double dist = math.sqrt(math.pow(row - centerRow, 2) + math.pow(col - centerCol, 2));
                          double normalizedDist = dist / maxDist; // 0.0 to 1.0
                          
                          // Animation logic:
                          // We want the ripple to start at 0 and end at 1.0
                          // The whole animation is controlled by _winAnimationController (0 to 1)
                          // We can say the ripple takes 60% of the time, and individual flips take 40%
                          // Start time for this cell: normalizedDist * 0.6
                          // End time for this cell: Start time + 0.4
                          
                          double start = normalizedDist * 0.5;
                          double end = start + 0.5;
                          double flipValue = 0.0;
                          
                          if (_winAnimationController.value > 0) {
                            if (_winAnimationController.value >= end) {
                              flipValue = 1.0;
                            } else if (_winAnimationController.value <= start) {
                              flipValue = 0.0;
                            } else {
                              flipValue = (_winAnimationController.value - start) / 0.5;
                            }
                            // Apply curve
                            flipValue = Curves.easeInOutBack.transform(flipValue);
                          }
                          
                          // Check if this cell has user-filled elements (from hints)
                          final String cellKey = '${row}_$col';
                          final bool hasUserFilledElements = _userFilledElements.containsKey(cellKey) && 
                                                           _userFilledElements[cellKey]!.isNotEmpty;
                          
                          Widget cellWidget = _SudokuCell(
                                key: ValueKey('cell_${row}_${col}_${value}_${isSelected}'), // Force rebuild on selection change
                                value: value,
                                notes: _notes[row][col],
                                shapeNotes: isCombinedMode ? _shapeNotes[row][col] : const {},
                                colorNotes: isCombinedMode ? _colorNotes[row][col] : const {},
                                numberNotes: isCombinedMode ? _numberNotes[row][col] : const {},
                                draftCell: isCombinedMode && isSelected ? _draftCell : null,
                                row: row,
                                col: col,
                                gridSize: _gridSize,
                                isEditable: isEditable,
                                isSelected: isSelected,
                                isInvalid: isInvalid,
                                highlight: highlight,
                                isAnimated: isAnimated,
                                glitterValue: _glitterController.value, // Pass animation value
                                gameMode: widget.mode,
                                difficulty: widget.difficulty,
                                combinedCell: combinedCell,
                                selectedElement: null, 
                                shapeId: _shapeMap[value > 0 ? value - 1 : 0],
                                shapeMap: _shapeMap, 
                                onTap: () => _selectCell(row, col),
                                hintShowNumber: hintShowNumber,
                                hintValue: hintValue,
                                hintElementType: hintElementType,
                                flipValue: flipValue,
                                hasUserFilledElements: hasUserFilledElements,
                          );

                          // Grid lines are now drawn ONLY by _GridDrawingPainter to avoid double lines
                          return Expanded(child: cellWidget);
                        }),
                      ),
                    );
                  }),
                      ),
                );
              },
            ),
          // Grid lines - drawn ON TOP of cells so they're always visible
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _gridAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(boardLength - 4, boardLength - 4),
                  painter: _GridDrawingPainter(
                    gridSize: _gridSize,
                    blockRows: _blockRows,
                    blockCols: _blockCols,
                    progress: _gridAnimationController.value,
                  ),
                );
              },
            ),
          ),
          // Line completion animation - Moved here to be ON TOP of cells
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _lineCompletionController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(boardLength - 4, boardLength - 4),
                  painter: _WaveCompletionPainter(
                    progress: _lineCompletionController.value,
                    row: _completedRow,
                    col: _completedCol,
                    triggerRow: _triggerRow,
                    triggerCol: _triggerCol,
                    gridSize: _gridSize,
                    triggerBlockRow: _triggerBlockRow,
                    triggerBlockCol: _triggerBlockCol,
                    blockRows: _blockRows,
                    blockCols: _blockCols,
                  ),
                );
              },
            ),
          ),
              ],
            ),
              );
            },
          ),
        );
      },
    );
  }
  
  CellHighlight _cellHighlight(int row, int col, int value) {
    final int? selRow = _selectedRow;
    final int? selCol = _selectedCol;
    if (selRow == null || selCol == null) return CellHighlight.none;

    if (row == selRow && col == selCol) return CellHighlight.selected;

    // Unified logic for all modes
    // Check matching value only for Numbers mode (standard Sudoku)
    if (widget.mode == GameMode.numbers) {
      final int selectedValue = _board[selRow][selCol];
      if (selectedValue != 0 && value != 0 && value == selectedValue) return CellHighlight.matching;
      
      // Check persistent highlight
      if (_highlightedNumber != null && value == _highlightedNumber) return CellHighlight.matching;
    }

    if (row == selRow || col == selCol || _sharesBlock(row, col, selRow, selCol)) {
      return CellHighlight.related; 
    }

    return CellHighlight.none;
  }

  bool _sharesBlock(int row, int col, int otherRow, int otherCol) {
    return _blockIndex(row, col) == _blockIndex(otherRow, otherCol);
  }

  int _blockIndex(int row, int col) {
    return (row ~/ _blockRows) * (_gridSize ~/ _blockCols) + (col ~/ _blockCols);
  }
  
  Widget _buildInputBar(BuildContext context) {
    return GameToolbar(
      gameMode: widget.mode,
      difficulty: widget.difficulty,
      gridSize: _gridSize,
      onInput: (int value, ElementType? type) {
        _handleInput(value, type: type);
      },
      draftCell: _draftCell,
      shapeMap: _shapeMap,
      isValueCompleted: _isValueCompleted,
      selectedElement: _combinedPuzzle?.selectedElement,
    );
  }
  
  bool _isValueCompleted(int value) {
    int count = 0;
    for (final List<int> row in _board) {
      for (final int cell in row) {
        if (cell == value) count++;
      }
    }
    return count >= _gridSize;
  }
}

class _HintOverlay extends StatelessWidget {
  const _HintOverlay({
    required this.info,
    required this.onApply,
    required this.onClose,
    required this.onNext,
    required this.onPrevious,
  });
  final HintInfo info;
  final VoidCallback onApply;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  // Build visual element widget based on game mode and element type
  Widget? _buildElementWidget(HintStep step, HintInfo info) {
    final value = step.elementValue ?? info.value;
    final gameMode = step.gameMode ?? info.gameMode;
    final elementType = step.elementType ?? info.elementType;
    final shapeMap = info.shapeMap;
    
    if (gameMode == null) return null;
    
    // For combined modes with element type specified
    if (elementType != null) {
      switch (elementType) {
        case ElementType.shape:
          return Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kRetroSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SudokuShape(id: value, color: kCosmicPrimary),
          );
        case ElementType.color:
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getColorForValue(value),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          );
        case ElementType.number:
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kRetroSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  color: kCosmicPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
      }
    }
    
    // For single-element modes
    switch (gameMode) {
      case GameMode.planets:
        return Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: kRetroSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(painter: PlanetPainter(value), size: const Size(32, 32)),
        );
      case GameMode.shapes:
        final shapeId = shapeMap != null && value > 0 && value <= shapeMap.length 
            ? shapeMap[value - 1] 
            : value;
        return Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kRetroSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SudokuShape(id: shapeId, color: kCosmicPrimary),
        );
      case GameMode.colors:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _getColorForValue(value),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      case GameMode.cosmic:
        return Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: kRetroSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(painter: CosmicPainter(value), size: const Size(32, 32)),
        );
      case GameMode.numbers:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kRetroSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                color: kCosmicPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      default:
        return null;
    }
  }

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
    final currentStep = info.currentStep;
    final isLastStep = info.isLastStep;
    final isFirstStep = info.isFirstStep;
    
    // Build element widget if this step should show one
    final Widget? elementWidget = currentStep.showNumber 
        ? _buildElementWidget(currentStep, info) 
        : null;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar with close button
           Row(
             children: [
              Expanded(
                child: Text(
                  info.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Description text with optional element widget
          if (elementWidget != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    currentStep.description,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                elementWidget,
              ],
            )
          else
            Text(
              currentStep.description,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
           const SizedBox(height: 16),
          // Progress indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              info.steps.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == info.currentStepIndex
                      ? kRetroHint
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Navigation buttons
          Row(
            children: [
              // Previous button (left arrow)
              if (!isFirstStep)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text("Previous"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black54,
                      side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                    ),
                  ),
                ),
              if (!isFirstStep) const SizedBox(width: 8),
              // Next/Apply button
              Expanded(
                flex: isFirstStep ? 1 : 1,
             child: ElevatedButton(
                  onPressed: isLastStep ? onApply : onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRetroHint,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(isLastStep ? "Apply" : "Next"),
                ),
              ),
            ],
           ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon, 
    required this.label, 
    required this.onTap, 
    this.isActive = false,
    this.badge,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? kRetroHighlight : kRetroSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: kRetroText.withOpacity(0.5)),
                ),
                child: Icon(icon, color: isActive ? kRetroText : kRetroText.withOpacity(0.8), size: 20),
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: kCosmicPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: kRetroSurface, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kCosmicPrimary.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: kRetroSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: kRetroText.withOpacity(0.8))),
        ],
      ),
    );
  }
}

// DEBUG: Remove before production
class _DebugButton extends StatelessWidget {
  const _DebugButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red, size: 16),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SudokuCell extends StatefulWidget {
  const _SudokuCell({
    super.key,
    required this.value,
    required this.notes,
    this.shapeNotes,
    this.colorNotes,
    this.numberNotes,
    this.draftCell,
    required this.row,
    required this.col,
    required this.gridSize,
    required this.isSelected,
    required this.isEditable,
    required this.isInvalid,
    required this.highlight,
    required this.isAnimated,
    required this.glitterValue,
    required this.gameMode,
    required this.difficulty,
    this.combinedCell,
    this.selectedElement,
    required this.shapeId,
    required this.shapeMap,
    required this.onTap,
    this.hintShowNumber = false,
    this.hintValue,
    this.hintElementType,
    this.flipValue = 0.0,
    this.hasUserFilledElements = false,
  });

  final int value;
  final Set<int> notes;
  final Set<int>? shapeNotes;
  final Set<int>? colorNotes;
  final Set<int>? numberNotes;
  final CombinedCell? draftCell;
  final int row;
  final int col;
  final int gridSize;
  final bool isSelected;
  final bool isEditable;
  final bool isInvalid;
  final CellHighlight highlight;
  final bool isAnimated;
  final double glitterValue;
  final GameMode gameMode;
  final Difficulty difficulty;
  final CombinedCell? combinedCell;
  final ElementType? selectedElement;
  final int shapeId;
  final List<int> shapeMap;
  final VoidCallback onTap;
  final bool hintShowNumber;
  final int? hintValue;
  final ElementType? hintElementType;
  final double flipValue;
  final bool hasUserFilledElements;

  @override
  State<_SudokuCell> createState() => _SudokuCellState();
}

class _SudokuCellState extends State<_SudokuCell> with SingleTickerProviderStateMixin {
  late AnimationController _errorController;

  @override
  void initState() {
    super.initState();
    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(_SudokuCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInvalid && !oldWidget.isInvalid) {
      _errorController.forward(from: 0).then((_) => _errorController.reverse());
    }
  }

  @override
  void dispose() {
    _errorController.dispose();
    super.dispose();
  }

  /// Builds an edge-based liquid glass highlight overlay
  /// This creates the glass effect through edge highlights without obscuring content
  Widget _buildEdgeHighlight({
    required Color highlightColor,
    required double intensity, // 0.0 to 1.0, controls overall visibility
    required double borderWidth,
    required bool isSelected, // Selected cells get stronger effect
  }) {
    // Edge colors based on Figma reference:
    // Top-left: Bright white/highlight color (#FFFFFF 50%, #B3B3B3 100%)
    // Bottom-right: Darker shadow (#999999 100%, #B3B3B3 100%)
    
    final topLeftColor = Colors.white.withOpacity(0.5 * intensity);
    final topLeftInner = const Color(0xFFB3B3B3).withOpacity(0.3 * intensity);
    final bottomRightColor = const Color(0xFF999999).withOpacity(0.4 * intensity);
    final bottomRightInner = const Color(0xFFF2F2F2).withOpacity(0.15 * intensity);
    
    return Stack(
      children: [
        // Top edge highlight (bright)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: isSelected ? 3.0 : 2.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  topLeftColor,
                  topLeftInner,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        
        // Left edge highlight (bright)
        Positioned(
          top: 0,
          left: 0,
          bottom: 0,
          child: Container(
            width: isSelected ? 3.0 : 2.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  topLeftColor,
                  topLeftInner,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        
        // Bottom edge shadow (dark)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: isSelected ? 2.5 : 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  bottomRightColor,
                  bottomRightInner,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
        ),
        
        // Right edge shadow (dark)
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: Container(
            width: isSelected ? 2.5 : 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  bottomRightColor,
                  bottomRightInner,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
        ),
        
        // Corner accent (top-left bright spot)
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: isSelected ? 6 : 4,
            height: isSelected ? 6 : 4,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.6 * intensity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ALL cells start with transparent background so grid lines show through
    Color baseColor = Colors.transparent;
    Color contentColor = kRetroText;

    // 1. Text styling only for prefilled vs editable (no opaque backgrounds)
    if (widget.isInvalid) {
      contentColor = kRetroError; // Red text/content for mistakes
    } else if (!widget.isEditable) {
       // Prefilled: brighter text, NO background so grid lines visible
       contentColor = Colors.white.withOpacity(0.95); // Brighter for prefilled
    } else if (widget.value > 0) {
       // User-filled: slightly dimmer text
       contentColor = kRetroText.withOpacity(0.85);
    }

    // 2. Determine highlight parameters
    Color? highlightBorderColor;
    double borderWidth = 0;
    double edgeIntensity = 0;
    bool isSelected = false;
    Color? verySubtleTint;
    
    if (widget.isSelected) {
      // SELECTED: Visible cyan fill + bright border
      highlightBorderColor = const Color(0xFF00E5FF);
      borderWidth = 2.5;
      edgeIntensity = 1.0;
      isSelected = true;
      verySubtleTint = const Color(0xFF00E5FF).withOpacity(0.25);
    } else if (widget.highlight == CellHighlight.related) {
      // RELATED: Very subtle blue tint - NOT same as prefilled!
      highlightBorderColor = null;
      borderWidth = 0;
      edgeIntensity = 0;
      // Very light blue tint (not dark like prefilled was)
      verySubtleTint = const Color(0xFF4FC3F7).withOpacity(0.12);
    } else if (widget.highlight == CellHighlight.matching) {
      // MATCHING: Purple border + tint
      highlightBorderColor = const Color(0xFFB388FF);
      borderWidth = 2.0;
      edgeIntensity = 0.8;
      verySubtleTint = const Color(0xFFB388FF).withOpacity(0.15);
    }
    
    // 3. Handle hint highlights (keep existing simple approach)
    Color finalBaseColor = baseColor;
    if (widget.highlight == CellHighlight.hintRelated) {
      finalBaseColor = Color.alphaBlend(kRetroHint.withOpacity(0.3), baseColor);
    } else if (widget.highlight == CellHighlight.hintEliminated) {
      finalBaseColor = Color.alphaBlend(kRetroHint.withOpacity(0.3), baseColor);
    } else if (widget.highlight == CellHighlight.hintNumberInstance) {
      finalBaseColor = Color.alphaBlend(kRetroHint.withOpacity(0.4), baseColor);
    } else if (widget.highlight == CellHighlight.hintTarget) {
      finalBaseColor = Color.alphaBlend(kRetroHint.withOpacity(0.6), baseColor);
      highlightBorderColor = const Color(0xFF0066CC);
      borderWidth = 3.0;
    }
    
    // Animation overrides
    if (widget.isAnimated) {
       finalBaseColor = Color.alphaBlend(const Color(0xFF64FFDA).withOpacity(0.3), finalBaseColor);
    }
    
    // Win animation override
    if (widget.flipValue > 0) {
      finalBaseColor = Color.lerp(
        finalBaseColor, 
        kCosmicPrimary.withOpacity(0.5), 
        math.sin(widget.flipValue * math.pi)
      )!;
    }
    
    // Apply very subtle tint if needed
    if (verySubtleTint != null) {
      finalBaseColor = Color.alphaBlend(verySubtleTint, finalBaseColor);
    }

    // 4. Build the decoration (minimal - just base color and border)
    final decoration = BoxDecoration(
      color: finalBaseColor,
      border: highlightBorderColor != null 
          ? Border.all(color: highlightBorderColor.withOpacity(0.85), width: borderWidth)
          : null,
    );
    
    // Check if this is an eliminated cell
    final bool showEliminatedMark = widget.highlight == CellHighlight.hintEliminated;
    
    // 5. Build the cell with edge highlight overlay
    Widget cellContent;
    if (widget.isInvalid) {
      cellContent = GestureDetector(
        onTap: widget.isEditable ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _errorController,
          builder: (context, child) {
            return _buildCellContainer(
              BoxDecoration(
                color: _errorController.value > 0 
                  ? Colors.red.withOpacity(0.5 * _errorController.value) 
                  : Colors.transparent,
              ),
              contentColor,
              showEliminatedMark,
              edgeHighlight: null, 
            );
          },
        ),
      );
    } else {
      cellContent = GestureDetector(
        onTap: widget.isEditable ? widget.onTap : null,
        child: _buildCellContainer(
          decoration,
          contentColor,
          showEliminatedMark,
          edgeHighlight: edgeIntensity > 0 
              ? _buildEdgeHighlight(
                  highlightColor: highlightBorderColor!,
                  intensity: edgeIntensity,
                  borderWidth: borderWidth,
                  isSelected: isSelected,
                )
              : null,
        ),
      );
    }
    
    // Apply 3D Flip Animation (unchanged)
    if (widget.flipValue > 0) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // Perspective
          ..rotateY(widget.flipValue * math.pi * 2), // Full 360 rotation
        child: cellContent,
      );
    }
    
    return cellContent;
  }

  Widget _buildCellContainer(BoxDecoration decoration, Color contentColor, bool showEliminatedMark, {Widget? edgeHighlight}) {
    // Medium and Hard modes: Show draft cell if selected, or show separate notes
    if ((widget.difficulty == Difficulty.medium || widget.difficulty == Difficulty.hard ||
         widget.difficulty == Difficulty.expert || widget.difficulty == Difficulty.master) && 
        widget.gameMode != GameMode.numbers) {
      Widget content;
      
      // Check if cell is filled first (before showing draft)
      // Medium: only needs shapeId and colorId (no numbers)
      // Hard/Expert/Master: needs all three (shapeId, colorId, numberId)
      final bool isMedium = widget.difficulty == Difficulty.medium;
      final bool isFilled = widget.combinedCell != null && 
          widget.combinedCell!.shapeId != null && 
          widget.combinedCell!.colorId != null && 
          (isMedium ? true : widget.combinedCell!.numberId != null) && // Medium doesn't need numberId
          (widget.value > 0 || !widget.isEditable); // Filled if has value or is fixed
      
      // Check if cell has any partial fill (from hints)
      // Only show partial fill if cell is editable and has user-filled elements
      final bool hasPartialFill = widget.combinedCell != null && 
          widget.isEditable && // Only editable cells can have partial fills from hints
          widget.hasUserFilledElements && // Must have user-filled elements
          (widget.combinedCell!.shapeId != null || 
           widget.combinedCell!.colorId != null || 
           widget.combinedCell!.numberId != null) &&
          !isFilled;
      
      // Priority: Filled cell > Partial fill > Draft cell (if selected) > Notes > Empty
      if (isFilled) {
        // Cell is filled - show the filled cell (even if selected)
        content = _buildCombinedElement(widget.combinedCell!, widget.selectedElement, contentColor);
      } else if (hasPartialFill) {
        // Cell has partial fill (from hint) - show it
        // Build content stack for partial fill + draft on top
        List<Widget> contentStack = [];
        
        // Show partial fill as base
        contentStack.add(_buildPartialFillElement(widget.combinedCell!, contentColor));
        
        // Show draft on top if selected and has additional selections
        if (widget.draftCell != null && widget.isSelected && widget.isEditable &&
            (widget.draftCell!.shapeId != null || widget.draftCell!.colorId != null || widget.draftCell!.numberId != null)) {
          final Color draftShapeColor = widget.draftCell!.colorId != null 
              ? _getColorForValue(widget.draftCell!.colorId!)
              : Colors.white.withOpacity(0.9);
          contentStack.add(_buildDraftCell(widget.draftCell!, draftShapeColor, contentColor));
        }
        
        if (contentStack.length == 1) {
          content = contentStack.first;
        } else {
          content = Stack(children: contentStack);
        }
      } else {
        // Build content stack
        List<Widget> contentStack = [];
        
        // Always show notes if present (behind draft)
        if (widget.shapeNotes != null && 
            (widget.shapeNotes!.isNotEmpty || widget.colorNotes!.isNotEmpty || widget.numberNotes!.isNotEmpty)) {
          contentStack.add(_buildMediumNotes());
        }
        
        // Show draft on top if selected
        if (widget.draftCell != null && widget.isSelected && widget.isEditable &&
            (widget.draftCell!.shapeId != null || widget.draftCell!.colorId != null || widget.draftCell!.numberId != null)) {
          // Use white as default if only shape is selected (no color)
          final Color draftShapeColor = widget.draftCell!.colorId != null 
              ? _getColorForValue(widget.draftCell!.colorId!)
              : Colors.white.withOpacity(0.9);
          contentStack.add(_buildDraftCell(widget.draftCell!, draftShapeColor, contentColor));
        }
        
        if (contentStack.isEmpty) {
          content = const SizedBox.expand();
        } else if (contentStack.length == 1) {
          content = contentStack.first;
        } else {
          content = Stack(children: contentStack);
        }
      }
      
      return Container(
        decoration: decoration,
        child: Stack(
          children: [
            Center(child: content),
            if (edgeHighlight != null)
              Positioned.fill(child: edgeHighlight),
            if (showEliminatedMark)
              Center(
                child: Text(
                  '✕',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Show hint element for combined modes
            if (widget.hintShowNumber && widget.hintValue != null && !isFilled &&
                widget.difficulty != Difficulty.medium)
              Center(
                child: _buildHintElement(),
              ),
          ],
        ),
      );
    }
    
    // Standard mode
    Widget content;
    if (widget.value > 0 || (widget.combinedCell != null && (widget.combinedCell!.shapeId != null || widget.combinedCell!.colorId != null || widget.combinedCell!.numberId != null))) {
          content = (widget.combinedCell != null)
                ? _buildCombinedElement(widget.combinedCell!, widget.selectedElement, contentColor)
                : _buildSingleElement(context, contentColor);
    } else if (widget.notes.isNotEmpty) {
       content = _buildNotes();
    } else {
       content = const SizedBox.expand();
    }

    return Container(
      decoration: decoration,
      child: Stack(
        children: [
          Center(child: content),
          if (edgeHighlight != null)
            Positioned.fill(child: edgeHighlight),
          if (showEliminatedMark)
            Center(
              child: Text(
                '✕',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Show hint element for standard mode (only show if cell is empty)
          if (widget.hintShowNumber && widget.hintValue != null && widget.value == 0)
            Center(
              child: _buildHintElement(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDraftCell(CombinedCell draft, Color draftShapeColor, Color defaultColor) {
    // Show ONLY what's selected in draft - nothing else
    List<Widget> widgets = [];
    
    // Show shape only if shapeId is selected
    if (draft.shapeId != null) {
      widgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SudokuShape(id: draft.shapeId!, color: draftShapeColor),
          ),
        ),
      );
    }
    
    // Show color circle only if colorId is selected (and shapeId is NOT selected)
    if (draft.colorId != null && draft.shapeId == null) {
      widgets.add(
        Center(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getColorForValue(draft.colorId!),
              shape: BoxShape.circle,
              border: Border.all(color: kRetroHighlight, width: 2),
            ),
          ),
        ),
      );
    }
    
    // Show number if numberId is selected
    if (draft.numberId != null) {
      // If shape is selected, overlay number on shape (like final filled cell)
      if (draft.shapeId != null) {
        widgets.add(
          Center(
            child: Text(
              draft.numberId.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'Courier',
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // If no shape, show number alone
        widgets.add(
          Center(
            child: Text(
              draft.numberId.toString(),
              style: TextStyle(
                color: kRetroText,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Courier',
              ),
            ),
          ),
        );
      }
    }
    
    if (widgets.isEmpty) {
      return const SizedBox.expand();
    }
    
    return Stack(
      fit: StackFit.expand,
      children: widgets,
    );
  }
  
  // Build partial fill element - shows elements that have been filled via hints
  Widget _buildPartialFillElement(CombinedCell cell, Color defaultColor) {
    List<Widget> widgets = [];
    
    final int? shapeId = cell.shapeId;
    final int? colorId = cell.colorId;
    final int? numberId = cell.numberId;
    
    // Determine shape color - use color if available, else a subtle gray
    final Color shapeColor = colorId != null 
        ? _getColorForValue(colorId)
        : Colors.white.withOpacity(0.7);
    
    // Show shape if present
    if (shapeId != null) {
      widgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SudokuShape(id: shapeId, color: shapeColor),
          ),
        ),
      );
    }
    
    // Show color circle if only color is present (no shape)
    if (colorId != null && shapeId == null) {
      widgets.add(
        Center(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: shapeColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: shapeColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)],
            ),
          ),
        ),
      );
    }
    
    // Show number if present
    if (numberId != null) {
      if (shapeId != null) {
        // Number overlaid on shape
        widgets.add(
          Center(
            child: Text(
              numberId.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'Courier',
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // Number alone
        widgets.add(
          Center(
            child: Text(
              numberId.toString(),
              style: TextStyle(
                color: kRetroText,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                fontFamily: 'Courier',
              ),
            ),
          ),
        );
      }
    }
    
    if (widgets.isEmpty) {
      return const SizedBox.expand();
    }
    
    return Stack(
      fit: StackFit.expand,
      children: widgets,
    );
  }
  
  Widget _buildMediumNotes() {
    final bool isMedium = widget.difficulty == Difficulty.medium;
    final bool isHard = widget.difficulty == Difficulty.hard;
    final bool isCrazySudoku = widget.gameMode != GameMode.numbers && 
                                widget.gameMode != GameMode.custom;
    
    // Determine grid size based on difficulty and mode
    int effectiveGridSize;
    if (isCrazySudoku && (isMedium || isHard)) {
      effectiveGridSize = 6; // Crazy Sudoku Medium/Hard is 6x6
    } else {
      effectiveGridSize = widget.gridSize;
    }
    
    // Item counts
    final int numberCount = isMedium ? 0 : effectiveGridSize;
    final int colorCount = effectiveGridSize;
    final int shapeCount = effectiveGridSize;
    final int totalItems = numberCount + colorCount + shapeCount;
    
    // Determine grid dimensions
    int rows, cols;
    double fontSize = 7;
    double iconSize = 6;
    double shapeSize = 8;
    
    if (isMedium) {
      // Medium (6x6): 12 items (6 colors + 6 shapes) -> 4 rows x 3 cols
      rows = 4;
      cols = 3;
    } else if (effectiveGridSize == 6) {
      // Hard (6x6): 18 items (6+6+6) -> 4 rows x 5 cols (fits 20, uses 18)
      rows = 4;
      cols = 5;
      fontSize = 6;
      iconSize = 5;
      shapeSize = 6;
    } else {
      // Expert/Master (9x9): 27 items (9+9+9) -> 6 rows x 5 cols (fits 30, uses 27)
      rows = 6;
      cols = 5;
      fontSize = 5;
      iconSize = 4;
      shapeSize = 5;
    }
    
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(rows, (rowIndex) {
          return Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(cols, (colIndex) {
                final int index = rowIndex * cols + colIndex;
                if (index >= totalItems) return const Expanded(child: SizedBox());
                
                // Determine element type and value
                ElementType type;
                int val;
                
                if (index < numberCount) {
                  type = ElementType.number;
                  val = index + 1;
                } else if (index < numberCount + colorCount) {
                  type = ElementType.color;
                  val = index - numberCount + 1;
                } else {
                  type = ElementType.shape;
                  val = index - numberCount - colorCount + 1;
                }
                
                // Check if this note is present
                bool isPresent = false;
                if (type == ElementType.number) {
                  isPresent = widget.numberNotes?.contains(val) ?? false;
                } else if (type == ElementType.color) {
                  isPresent = widget.colorNotes?.contains(val) ?? false;
                } else {
                  isPresent = widget.shapeNotes?.contains(val) ?? false;
                }
                
                if (!isPresent) {
                  return const Expanded(child: SizedBox());
                }
                
                return Expanded(
                  child: _buildDenseNoteWithSize(type, val, fontSize, iconSize, shapeSize),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDenseNoteWithSize(ElementType type, int val, double fontSize, double iconSize, double shapeSize) {
    if (type == ElementType.number) {
      return Center(
        child: Text(
          '$val',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: kRetroText.withOpacity(0.8),
          ),
        ),
      );
    } else if (type == ElementType.color) {
      return Center(
        child: Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: _getColorForValue(val),
            shape: BoxShape.circle,
          ),
        ),
      );
    } else {
      return Center(
        child: SizedBox(
          width: shapeSize,
          height: shapeSize,
          child: SudokuShape(
            id: val,
            color: kRetroText.withOpacity(0.7),
          ),
        ),
      );
    }
  }

  Widget _buildStackedNote(int val, bool hasShape, bool hasColor, bool hasNumber) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Color Note (Planet/Nebula Background)
        if (hasColor)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _getColorForValue(val).withOpacity(0.8),
                  _getColorForValue(val).withOpacity(0.3),
                  Colors.transparent,
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
              shape: BoxShape.circle,
            ),
          ),
          
        // 2. Shape Note (Glowing Icon)
        if (hasShape)
          Padding(
            padding: const EdgeInsets.all(2),
            child: SudokuShape(
              id: val, 
              color: hasColor ? Colors.white.withOpacity(0.9) : kRetroText.withOpacity(0.8),
            ),
          ),
          
        // 3. Number Note (Floating Overlay)
        if (hasNumber)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kRetroText.withOpacity(0.3), width: 0.5),
              ),
              child: Text(
                '$val',
                style: TextStyle(
                  fontSize: 8, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    BoxShadow(color: kRetroHighlight, blurRadius: 2)
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotes() {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: List.generate(widget.gridSize, (index) {
          final val = index + 1;
          if (!widget.notes.contains(val)) return SizedBox(width: widget.gridSize == 9 ? 8 : 12, height: widget.gridSize == 9 ? 8 : 12);
          
          // Render shape for notes if shapes mode
          if (widget.gameMode == GameMode.shapes) {
              final int mappedId = widget.shapeMap[index]; // Index 0 is value 1
              return SizedBox(
                width: widget.gridSize == 9 ? 8 : 12,
                height: widget.gridSize == 9 ? 8 : 12,
                child: SudokuShape(id: mappedId, color: kRetroText.withOpacity(0.7)),
              );
          }
          // Render planet icon for notes if planets mode
          if (widget.gameMode == GameMode.planets) {
            return SizedBox(
              width: widget.gridSize == 9 ? 8 : 12,
              height: widget.gridSize == 9 ? 8 : 12,
              child: CustomPaint(painter: PlanetPainter(val), size: const Size(8, 8)),
            );
          }
          // Render cosmic icon for notes if cosmic mode
          if (widget.gameMode == GameMode.cosmic) {
            return SizedBox(
              width: widget.gridSize == 9 ? 8 : 12,
              height: widget.gridSize == 9 ? 8 : 12,
              child: CustomPaint(painter: CosmicPainter(val), size: const Size(8, 8)),
            );
          }
          // Default Number Note
          return SizedBox(
            width: widget.gridSize == 9 ? 8 : 12,
            height: widget.gridSize == 9 ? 8 : 12,
            child: Center(child: Text('$val', style: TextStyle(fontSize: widget.gridSize == 9 ? 8 : 10, color: kRetroText))),
          );
        }),
      ),
    );
  }

  /// Builds the visual element to display in a cell during hint
  /// Shows shape, color, or number based on hintElementType
  Widget _buildHintElement() {
    final value = widget.hintValue!;
    final elementType = widget.hintElementType;
    
    // For element-specific hints (shape/color/number in combined modes)
    if (elementType != null) {
      switch (elementType) {
        case ElementType.shape:
          return SizedBox(
            width: 32,
            height: 32,
            child: SudokuShape(id: value, color: kCosmicPrimary),
          );
        case ElementType.color:
          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _getColorForValue(value),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _getColorForValue(value).withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        case ElementType.number:
          return Text(
            value.toString(),
            style: TextStyle(
              color: kCosmicPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 28,
              fontFamily: 'Courier',
              shadows: [
                Shadow(
                  color: kCosmicPrimary.withOpacity(0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          );
      }
    }
    
    // Default: show based on game mode for non-element-specific hints
    switch (widget.gameMode) {
      case GameMode.shapes:
        final shapeId = widget.shapeMap[value > 0 ? value - 1 : 0];
        return SizedBox(
          width: 32,
          height: 32,
          child: SudokuShape(id: shapeId, color: kCosmicPrimary),
        );
      case GameMode.colors:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _getColorForValue(value),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: _getColorForValue(value).withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      case GameMode.planets:
        return SizedBox(
          width: 32,
          height: 32,
          child: CustomPaint(painter: PlanetPainter(value)),
        );
      case GameMode.cosmic:
        return SizedBox(
          width: 32,
          height: 32,
          child: CustomPaint(painter: CosmicPainter(value)),
        );
      default:
        // Numbers or custom mode - show number
        return Text(
          value.toString(),
          style: TextStyle(
            color: kCosmicPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 28,
            fontFamily: 'Courier',
            shadows: [
              Shadow(
                color: kCosmicPrimary.withOpacity(0.8),
                blurRadius: 8,
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSingleElement(BuildContext context, Color color) {
    final value = widget.value;
    if (widget.gameMode == GameMode.colors) {
      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getColorForValue(value),
          boxShadow: [BoxShadow(color: _getColorForValue(value).withOpacity(0.6), blurRadius: 10, spreadRadius: 1)],
          shape: BoxShape.circle,
        ),
      );
    } else if (widget.gameMode == GameMode.numbers) {
      return Text(
        value.toString(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24, fontFamily: 'Courier'),
      );
    } else if (widget.gameMode == GameMode.planets) {
       return CustomPaint(painter: PlanetPainter(value), size: const Size(32, 32));
    } else if (widget.gameMode == GameMode.cosmic) {
       return CustomPaint(painter: CosmicPainter(value), size: const Size(32, 32));
    } else if (widget.gameMode == GameMode.custom) {
      return FutureBuilder<List<String?>>(
        future: CustomImageRepository.loadCustomImages(),
        builder: (context, snapshot) {
             if (snapshot.hasData && snapshot.data![value - 1] != null) {
               return Container(
                 margin: const EdgeInsets.all(4),
                 decoration: BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: FileImage(File(snapshot.data![value - 1]!)), fit: BoxFit.cover)),
               );
             }
             return SudokuShape(id: widget.shapeId, color: color);
        },
      );
    }
    // Use the mapped shape ID
    return SudokuShape(id: widget.shapeId, color: color);
  }

  Widget _buildCombinedElement(CombinedCell cell, ElementType? selectedElement, Color defaultColor) {
    final int? shapeId = cell.shapeId;
    final int? colorId = cell.colorId;
    final int? numberId = cell.numberId;

    final Color shapeColor = colorId != null 
        ? _getColorForValue(colorId)
        : Colors.white; // Full white for shapes without color
    
    // For cells with all 3 elements (Expert/Master), use clean integrated design
    if (shapeId != null && colorId != null && numberId != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Shape fills the cell with color - similar to Medium
          Padding(
            padding: const EdgeInsets.all(4),
            child: SudokuShape(id: shapeId, color: shapeColor),
          ),
          // Number integrated into the shape without box
          Center(
            child: Text(
              numberId.toString(),
              style: TextStyle(
                color: Colors.white, // Bright white number
                fontWeight: FontWeight.w900,
                fontSize: 22,
                fontFamily: 'Courier',
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8), // Strong black shadow for contrast
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // For Medium (shape + color only)
    Widget? shapeWidget;
    if (shapeId != null) {
      shapeWidget = Padding(
        padding: const EdgeInsets.all(4),
        child: SudokuShape(id: shapeId, color: shapeColor),
      );
    } else if (colorId != null) {
       shapeWidget = Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: shapeColor,
          boxShadow: [BoxShadow(color: shapeColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)],
          shape: BoxShape.circle,
        ),
      );
    }

    Widget? numberWidget;
    if (numberId != null) {
      final Color numberColor = const Color(0xFF1A1A2E).withOpacity(0.9);
      numberWidget = Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: null,
          child: Text(
            numberId.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: numberColor,
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [if (shapeWidget != null) shapeWidget, if (numberWidget != null) numberWidget],
    );
  }
}
// End of _GameScreenState

class LevelCompletionDialog extends StatefulWidget {
  final int levelNumber;
  final int starsEarned;
  final String timeTaken;
  final VoidCallback onNextLevel;
  final VoidCallback onClose;

  const LevelCompletionDialog({
    Key? key,
    required this.levelNumber,
    required this.starsEarned,
    required this.timeTaken,
    required this.onNextLevel,
    required this.onClose,
  }) : super(key: key);

  @override
  State<LevelCompletionDialog> createState() => _LevelCompletionDialogState();
}

class _LevelCompletionDialogState extends State<LevelCompletionDialog> with TickerProviderStateMixin {
  late List<AnimationController> _starControllers;
  late List<Animation<double>> _starAnimations;

  @override
  void initState() {
    super.initState();
    _starControllers = List<AnimationController>.generate(
      3,
      (int index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    
    _starAnimations = _starControllers.map((AnimationController c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.elasticOut),
      );
    }).toList();
    
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      for (int i = 0; i < widget.starsEarned; i++) {
        Future<void>.delayed(Duration(milliseconds: i * 200), () {
          if (mounted) _starControllers[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    for (final AnimationController controller in _starControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1F3A).withOpacity(0.85),
              const Color(0xFF0A0E27).withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF4DD0E1).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4DD0E1).withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LEVEL COMPLETE!',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kCosmicPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ScaleTransition(
                          scale: _starAnimations[index],
                          child: Icon(
                            index < widget.starsEarned ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 48,
                            shadows: [
                              if (index < widget.starsEarned)
                                BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TIME: ${widget.timeTaken}',
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kCosmicText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Column(
                    children: [
                      CosmicButton(
                        text: 'NEXT LEVEL',
                        icon: Icons.skip_next,
                        onPressed: widget.onNextLevel,
                      ),
                      const SizedBox(height: 12),
                      CosmicButton(
                        text: 'MENU',
                        icon: Icons.menu,
                        type: CosmicButtonType.secondary,
                        onPressed: () {
                          widget.onClose();
                          SoundManager().playAmbientMusic();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


