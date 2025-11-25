import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_logic.dart';
import 'shapes.dart';

enum GameMode { shapes, colors, numbers, custom, planets, cosmic }

enum Difficulty { easy, medium, hard, veryHard }

enum CellHighlight { none, selected, related, matching, block, hintTarget, hintRelated }

class CellPosition {
  final int row;
  final int col;
  const CellPosition({required this.row, required this.col});
}

class HintInfo {
  final String title;
  final String description;
  final int targetRow;
  final int targetCol;
  final int value;
  final Set<int> highlights;
  HintInfo(this.title, this.description, this.targetRow, this.targetCol, this.value, this.highlights);
}

// Simple Vector3 class for axis-angle rotation
class Vector3 {
  final double x;
  final double y;
  final double z;
  Vector3(this.x, this.y, this.z);
}

// Helper function to create rotation matrix from axis and angle (Rodrigues rotation formula)
Matrix4 _rotationAxis(Vector3 axis, double angle) {
  // Normalize axis
  final double length = math.sqrt(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z);
  final double nx = axis.x / length;
  final double ny = axis.y / length;
  final double nz = axis.z / length;
  
  final double c = math.cos(angle);
  final double s = math.sin(angle);
  final double t = 1 - c;
  
  // Rodrigues rotation formula
  return Matrix4(
    t * nx * nx + c,        t * nx * ny - s * nz,  t * nx * nz + s * ny,  0,
    t * nx * ny + s * nz,   t * ny * ny + c,       t * ny * nz - s * nx,  0,
    t * nx * nz - s * ny,   t * ny * nz + s * nx,  t * nz * nz + c,       0,
    0,                      0,                      0,                      1,
  );
}

class FallingObject {
  String id;
  int col;
  double y; // 0.0 to 1.0 (relative to screen height, 0.0 = top, 1.0 = bottom)
  int shapeId;
  int colorId;
  int numberId;
  double rotationAngle; // Current rotation angle around axis
  // Rotation axis as normalized Vector3 (mostly vertical: y≈1.0, x/z small)
  double axisX;
  double axisY;
  double axisZ;
  double rotationSpeed; // Rotation speed multiplier (0.8-1.5)
  double rotationPhase; // Phase offset for unique starting rotation (0-2π)
  FallingObject({
    required this.id, 
    required this.col, 
    required this.y, 
    required this.shapeId,
    required this.colorId,
    required this.numberId,
    this.rotationAngle = 0.0,
    required this.axisX,
    required this.axisY,
    required this.axisZ,
    required this.rotationSpeed,
    required this.rotationPhase,
  });
}

// Retro Pixel Palette
const Color kRetroBackground = Color(0xFF1A1A2E); // Deep Navy
const Color kRetroSurface = Color(0xFF16213E); // Dark Blue
const Color kRetroAccent = Color(0xFF0F3460); // Slate
const Color kRetroHighlight = Color(0xFFE94560); // Red/Pink
const Color kRetroText = Color(0xFFEEEEEE); // White-ish
const Color kRetroError = Color(0xFFFF0055); // Bright Red
const Color kRetroHint = Color(0xFF00FF55); // Green for Hint

Color _getColorForValue(int value) {
  switch (value) {
    case 1: return const Color(0xFFFF0055); // Red
    case 2: return const Color(0xFF00FF55); // Green
    case 3: return const Color(0xFF5500FF); // Blue
    case 4: return const Color(0xFFFFFF00); // Yellow
    case 5: return const Color(0xFF00FFFF); // Cyan
    case 6: return const Color(0xFFFF9900); // Orange
    case 7: return const Color(0xFF9D00FF); // Purple
    case 8: return const Color(0xFFFF00CC); // Pink
    case 9: return const Color(0xFF00FFCC); // Teal
    default: return Colors.grey;
  }
}

/// Returns high-luminance pastel colors for holographic sci-fi UI
/// Designed for dark blue background (0xFF1A1A2E) to prevent eye strain
Color getCosmicColor(int index) {
  switch (index) {
    case 1: return const Color(0xFFFF80AB); // Pink
    case 2: return const Color(0xFF80DEEA); // Cyan
    case 3: return const Color(0xFFFFD54F); // Gold
    case 4: return const Color(0xFFFFAB91); // Orange
    case 5: return const Color(0xFFB9F6CA); // Mint
    case 6: return const Color(0xFFD1C4E9); // Lavender
    case 7: return const Color(0xFF64B5F6); // Blue
    case 8: return const Color(0xFFE0E0E0); // Silver
    case 9: return const Color(0xFFEF9A9A); // Soft Red
    default: return const Color(0xFFE0E0E0); // Default to Silver
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UnsudokuApp());
}

class UnsudokuApp extends StatelessWidget {
  const UnsudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: kRetroHighlight,
      brightness: Brightness.dark,
      surface: kRetroBackground,
      onSurface: kRetroText,
      primary: kRetroHighlight,
      secondary: kRetroAccent,
    );

    return MaterialApp(
      title: 'Unsudoku',
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: kRetroBackground,
        useMaterial3: true,
        fontFamily: 'Courier',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: kRetroText),
          titleTextStyle: TextStyle(
            color: kRetroText,
            fontSize: 24,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: kRetroText,
          displayColor: kRetroText,
          fontFamily: 'Courier',
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kRetroHighlight,
            foregroundColor: kRetroText,
            shape: const BeveledRectangleBorder(),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kRetroHighlight,
            side: const BorderSide(color: kRetroHighlight, width: 2),
            shape: const BeveledRectangleBorder(),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kRetroHighlight,
            shape: const BeveledRectangleBorder(),
          ),
        ),
        cardTheme: const CardThemeData(
          color: kRetroSurface,
          shape: BeveledRectangleBorder(),
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: kRetroSurface,
          shape: BeveledRectangleBorder(
            side: BorderSide(color: kRetroHighlight, width: 2),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class StarryBackground extends StatefulWidget {
  const StarryBackground({super.key});

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _StarPainter(_controller.value),
          size: Size.infinite,
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const StarryBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'UNSUDOKU',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: kRetroText,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 64),
                    _MenuButton(
                      title: 'SUDOKU',
                      subtitle: 'Classic Numbers',
                      color: Colors.cyanAccent,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SudokuSectionScreen())),
                    ),
                    const SizedBox(height: 24),
                    _MenuButton(
                      title: 'CRAZY SUDOKU',
                      subtitle: 'Shapes, Colors & More',
                      color: Colors.purpleAccent,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrazySudokuSectionScreen())),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kRetroSurface,
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: kRetroText.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class SudokuSectionScreen extends StatelessWidget {
  const SudokuSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SUDOKU')),
      body: Stack(
        children: [
          const StarryBackground(),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _DifficultyCard(
                title: 'EASY',
                description: '6x6 GRID',
                icon: Icons.looks_one,
                color: Colors.greenAccent,
                onTap: () => _startOrContinueGame(context, GameMode.numbers, Difficulty.easy),
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                title: 'MEDIUM',
                description: '9x9 GRID',
                icon: Icons.looks_two,
                color: Colors.orangeAccent,
                onTap: () => _startOrContinueGame(context, GameMode.numbers, Difficulty.medium),
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                title: 'HARD',
                description: '9x9 GRID (ADVANCED)',
                icon: Icons.looks_3,
                color: Colors.redAccent,
                onTap: () => _startOrContinueGame(context, GameMode.numbers, Difficulty.hard),
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                title: 'VERY HARD',
                description: 'CONTACT DEVELOPER',
                icon: Icons.warning_amber_rounded,
                color: Colors.purpleAccent,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const _MailToDeveloperDialog(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startOrContinueGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final savedGame = await CurrentGameRepository.loadGame(mode, diff);
    if (savedGame != null && context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('RESUME GAME?'),
          content: Text('Time: ${_formatTime(savedGame.elapsedSeconds)}'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await CurrentGameRepository.clearGame(mode, diff);
                if (context.mounted) _startNewGame(context, mode, diff);
              },
              child: const Text('NEW GAME'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen.resume(savedGame: savedGame)));
              },
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      );
    } else if (context.mounted) {
      _startNewGame(context, mode, diff);
    }
  }

  void _startNewGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final int level = await ProgressRepository.getLastUnlockedLevel(mode, diff);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level, mode: mode, difficulty: diff)));
    }
  }
}

class CrazySudokuSectionScreen extends StatelessWidget {
  const CrazySudokuSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRAZY SUDOKU')),
      body: Stack(
        children: [
          const StarryBackground(),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _DifficultyCard(
                title: 'EASY',
                description: '9x9 - Shapes / Planets / Cosmic',
                icon: Icons.category,
                color: Colors.greenAccent,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => SimpleDialog(
                      title: const Text('CHOOSE TYPE', style: TextStyle(color: kRetroHighlight)),
                      backgroundColor: kRetroSurface,
                      children: [
                        SimpleDialogOption(
                          onPressed: () { Navigator.pop(context); _startOrContinueGame(context, GameMode.shapes, Difficulty.easy); },
                          child: const Padding(padding: EdgeInsets.all(8.0), child: Text('SHAPES (9x9)', style: TextStyle(color: kRetroText, fontSize: 18))),
                        ),
                        SimpleDialogOption(
                          onPressed: () { Navigator.pop(context); _startOrContinueGame(context, GameMode.planets, Difficulty.easy); },
                          child: const Padding(padding: EdgeInsets.all(8.0), child: Text('PLANETS (9x9)', style: TextStyle(color: kRetroText, fontSize: 18))),
                        ),
                        SimpleDialogOption(
                          onPressed: () { Navigator.pop(context); _startOrContinueGame(context, GameMode.cosmic, Difficulty.easy); },
                          child: const Padding(padding: EdgeInsets.all(8.0), child: Text('COSMIC (9x9)', style: TextStyle(color: kRetroText, fontSize: 18))),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                title: 'MEDIUM',
                description: '9x9 - Combined Elements',
                icon: Icons.star_half,
                color: Colors.orangeAccent,
                onTap: () => _startOrContinueGame(context, GameMode.shapes, Difficulty.medium),
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                title: 'HARD',
                description: '9x9 - Falling Objects',
                icon: Icons.arrow_downward,
                color: Colors.redAccent,
                onTap: () => _startOrContinueGame(context, GameMode.shapes, Difficulty.hard),
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                title: 'CUSTOM',
                description: '9x9 - Your Images',
                icon: Icons.add_photo_alternate,
                color: Colors.purpleAccent,
                onTap: () async {
                  final images = await CustomImageRepository.loadCustomImages();
                  final bool allSet = images.every((path) => path != null);
                  if (context.mounted) {
                    if (allSet) {
                       _startOrContinueGame(context, GameMode.custom, Difficulty.medium);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomImageSetupScreen()));
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startOrContinueGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final savedGame = await CurrentGameRepository.loadGame(mode, diff);
    if (savedGame != null && context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('RESUME GAME?'),
          content: Text('Time: ${_formatTime(savedGame.elapsedSeconds)}'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await CurrentGameRepository.clearGame(mode, diff);
                if (context.mounted) _startNewGame(context, mode, diff);
              },
              child: const Text('NEW GAME'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen.resume(savedGame: savedGame)));
              },
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      );
    } else if (context.mounted) {
      _startNewGame(context, mode, diff);
    }
  }

  void _startNewGame(BuildContext context, GameMode mode, Difficulty diff) async {
    final int level = await ProgressRepository.getLastUnlockedLevel(mode, diff);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level, mode: mode, difficulty: diff)));
    }
  }
}

