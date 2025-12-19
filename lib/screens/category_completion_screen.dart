import 'package:flutter/material.dart';
import '../models/game_enums.dart'; // Ensure correct import path
// import '../utils/sound_manager.dart'; // Uncomment if sound manager is needed directly here
import '../widgets/cosmic_button.dart'; // Ensure correct path
import '../widgets/glass_modal.dart';   // Ensure correct path - using for style hints if needed, or similar aesthetic

class CategoryCompletionScreen extends StatelessWidget {
  final Difficulty difficulty;
  final VoidCallback onReturnToMenu;

  const CategoryCompletionScreen({
    super.key,
    required this.difficulty,
    required this.onReturnToMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // kCosmicBackground
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B0F19),
              Color(0xFF1A1F3A),
              Color(0xFF0B0F19),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Trophy / Celebration Icon
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 100,
                  color: Color(0xFFFFD700), // Gold
                ),
                const SizedBox(height: 32),
                
                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00F0FF), Color(0xFF7000FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'COMPLETED!',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  'You have mastered\n${difficulty.name.toUpperCase()} mode.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Stats Summary (Placeholder for now, could act as "fun stats")
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Total Levels: 200',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All levels solved!',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Action Button
                CosmicButton(
                  text: 'RETURN TO MENU',
                  icon: Icons.home,
                  onPressed: onReturnToMenu,
                  isFullWidth: true,
                  height: 56,
                  type: CosmicButtonType.primary,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
