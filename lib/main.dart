import '../screens/category_completion_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_logic.dart';
import 'models/game_enums.dart'; // Ensure this file exists and contains GameMode/Difficulty
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
import 'screens/splash_screen.dart';
import 'widgets/cosmic_button.dart';
import 'widgets/game_toolbar.dart';
import 'data/classic_puzzles.dart';
import 'utils/ad_manager.dart';
import 'utils/iap_manager.dart';
import 'utils/firebase_service.dart';
import 'utils/stats_repository.dart';
import 'package:provider/provider.dart';
import 'screens/premium_screen.dart';

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
  
  HintInfo({
    required this.title,
    required this.steps,
    this.currentStepIndex = 0,
    required this.targetRow,
    required this.targetCol,
    required this.value,
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
    );
  }
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
  await FirebaseService().initialize();
  await SoundManager().init();
  await SettingsController().init();
  // Don't await these to speed up launch
  AdManager.instance.initialize();
  IAPManager.instance.initialize();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => IAPManager.instance,
      child: const UnsudokuApp(),
    ),
  );
}

// Global RouteObserver to track navigation for refreshing level data
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
        // App going to background
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground
        break;
      case AppLifecycleState.detached:
        // App being destroyed
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
            title: 'Mini Sudoku',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: scheme,
            scaffoldBackgroundColor: const Color(0xFF0F0518), // Deep cosmic background
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
          navigatorObservers: [routeObserver],
          home: const SplashScreen(),
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
/// Cosmic Grid Painter: Scans the grid into existence
class _CosmicGridPainter extends CustomPainter {
  _CosmicGridPainter({
    required this.gridSize,
    required this.blockRows,
    required this.blockCols,
    required this.progress, // 0.0 to 1.0 from _startupController
  });

  final int gridSize;
  final int blockRows;
  final int blockCols;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final double width = size.width;
    final double height = size.height;
    final double cellWidth = width / gridSize;
    final double cellHeight = height / gridSize;

    // --- 1. Scanner Beam Logic ---
    // The beam moves from top-left (-20%) to bottom-right (120%)
    // Mapping progress 0.0-1.0 to a diagonal scan range
    // Using a simple vertical scan for clearer "printing" effect
    
    // Scan Line Y position: moves from 0 to height based on progress (0.0 to 0.8)
    // The last 0.2 is for settling/glow
    final double scanProgress = (progress * 1.25).clamp(0.0, 1.0); // complete scan by 0.8
    final double currentScanY = height * scanProgress;
    
    // --- 2. Grid Lines (Reveal Behind Scanner) ---
    
    final Paint linePaint = Paint()
      ..color = kCosmicPrimary.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final Paint blockPaint = Paint()
      ..color = kCosmicPrimary.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw lines only if they are "above" the scan line
    