String _formatTime(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kRetroSurface,
        border: Border.all(color: color, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: kRetroText.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
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

class CustomImageRepository {
  static const String _keyPrefix = 'custom_img_';
  static Future<void> saveCustomImage(int index, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$index', path);
  }
  static Future<List<String?>> loadCustomImages() async {
    final prefs = await SharedPreferences.getInstance();
    return List.generate(9, (i) => prefs.getString('$_keyPrefix$i'));
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

  static Future<void> completeLevel(int level, GameMode mode, Difficulty difficulty, int stars, int timeSeconds) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = '${_prefix(mode, difficulty)}$level';
    await prefs.setString(key, 'completed');
    await prefs.setInt('${key}_stars', stars);
    await prefs.setInt('${key}_time', timeSeconds);
  }

  static String _prefix(GameMode mode, Difficulty difficulty) {
    return '${difficulty.name}_${mode.name}_level_';
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<List<int>> _board;
  late List<List<bool>> _isEditable;
  late List<List<Set<int>>> _notes;
  // Medium mode separate notes
  late List<List<Set<int>>> _shapeNotes;
  late List<List<Set<int>>> _colorNotes;
  late List<List<Set<int>>> _numberNotes;
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
  
  // Hard Mode Falling
  late Ticker _fallingTicker;
  final List<FallingObject> _fallingObjects = [];
  double _lastSpawnTime = 0;
  
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
  
  late List<int> _shapeMap;
  HintInfo? _activeHint;

  @override
  void initState() {
    super.initState();
    _initializeGridSize();
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
    
    if (widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers) {
      _fallingTicker = createTicker(_onFallingTick);
      _fallingTicker.start();
    }

    final allShapes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    if (_gridSize == 6) {
      allShapes.shuffle(math.Random(widget.levelNumber));
      _shapeMap = allShapes.take(6).toList();
    } else {
      _shapeMap = allShapes;
    }

    _initializeGame();
    
    _stopwatch.start();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_stopwatch.isRunning) {
        setState(() {
          _elapsed = (widget.initialState?.elapsedSeconds ?? 0) + _stopwatch.elapsed.inSeconds;
        });
        if (widget.difficulty != Difficulty.hard) _saveGameState();
      }
    });
  }
  
  void _onFallingTick(Duration elapsed) {
    final double t = elapsed.inMilliseconds / 1000.0;
    final double dt = t - _lastSpawnTime;
    
    // Move objects and rotate them with unique patterns for each object
    setState(() {
      for (var obj in _fallingObjects) {
        obj.y += 0.002; // Fall speed
        
        // Calculate rotation angle for this object using its unique speed and phase
        // Base rotation from controller (0 to 2π, seamless loop)
        final double baseRotation = _rotationController.value * 2 * math.pi;
        // Apply unique speed and phase for this object
        obj.rotationAngle = (baseRotation * obj.rotationSpeed + obj.rotationPhase);
        // No modulo needed - Transform handles wrapping, and controller loops seamlessly
      }
      // Remove objects that have fallen past the board (y > 1.0 means past board bottom)
      _fallingObjects.removeWhere((obj) => obj.y > 1.0);
    });
    
    // Spawn logic - space out spawns per column
    if (dt > 2.0) { // Spawn every 2s
      _lastSpawnTime = t;
      _spawnFallingObject();
    }
  }
  
  void _spawnFallingObject() {
    final rnd = math.Random();
    int col = rnd.nextInt(_gridSize);
    
    // Get needed objects for this column
    List<CombinedCell> needed = [];
    for(int r=0; r<_gridSize; r++) {
      if (_board[r][col] == 0 && _combinedPuzzle != null) {
        needed.add(_combinedPuzzle!.solution[r][col]);
      }
    }
    
    int shapeId, colorId, numberId;
    
    // 60% chance to spawn correct object, 40% random
    if (needed.isNotEmpty && rnd.nextDouble() < 0.6) {
      final correct = needed[rnd.nextInt(needed.length)];
      shapeId = correct.shapeId!;
      colorId = correct.colorId!;
      numberId = correct.numberId!;
    } else {
      // Random object
      shapeId = rnd.nextInt(_gridSize) + 1;
      colorId = rnd.nextInt(_gridSize) + 1;
      numberId = rnd.nextInt(_gridSize) + 1;
    }
    
    setState(() {
      // Generate unique rotation axis (normalized Vector3, mostly vertical)
      // X and Z components are small (0.1-0.3), Y is large (0.9-1.0) to keep face visible
      final double axisX = (rnd.nextDouble() - 0.5) * 0.4; // -0.2 to 0.2
      final double axisZ = (rnd.nextDouble() - 0.5) * 0.4; // -0.2 to 0.2
      final double axisY = 0.9 + (rnd.nextDouble() * 0.1); // 0.9 to 1.0 (mostly vertical)
      
      // Normalize the axis vector
      final double length = math.sqrt(axisX * axisX + axisY * axisY + axisZ * axisZ);
      final double normalizedX = axisX / length;
      final double normalizedY = axisY / length;
      final double normalizedZ = axisZ / length;
      
      // Rotation speed: 0.8x to 1.5x (as per requirement)
      final double speed = 0.8 + (rnd.nextDouble() * 0.7);
      // Phase offset: 0 to 2π for unique starting rotation
      final double phase = rnd.nextDouble() * 2 * math.pi;
      
      _fallingObjects.add(FallingObject(
        id: DateTime.now().toString(),
        col: col,
        y: 0.0, // Start from top of screen (0.0 = top, 1.0 = bottom)
        shapeId: shapeId,
        colorId: colorId,
        numberId: numberId,
        rotationAngle: 0.0, // Will be calculated using rotation controller
        axisX: normalizedX,
        axisY: normalizedY,
        axisZ: normalizedZ,
        rotationSpeed: speed,
        rotationPhase: phase,
      ));
    });
  }

  void _initializeGridSize() {
    if (widget.mode == GameMode.numbers) {
      _gridSize = widget.difficulty == Difficulty.easy ? 6 : 9;
    } else {
      // Crazy Mode
      _gridSize = 9;
    }
    if (_gridSize == 6) {
      _blockRows = 2; _blockCols = 3;
    } else {
      _blockRows = 3; _blockCols = 3;
    }
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
  }

  void _generateLevelLogic() {
    if ((widget.difficulty == Difficulty.medium || widget.difficulty == Difficulty.hard) && 
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
            // For hard mode, use fixed cells as prefilled (like other modes)
            if (widget.difficulty == Difficulty.hard) {
               if (widget.initialState == null) {
                  _board[r][c] = isFixed ? 1 : 0; // Prefill fixed cells
               }
               _isEditable[r][c] = !isFixed; // Only non-fixed cells are editable
            } else {
               if (widget.initialState == null) {
                  _board[r][c] = isFixed ? 1 : 0;
               }
               _isEditable[r][c] = !isFixed;
            }
         }
       }
       _sudokuPuzzle = null;
    } else {
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
    // Skip save for Hard mode (arcade style)
    if (widget.difficulty == Difficulty.hard) return;
    
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
    if (widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers) {
      _fallingTicker.dispose();
    }
    super.dispose();
  }

  /// Find a falling object that is currently over the specified cell
  FallingObject? _findFallingObjectOverCell(int row, int col) {
    final BuildContext? boardContext = _boardKey.currentContext;
    if (boardContext == null) return null;
    
    final RenderBox? renderBox = boardContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    
    // Get board's global position
    final Offset boardPosition = renderBox.localToGlobal(Offset.zero);
    final double boardTop = boardPosition.dy;
    final double boardHeight = renderBox.size.height;
    final double cellHeight = boardHeight / _gridSize;
    final double cellWidth = renderBox.size.width / _gridSize;
    
    // Calculate cell's vertical bounds
    final double cellTop = boardTop + (row * cellHeight);
    final double cellBottom = cellTop + cellHeight;
    
    // Find falling object in this column that is within the cell's vertical bounds
    final double screenHeight = MediaQuery.of(boardContext).size.height;
    for (var obj in _fallingObjects) {
      if (obj.col != col) continue; // Must be in the same column
      
      // Convert obj.y (0.0-1.0) to screen coordinates - obj.y is the TOP of the object
      final double objTopY = obj.y * screenHeight;
      // Calculate the CENTER of the object (object is cellWidth x cellWidth)
      final double objCenterY = objTopY + (cellWidth / 2);
      
      // Check if object's center is within the cell's bounds (smaller tolerance for precision)
      if (objCenterY >= cellTop && objCenterY <= cellBottom) {
        return obj;
      }
    }
    
    return null;
  }

  void _selectCell(int row, int col) {
    // For hard mode, check if there's a falling object over this cell
    if (widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers) {
      final FallingObject? objOverCell = _findFallingObjectOverCell(row, col);
      if (objOverCell != null) {
        // Place the falling object in the cell
        _handleFallingObjectPlacement(objOverCell, row, col);
        return;
      }
    }
    
    setState(() {
      // Reset draft if changing cells
      if (_selectedRow != row || _selectedCol != col) {
        _draftCell = null;
      }
      _selectedRow = row;
      _selectedCol = col;
      if (_activeHint != null) _activeHint = null;
    });
  }
  
  /// Handle placing a falling object into a cell
  void _handleFallingObjectPlacement(FallingObject obj, int row, int col) {
    if (!_isEditable[row][col] || _board[row][col] != 0) {
      _handleMistake();
      setState(() {
        _fallingObjects.remove(obj);
      });
      return;
    }
    
    // Check if the full object matches (shape, color, number)
    final correctCell = _combinedPuzzle!.solution[row][col];
    if (obj.shapeId == correctCell.shapeId && 
        obj.colorId == correctCell.colorId && 
        obj.numberId == correctCell.numberId) {
      setState(() {
        _board[row][col] = 1; // Mark filled
        _combinedPuzzle!.initialBoard[row][col] = _combinedPuzzle!.solution[row][col];
        
        _fallingObjects.remove(obj);
        _animatedCells.add(row * _gridSize + col);
        
        if (_isBoardSolved()) _onLevelComplete();
      });
    } else {
      _handleMistake();
      setState(() {
        _fallingObjects.remove(obj);
      });
    }
  }

  void _pushHistory() {
    // No history/undo for Hard mode
    if (widget.difficulty == Difficulty.hard) return;
    
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

  void _handleFallingTap(FallingObject obj) {
    // Calculate which row the object is over using board's actual position
    final BuildContext? boardContext = _boardKey.currentContext;
    if (boardContext == null) return;
    
    final RenderBox? renderBox = boardContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    // Get board's global position
    final Offset boardPosition = renderBox.localToGlobal(Offset.zero);
    final double boardTop = boardPosition.dy;
    final double boardHeight = renderBox.size.height;
    final double cellHeight = boardHeight / _gridSize;
    final double cellWidth = renderBox.size.width / _gridSize;
    
    // Convert obj.y (0.0-1.0 screen height) to screen coordinates - obj.y is the TOP of the object
    final double screenHeight = MediaQuery.of(boardContext).size.height;
    final double objTopY = obj.y * screenHeight;
    // Calculate the CENTER of the object (object is cellWidth x cellWidth)
    final double objCenterY = objTopY + (cellWidth / 2);
    
    // Calculate which row the object's center is over
    final double relativeY = objCenterY - boardTop;
    if (relativeY < 0 || relativeY >= boardHeight) return; // Out of bounds
    
    final int rowEstimate = (relativeY / cellHeight).floor();
    if (rowEstimate < 0 || rowEstimate >= _gridSize) return; // Out of bounds
    
    // Use the placement handler
    _handleFallingObjectPlacement(obj, rowEstimate, obj.col);
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

    // Hard mode handles input via falling objects
    if (widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers) return;

    _pushHistory();

    // Medium (Combined) Logic
    if (widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers) {
       if (type == null) return;
       
       // Pencil Mode for Medium - type is determined by which input row was clicked
       if (_pencilMode) {
         setState(() {
           switch(type) {
             case ElementType.shape:
               final notes = _shapeNotes[_selectedRow!][_selectedCol!];
               if (notes.contains(value)) {
                 notes.clear(); // Toggle off
               } else {
                 notes.clear(); // Only one allowed
                 notes.add(value);
               }
               break;
             case ElementType.color:
               final notes = _colorNotes[_selectedRow!][_selectedCol!];
               if (notes.contains(value)) {
                 notes.clear(); // Toggle off
               } else {
                 notes.clear(); // Only one allowed
                 notes.add(value);
               }
               break;
             case ElementType.number:
               final notes = _numberNotes[_selectedRow!][_selectedCol!];
               if (notes.contains(value)) {
                 notes.clear(); // Toggle off
               } else {
                 notes.clear(); // Only one allowed
                 notes.add(value);
               }
               break;
           }
         });
         return;
       }
       
       // Normal selection mode
       _pushHistory();
       setState(() {
         if (_draftCell == null) _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
         
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
         
         // Check if all three are selected (third selection triggers validation)
         if (_draftCell!.shapeId != null && _draftCell!.colorId != null && _draftCell!.numberId != null) {
            // Validate - this is the final selection
            final sol = _combinedPuzzle!.solution[_selectedRow!][_selectedCol!];
            if (_draftCell!.shapeId == sol.shapeId && _draftCell!.colorId == sol.colorId && _draftCell!.numberId == sol.numberId) {
               // Correct
               _combinedPuzzle!.initialBoard[_selectedRow!][_selectedCol!] = sol;
               _board[_selectedRow!][_selectedCol!] = 1; // Mark solved
               _animatedCells.add(_selectedRow! * _gridSize + _selectedCol!);
               _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false); // Reset draft
               
               if (_isBoardSolved()) _onLevelComplete();
            } else {
               // Wrong - show error
               _handleMistake();
               _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false); // Reset draft
               _errorCells.add(_selectedRow! * _gridSize + _selectedCol!);
               // Clear error after animation
               Future.delayed(const Duration(milliseconds: 1000), () {
                 if (mounted) setState(() => _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!));
               });
            }
         }
       });
       return;
    }

    // Pencil Mode (for non-Medium modes)
    if (_pencilMode) {
      setState(() {
        final cellNotes = _notes[_selectedRow!][_selectedCol!];
        if (cellNotes.contains(value)) cellNotes.remove(value);
        else cellNotes.add(value);
      });
      return;
    }

    // Standard Mode
    int correctValue = _getCorrectValue(_selectedRow!, _selectedCol!);
    bool isCorrect = (value == correctValue);

    setState(() {
      if (isCorrect) {
        _board[_selectedRow!][_selectedCol!] = value;
        _notes[_selectedRow!][_selectedCol!].clear(); 
        _clearNotesFor(value, _selectedRow!, _selectedCol!);
        
        _animatedCells.add(_selectedRow! * _gridSize + _selectedCol!);
        _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!);
        _activeHint = null;
        
        if (_isGroupComplete(_selectedRow!, _selectedCol!)) {
          _groupCompletionController.forward(from: 0);
        }

        if (_isBoardSolved()) {
          _onLevelComplete();
        }
      } else {
        _board[_selectedRow!][_selectedCol!] = value;
        _handleMistake();
        _errorCells.add(_selectedRow! * _gridSize + _selectedCol!);
      }
    });
    _saveGameState();
  }

  int _getCorrectValue(int r, int c) {
    if (_combinedPuzzle != null) {
        final s = _combinedPuzzle!.solution;
        return s[r][c].shapeId ?? 0;
    }
    return _sudokuPuzzle!.solution[r][c];
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

  bool _isGroupComplete(int r, int c) {
    bool rowFull = true;
    for(int i=0; i<_gridSize; i++) if(_board[r][i] == 0) rowFull = false;
    if (rowFull) return true;
    
    bool colFull = true;
    for(int i=0; i<_gridSize; i++) if(_board[i][c] == 0) colFull = false;
    if (colFull) return true;
    return false;
  }

  bool _isBoardSolved() {
    for(int r=0; r<_gridSize; r++) {
      for(int c=0; c<_gridSize; c++) {
        if (_board[r][c] == 0) return false; 
        if (_board[r][c] != 0 && widget.difficulty != Difficulty.medium && widget.difficulty != Difficulty.hard && _board[r][c] != _getCorrectValue(r, c)) return false;
      }
    }
    return true;
  }

  void _onLevelComplete() {
    _stopwatch.stop();
    _completionController.forward();
    CurrentGameRepository.clearGame(widget.mode, widget.difficulty);
    ProgressRepository.completeLevel(widget.levelNumber, widget.mode, widget.difficulty, 3, _elapsed);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
         levelNumber: widget.levelNumber + 1, 
         mode: widget.mode,
         difficulty: widget.difficulty
      )));
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
    });
  }

  void _erase() {
    if (_selectedRow == null || _selectedCol == null) return;
    if (!_isEditable[_selectedRow!][_selectedCol!]) return;
    _pushHistory();
    setState(() {
      _board[_selectedRow!][_selectedCol!] = 0;
      if (widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers) {
         _draftCell = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
         _combinedPuzzle!.initialBoard[_selectedRow!][_selectedCol!] = CombinedCell(shapeId: null, colorId: null, numberId: null, isFixed: false);
         // Clear all notes
         _shapeNotes[_selectedRow!][_selectedCol!].clear();
         _colorNotes[_selectedRow!][_selectedCol!].clear();
         _numberNotes[_selectedRow!][_selectedCol!].clear();
      } else {
         _notes[_selectedRow!][_selectedCol!].clear();
      }
      _errorCells.remove(_selectedRow! * _gridSize + _selectedCol!);
    });
  }

  void _hint() {
    if (_selectedRow != null && _selectedCol != null && _board[_selectedRow!][_selectedCol!] == 0) {
      final r = _selectedRow!;
      final c = _selectedCol!;
      
      final correctVal = _getCorrectValue(r, c);
      final bRow = (r ~/ _blockRows) * _blockRows;
      final bCol = (c ~/ _blockCols) * _blockCols;
      
      bool hiddenSingle = true;
      Set<int> highlights = {};
      
      for(int i=0; i<_blockRows; i++) {
        for(int j=0; j<_blockCols; j++) {
           int nr = bRow + i;
           int nc = bCol + j;
           if (nr == r && nc == c) continue;
           if (_board[nr][nc] != 0) continue;
           
           bool rowBlocked = false;
           for(int k=0; k<_gridSize; k++) if (_board[nr][k] == correctVal) rowBlocked = true;
           bool colBlocked = false;
           for(int k=0; k<_gridSize; k++) if (_board[k][nc] == correctVal) colBlocked = true;
           
           if (!rowBlocked && !colBlocked) {
              hiddenSingle = false;
           } else {
              if (rowBlocked) highlights.addAll(_getRowIndices(nr));
              if (colBlocked) highlights.addAll(_getColIndices(nc));
           }
        }
      }
      
      if (hiddenSingle) {
         _activateHint("Cross-Hatching", "This is the only valid cell for this number in this block.", r, c, correctVal, highlights);
         return;
      }
      
      int zerosRow = 0;
      for(int k=0; k<_gridSize; k++) if(_board[r][k] == 0) zerosRow++;
      if (zerosRow == 1) {
         _activateHint("Last Digit (Row)", "Only one missing number in this row.", r, c, correctVal, _getRowIndices(r));
         return;
      }
      
      int zerosCol = 0;
      for(int k=0; k<_gridSize; k++) if(_board[k][c] == 0) zerosCol++;
      if (zerosCol == 1) {
         _activateHint("Last Digit (Column)", "Only one missing number in this column.", r, c, correctVal, _getColIndices(c));
         return;
      }
    }

    for (int r = 0; r < _gridSize; r++) {
      int zeros = 0; int lastCol = -1;
      for (int c = 0; c < _gridSize; c++) if (_board[r][c] == 0) { zeros++; lastCol = c; }
      if (zeros == 1) {
        _activateHint("Last Digit (Row)", "The only missing number in this row.", r, lastCol, _getCorrectValue(r, lastCol), _getRowIndices(r));
        return;
      }
    }
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_board[r][c] == 0) {
          _activateHint("Reveal Cell", "Revealing this cell.", r, c, _getCorrectValue(r, c), const {});
          return;
        }
      }
    }
  }

  Set<int> _getRowIndices(int r) {
    return List.generate(_gridSize, (c) => r * _gridSize + c).toSet();
  }
  Set<int> _getColIndices(int c) {
    return List.generate(_gridSize, (r) => r * _gridSize + c).toSet();
  }

  void _activateHint(String title, String desc, int r, int c, int val, Set<int> highlights) {
    setState(() {
      _selectCell(r, c);
      _activeHint = HintInfo(title, desc, r, c, val, highlights);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isHard = widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers;
    
    return WillPopScope(
      onWillPop: () async {
        _stopwatch.stop();
        showDialog(
          context: context,
          builder: (_) => _PauseRestartDialog(
            onRestart: () {
               Navigator.pop(context);
               CurrentGameRepository.clearGame(widget.mode, widget.difficulty);
               Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
                 levelNumber: widget.levelNumber, mode: widget.mode, difficulty: widget.difficulty
               )));
            },
            onExitGame: () {
               Navigator.pop(context);
               Navigator.pop(context);
            },
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
            const StarryBackground(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_formatTime(_elapsed), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  if (isHard) const Spacer(),
                  Expanded(
                    flex: isHard ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Stack(
                        children: [
                          if (isHard) _buildSpaceship(context),
                          _buildBoard(context),
                        ],
                      ),
                    ),
                  ),
                  if (isHard) const Spacer(),
                  if (!isHard) ...[
                     _buildTools(context),
                     if (_activeHint == null) _buildInputBar(context),
                     if (_activeHint != null) Container(height: 120),
                  ]
                ],
              ),
            ),
            // Falling objects overlay - covers entire Scaffold body
            if (isHard)
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) => _buildFallingObjects(),
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
                    _handleInput(_activeHint!.value);
                    setState(() => _activeHint = null);
                  },
                  onClose: () => setState(() => _activeHint = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSpaceship(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double boardLength = math.min(constraints.maxWidth, constraints.maxHeight);
      final double spaceshipWidth = boardLength * 0.8;
      final double spaceshipHeight = 80;
      final double spaceshipTop = -spaceshipHeight - 20; // Position above board
      
      return Positioned(
        left: (constraints.maxWidth - spaceshipWidth) / 2,
        top: spaceshipTop,
        width: spaceshipWidth,
        height: spaceshipHeight,
        child: CustomPaint(
          painter: SpaceshipPainter(),
          size: Size(spaceshipWidth, spaceshipHeight),
        ),
      );
    });
  }

  Widget _buildFallingCombinedElement(CombinedCell cell, Color defaultColor) {
    final int? shapeId = cell.shapeId;
    final int? colorId = cell.colorId;
    final int? numberId = cell.numberId;

    // Hard mode uses cosmic style
    final bool useCosmicStyle = widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers;
    
    final Color shapeColor = colorId != null 
        ? (useCosmicStyle ? getCosmicColor(colorId) : _getColorForValue(colorId))
        : defaultColor.withOpacity(0.2);
    
    Widget? shapeWidget;
    if (shapeId != null) {
      shapeWidget = Padding(
        padding: const EdgeInsets.all(4),
        child: useCosmicStyle
            ? CosmicGlyph(shapeId: shapeId, color: shapeColor)
            : SudokuShape(id: shapeId, color: shapeColor), 
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
      // For cosmic style, use semi-transparent black or deep blue for contrast
      final Color numberColor = useCosmicStyle 
          ? const Color(0xFF1A1A2E).withOpacity(0.8) // Deep blue for contrast
          : Colors.white;
      numberWidget = Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: useCosmicStyle 
              ? BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            numberId.toString(),
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: numberColor,
              shadows: useCosmicStyle 
                  ? [] 
                  : [const Shadow(blurRadius: 2, color: Colors.black)],
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

  /// Calculate the X position for a falling object to align with a specific column
  /// Uses the board's GlobalKey to get exact position and width
  double? _calculateColumnX(int colIndex, double objectSize) {
    final RenderBox? renderBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    
    // Get the board's global position and size
    final Offset boardPosition = renderBox.localToGlobal(Offset.zero);
    final double boardStartX = boardPosition.dx;
    final double boardWidth = renderBox.size.width;
    
    // Formula: boardStartX + (colIndex * cellWidth) + (cellWidth / 2) - (objectSize / 2)
    // This centers the object in the column
    final double cellWidth = boardWidth / _gridSize;
    final double columnCenterX = boardStartX + (colIndex * cellWidth) + (cellWidth / 2);
    final double objectX = columnCenterX - (objectSize / 2);
    
    return objectX;
  }

  Widget _buildFallingObjects() {
    // Cover entire Scaffold body - use MediaQuery for full screen coordinates
    return Builder(builder: (context) {
      final Size screenSize = MediaQuery.of(context).size;
      final double screenHeight = screenSize.height;
      
      // Get board dimensions for object size
      final RenderBox? renderBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
      final double cellWidth = renderBox != null ? renderBox.size.width / _gridSize : 50.0; // Fallback size
      
      return Stack(
        children: _fallingObjects.map((obj) {
          // Calculate x position using the rail system - aligns perfectly with column center
          final double? calculatedX = _calculateColumnX(obj.col, cellWidth);
          // Use calculated X if available, otherwise skip rendering this object
          if (calculatedX == null) return const SizedBox.shrink();
          
          // Calculate y position: obj.y goes from 0.0 (top of screen) to 1.0 (bottom of screen)
          // Map directly to screen coordinates: y=0.0 -> top, y=1.0 -> bottom
          double y = obj.y * screenHeight;
          
          // Create combined cell for rendering (exactly like filled cells)
          final CombinedCell fallingCell = CombinedCell(
            shapeId: obj.shapeId,
            colorId: obj.colorId,
            numberId: obj.numberId,
            isFixed: false,
          );
          
          // Render exactly like filled cells using the same method
          Widget combinedContent = _buildFallingCombinedElement(fallingCell, kRetroText);
          
          // Apply axis-angle rotation using Rodrigues rotation formula
          // This ensures the face is always visible and never rotates into horizontal plane
          final Vector3 rotationAxis = Vector3(obj.axisX, obj.axisY, obj.axisZ);
          Widget rotatedContent = Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..multiply(_rotationAxis(rotationAxis, obj.rotationAngle)),
            alignment: Alignment.center,
            child: combinedContent,
          );
          
          return Positioned(
            left: calculatedX, 
            top: y,
            width: cellWidth, 
            height: cellWidth,
            child: GestureDetector(
              onTap: () => _handleFallingTap(obj),
              child: rotatedContent,
            ),
          );
        }).toList(),
      );
    });
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
          _ToolButton(icon: Icons.lightbulb, label: 'Hint', onTap: _hint),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boardLength = math.min(constraints.maxWidth, constraints.maxHeight);
        return Align(
          alignment: Alignment.topCenter, 
          child: Container(
            key: _boardKey,
            width: boardLength,
            height: boardLength,
            decoration: BoxDecoration(
              color: kRetroSurface.withOpacity(0.5),
              border: Border.all(color: kRetroAccent, width: 4),
            ),
            padding: const EdgeInsets.all(2),
            child: AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _groupCompletionController]),
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
                             if (_activeHint!.highlights.contains(idx)) {
                                highlight = CellHighlight.hintRelated;
                             }
                             if (row == _activeHint!.targetRow && col == _activeHint!.targetCol) {
                                highlight = CellHighlight.hintTarget;
                             }
                          }

                          final int cellIndex = row * _gridSize + col;
                          final bool isAnimated = _animatedCells.contains(cellIndex);
                          
                          CombinedCell? combinedCell;
                          if (_combinedPuzzle != null) {
                            // For hard mode, show initialBoard for prefilled cells, solution for user-filled cells
                            if (widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers) {
                              if (value > 0) {
                                // Check if it's a prefilled cell (fixed) or user-filled
                                if (!_isEditable[row][col]) {
                                  // Prefilled cell - use initialBoard
                                  combinedCell = _combinedPuzzle!.initialBoard[row][col];
                                } else {
                                  // User-filled cell - use solution
                                  combinedCell = _combinedPuzzle!.solution[row][col];
                                }
                              } else {
                                combinedCell = null; // Empty cell
                              }
                            } else {
                              combinedCell = _combinedPuzzle!.initialBoard[row][col];
                            }
                          }
                          
                          // Calculate 3D rotation angle for hard mode (seamless 4-second loop)
                          double rotationAngle = 0.0;
                          if (widget.difficulty == Difficulty.hard && widget.mode != GameMode.numbers && value > 0) {
                            // Use different rotation speeds per cell for variety
                            // Use integer multipliers (1, 2, 3) for seamless looping
                            final int cellIndex = row * _gridSize + col;
                            final int speedMultiplier = 1 + (cellIndex % 3); // 1, 2, or 3 (integers for seamless loop)
                            // Calculate rotation: controller goes 0-1, multiply by 2π for full rotation
                            rotationAngle = (_rotationController.value * 2 * math.pi * speedMultiplier);
                            // Axis tilt is calculated in the cell widget itself for each cell
                          }
                          
                          final bool rightBorder = (col + 1) % _blockCols == 0 && col != _gridSize - 1;
                          final bool bottomBorder = (row + 1) % _blockRows == 0 && row != _gridSize - 1;

                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: rightBorder ? kRetroText.withOpacity(0.6) : kRetroText.withOpacity(0.1), width: rightBorder ? 2 : 0.5),
                                  bottom: BorderSide(color: bottomBorder ? kRetroText.withOpacity(0.6) : kRetroText.withOpacity(0.1), width: bottomBorder ? 2 : 0.5),
                                ),
                              ),
                              child: _SudokuCell(
                                value: value,
                                notes: _notes[row][col],
                                shapeNotes: widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers ? _shapeNotes[row][col] : const {},
                                colorNotes: widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers ? _colorNotes[row][col] : const {},
                                numberNotes: widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers ? _numberNotes[row][col] : const {},
                                draftCell: widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers && isSelected ? _draftCell : null,
                                rotationAngle: rotationAngle, 
                                row: row,
                                col: col,
                                gridSize: _gridSize,
                                isEditable: isEditable,
                                isSelected: isSelected,
                                isInvalid: isInvalid,
                                highlight: highlight,
                                isAnimated: isAnimated,
                                gameMode: widget.mode,
                                difficulty: widget.difficulty,
                                combinedCell: combinedCell,
                                selectedElement: null, 
                                shapeId: _shapeMap[value > 0 ? value - 1 : 0],
                                shapeMap: _shapeMap, 
                                onTap: () => _selectCell(row, col),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                );
              },
            ),
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

    if (widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers) {
       if (row == selRow || col == selCol || _sharesBlock(row, col, selRow, selCol)) return CellHighlight.related;
       return CellHighlight.none;
    }

    final int selectedValue = _board[selRow][selCol];
    if (selectedValue != 0 && value != 0 && value == selectedValue) return CellHighlight.matching;

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
    if (widget.difficulty == Difficulty.medium && widget.mode != GameMode.numbers) {
       return Container(
         height: 160,
         padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
         decoration: BoxDecoration(color: kRetroSurface, border: Border(top: BorderSide(color: kRetroAccent, width: 4))),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             _buildInputRow(ElementType.number),
             const SizedBox(height: 1),
             _buildInputRow(ElementType.color),
             const SizedBox(height: 1),
             _buildInputRow(ElementType.shape),
           ],
         ),
       );
    }
  
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      decoration: BoxDecoration(
        color: kRetroSurface,
        border: Border(top: BorderSide(color: kRetroAccent, width: 4)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: List<Widget>.generate(_gridSize, (int index) {
          final int value = index + 1;
          final bool completed = _isValueCompleted(value);
          return _ShapePickerButton(
            value: value,
            shapeId: _shapeMap[index],
            isCompleted: completed,
            gameMode: widget.mode,
            difficulty: widget.difficulty,
            selectedElement: _combinedPuzzle?.selectedElement,
            onTap: () => _handleInput(value),
          );
        }),
      ),
    );
  }
  
  Widget _buildInputRow(ElementType type) {
     return SizedBox(
       height: 46,
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
         children: List.generate(_gridSize, (index) {
            final val = index + 1;
            bool isSelected = false;
            if (_selectedRow != null && _selectedCol != null && _draftCell != null) {
              switch(type) {
                case ElementType.number: isSelected = _draftCell!.numberId == val; break;
                case ElementType.color: isSelected = _draftCell!.colorId == val; break;
                case ElementType.shape: isSelected = _draftCell!.shapeId == val; break;
              }
            }
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () => _handleInput(val, type: type),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? kRetroHighlight.withOpacity(0.3) : kRetroSurface,
                      border: Border.all(
                        color: isSelected ? kRetroHighlight : kRetroText.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: type == ElementType.number 
                        ? Text('$val', style: TextStyle(color: isSelected ? kRetroHighlight : kRetroText, fontWeight: FontWeight.bold, fontSize: 14))
                        : type == ElementType.color 
                        ? Container(
                            decoration: BoxDecoration(
                              color: _getColorForValue(val),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: kRetroHighlight, width: 2) : null,
                            ),
                            width: 24,
                            height: 24,
                          )
                        : SudokuShape(id: widget.mode == GameMode.shapes ? _shapeMap[index] : val, color: isSelected ? kRetroHighlight : kRetroText),
                    ),
                  ),
                ),
              ),
            );
         }),
       ),
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
  const _HintOverlay({required this.info, required this.onApply, required this.onClose});
  final HintInfo info;
  final VoidCallback onApply;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kRetroSurface,
        border: Border.all(color: kRetroHint, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               const Icon(Icons.lightbulb, color: kRetroHint),
               const SizedBox(width: 8),
               Expanded(child: Text(info.title, style: const TextStyle(fontWeight: FontWeight.bold, color: kRetroHint, fontSize: 18))),
               IconButton(icon: const Icon(Icons.close), onPressed: onClose)
             ],
           ),
           const SizedBox(height: 8),
           Text(info.description, style: const TextStyle(color: kRetroText)),
           const SizedBox(height: 16),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton(
               onPressed: onApply,
               style: ElevatedButton.styleFrom(backgroundColor: kRetroHint, foregroundColor: kRetroSurface),
               child: const Text("APPLY HINT"),
             ),
           ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap, this.isActive = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: kRetroText.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _SudokuCell extends StatefulWidget {
  const _SudokuCell({
    required this.value,
    required this.notes,
    this.shapeNotes,
    this.colorNotes,
    this.numberNotes,
    this.draftCell,
    required this.rotationAngle,
    required this.row,
    required this.col,
    required this.gridSize,
    required this.isSelected,
    required this.isEditable,
    required this.isInvalid,
    required this.highlight,
    required this.isAnimated,
    required this.gameMode,
    required this.difficulty,
    this.combinedCell,
    this.selectedElement,
    required this.shapeId,
    required this.shapeMap,
    required this.onTap,
  });

  final int value;
  final Set<int> notes;
  final Set<int>? shapeNotes;
  final Set<int>? colorNotes;
  final Set<int>? numberNotes;
  final CombinedCell? draftCell;
  final double rotationAngle;
  final int row;
  final int col;
  final int gridSize;
  final bool isSelected;
  final bool isEditable;
  final bool isInvalid;
  final CellHighlight highlight;
  final bool isAnimated;
  final GameMode gameMode;
  final Difficulty difficulty;
  final CombinedCell? combinedCell;
  final ElementType? selectedElement;
  final int shapeId;
  final List<int> shapeMap;
  final VoidCallback onTap;

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
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _errorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.transparent;
    Color contentColor = kRetroText;
    
    if (widget.highlight == CellHighlight.related) {
      backgroundColor = kRetroAccent.withOpacity(0.5);
    } else if (widget.highlight == CellHighlight.matching) {
      backgroundColor = kRetroHighlight.withOpacity(0.1);
    } else if (widget.highlight == CellHighlight.hintRelated) {
      backgroundColor = kRetroHint.withOpacity(0.15); // Lighter hint bg
    }

    if (!widget.isEditable) {
       backgroundColor = Color.alphaBlend(backgroundColor, kRetroSurface);
       contentColor = kRetroText.withOpacity(0.9);
    }

    if (widget.isSelected) {
      backgroundColor = kRetroHighlight.withOpacity(0.2);
    }
    if (widget.highlight == CellHighlight.hintTarget) {
      backgroundColor = kRetroHint.withOpacity(0.4);
    }
    
    if (widget.isAnimated) {
      backgroundColor = Colors.cyanAccent.withOpacity(0.3);
    }
    
    if (widget.isInvalid) {
      return AnimatedBuilder(
        animation: _errorController,
        builder: (context, child) {
          return _buildCellContainer(
            Color.alphaBlend(Colors.red.withOpacity(0.3 * _errorController.value + 0.2), kRetroSurface),
            contentColor,
          );
        },
      );
    }

    return GestureDetector(
      onTap: widget.isEditable ? widget.onTap : null,
      child: _buildCellContainer(backgroundColor, contentColor),
    );
  }

  Widget _buildCellContainer(Color bgColor, Color contentColor) {
    // Medium mode: Show draft cell if selected, or show separate notes
    if (widget.difficulty == Difficulty.medium && widget.gameMode != GameMode.numbers) {
      Widget content;
      
      // Priority: Draft cell (if selected) > Filled cell > Notes > Empty
      if (widget.draftCell != null && widget.isSelected && widget.isEditable) {
        // Show draft selections - only what's selected
        // Check if draft has any selections
        if (widget.draftCell!.shapeId != null || widget.draftCell!.colorId != null || widget.draftCell!.numberId != null) {
          content = _buildDraftCell(widget.draftCell!, contentColor);
        } else {
          content = const SizedBox.expand();
        }
      } else {
        // Check if cell is filled (has all three elements and is not editable OR has value > 0)
        final bool isFilled = widget.combinedCell != null && 
            widget.combinedCell!.shapeId != null && 
            widget.combinedCell!.colorId != null && 
            widget.combinedCell!.numberId != null &&
            (widget.value > 0 || !widget.isEditable); // Filled if has value or is fixed
        
        if (isFilled) {
          // Cell is filled - show the filled cell
          content = _buildCombinedElement(widget.combinedCell!, widget.selectedElement, contentColor);
        } else if (widget.shapeNotes != null && (widget.shapeNotes!.isNotEmpty || widget.colorNotes!.isNotEmpty || widget.numberNotes!.isNotEmpty)) {
          // Show pencil notes
          content = _buildMediumNotes();
        } else {
          content = const SizedBox.expand();
        }
      }
      
      return Container(
        decoration: BoxDecoration(color: bgColor),
        child: Center(child: content),
      );
    }
    
    // Standard mode
    Widget content;
    if (widget.value > 0 || (widget.combinedCell != null && (widget.combinedCell!.shapeId != null || widget.combinedCell!.colorId != null || widget.combinedCell!.numberId != null))) {
       if (widget.difficulty == Difficulty.hard && widget.gameMode != GameMode.numbers) {
          // Hard mode: Apply 3D rotation around tilted vertical axis
          Widget combined = _buildCombinedElement(widget.combinedCell!, widget.selectedElement, contentColor);
          if (widget.rotationAngle != 0.0) {
            // Calculate unique axis tilt for this cell (small angles to keep face visible)
            final int cellIndex = widget.row * widget.gridSize + widget.col;
            final math.Random cellRnd = math.Random(cellIndex);
            final double axisTiltX = 0.1 + (cellRnd.nextDouble() * 0.3); // 0.1 to 0.4 radians
            final double axisTiltZ = 0.1 + (cellRnd.nextDouble() * 0.3); // 0.1 to 0.4 radians
            
            // 3D rotation around tilted vertical axis - keeps face visible most of the time
            content = Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                // Rotate around vertical axis (Y) - main rotation
                ..rotateY(widget.rotationAngle)
                // Apply small tilts that vary with rotation to create tilted axis effect
                ..rotateX(axisTiltX * math.sin(widget.rotationAngle))
                ..rotateZ(axisTiltZ * math.cos(widget.rotationAngle)),
              alignment: Alignment.center,
              child: combined,
            );
          } else {
            content = combined;
          }
       } else {
          content = (widget.combinedCell != null)
                ? _buildCombinedElement(widget.combinedCell!, widget.selectedElement, contentColor)
                : _buildSingleElement(context, contentColor);
       }
    } else if (widget.notes.isNotEmpty) {
       content = _buildNotes();
    } else {
       content = const SizedBox.expand();
    }

    return Container(
      decoration: BoxDecoration(color: bgColor),
      child: Center(child: content),
    );
  }
  
  Widget _buildDraftCell(CombinedCell draft, Color defaultColor) {
    // Show ONLY what's selected in draft - nothing else
    List<Widget> widgets = [];
    
    // Show shape only if shapeId is selected
    if (draft.shapeId != null) {
      // Use different color when no color is selected - use cyan instead of red so it's visible with number
      final Color shapeColor = draft.colorId != null 
          ? _getColorForValue(draft.colorId!) 
          : Colors.cyanAccent;
      widgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: SudokuShape(id: draft.shapeId!, color: shapeColor),
          ),
        ),
      );
    }
    
    // Show color circle only if colorId is selected (and shapeId is NOT selected)
    if (draft.colorId != null && draft.shapeId == null) {
      widgets.add(
        Center(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getColorForValue(draft.colorId!),
              shape: BoxShape.circle,
              border: Border.all(color: kRetroHighlight, width: 2),
            ),
          ),
        ),
      );
    }
    
    // Show number only if numberId is selected
    // Center number on top of shape if shape is present, otherwise center alone
    if (draft.numberId != null) {
      widgets.add(
        draft.shapeId != null
          ? Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  draft.numberId.toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            )
          : Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: kRetroHighlight.withOpacity(0.3),
                  border: Border.all(color: kRetroHighlight, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  draft.numberId.toString(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kRetroHighlight),
                ),
              ),
            ),
      );
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shape note (top-left corner)
        if (widget.shapeNotes != null && widget.shapeNotes!.isNotEmpty)
          Positioned(
            top: 2,
            left: 2,
            child: SizedBox(
              width: 30, // 3x larger (was 10)
              height: 30, // 3x larger (was 10)
              child: SudokuShape(id: widget.shapeNotes!.first, color: kRetroText.withOpacity(0.7)),
            ),
          ),
        // Color note (top-right corner)
        if (widget.colorNotes != null && widget.colorNotes!.isNotEmpty)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 18, // 3x larger (was 6)
              height: 18, // 3x larger (was 6)
              decoration: BoxDecoration(
                color: _getColorForValue(widget.colorNotes!.first),
                shape: BoxShape.circle,
                border: Border.all(color: kRetroText.withOpacity(0.3), width: 1),
              ),
            ),
          ),
        // Number note (bottom-left corner)
        if (widget.numberNotes != null && widget.numberNotes!.isNotEmpty)
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: kRetroText.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                widget.numberNotes!.first.toString(),
                style: TextStyle(fontSize: 21, color: kRetroText.withOpacity(0.7), fontWeight: FontWeight.bold), // 3x larger (was 7)
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

    // Check if Medium or Hard mode - use cosmic style
    final bool useCosmicStyle = (widget.difficulty == Difficulty.medium || widget.difficulty == Difficulty.hard) && 
                                widget.gameMode != GameMode.numbers;
    
    final Color shapeColor = colorId != null 
        ? (useCosmicStyle ? getCosmicColor(colorId) : _getColorForValue(colorId))
        : defaultColor.withOpacity(0.2);
    
    Widget? shapeWidget;
    if (shapeId != null) {
      shapeWidget = Padding(
        padding: const EdgeInsets.all(4),
        child: useCosmicStyle
            ? CosmicGlyph(shapeId: shapeId, color: shapeColor)
            : SudokuShape(id: shapeId, color: shapeColor), 
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
      // For cosmic style, use semi-transparent black or deep blue for contrast
      final Color numberColor = useCosmicStyle 
          ? const Color(0xFF1A1A2E).withOpacity(0.8) // Deep blue for contrast
          : Colors.white;
      numberWidget = Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: useCosmicStyle 
              ? BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            numberId.toString(),
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: numberColor,
              shadows: useCosmicStyle 
                  ? [] 
                  : [const Shadow(blurRadius: 2, color: Colors.black)],
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

class CosmicGlyphPainter extends CustomPainter {
  const CosmicGlyphPainter({required this.shapeId, required this.color});
  
  final int shapeId;
  final Color color;
  
  @override
  void paint(Canvas canvas, Size size) {
    final double minSide = math.min(size.width, size.height);
    final Rect bounds = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: minSide,
      height: minSide,
    );
    
    final Offset center = bounds.center;
    final double radius = minSide / 2;
    
    // Create glow effect paint
    final Paint glowPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
      ..style = PaintingStyle.fill;
    
    // Create gradient fill paint
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    
    // Radial gradient: white center → color mid → color edge
    fillPaint.shader = RadialGradient(
      center: Alignment.topCenter,
      colors: [Colors.white, color, color],
      stops: const [0.0, 0.3, 1.0],
    ).createShader(bounds);
    
    // Draw shape based on shapeId (1-9)
    switch (shapeId) {
      case 1: _drawOrb(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 2: _drawHalo(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 3: _drawPrism(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 4: _drawPolaris(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 5: _drawNova(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 6: _drawCrescent(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 7: _drawCapsule(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 8: _drawHex(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      case 9: _drawSector(canvas, bounds, center, radius, glowPaint, fillPaint); break;
      default: _drawOrb(canvas, bounds, center, radius, glowPaint, fillPaint);
    }
  }
  
  void _drawOrb(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    final double orbRadius = radius * 0.4;
    // Draw glow
    canvas.drawCircle(center, orbRadius, glowPaint);
    // Draw orb with gradient
    canvas.drawCircle(center, orbRadius, fillPaint);
    // Add shine highlight (small white circle at top-left)
    final Paint shinePaint = Paint()..color = Colors.white.withOpacity(0.6);
    canvas.drawCircle(center + Offset(-orbRadius * 0.3, -orbRadius * 0.3), orbRadius * 0.2, shinePaint);
  }
  
  void _drawHalo(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    final double outerRadius = radius * 0.45;
    final double innerRadius = radius * 0.25;
    // Draw glow
    canvas.drawCircle(center, outerRadius, glowPaint);
    // Draw donut using path difference
    final Path outerPath = Path()..addOval(Rect.fromCircle(center: center, radius: outerRadius));
    final Path innerPath = Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    final Path donutPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(donutPath, fillPaint);
  }
  
  void _drawPrism(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    final double padding = radius * 0.15;
    final Path path = Path()
      ..moveTo(center.dx, bounds.top + padding)
      ..lineTo(bounds.right - padding, bounds.bottom - padding)
      ..lineTo(bounds.left + padding, bounds.bottom - padding)
      ..close();
    // Draw glow
    canvas.drawPath(path, glowPaint);
    // Draw prism
    canvas.drawPath(path, fillPaint);
  }
  
  void _drawPolaris(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    // 4-pointed concave star (diamond with concave sides)
    final double size = radius * 0.4;
    final Path path = Path()
      ..moveTo(center.dx, center.dy - size) // Top
      ..lineTo(center.dx + size * 0.6, center.dy) // Right (concave)
      ..lineTo(center.dx, center.dy + size) // Bottom
      ..lineTo(center.dx - size * 0.6, center.dy) // Left (concave)
      ..close();
    // Draw glow
    canvas.drawPath(path, glowPaint);
    // Draw star
    canvas.drawPath(path, fillPaint);
  }
  
  void _drawNova(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    // 5-pointed star with rounded tips
    final double outerRadius = radius * 0.4;
    final double innerRadius = radius * 0.15;
    final int points = 5;
    final double step = math.pi / points;
    
    final Path path = Path();
    double angle = -math.pi / 2; // Start at top
    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      angle += step;
    }
    path.close();
    // Draw glow
    canvas.drawPath(path, glowPaint);
    // Draw star
    canvas.drawPath(path, fillPaint);
  }
  
  void _drawCrescent(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    // Thick moon shape (two overlapping circles)
    final double moonRadius = radius * 0.4;
    final Offset leftCenter = center + Offset(-moonRadius * 0.3, 0);
    final Offset rightCenter = center + Offset(moonRadius * 0.3, 0);
    
    final Path outerPath = Path()..addOval(Rect.fromCircle(center: leftCenter, radius: moonRadius));
    final Path innerPath = Path()..addOval(Rect.fromCircle(center: rightCenter, radius: moonRadius * 0.7));
    final Path crescentPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    // Draw glow
    canvas.drawPath(crescentPath, glowPaint);
    // Draw crescent
    canvas.drawPath(crescentPath, fillPaint);
  }
  
  void _drawCapsule(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    // Vertical pill shape (rounded rectangle)
    final double width = radius * 0.5;
    final double height = radius * 0.8;
    final RRect capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      Radius.circular(width / 2),
    );
    // Draw glow
    canvas.drawRRect(capsule, glowPaint);
    // Draw capsule
    canvas.drawRRect(capsule, fillPaint);
  }
  
  void _drawHex(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    // Hexagon with pointy top
    final double hexRadius = radius * 0.4;
    final int sides = 6;
    
    final Path path = Path();
    for (int i = 0; i < sides; i++) {
      final double angle = -math.pi / 2 + (i * 2 * math.pi / sides); // Start at top
      final double x = center.dx + math.cos(angle) * hexRadius;
      final double y = center.dy + math.sin(angle) * hexRadius;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    // Draw glow
    canvas.drawPath(path, glowPaint);
    // Draw hexagon
    canvas.drawPath(path, fillPaint);
  }
  
  void _drawSector(Canvas canvas, Rect bounds, Offset center, double radius, Paint glowPaint, Paint fillPaint) {
    // Thick cross/plus with rounded ends
    final double thickness = radius * 0.2;
    final double length = radius * 0.6;
    
    // Vertical bar
    final RRect verticalBar = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: thickness, height: length),
      Radius.circular(thickness / 2),
    );
    // Horizontal bar
    final RRect horizontalBar = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: length, height: thickness),
      Radius.circular(thickness / 2),
    );
    // Draw glow
    canvas.drawRRect(verticalBar, glowPaint);
    canvas.drawRRect(horizontalBar, glowPaint);
    // Draw cross
    canvas.drawRRect(verticalBar, fillPaint);
    canvas.drawRRect(horizontalBar, fillPaint);
  }
  
  @override
  bool shouldRepaint(covariant CosmicGlyphPainter oldDelegate) {
    return oldDelegate.shapeId != shapeId || oldDelegate.color != color;
  }
}

/// Widget wrapper for CosmicGlyphPainter
class CosmicGlyph extends StatelessWidget {
  const CosmicGlyph({super.key, required this.shapeId, required this.color});
  
  final int shapeId;
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: CosmicGlyphPainter(shapeId: shapeId, color: color),
        isComplex: true,
      ),
    );
  }
}

class PlanetPainter extends CustomPainter {
  final int planetId;
  PlanetPainter(this.planetId);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final Paint paint = Paint();
    List<Color> colors;
    switch(planetId) {
      case 1: colors = [Colors.grey, Colors.brown]; break;
      case 2: colors = [Colors.yellow[100]!, Colors.orangeAccent]; break; 
      case 3: colors = [Colors.blue, Colors.green]; break; 
      case 4: colors = [Colors.red, Colors.redAccent[700]!]; break; 
      case 5: colors = [Colors.orange, Colors.brown]; break; 
      case 6: colors = [Colors.amber, Colors.yellow[200]!]; break; 
      case 7: colors = [Colors.cyan[100]!, Colors.cyan]; break; 
      case 8: colors = [Colors.orangeAccent, Colors.yellow]; break; 
      case 9: colors = [Colors.grey[300]!, Colors.white]; break; 
      default: colors = [Colors.white, Colors.grey];
    }
    paint.shader = RadialGradient(colors: colors, center: Alignment.topLeft, radius: 1.2).createShader(Rect.fromCircle(center: center, radius: radius));
    if (planetId == 8) {
       canvas.drawCircle(center, radius + 4, Paint()..color = Colors.orange.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    canvas.drawCircle(center, radius, paint);
    if (planetId == 6 || planetId == 7) {
       final ringPaint = Paint()..color = Colors.white.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 3;
       canvas.drawOval(Rect.fromCenter(center: center, width: size.width + 4, height: size.height / 2), ringPaint);
    }
    if (planetId == 1 || planetId == 4 || planetId == 9) {
       final craterPaint = Paint()..color = Colors.black12;
       canvas.drawCircle(center + Offset(radius*0.3, -radius*0.3), radius*0.2, craterPaint);
       canvas.drawCircle(center + Offset(-radius*0.4, radius*0.2), radius*0.15, craterPaint);
    }
  }
  @override
  bool shouldRepaint(covariant PlanetPainter oldDelegate) => oldDelegate.planetId != planetId;
}

class CosmicPainter extends CustomPainter {
  final int cosmicId;
  CosmicPainter(this.cosmicId);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 2;
    
    switch (cosmicId) {
      case 1: _drawSun(canvas, center, radius); break;
      case 2: _drawCrescentMoon(canvas, center, radius); break;
      case 3: _drawStar(canvas, center, radius); break;
      case 4: _drawBolt(canvas, center, radius); break;
      case 5: _drawGalaxy(canvas, center, radius); break;
      case 6: _drawComet(canvas, center, radius); break;
      case 7: _drawRocket(canvas, center, radius); break;
      case 8: _drawBlackHole(canvas, center, radius); break;
      case 9: _drawNebula(canvas, center, radius); break;
      default: _drawSun(canvas, center, radius);
    }
  }
  
  void _drawSun(Canvas canvas, Offset center, double radius) {
    // Sun: RadialGradient (White→Yellow→Orange), blurred corona
    final Paint sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.yellow, Colors.orange],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    // Corona glow
    final Paint coronaPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(center, radius * 1.2, coronaPaint);
    
    canvas.drawCircle(center, radius, sunPaint);
  }
  
  void _drawCrescentMoon(Canvas canvas, Offset center, double radius) {
    // Crescent Moon: Path.combine difference, silvery-white, earthshine
    final Paint moonPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..style = PaintingStyle.fill;
    
    final Path outerPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final Path innerPath = Path()..addOval(Rect.fromCircle(center: center + Offset(radius * 0.3, 0), radius: radius * 0.8));
    final Path crescentPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    
    // Earthshine (subtle glow on dark side)
    final Paint earthshinePaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(crescentPath, earthshinePaint);
    
    canvas.drawPath(crescentPath, moonPaint);
  }
  
  void _drawStar(Canvas canvas, Offset center, double radius) {
    // Star: 5-pointed rounded, Gold→Amber gradient, glow
    final double outerRadius = radius * 0.7;
    final double innerRadius = radius * 0.3;
    final int points = 5;
    final double step = math.pi / points;
    
    final Path path = Path();
    double angle = -math.pi / 2;
    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      angle += step;
    }
    path.close();
    
    // Glow
    final Paint glowPaint = Paint()
      ..color = Colors.amber.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(path, glowPaint);
    
    // Star with gradient
    final Paint starPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.amber, Colors.orange],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawPath(path, starPaint);
  }
  
  void _drawBolt(Canvas canvas, Offset center, double radius) {
    // Bolt: Lightning, neon (thick blurred cyan + thin white)
    final Path boltPath = Path()
      ..moveTo(center.dx - radius * 0.3, center.dy - radius * 0.5)
      ..lineTo(center.dx + radius * 0.1, center.dy - radius * 0.1)
      ..lineTo(center.dx - radius * 0.1, center.dy)
      ..lineTo(center.dx + radius * 0.3, center.dy + radius * 0.5)
      ..lineTo(center.dx - radius * 0.1, center.dy + radius * 0.3)
      ..lineTo(center.dx + radius * 0.1, center.dy + radius * 0.1)
      ..close();
    
    // Thick blurred cyan
    final Paint thickPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.15
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(boltPath, thickPaint);
    
    // Thin white
    final Paint thinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05;
    canvas.drawPath(boltPath, thinPaint);
  }
  
  void _drawGalaxy(Canvas canvas, Offset center, double radius) {
    // Galaxy: Spiral with SweepGradient (Pink→Purple→Blue), two arms, star dots
    final Paint spiralPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.pink, Colors.purple, Colors.blue, Colors.pink],
        stops: const [0.0, 0.33, 0.66, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    // Draw spiral arms
    final Path spiralPath = Path();
    for (double angle = 0; angle < math.pi * 4; angle += 0.1) {
      final double r = radius * (0.2 + (angle / (math.pi * 4)) * 0.6);
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;
      if (angle == 0) spiralPath.moveTo(x, y);
      else spiralPath.lineTo(x, y);
    }
    spiralPaint.style = PaintingStyle.stroke;
    spiralPaint.strokeWidth = radius * 0.1;
    canvas.drawPath(spiralPath, spiralPaint);
    
    // Star dots
    final Paint starPaint = Paint()..color = Colors.white;
    for (int i = 0; i < 8; i++) {
      final double angle = (i / 8) * math.pi * 2;
      final double r = radius * (0.3 + (i % 3) * 0.15);
      canvas.drawCircle(
        center + Offset(math.cos(angle) * r, math.sin(angle) * r),
        radius * 0.05,
        starPaint,
      );
    }
  }
  
  void _drawComet(Canvas canvas, Offset center, double radius) {
    // Comet: Ice blue/white ball, LinearGradient tail (Blue→Transparent)
    final double cometRadius = radius * 0.3;
    final Offset cometCenter = center + Offset(-radius * 0.2, 0);
    
    // Tail
    final Paint tailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [Colors.blue, Colors.blue.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(center.dx - radius, center.dy - radius * 0.2, radius * 1.5, radius * 0.4));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - radius, center.dy - radius * 0.2, radius * 1.5, radius * 0.4),
        Radius.circular(radius * 0.2),
      ),
      tailPaint,
    );
    
    // Comet head
    final Paint cometPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.lightBlue, Colors.blue],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: cometCenter, radius: cometRadius));
    canvas.drawCircle(cometCenter, cometRadius, cometPaint);
  }
  
  void _drawRocket(Canvas canvas, Offset center, double radius) {
    // Rocket: Retro rocket (silver gradient, red fins, window, flame)
    final double rocketWidth = radius * 0.4;
    final double rocketHeight = radius * 1.2;
    
    // Body (silver gradient)
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white70, Colors.grey, Colors.white70],
      ).createShader(Rect.fromCenter(center: center, width: rocketWidth, height: rocketHeight));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: rocketWidth, height: rocketHeight),
        Radius.circular(rocketWidth / 4),
      ),
      bodyPaint,
    );
    
    // Window
    final Paint windowPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(center + Offset(0, -rocketHeight * 0.2), radius * 0.08, windowPaint);
    
    // Fins (red)
    final Paint finPaint = Paint()..color = Colors.red;
    final Path finPath = Path()
      ..moveTo(center.dx - rocketWidth / 2, center.dy + rocketHeight / 2)
      ..lineTo(center.dx - rocketWidth / 2 - radius * 0.15, center.dy + rocketHeight / 2 + radius * 0.2)
      ..lineTo(center.dx - rocketWidth / 2, center.dy + rocketHeight / 2 + radius * 0.15)
      ..close();
    canvas.drawPath(finPath, finPaint);
    final Path finPath2 = Path()
      ..moveTo(center.dx + rocketWidth / 2, center.dy + rocketHeight / 2)
      ..lineTo(center.dx + rocketWidth / 2 + radius * 0.15, center.dy + rocketHeight / 2 + radius * 0.2)
      ..lineTo(center.dx + rocketWidth / 2, center.dy + rocketHeight / 2 + radius * 0.15)
      ..close();
    canvas.drawPath(finPath2, finPaint);
    
    // Flame
    final Paint flamePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.orange, Colors.red, Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center + Offset(0, rocketHeight / 2 + radius * 0.2), radius: radius * 0.15));
    canvas.drawCircle(center + Offset(0, rocketHeight / 2 + radius * 0.2), radius * 0.15, flamePaint);
  }
  
  void _drawBlackHole(Canvas canvas, Offset center, double radius) {
    // Black Hole: Black circle, glowing accretion disk (SweepGradient Orange→Red→Transparent)
    // Accretion disk
    final Paint diskPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.orange, Colors.red, Colors.transparent, Colors.transparent],
        stops: const [0.0, 0.3, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.8));
    canvas.drawCircle(center, radius * 0.8, diskPaint);
    
    // Black hole center
    final Paint blackPaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, radius * 0.4, blackPaint);
    
    // Glow
    final Paint glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(center, radius * 0.9, glowPaint);
  }
  
  void _drawNebula(Canvas canvas, Offset center, double radius) {
    // Nebula: Amorphous cloud (3-4 blurred circles Deep Purple/Magenta, 3 white stars)
    final Paint nebulaPaint = Paint()
      ..color = Colors.deepPurple.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    
    // Draw 3-4 blurred circles
    canvas.drawCircle(center + Offset(-radius * 0.2, -radius * 0.1), radius * 0.5, nebulaPaint);
    canvas.drawCircle(center + Offset(radius * 0.2, radius * 0.1), radius * 0.4, nebulaPaint);
    canvas.drawCircle(center + Offset(0, radius * 0.2), radius * 0.35, nebulaPaint);
    
    final Paint magentaPaint = Paint()
      ..color = Colors.pink.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(center + Offset(radius * 0.15, -radius * 0.15), radius * 0.3, magentaPaint);
    
    // 3 white stars
    final Paint starPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center + Offset(-radius * 0.3, -radius * 0.2), radius * 0.06, starPaint);
    canvas.drawCircle(center + Offset(radius * 0.25, radius * 0.15), radius * 0.05, starPaint);
    canvas.drawCircle(center + Offset(0, -radius * 0.3), radius * 0.07, starPaint);
  }
  
  @override
  bool shouldRepaint(covariant CosmicPainter oldDelegate) => oldDelegate.cosmicId != cosmicId;
}

class SpaceshipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint shipPaint = Paint()
      ..color = kRetroAccent
      ..style = PaintingStyle.fill;
    
    final Paint glowPaint = Paint()
      ..color = kRetroHighlight.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    final Paint windowPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    // Draw spaceship body (triangular/arrow shape)
    final Path shipPath = Path()
      ..moveTo(centerX, size.height * 0.1) // Top point
      ..lineTo(size.width * 0.2, size.height * 0.7) // Left bottom
      ..lineTo(size.width * 0.35, size.height * 0.9) // Left wing
      ..lineTo(centerX, size.height * 0.85) // Center bottom
      ..lineTo(size.width * 0.65, size.height * 0.9) // Right wing
      ..lineTo(size.width * 0.8, size.height * 0.7) // Right bottom
      ..close();
    
    // Draw glow
    canvas.drawPath(shipPath, glowPaint);
    
    // Draw ship body
    canvas.drawPath(shipPath, shipPaint);
    
    // Draw windows
    canvas.drawCircle(Offset(centerX - size.width * 0.15, centerY), 8, windowPaint);
    canvas.drawCircle(Offset(centerX, centerY), 10, windowPaint);
    canvas.drawCircle(Offset(centerX + size.width * 0.15, centerY), 8, windowPaint);
    
    // Draw details
    final Paint detailPaint = Paint()
      ..color = kRetroHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw lines on ship
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.5),
      Offset(size.width * 0.7, size.height * 0.5),
      detailPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant SpaceshipPainter oldDelegate) => false;
}

