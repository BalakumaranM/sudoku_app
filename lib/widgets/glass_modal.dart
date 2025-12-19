import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import 'cosmic_button.dart'; // For GlassBevelPainter

/// A reusable glassmorphism modal dialog with backdrop blur
class GlassModal {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.7),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              minWidth: 300,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: const Color(0xFF4DD0E1).withValues(alpha: 0.1), // Subtle cyan glow
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 1. Background Gradient & Blur
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1A1F3A).withValues(alpha: 0.60),
                              const Color(0xFF0A0E27).withValues(alpha: 0.80),
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: 'Orbitron',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: kCosmicPrimary,
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: child,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Glass Bevel Border
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: GlassBevelPainter(
                          borderRadius: BorderRadius.circular(24),
                          borderColor: Colors.white.withValues(alpha: 0.1),
                          isPressed: false,
                        ),
                      ),
                    ),
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