    // Vertical Lines (drawn partially down to currentScanY)
    for (int i = 1; i < gridSize; i++) {
      final double x = i * cellWidth;
      final bool isBlockLine = (i % blockCols == 0);
      final Paint p = isBlockLine ? blockPaint : linePaint;
      
      // Draw vertical line up to the scan position
      if (currentScanY > 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, currentScanY), p);
      }
    }
    
    // Horizontal Lines (drawn if their Y is less than currentScanY)
    for (int i = 1; i < gridSize; i++) {
        final double y = i * cellHeight;
        final bool isBlockLine = (i % blockRows == 0);
        final Paint p = isBlockLine ? blockPaint : linePaint;
        
        // If the scanner has passed this line, draw it fully
        if (currentScanY >= y) {
             canvas.drawLine(Offset(0, y), Offset(width, y), p);
        } else {
             // Optional: Draw a faint "blueprint" line ahead of time? No, stick to scan.
        }
    }
    
    // --- 3. Scanner Beam Visuals ---
    if (scanProgress < 1.0 && scanProgress > 0.0) {
        final Paint scannerPaint = Paint()
          ..shader = LinearGradient(
              colors: [
                Colors.transparent, 
                Colors.cyanAccent.withOpacity(0.8), 
                Colors.cyanAccent, 
                Colors.cyanAccent.withOpacity(0.8),
                Colors.transparent
              ],
              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
          ).createShader(Rect.fromLTWH(0, currentScanY - 10, width, 20))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        // Draw the main scan laser line
        canvas.drawLine(Offset(0, currentScanY), Offset(width, currentScanY), scannerPaint);
        
        // Add a glow under the scanner
        final Paint glowPaint = Paint()
           ..color = Colors.cyanAccent.withOpacity(0.2)
           ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawRect(Rect.fromLTWH(0, currentScanY - 20, width, 40), glowPaint);
    }
    
    // --- 4. Final Flash / Lock-in (at end) ---
    if (progress > 0.9) {
       // A quick white flash over the grid lines to signify "locked"
       // 0.9 -> 1.0 (opacity 1.0 -> 0.0)
       double flashOpacity = (1.0 - progress) * 10; 
       flashOpacity = flashOpacity.clamp(0.0, 0.5); // Max 0.5 opacity
       
       if (flashOpacity > 0) {
         final Paint flashPaint = Paint()
            ..color = Colors.white.withOpacity(flashOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0; // Thicker lines for flash
            
         // Flash all block lines
         for (int i = 1; i < gridSize; i++) {
             if (i % blockCols == 0) canvas.drawLine(Offset(i * cellWidth, 0), Offset(i * cellWidth, height), flashPaint);
             if (i % blockRows == 0) canvas.drawLine(Offset(0, i * cellHeight), Offset(width, i * cellHeight), flashPaint);
         }
         canvas.drawRect(Rect.fromLTWH(0, 0, width, height), flashPaint);
       }
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicGridPainter oldDelegate) {
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
    // Draw Block Wave (Flip Glow Effect)
    if (triggerBlockRow != null && triggerBlockCol != null && blockRows != null && blockCols != null) {
       // Use trigger cell as center if available, otherwise block center
       double centerX, centerY;
       
       if (triggerRow != null && triggerCol != null) {
         centerX = (triggerCol! + 0.5) * cellWidth;
         centerY = (triggerRow! + 0.5) * cellHeight;
       } else {
         centerX = (triggerBlockCol! + blockCols! / 2) * cellWidth;
         centerY = (triggerBlockRow! + blockRows! / 2) * cellHeight;
       }
       
       // Calculate max radius needed to cover the block from the trigger point
       // This ensures the wave covers the whole block 
       double maxRadius = math.max(blockRows!, blockCols!) * cellWidth * 1.5;
       
       // Flip Glow Animation
       // 1. Initial Flash (fast, bright)
       // 2. Expanding Glow (slower, colorful)
       
       // Expanding radius
       double currentRadius = maxRadius * progress;
       
       // Opacity fades out at the end
       double opacity = 1.0 - progress;
       opacity = opacity.clamp(0.0, 1.0);
       
       // Draw expanding glow circle
       final Paint glowPaint = Paint()
         ..shader = RadialGradient(
           colors: [
             Colors.white.withOpacity(0.8 * opacity),
             Colors.purpleAccent.withOpacity(0.4 * opacity),
             Colors.purple.withOpacity(0.0),
           ],
           stops: const [0.0, 0.5, 1.0],
         ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: currentRadius))
         ..style = PaintingStyle.fill;
         
       canvas.drawCircle(Offset(centerX, centerY), currentRadius, glowPaint);
       
       // Draw a crisp expanding ring
       final Paint ringPaint = Paint()
         ..color = Colors.white.withOpacity(0.6 * opacity)
         ..style = PaintingStyle.stroke
         ..strokeWidth = 4 * (1.0 - progress); // Thins out
         
       canvas.drawCircle(Offset(centerX, centerY), currentRadius * 0.8, ringPaint);
       
       // Highlight the block itself slightly to show completion
       final Paint blockTint = Paint()
         ..color = Colors.purpleAccent.withOpacity(0.1 * opacity)
         ..style = PaintingStyle.fill;
         
       final Rect blockRect = Rect.fromLTWH(
         triggerBlockCol! * cellWidth, 
         triggerBlockRow! * cellHeight, 
         blockCols! * cellWidth, 
         blockRows! * cellHeight
       );
       canvas.drawRect(blockRect, blockTint);
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
              HomeScreen(
                onToSettings: () => _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
                onToStats: () => _pageController.animateToPage(
                  2,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
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
  final VoidCallback? onToSettings;
  final VoidCallback? onToStats;

  const HomeScreen({
    super.key,
    this.onToSettings,
    this.onToStats,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, RouteAware {
  // Hardcoded for Mini Sudoku Refactor

  final GameMode _mode = GameMode.numbers;

  int? _easyLevel;
  int? _mediumLevel;
  int? _hardLevel;
  int? _expertLevel;
  int? _masterLevel;
  bool _expertUnlocked = false;
  bool _masterUnlocked = false;
  bool _isLoading = true;

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
    
    _loadLevelsAndUnlockStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to RouteObserver
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh levels when returning from game
    _loadLevelsAndUnlockStatus();
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
                    SoundManager().playGameStart();
                    if (SettingsController().hapticsEnabled) HapticFeedback.mediumImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen.resume(savedGame: savedGame))).then((_) => _loadLevelsAndUnlockStatus());
                  },
                ),
                const SizedBox(height: 12),
                CosmicButton(
                  text: 'RESTART',
                  icon: Icons.refresh,
                  type: CosmicButtonType.secondary,
                  onPressed: () async {
                     Navigator.pop(context);
                      await CurrentGameRepository.clearGame(mode, diff);
                      if (context.mounted) {
                        SoundManager().playGameStart();
                        if (SettingsController().hapticsEnabled) HapticFeedback.mediumImpact();
                        // Start new game at the current unlocked level (not the saved game level)
                        final int currentLevel = await ProgressRepository.getLastUnlockedLevel(mode, diff);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(levelNumber: currentLevel, mode: mode, difficulty: diff))).then((_) => _loadLevelsAndUnlockStatus());
                      }
                  },
                ),
              ],
            ),
          ],
        ),
      );
    } else if (context.mounted) {
      SoundManager().playGameStart();
      if (SettingsController().hapticsEnabled) HapticFeedback.mediumImpact();
      _startNewGame(context, mode, diff);
    }
  }

  void _startNewGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final int level = await ProgressRepository.getLastUnlockedLevel(mode, diff);
    
    if (!mounted) return;
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level, mode: mode, difficulty: diff))).then((_) => _loadLevelsAndUnlockStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
    const String sizeKey = 'mini';
    const String gridLabel = '6×6';
    
    return Scaffold(
      body: Stack(
        children: [
          const StarryBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // App Title
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _pulseAnimation.value,
                            child: Text(
                              'MINI SUDOKU',
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
                      const SizedBox(height: 8),
                      Text(
                        'COSMIC EDITION',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kCosmicPrimary,
                          letterSpacing: 6,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Explicit Navigation Buttons directly on implementation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNavButton(
                            icon: Icons.settings,
                            label: 'SETTINGS',
                            onTap: widget.onToSettings ?? () {},
                          ),
                          const SizedBox(width: 24),
                          _buildNavButton(
                            icon: Icons.bar_chart,
                            label: 'STATISTICS',
                            onTap: widget.onToStats ?? () {},
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Difficulty List
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            StaggeredSlideFade(
                              key: ValueKey('sudoku_easy_${sizeKey}_${_easyLevel ?? 0}'),
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
                              key: ValueKey('sudoku_medium_${sizeKey}_${_mediumLevel ?? 0}'),
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
                              key: ValueKey('sudoku_hard_${sizeKey}_${_hardLevel ?? 0}'),
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
                              key: ValueKey('sudoku_expert_${sizeKey}_${_expertLevel ?? 0}'),
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
                              key: ValueKey('sudoku_master_${sizeKey}_${_masterLevel ?? 0}'),
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
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
  
  Widget _buildNavButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        SoundManager().playClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: kCosmicLocked.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kCosmicPrimary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kCosmicText, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kCosmicText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({super.key, required this.title, required this.subtitle, required this.color, required this.onTap});
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
    final String displayTitle = widget.title; // Removed 'Lv{n}' as requested by user
    
    final effectiveColor = widget.isLocked ? kCosmicLocked : kCosmicPrimary;
    final opacity = widget.isLocked ? 0.5 : 1.0;
    
    return ShakeAnimation(
      shouldShake: _shouldShake,
      child: AnimatedButton(
        onTap: widget.isLocked ? () {
          SoundManager().playLocked();
          if (SettingsController().hapticsEnabled) HapticFeedback.mediumImpact();
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
          widget.onTap();
        } : () {
          SoundManager().playClick();
          if (SettingsController().hapticsEnabled) HapticFeedback.lightImpact();
          widget.onTap();
        },
        enabled: true,
        child: Container(
          decoration: BoxDecoration(
            // Outer glow/shadow
            boxShadow: [
              BoxShadow(
                color: effectiveColor.withOpacity(widget.isLocked ? 0.05 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 1. Blur Effect (Glass)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                              effectiveColor.withOpacity(widget.isLocked ? 0.05 : 0.2),
                              effectiveColor.withOpacity(widget.isLocked ? 0.02 : 0.1),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                  shadows: widget.isLocked ? null : [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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

              // 2. Inner Shadows & Highlights (Custom Painter)
              Positioned.fill(
                child: CustomPaint(
                  painter: GlassBevelPainter(
                    borderRadius: BorderRadius.circular(20),
                    borderColor: effectiveColor.withOpacity(widget.isLocked ? 0.2 : 0.5),
                    isPressed: false, // Difficulty card doesn't track press state visually in the same way via painter yet
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... CustomImageSetupScreen ...



class ProgressRepository {
  static Future<LevelStatus> getLevelStatus(int level, GameMode mode, Difficulty difficulty, {SudokuSize? size}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = '${_prefix(mode, difficulty, size: size)}$level';
    final String? status = prefs.getString(key);
    
    // First check if this level is completed
    if (status == 'completed') return LevelStatus.completed;
    
    // Level 1 is always unlocked (never locked) if not completed
    if (level == 1) return LevelStatus.unlocked;
    
    // For other levels, check if previous level is completed
    final String prevKey = '${_prefix(mode, difficulty, size: size)}${level - 1}';
    if (prefs.getString(prevKey) == 'completed') return LevelStatus.unlocked;
    
    return LevelStatus.locked;
  }

  static Future<int> getLastUnlockedLevel(GameMode mode, Difficulty difficulty, {SudokuSize? size}) async {
    for (int i = 1; i <= StatsRepository.levelsPerDifficulty; i++) {
      final status = await getLevelStatus(i, mode, difficulty, size: size);
      if (status == LevelStatus.locked) {
        return math.max(1, i - 1);
      }
      if (status == LevelStatus.unlocked) {
        return i;
      }
    }
    return StatsRepository.levelsPerDifficulty;
  }

  static Future<void> completeLevel(int level, GameMode mode, Difficulty difficulty, int stars, int timeSeconds, int mistakes, {SudokuSize? size}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = '${_prefix(mode, difficulty, size: size)}$level';
    await prefs.setString(key, 'completed');
    await prefs.setInt('${key}_stars', stars);
    await prefs.setInt('${key}_time', timeSeconds);
    await prefs.setInt('${key}_mistakes', mistakes);
  }

  /// Generate storage key prefix. Uses original format for compatibility with existing data.
  static String _prefix(GameMode mode, Difficulty difficulty, {SudokuSize? size}) {
    if (size == SudokuSize.mini) {
      return '${difficulty.name}_${mode.name}_mini_level_';
    }
    return '${difficulty.name}_${mode.name}_level_';
  }
  
  static Future<int> getCompletedLevelsCount(GameMode mode, Difficulty difficulty, {SudokuSize? size}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (int i = 1; i <= StatsRepository.levelsPerDifficulty; i++) {
      final String key = '${_prefix(mode, difficulty, size: size)}$i';
      if (prefs.getString(key) == 'completed') count++;
    }
    return count;
  }
  
  static Future<bool> isDifficultyUnlocked(GameMode mode, Difficulty difficulty, {SudokuSize? size}) async {
    switch (difficulty) {
      case Difficulty.easy:
      case Difficulty.medium:
      case Difficulty.hard:
      case Difficulty.expert:
        return true; // Always unlocked
      case Difficulty.master:
        final expertCount = await getCompletedLevelsCount(mode, Difficulty.expert, size: size);
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


  GameStateData({
    required this.mode,
    required this.difficulty,
    required this.levelNumber,
    required this.board,
    required this.notes,
    required this.mistakes,
    required this.elapsedSeconds,
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
  });

  final int levelNumber;
  final GameMode mode;
  final Difficulty difficulty;
  final GameStateData? initialState;

  factory GameScreen.resume({required GameStateData savedGame}) {
    return GameScreen(
      levelNumber: savedGame.levelNumber,
      mode: savedGame.mode,
      difficulty: savedGame.difficulty,
      initialState: savedGame,
    );
  }

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late List<List<int>> _board;
  late List<List<bool>> _isEditable;
  late List<List<Set<int>>> _notes;
  late SudokuPuzzle? _sudokuPuzzle;
  
  int? _selectedRow;
  int? _selectedCol;
  final Set<int> _animatedCells = {};
  final Set<int> _errorCells = {};
  
  late Stopwatch _stopwatch;
  late int _elapsed;
  late AnimationController _rotationController;
    // 4. Game Screen State Updates
    late AnimationController _startupController;
    late AnimationController _completionController;
  late AnimationController _groupCompletionController;
  late AnimationController _gridAnimationController;
  late AnimationController _numbersFadeController;
  late AnimationController _winAnimationController;
  late AnimationController _lineCompletionController;
  // late AnimationController _glitterController; // Removed
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
  bool _showTimer = true;
  
  bool _pencilMode = false;
  int _mistakes = 0;
  late int _maxMistakes;
  final List<GameStateData> _history = [];
  
  // Hint tracking
  int _hintsRemaining = 0;
  int _maxHints = 0;

  HintInfo? _activeHint;

  // Debug toolbar state
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGridSize();
    _initializeHintCounter();

    // Initialize Max Mistakes based on difficulty
    switch (widget.difficulty) {
      case Difficulty.easy:
      case Difficulty.medium:
        _maxMistakes = 3;
        break;
      case Difficulty.hard:
      case Difficulty.expert:
        _maxMistakes = 2;
        break;
      case Difficulty.master:
        _maxMistakes = 1;
        break;
    }

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

    // Cosmic Startup Master Controller
    _startupController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1650), // ANIMATION: 1.65 SECONDS
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



    _initializeGame().catchError((error) {
      debugPrint("Error initializing game: $error");
    }).then((_) {
      // Check if the game is already completed AFTER board is initialized
      if (mounted && _isBoardSolved()) {
        // Game is already completed (resumed from finished state).
        // Skip win animation and go directly to next level.
        if (widget.levelNumber >= 50) {
          // Max level reached, just exit to menu
          Navigator.pop(context);
        } else {
          // Go to next level
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
            levelNumber: widget.levelNumber + 1, 
            mode: widget.mode,
            difficulty: widget.difficulty,
          )));
        }
      }
    });
    
    
    // Start STARTUP SEQUENCE (Animation: 1.65s, Timer start: 2.0s)
    if (_elapsed == 0) { // Only animate on fresh start
        _startupController.forward().whenComplete(() {
            // Animation done at 1.65s, wait until 2.0s to start timer
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted && !_stopwatch.isRunning) _stopwatch.start();
            });
        });
    } else {
        // Resume immediate
        _startupController.value = 1.0; 
        _stopwatch.start();
    }
    
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
    // Hardcoded for Mini Sudoku (6x6)
    _gridSize = 6;
    _blockRows = 2;
    _blockCols = 3;
  }

  void _initializeHintCounter() {
    _maxHints = 3;
    _hintsRemaining = _maxHints;
  }

  Future<void> _initializeGame() async {
    await _generateLevelLogic();

    if (!mounted) return;
    setState(() {
      if (widget.initialState != null) {
        _board = List.generate(_gridSize, (r) => List.from(widget.initialState!.board[r]));
        _notes = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => Set<int>.from(widget.initialState!.notes[r][c])));
        _mistakes = widget.initialState!.mistakes;
      } else {
      _notes = List.generate(_gridSize, (r) => List.generate(_gridSize, (c) => {}));
      _mistakes = 0;
    }
    
    _isLoading = false;
    });
  }

  Future<void> _generateLevelLogic() async {
     await Future.microtask(() {}); // Ensure async behavior consistency

     // For Numbers mode (Classic Sudoku): use pre-generated puzzles from ClassicPuzzles
     // Hardcode size to mini (6x6)
     _sudokuPuzzle = ClassicPuzzles.getPuzzle(SudokuSize.mini, widget.difficulty, widget.levelNumber);
     
     // Initialize board with prefilled cells from the generated puzzle
     if (widget.initialState == null) {
       _board = List.generate(_gridSize, (i) => List.from(_sudokuPuzzle!.initialBoard[i]));
     }
     
     _isEditable = List.generate(
       _gridSize,
       (r) => List.generate(_gridSize, (c) => _sudokuPuzzle!.initialBoard[r][c] == 0),
     );

  }

  Future<void> _saveGameState() async {
    // Prevent saving if game is already won/completed
    if (!mounted || _isBoardSolved()) return;

    // Skip save for Hard, Expert, Master modes (arcade style)
    // Save allowed for all modes now (Resume Game feature)
    // if (widget.difficulty == Difficulty.hard || widget.difficulty == Difficulty.expert || widget.difficulty == Difficulty.master) return;
    
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveGameState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveGameState();
    _rotationController.dispose();
    _completionController.dispose();
    _groupCompletionController.dispose();
    _gridAnimationController.dispose();
    _numbersFadeController.dispose();
    _winAnimationController.dispose();
    _lineCompletionController.dispose();

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
      _selectedRow = row;
      _selectedCol = col;
      _highlightedNumber = null; // Clear highlight on new selection
    });
  }

  void _pushHistory() {
    _history.add(GameStateData(
      mode: widget.mode,
      difficulty: widget.difficulty,
      levelNumber: widget.levelNumber,
      board: List.generate(_gridSize, (i) => List.from(_board[i])),
      notes: List.generate(_gridSize, (i) => List.generate(_gridSize, (j) => Set.from(_notes[i][j]))),
      mistakes: _mistakes,
      elapsedSeconds: _elapsed,
    ));
    if (_history.length > 20) _history.removeAt(0); 
  }

  
  void _handleMistake() {
    setState(() {
      _mistakes++;
      if (_mistakes >= _maxMistakes) _onGameOver();
    });
  }

  void _handleInput(int value) {
    if (_selectedRow == null || _selectedCol == null) return;
    if (!_isEditable[_selectedRow!][_selectedCol!]) return;

    // Pencil Mode
    if (_pencilMode) {
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

    // Standard input
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
        if (SettingsController().hapticsEnabled) HapticFeedback.lightImpact();
        _board[_selectedRow!][_selectedCol!] = value;
        _handleMistake();
        _errorCells.add(_selectedRow! * _gridSize + _selectedCol!);
      }
    });
    
    if (isCorrect) {
      if (SettingsController().hapticsEnabled) HapticFeedback.lightImpact();
      SoundManager().playSuccessSound();
    }
    
    _saveGameState();
  }

  int _getCorrectValue(int r, int c) {
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
    bool rowCorrect = true;
    for(int i=0; i<_gridSize; i++) {
      if(_board[r][i] == 0) rowFull = false;
      // FIX: Only trigger animation if row is CORRECT
      if(rowFull && _board[r][i] != _getCorrectValue(r, i)) rowCorrect = false;
    }
    
    // Check Column
    bool colFull = true;
    bool colCorrect = true;
    for(int i=0; i<_gridSize; i++) {
      if(_board[i][c] == 0) colFull = false;
      // FIX: Only trigger animation if col is CORRECT
      if(colFull && _board[i][c] != _getCorrectValue(i, c)) colCorrect = false;
    }

    // Check Block
    bool blockFull = true;
    bool blockCorrect = true;
    int bRowStart = (r ~/ _blockRows) * _blockRows;
    int bColStart = (c ~/ _blockCols) * _blockCols;
    for(int i=0; i<_blockRows; i++) {
      for(int j=0; j<_blockCols; j++) {
        if(_board[bRowStart + i][bColStart + j] == 0) blockFull = false;
        // FIX: Only trigger animation if block is CORRECT
        if(blockFull && _board[bRowStart + i][bColStart + j] != _getCorrectValue(bRowStart + i, bColStart + j)) blockCorrect = false;
      }
    }

    // Only set the state variables if the group is FULL and CORRECT
    if ((rowFull && rowCorrect) || (colFull && colCorrect) || (blockFull && blockCorrect)) {
      setState(() {
        if (rowFull && rowCorrect) _completedRow = r;
        if (colFull && colCorrect) _completedCol = c;
        if (blockFull && blockCorrect) {
          _triggerBlockRow = bRowStart;
          _triggerBlockCol = bColStart;
        }
        _triggerRow = r;
        _triggerCol = c;
        _lineCompletionController.forward(from: 0);
      });
      SoundManager().playCompletionSound();
      if (SettingsController().hapticsEnabled) HapticFeedback.mediumImpact();
    }
    
    // Pulse animation also conditional on correctness (or just fullness? user said "animations trigger... check correctness")
    // Assuming pulse should also be for sweet success only
    if ((rowFull && rowCorrect) || (colFull && colCorrect) || (blockFull && blockCorrect)) {
      _groupCompletionController.forward(from: 0);
    }
  }

  bool _isBoardSolved() {
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
            
            if (widget.levelNumber >= StatsRepository.levelsPerDifficulty) {
              // Game Finished!
              Navigator.pop(context); // Go back to menu
              
              // Show Category Completion Screen
              Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryCompletionScreen(
                difficulty: widget.difficulty,
                onReturnToMenu: () {
                   Navigator.pop(context); // Pop completion screen
                },
              )));
            } else {
              // Navigate to next level without ambient music
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
                levelNumber: widget.levelNumber + 1, 
                mode: widget.mode,
                difficulty: widget.difficulty,
              )));
              // Music for next level is handled by the page transition/initState logic if needed,
              // or we can force it here. Previous code said "Navigate to next level without ambient music"
              // But we want GAME START music.
              SoundManager().playGameStart();
            }
          },
          onClose: () {
            Navigator.pop(context); // pop dialog
            Navigator.pop(context); // pop GameScreen
            // Refresh level data when returning to menu - handled by didChangeDependencies
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
    GlassModal.show(
      context: context,
      barrierDismissible: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'GAME OVER',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kRetroError, // Red
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Too many mistakes!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          // Actions: Second Chance
          CosmicButton(
              text: 'SECOND CHANCE',
              icon: Icons.replay,
              type: CosmicButtonType.secondary,
              onPressed: () {
                // Revive logic
                void revive() {
                    Navigator.pop(context);
                    setState(() {
                            _mistakes = _maxMistakes - 1; // Give 1 life back
                        _stopwatch.start();
                    });
                    if (SettingsController().hapticsEnabled) HapticFeedback.mediumImpact();
                }

                if (IAPManager.instance.isPremium) {
                    revive();
                } else {
                    AdManager.instance.showRewardedAd(revive);
                }
              },
              height: 56,
              isFullWidth: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CosmicButton(
                  text: 'MENU',
                  type: CosmicButtonType.secondary,
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go to home
                  },
                  height: 56,
                  isFullWidth: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CosmicButton(
                  text: 'RESTART',
                  type: CosmicButtonType.primary,
                  onPressed: () {
                    Navigator.pop(context);
                    final int safeLevel = widget.levelNumber.clamp(1, 50);
                      if (SettingsController().hapticsEnabled) HapticFeedback.mediumImpact();
                      
                      void doRestart() {
                         SoundManager().playGameStart();
                         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
                            levelNumber: safeLevel, 
                            mode: widget.mode,
                            difficulty: widget.difficulty,
                         )));
                      }

                      if (IAPManager.instance.isPremium) {
                        doRestart();
                      } else {
                        AdManager.instance.showInterstitialAd(onAdClosed: doRestart);
                      }
                  },
                  height: 56,
                  isFullWidth: true,
                ),
              ),
            ],
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
      // _mistakes = prev.mistakes; // Don't revert mistakes count on undo
      _errorCells.clear();
      
      // Re-validate the board to identify any persisting errors
      for (int r = 0; r < _gridSize; r++) {
         for (int c = 0; c < _gridSize; c++) {
            if (_board[r][c] != 0 && _board[r][c] != _getCorrectValue(r, c)) {
               _errorCells.add(r * _gridSize + c);
            }
         }
      }
      
      // Restore combined mode notes if present
    });
  }

  void _erase() {
    if (_selectedRow == null || _selectedCol == null) return;
    if (!_isEditable[_selectedRow!][_selectedCol!]) return;
    _pushHistory();
    setState(() {
      _board[_selectedRow!][_selectedCol!] = 0;
      _notes[_selectedRow!][_selectedCol!].clear();
      _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!);
    });
  }

  void _hint() async {
    if (_selectedRow == null || _selectedCol == null) {
      if (mounted) {
        showCosmicSnackbar(context, "Please select a cell first to get a hint.");
      }
      return;
    }
    
    final r = _selectedRow!;
    if (_board[r][_selectedCol!] != 0) return;

    // Check Premium status for unlimited hints
    if (IAPManager.instance.isPremium) {
      _stopwatch.stop();
      _showStandardHint(r, _selectedCol!);
      return;
    }
    
    // Check hint availability
    if (_hintsRemaining > 0) {
      _stopwatch.stop();
      _showStandardHint(r, _selectedCol!);
    } else {
      // Show Ad Dialog
      final bool? watchAd = await GlassModal.show<bool>(
        context: context,
        title: "NEED A HINT?",
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "You're out of hints!",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            CosmicButton(
              text: "WATCH AD (+1 HINT)",
              icon: Icons.play_arrow,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            CosmicButton(
              text: "GET UNLIMITED HINTS",
              icon: Icons.star, 
              type: CosmicButtonType.secondary,
              onPressed: () {
                 Navigator.pop(context, false);
                 Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumScreen()));
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );

      if (watchAd == true) {
        AdManager.instance.showRewardedAd(() {
          setState(() {
            _hintsRemaining++;
          });
          if (mounted) {
             _stopwatch.stop();
             _showStandardHint(r, _selectedCol!);
          }
        });
      }
    }
  }

  // Simplified terminology helpers
  String _getElementNameSingular() => 'number';
  String _getElementNamePlural() => 'numbers';
  
  String _getHintTypeName() => 'Last Digit';

  String _getRuleDescription() {
    final elementName = _getElementNamePlural();
    return 'Each $elementName can only appear once in each row, column, or box. As shown, the $elementName that appear in the highlighted area cannot appear in this cell.';
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
      ),
    ];
  }

  void _activateHint(String title, String desc, int r, int c, int val, Set<int> highlights) {
    setState(() {
      _selectCell(r, c);
      _activeHint = HintInfo(
        title: title,
        steps: [HintStep(description: desc, highlights: highlights)],
        targetRow: r,
        targetCol: c,
        value: val,
      );
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

  /// Mock: Fill a row INCORRECTLY (one wrong number) to test animation suppression
  void _mockFillRowIncorrect() async {
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
        List<int> emptyCols = [];
        for (int c = 0; c < _gridSize; c++) {
          if (_board[r][c] == 0) emptyCols.add(c);
        }
        
        for (int i = 0; i < emptyCols.length; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (!mounted) return;
          
          int col = emptyCols[i];
          // Intentionally put WRONG value for the last empty cell
          int value = (i == emptyCols.length - 1) 
              ? (_getCorrectValue(r, col) % 9) + 1 // Guarantee wrong value (1-9)
              : _getCorrectValue(r, col);
          
          setState(() {
             _selectedRow = r;
             _selectedCol = col;
             _board[r][col] = value;
             _checkGroupCompletion(r, col); // Should NOT trigger animation
          });
        }
        return;
      }
    }
  }

  /// Mock: Simulate Wrong Input in Easy Mode
  void _mockEasyInputWrong() {
    if (widget.difficulty != Difficulty.easy) {
       showCosmicSnackbar(context, "Switch to Easy mode to test this!");
       return;
    }
    // Find an empty cell
    for (int r=0; r<_gridSize; r++) {
      for (int c=0; c<_gridSize; c++) {
        if (_board[r][c] == 0) {
           setState(() {
             _selectedRow = r;
             _selectedCol = c;
           });
           
           // Try to input a WRONG value
           int correct = _getCorrectValue(r, c);
           // Fix: Use _gridSize instead of 9 to support 6x6 grids
           int wrong = (correct % _gridSize) + 1;
           
           // Call handle input directly
           _handleInput(wrong);
           
           // Verify result (visual check only for mock)
           showCosmicSnackbar(context, "Tried inputting $wrong (Correct: $correct). Board value: ${_board[r][c]}");
           return;
        }
      }
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

  Future<void> _showPauseMenu() {
    _stopwatch.stop();
    return GlassModal.show(
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
               final int safeLevel = widget.levelNumber.clamp(1, 50);
               Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
                 levelNumber: safeLevel, mode: widget.mode, difficulty: widget.difficulty,
               )));
            },
          ),
          const SizedBox(height: 16),
          CosmicButton(
            text: 'EXIT GAME',
            icon: Icons.exit_to_app,
            type: CosmicButtonType.destructive,
            onPressed: () {
               Navigator.pop(context); // Close dialog
               Navigator.pop(context); // Close screen
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ).then((_) {
       if (mounted) _stopwatch.start();
    });
  }

  

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _showPauseMenu();
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
              icon: Icon(_showTimer ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showTimer = !_showTimer),
            ),
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: _showPauseMenu,
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
          // Loading indicator
          if (_isLoading)
            Container(
              color: kCosmicBackground,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: kCosmicPrimary),
                    SizedBox(height: 16),
                    Text(
                      "Generating Reality...",
                      style: TextStyle(fontFamily: 'Orbitron', color: kCosmicPrimary),
                    )
                  ],
                ),
              ),
            ),
          
          // Accelerated starry background during win animation
          if (!_isLoading) AnimatedBuilder(
            animation: _winAnimationController,
            builder: (context, child) {
              return StarryBackground(
                speedMultiplier: _winAnimationController.value > 0 ? 4.0 : 1.0,
              );
            },
          ),
          if (!_isLoading) SafeArea(
            child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Visibility(
                      visible: _showTimer,
                      maintainSize: true, 
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text(_formatTime(_elapsed), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildBoard(context),
                    ),
                  ),
                  _buildTools(context),
 
                  if (_activeHint == null) _buildInputBar(context),
                  if (_activeHint != null) Container(height: 120),
                ],
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
                    _handleInput(_activeHint!.value);
                    
                    setState(() {
                      _activeHint = null;
                      // _activeHintElementType = null; // FIELD REMOVED
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
                    width: 2.0, // Same as interior block lines
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
                      _startupController, // Added startup controller
                    ]),
                  builder: (context, child) {

                    return Column(
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
                          
                          
                          // Check if we should show hint number for this cell
                          bool hintShowNumber = false;
                          int? hintValue;
                          if (_activeHint != null && 
                              row == _activeHint!.targetRow && 
                              col == _activeHint!.targetCol &&
                              _activeHint!.currentStep.showNumber) {
                            hintShowNumber = true;
                            // _activeHint!.currentStep.elementValue is removed, use value
                            hintValue = _activeHint!.value;
                          }
                          
                          // Calculate flip delay based on distance from center
                          double dist = math.sqrt(math.pow(row - centerRow, 2) + math.pow(col - centerCol, 2));
                          double normalizedDist = dist / maxDist; // 0.0 to 1.0
                          
                          // Animation logic:
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
                          
                          Widget cellWidget = _SudokuCell(
                                key: ValueKey('cell_${row}_${col}_${value}_${isSelected}'), // Force rebuild on selection change
                                value: value,
                                notes: _notes[row][col],
                                row: row,
                                col: col,
                                gridSize: _gridSize,
                                isEditable: isEditable,
                                isSelected: isSelected,
                                isInvalid: isInvalid,
                                highlight: highlight,
                                isAnimated: isAnimated,
                                difficulty: widget.difficulty,
                                onTap: () => _selectCell(row, col),
                                hintShowNumber: hintShowNumber,
                                hintValue: hintValue,
                                flipValue: flipValue,
                          );

                          // Grid lines are now drawn ONLY by _GridDrawingPainter to avoid double lines
                          return Expanded(child: cellWidget);
                        }),
                      ),
                    );

                  }),
                );
              },
            ),
            // Grid lines - drawn ON TOP of cells so they're always visible
            IgnorePointer(
            child: AnimatedBuilder(
                animation: _startupController,
                builder: (context, child) {
                return CustomPaint(
                    size: Size(boardLength - 4, boardLength - 4),
                    painter: _CosmicGridPainter(
                    gridSize: _gridSize,
                    blockRows: _blockRows,
                    blockCols: _blockCols,
                    progress: _startupController.value,
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
      onInput: (int value) {
        _handleInput(value);
      },
      isValueCompleted: _isValueCompleted,
    );
  }

  void _showStandardHint(int r, int c) {
    if (_activeHint != null) return; // Already showing hint
    
    // Decrease hints remaining
    setState(() {
      _hintsRemaining--;
    });
    
    // Try to find a smart hint
    final smartHint = _tryHintForCell(r, c);
    
    setState(() {
      if (smartHint != null) {
          _activeHint = HintInfo(
            title: smartHint.hintType,
            steps: smartHint.steps,
            targetRow: smartHint.targetRow,
            targetCol: smartHint.targetCol,
            value: smartHint.correctVal,
          );
      } else {
          // Fallback to simple number show if no smart hint found
          final correctVal = _getCorrectValue(r, c);
          final step = HintStep(
            description: "The value here is $correctVal",
            showNumber: true,
            highlights: {r * _gridSize + c},
          );
           
          _activeHint = HintInfo(
            title: "Hint",
            steps: [step],
            targetRow: r,
            targetCol: c,
            value: correctVal,
          );
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final currentStep = info.currentStep;
    final isLastStep = info.isLastStep;
    final isFirstStep = info.isFirstStep;
    
    // Build visual element if this step should show it (just the number for Mini Sudoku)
    final Widget? elementWidget = currentStep.showNumber 
        ? Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kRetroSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${info.value}',
                style: const TextStyle(
                  color: kCosmicPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
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
    required this.row,
    required this.col,
    required this.gridSize,
    required this.isSelected,
    required this.isEditable,
    required this.isInvalid,
    required this.highlight,
    required this.isAnimated,
    required this.difficulty,
    required this.onTap,
    this.hintShowNumber = false,
    this.hintValue,
    this.flipValue = 0.0,
    this.startupProgress = 1.0,
  });

  final int value;
  final Set<int> notes;
  final int row;
  final int col;
  final int gridSize;
  final bool isSelected;
  final bool isEditable;
  final bool isInvalid;
  final CellHighlight highlight;
  final bool isAnimated;
  final Difficulty difficulty;
  final VoidCallback onTap;
  final bool hintShowNumber;
  final int? hintValue;
  final double flipValue;
  final double startupProgress;

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
    // --- Cosmic Materialization Logic ---
    double opacity = 1.0;
    double scale = 1.0;

    if (widget.startupProgress < 1.0) {
      final double scanProgress = (widget.startupProgress * 1.25).clamp(0.0, 1.0);
      final double cellRelY = widget.row / widget.gridSize; 
      
      if (scanProgress > cellRelY) {
         double cellReveal = (scanProgress - cellRelY) * 5.0; 
         cellReveal = cellReveal.clamp(0.0, 1.0);
         opacity = cellReveal;
         scale = 0.8 + (0.2 * cellReveal);
      } else {
         opacity = 0.0;
         scale = 0.0;
      }
    }

    // ALL cells start with transparent background so grid lines show through
    Color baseColor = Colors.transparent;
    Color contentColor = kRetroText;

    // 1. Text styling only for prefilled vs editable (no opaque backgrounds)
    if (widget.isInvalid) {
      contentColor = kRetroError; // Red text/content for mistakes
    } else if (!widget.isEditable) {
       // Prefilled: brighter text, NO background so grid lines visible
       // Prefilled: brighter text, NO background so grid lines visible
       contentColor = Colors.white; // Brighter for prefilled
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
    // Use unified logic for both invalid and valid cells to ensure proper selection behavior
    
    Widget cellContent;
    
    Widget buildContent(BuildContext context, Color? flashColor) {
      Color currentBaseColor = flashColor != null 
          ? Color.alphaBlend(flashColor, decoration.color ?? Colors.transparent)
          : (decoration.color ?? Colors.transparent);
          
      return _buildCellContainer(
        decoration.copyWith(color: currentBaseColor),
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
      );
    }

    if (widget.isInvalid) {
      cellContent = GestureDetector(
        onTap: widget.isEditable ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _errorController,
          builder: (context, child) {
            Color? flashColor = _errorController.value > 0 
                ? Colors.red.withOpacity(0.5 * _errorController.value) 
                : null;
            return buildContent(context, flashColor);
          },
        ),
      );
    } else {
      cellContent = GestureDetector(
        onTap: widget.onTap,
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
    
    // Apply Startup Animation
    if (opacity < 1.0 || scale < 1.0) {
       cellContent = Opacity(
          opacity: opacity,
          child: Transform.scale(
             scale: scale,
             child: cellContent,
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
    final double cellHeight = MediaQuery.of(context).size.width / widget.gridSize;

    // Simplified content builder
    Widget content;
    
    // Hint overrides everything if valid
    if (widget.hintShowNumber && widget.hintValue != null) {
      if (widget.hintValue != null) {
        content = _buildHintElement();
      } else {
        content = const SizedBox.shrink();
      }
    }
    // Value display
    else if (widget.value > 0) {
      // Standard Number
      content = Text(
        '${widget.value}',
        style: TextStyle(
          fontSize: widget.gridSize == 6 ? 28 : (cellHeight * 0.55),
          fontWeight: widget.isEditable ? FontWeight.w500 : FontWeight.bold,
          color: contentColor,
          fontFamily: 'Rajdhani',
        ),
      );
    }
    // Notes display
    else if (widget.notes.isNotEmpty) {
      content = _buildNotes();
    }
    // Empty
    else {
      content = const SizedBox.shrink();
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
        ],
      ),
    );
  }
  
  Widget _buildNotes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = constraints.maxWidth;
        // 2x3 grid for 6x6 notes
        final int cols = 3;
        final int rows = 2;
        final double cellW = size / cols;
        final double cellH = size / rows;
        
        return Stack(
          children: widget.notes.map((n) {
            // Map 1-6 to grid positions (0-5)
            // 1 2 3
            // 4 5 6
            final int index = n - 1;
            final int r = index ~/ cols;
            final int c = index % cols;
            
            return Positioned(
              left: c * cellW,
              top: r * cellH,
              width: cellW,
              height: cellH,
              child: Center(
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: size * 0.25,
                    color: kRetroText.withOpacity(0.7),
                    height: 1.0,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHintElement() {
    return Center(
      child: Text(
        (widget.hintValue ?? '').toString(),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: kRetroHint,
          shadows: [
            Shadow(
              color: kCosmicPrimary.withOpacity(0.8),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleElement(BuildContext context, Color color) {
    if (widget.value <= 0) return const SizedBox.shrink();
    
    return Text(
      widget.value.toString(),
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24, fontFamily: 'Courier'),
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
              const Color(0xFF1A1F3A).withOpacity(0.60), 
              const Color(0xFF0A0E27).withOpacity(0.80),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF4DD0E1).withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -5,
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


