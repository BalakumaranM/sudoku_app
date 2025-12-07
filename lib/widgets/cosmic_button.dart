import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CosmicButtonType { primary, secondary, destructive }

class CosmicButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final CosmicButtonType type;
  final IconData? icon;
  final bool isFullWidth;

  const CosmicButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = CosmicButtonType.primary,
    this.icon,
    this.isFullWidth = true,
  }) : super(key: key);

  @override
  State<CosmicButton> createState() => _CosmicButtonState();
}

class _CosmicButtonState extends State<CosmicButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isPressed) {
      _isPressed = true;
      _scaleController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      _isPressed = false;
      _scaleController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _isPressed = false;
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onPressed,
          child: Container(
            width: widget.isFullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: _getDecoration(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: _getTextColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: _getTextColor(),
                    shadows: widget.type == CosmicButtonType.primary
                        ? [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration() {
    switch (widget.type) {
      case CosmicButtonType.primary:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4DD0E1), Color(0xFF00ACC1)], // Cyan gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4DD0E1).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case CosmicButtonType.secondary:
        return BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        );
      case CosmicButtonType.destructive:
        return BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        );
    }
  }

  Color _getTextColor() {
    switch (widget.type) {
      case CosmicButtonType.primary:
        return Colors.white;
      case CosmicButtonType.secondary:
        return Colors.white.withOpacity(0.9);
      case CosmicButtonType.destructive:
        return const Color(0xFFFF5252);
    }
  }
}