class _ShapePickerButton extends StatelessWidget {
  const _ShapePickerButton({
    required this.value,
    required this.shapeId,
    required this.isCompleted,
    required this.gameMode,
    required this.difficulty,
    this.selectedElement,
    required this.onTap,
  });
  final int value;
  final int shapeId;
  final bool isCompleted;
  final GameMode gameMode;
  final Difficulty difficulty;
  final ElementType? selectedElement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = isCompleted;
    final Color shapeColor = disabled ? kRetroText.withOpacity(0.2) : kRetroHighlight;
    Widget content;
    
    // Logic for Combined handled in _buildInputBar rows now
    if (gameMode == GameMode.colors) {
       content = Container(decoration: BoxDecoration(color: _getColorForValue(value).withOpacity(disabled ? 0.3 : 1.0), shape: BoxShape.circle));
    } else if (gameMode == GameMode.numbers) {
       content = Center(child: Text(value.toString(), style: TextStyle(color: shapeColor, fontWeight: FontWeight.bold, fontSize: 20)));
    } else if (gameMode == GameMode.planets) {
       content = CustomPaint(painter: PlanetPainter(value), size: const Size(24,24));
    } else if (gameMode == GameMode.custom) {
       content = FutureBuilder<List<String?>>(
         future: CustomImageRepository.loadCustomImages(),
         builder: (context, snapshot) {
           if (snapshot.hasData && snapshot.data![value - 1] != null) {
             return Container(decoration: BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: FileImage(File(snapshot.data![value - 1]!)), colorFilter: disabled ? ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken) : null, fit: BoxFit.cover)));
           }
           return SudokuShape(id: shapeId, color: shapeColor);
         }
       );
    } else {
       content = SudokuShape(id: shapeId, color: shapeColor);
    }
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(color: disabled ? kRetroSurface : kRetroSurface.withOpacity(0.8), border: Border.all(color: disabled ? kRetroText.withOpacity(0.1) : kRetroHighlight, width: 2)),
        child: Padding(padding: const EdgeInsets.all(8), child: content),
      ),
    );
  }
  Color defaultColor(bool disabled) => disabled ? kRetroText.withOpacity(0.2) : kRetroHighlight;
}

