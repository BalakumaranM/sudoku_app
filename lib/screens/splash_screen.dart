import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../main.dart'; // Import for SudokuSectionScreen or SudokuGameApp

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    // Wait for animation
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreenWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.white, // Match native splash background
      body: Stack(
        fit: StackFit.expand, // Cover entire screen
        children: [
          // Background Image (Matches native splash for seamless transition)
          Image.asset(
            'assets/icons/splash.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Cool Loading Animation Overlay
          Positioned(
            bottom: size.height * 0.15, // Position near bottom
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A0DAD)), // Cosmic Purple
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  duration: const Duration(milliseconds: 1000),
                  child: const Text(
                    "Entering the Cosmos...",
                    style: TextStyle(
                      fontFamily: 'Orbitron', // Assuming Orbitron is available/used in app
                      color: Color(0xFF180034), // Dark cosmic Text
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
