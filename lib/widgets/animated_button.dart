import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

/// A button wrapper that provides scale and opacity animations on press
/// Uses spring physics for natural bounce-back effect
class AnimatedButton extends StatefulWidget {
  const AnimatedButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.enabled = true,
    this.hapticFeedback = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final bool enabled;
  final bool hapticFeedback;

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late SpringSimulation _springSimulation;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Create spring simulation for natural bounce-back
    _springSimulation = SpringSimulation(
      SpringDescription(
        mass: 1.0,
        stiffness: 500.0,
        damping: 30.0,
      ),
      0.95, // start (pressed scale)
      1.0,  // end (normal scale)
      0.0,  // velocity
    );
    
    _scaleAnimation = _controller.drive(
      Tween<double>(begin: 1.0, end: 0.95),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onTapDown?.call();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
    // Use spring animation for bounce-back
    _controller.animateWith(_springSimulation);
    widget.onTapUp?.call();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
    // Use spring animation for bounce-back
    _controller.animateWith(_springSimulation);
    widget.onTapCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.translucent, // Ensure taps are caught even on transparent parts
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: Opacity(
              opacity: _isPressed ? 0.8 : 1.0,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