class _PauseRestartDialog extends StatelessWidget {
  const _PauseRestartDialog({required this.onRestart, required this.onExitGame});
  final VoidCallback onRestart;
  final VoidCallback onExitGame;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('PAUSE', style: TextStyle(fontWeight: FontWeight.bold, color: kRetroHighlight, fontSize: 20, letterSpacing: 2)), const SizedBox(height: 24), Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [OutlinedButton(onPressed: onRestart, child: const Text('RESTART')), const SizedBox(height: 12), TextButton(onPressed: onExitGame, child: const Text('EXIT GAME'))])]),
      ),
    );
  }
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog({required this.levelNumber, required this.starsEarned, required this.timeTaken, required this.onNextLevel, required this.onClose});
  final int levelNumber; final int starsEarned; final String timeTaken; final VoidCallback onNextLevel; final VoidCallback onClose;
  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> with TickerProviderStateMixin {
  late List<AnimationController> _starControllers; late List<Animation<double>> _starAnimations;
  @override
  void initState() {
    super.initState();
    _starControllers = List<AnimationController>.generate(3, (int index) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _starAnimations = _starControllers.map((AnimationController c) => Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut))).toList();
    Future<void>.delayed(const Duration(milliseconds: 300), () { for (int i = 0; i < widget.starsEarned; i++) { Future<void>.delayed(Duration(milliseconds: i * 200), () { if (mounted) _starControllers[i].forward(); }); } });
  }
  @override
  void dispose() { for (final AnimationController controller in _starControllers) controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Dialog(child: Container(padding: const EdgeInsets.all(32), constraints: const BoxConstraints(maxWidth: 320), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('LEVEL COMPLETE', style: TextStyle(fontWeight: FontWeight.bold, color: kRetroHighlight, fontSize: 20, letterSpacing: 2)), const SizedBox(height: 24), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (index) { return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ScaleTransition(scale: _starAnimations[index], child: Icon(index < widget.starsEarned ? Icons.star : Icons.star_border, color: Colors.amber, size: 48))); })), const SizedBox(height: 16), Text('TIME: ${widget.timeTaken}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 32), Row(children: [Expanded(child: OutlinedButton(onPressed: widget.onClose, child: const Text('MENU'))), const SizedBox(width: 16), Expanded(child: ElevatedButton(onPressed: widget.onNextLevel, child: const Text('NEXT')))])])));
  }
}

class _MailToDeveloperDialog extends StatelessWidget {
  const _MailToDeveloperDialog();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(title: const Text('VERY HARD MODE'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Have an idea for a Very Hard mode? Mail the developer!'), const SizedBox(height: 16), SelectableText('muralibala789@gmail.com', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))]), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CLOSE'))]);
  }
}
