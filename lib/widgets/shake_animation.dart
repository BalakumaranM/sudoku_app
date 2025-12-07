import 'package:flutter/material.dart';

/// A widget that applies a horizontal shake animation when triggered
class ShakeAnimation extends StatefulWidget {
  const ShakeAnimation({
    super.key,
    required this.child,
    required this.shouldShake,
  });

  final Widget child;
  final bool shouldShake;

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldShake && !oldWidget.shouldShake) {
      _controller.forward(from: 0).then((_) {
        _controller.reset();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getShakeOffset(double animationValue) {
    // Create shake pattern: -8, 8, -8, 8, 0
    if (animationValue < 0.2) {
      return -8 * (animationValue / 0.2);
    } else if (animationValue < 0.4) {
      return 8 * ((animationValue - 0.2) / 0.2);
    } else if (animationValue < 0.6) {
      return -8 * ((animationValue - 0.4) / 0.2);
    } else if (animationValue < 0.8) {
      return 8 * ((animationValue - 0.6) / 0.2);
    } else {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_getShakeOffset(_shakeAnimation.value), 0),
          child: widget.child,
        );
      },
    );
  }
}
