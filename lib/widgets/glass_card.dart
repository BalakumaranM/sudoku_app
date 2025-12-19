import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import 'cosmic_button.dart';

/// A reusable glassmorphism card component
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderWidth = 1.5,
    this.borderRadius = 20.0,
    this.padding,
    this.margin,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? kCosmicPrimary;
    final effectiveBorderColor = borderColor ?? effectiveColor.withValues(alpha: 0.6);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Details: Glass Background
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      effectiveColor.withValues(alpha: 0.1),
                      effectiveColor.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
          
          // 2. Bevel Border
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: GlassBevelPainter(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderColor: enabled ? effectiveBorderColor : effectiveBorderColor.withValues(alpha: 0.3),
                  isPressed: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null && enabled) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }

    return card;
  }
}
