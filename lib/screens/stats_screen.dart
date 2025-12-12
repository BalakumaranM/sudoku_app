import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/game_enums.dart';
import '../utils/stats_repository.dart';
import '../utils/sound_manager.dart';

// Cosmic color constants
const Color kCosmicBackground = Color(0xFF0B0F19);
const Color kCosmicPrimary = Color(0xFF00F0FF);
const Color kCosmicSecondary = Color(0xFF7000FF);
const Color kCosmicAccent = Color(0xFFFF00E5);
const Color kCosmicText = Color(0xFFE0E6FF);

class StatsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const StatsScreen({super.key, this.onBack});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  Difficulty _classicDifficulty = Difficulty.easy;
  SudokuSize _classicSize = SudokuSize.standard; // Default to Standard (9x9)
  Difficulty _crazyDifficulty = Difficulty.easy;
  
  CategoryStats? _classicStats;
  CategoryStats? _crazyStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _loadStats();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    final classic = await StatsRepository.getClassicStats(_classicDifficulty, _classicSize);
    final crazy = await StatsRepository.getCrazyStats(_crazyDifficulty);
    
    setState(() {
      _classicStats = classic;
      _crazyStats = crazy;
      _isLoading = false;
    });
    
    _fadeController.forward(from: 0);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCosmicBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kCosmicBackground,
              const Color(0xFF1A1F3A),
              kCosmicBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildCategoryTab(
                              isClassic: true,
                              stats: _classicStats,
                              difficulty: _classicDifficulty,
                              onDifficultyChanged: (d) {
                                setState(() => _classicDifficulty = d);
                                _loadStats();
                              },
                            ),
                            _buildCategoryTab(
                              isClassic: false,
                              stats: _crazyStats,
                              difficulty: _crazyDifficulty,
                              onDifficultyChanged: (d) {
                                setState(() => _crazyDifficulty = d);
                                _loadStats();
                              },
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // No back button needed - use swipe gesture to go back
    return Container(
      padding: const EdgeInsets.all(20),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [kCosmicPrimary, kCosmicAccent],
        ).createShader(bounds),
        child: const Text(
          'STATISTICS',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [kCosmicPrimary.withValues(alpha: 0.3), kCosmicSecondary.withValues(alpha: 0.3)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: kCosmicPrimary,
        unselectedLabelColor: kCosmicText.withValues(alpha: 0.5),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_on, size: 20),
                SizedBox(width: 8),
                Text('Classic Sudoku'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 20),
                SizedBox(width: 8),
                Text('Crazy Sudoku'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(kCosmicPrimary),
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildCategoryTab({
    required bool isClassic,
    required CategoryStats? stats,
    required Difficulty difficulty,
    required Function(Difficulty) onDifficultyChanged,
  }) {
    if (stats == null) return const SizedBox();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDifficultySelector(difficulty, onDifficultyChanged),
          const SizedBox(height: 12),
          if (isClassic) ...[
            _buildSizeSelector(),
            const SizedBox(height: 20),
          ] else 
            const SizedBox(height: 20),
          if (!stats.isUnlocked)
            _buildLockedCard()
          else ...[
            _buildProgressCard(stats),
            const SizedBox(height: 20),
            _buildTimeGraph(stats),
            const SizedBox(height: 20),
            _buildMistakesGraph(stats),
          ],
        ],
      ),
    );
  }

  Widget _buildSizeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Text(
            'Size:',
            style: TextStyle(color: kCosmicText.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                _buildSizeOption(SudokuSize.mini, 'Mini (6x6)'),
                const SizedBox(width: 8),
                _buildSizeOption(SudokuSize.standard, 'Standard (9x9)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeOption(SudokuSize size, String label) {
    final isSelected = _classicSize == size;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() => _classicSize = size);
          _loadStats();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? kCosmicPrimary.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? kCosmicPrimary 
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kCosmicPrimary : kCosmicText.withValues(alpha: 0.6),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultySelector(
    Difficulty current,
    Function(Difficulty) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Text(
            'Difficulty:',
            style: TextStyle(color: kCosmicText.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: Difficulty.values.map((d) {
                  final isSelected = d == current;
                  return GestureDetector(
                    onTap: () => onChanged(d),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? _getDifficultyColor(d).withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected 
                              ? _getDifficultyColor(d)
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        _getDifficultyName(d),
                        style: TextStyle(
                          color: isSelected ? _getDifficultyColor(d) : kCosmicText.withValues(alpha: 0.6),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.4), size: 48),
          const SizedBox(height: 16),
          Text(
            'Complete 3 Expert levels to unlock',
            style: TextStyle(color: kCosmicText.withValues(alpha: 0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(CategoryStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kCosmicPrimary.withValues(alpha: 0.1),
            kCosmicSecondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCosmicPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: kCosmicText.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${stats.levelsCompleted}/${stats.totalLevels}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.completionPercentage / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(kCosmicPrimary),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('Avg Time', stats.formattedAvgTime, Icons.timer_outlined),
              _buildQuickStat('Best Time', stats.formattedBestTime, Icons.emoji_events_outlined),
              _buildQuickStat('Avg Mistakes', stats.avgMistakes.toStringAsFixed(1), Icons.error_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kCosmicPrimary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: kCosmicText.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeGraph(CategoryStats stats) {
    final completedLevels = stats.levelDetails.where((l) => l.isCompleted).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: kCosmicPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'TIME PER LEVEL',
                style: TextStyle(
                  color: kCosmicText.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: completedLevels.isEmpty
                ? Center(
                    child: Text(
                      'Complete levels to see your progress',
                      style: TextStyle(color: kCosmicText.withValues(alpha: 0.5)),
                    ),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 150),
                    painter: _TimeGraphPainter(completedLevels),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMistakesGraph(CategoryStats stats) {
    final completedLevels = stats.levelDetails.where((l) => l.isCompleted).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: kCosmicAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'MISTAKES PER LEVEL',
                style: TextStyle(
                  color: kCosmicText.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: completedLevels.isEmpty
                ? Center(
                    child: Text(
                      'Complete levels to see your progress',
                      style: TextStyle(color: kCosmicText.withValues(alpha: 0.5)),
                    ),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: _MistakesGraphPainter(completedLevels),
                  ),
          ),
        ],
      ),
    );
  }

  String _getDifficultyName(Difficulty d) {
    switch (d) {
      case Difficulty.easy: return 'Easy';
      case Difficulty.medium: return 'Medium';
      case Difficulty.hard: return 'Hard';
      case Difficulty.expert: return 'Expert';
      case Difficulty.master: return 'Master';
    }
  }

  Color _getDifficultyColor(Difficulty d) {
    switch (d) {
      case Difficulty.easy: return const Color(0xFF4CAF50);
      case Difficulty.medium: return const Color(0xFFFFEB3B);
      case Difficulty.hard: return const Color(0xFFFF9800);
      case Difficulty.expert: return const Color(0xFFF44336);
      case Difficulty.master: return const Color(0xFF9C27B0);
    }
  }
}

/// Line graph painter for time visualization
class _TimeGraphPainter extends CustomPainter {
  final List<LevelDetail> levels;
  
  _TimeGraphPainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    
    final maxTime = levels.map((l) => l.timeSeconds).reduce(math.max).toDouble();
    if (maxTime == 0) return;
    
    final path = Path();
    final paint = Paint()
      ..color = kCosmicPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kCosmicPrimary.withValues(alpha: 0.3), kCosmicPrimary.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final dotPaint = Paint()
      ..color = kCosmicPrimary
      ..style = PaintingStyle.fill;
    
    final spacing = size.width / (levels.length - 1).clamp(1, 50);
    
    for (int i = 0; i < levels.length; i++) {
      final x = i * spacing;
      final y = size.height - (levels[i].timeSeconds / maxTime) * (size.height - 20);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // Draw dot
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    
    // Draw fill
    final fillPath = Path.from(path)
      ..lineTo((levels.length - 1) * spacing, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    canvas.drawPath(path, paint);
    
    // Draw Y-axis labels (5 tick marks: 0, 25%, 50%, 75%, 100%)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelStyle = TextStyle(color: kCosmicText.withValues(alpha: 0.4), fontSize: 10);
    
    for (int i = 0; i <= 4; i++) {
      final percent = i / 4.0;
      final timeValue = (maxTime * percent).toInt();
      final minutes = timeValue ~/ 60;
      final seconds = timeValue % 60;
      final label = minutes > 0 ? '${minutes}m${seconds > 0 ? '${seconds}s' : ''}' : '${seconds}s';
      final y = size.height - percent * (size.height - 20);
      
      textPainter.text = TextSpan(text: label, style: labelStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TimeGraphPainter oldDelegate) => true;
}

/// Bar graph painter for mistakes visualization
class _MistakesGraphPainter extends CustomPainter {
  final List<LevelDetail> levels;
  
  _MistakesGraphPainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    
    final maxMistakes = levels.map((l) => l.mistakes).reduce(math.max).toDouble();
    final effectiveMax = maxMistakes == 0 ? 4.0 : maxMistakes;
    
    final barWidth = (size.width / levels.length) * 0.6;
    final spacing = size.width / levels.length;
    
    for (int i = 0; i < levels.length; i++) {
      final mistakes = levels[i].mistakes;
      final barHeight = (mistakes / effectiveMax) * (size.height - 20);
      final x = i * spacing + (spacing - barWidth) / 2;
      final y = size.height - barHeight;
      
      // Gradient based on mistakes count
      final color = mistakes == 0 
          ? kCosmicPrimary 
          : mistakes <= 1 
              ? const Color(0xFF4CAF50) 
              : mistakes <= 2 
                  ? const Color(0xFFFFEB3B) 
                  : kCosmicAccent;
      
      final paint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;
      
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, barWidth, barHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, paint);
  }
  
  // Draw Y-axis labels (integer values up to max)
  final textPainter = TextPainter(textDirection: TextDirection.ltr);
  final labelStyle = TextStyle(color: kCosmicText.withValues(alpha: 0.4), fontSize: 10);
  final labelsCount = effectiveMax.toInt().clamp(1, 5);
  
  for (int i = 0; i <= labelsCount; i++) {
    final value = (effectiveMax * i / labelsCount).round();
    final y = size.height - (i / labelsCount) * (size.height - 20);
    
    textPainter.text = TextSpan(text: '$value', style: labelStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
  }
}

  @override
  bool shouldRepaint(covariant _MistakesGraphPainter oldDelegate) => true;
}
