import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CosmicButtonType { primary, secondary, destructive }

class CosmicButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final CosmicButtonType type;
  final IconData? icon;
  final bool isFullWidth;
  final double height;
  final double? width;

  final String? subtitle;

  const CosmicButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = CosmicButtonType.primary,
    this.icon,
    this.isFullWidth = true,
    this.height = 72, 
    this.width,
    this.subtitle,
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
      setState(() => _isPressed = true);
      _scaleController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _scaleController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _scaleController.reverse();
    }
  }

  List<Color> _getGradientColors() {
    switch (widget.type) {
      case CosmicButtonType.primary:
        return [
          const Color(0xFF00F2FE).withValues(alpha: 0.3),
          const Color(0xFF4FACFE).withValues(alpha: 0.4),
        ];
      case CosmicButtonType.secondary:
        return [
          const Color(0xFF7000FF).withValues(alpha: 0.3), // Purple/Cosmic Secondary
          const Color(0xFF00C6FF).withValues(alpha: 0.2),
        ];
      case CosmicButtonType.destructive:
        return [
          const Color(0xFFFF512F).withValues(alpha: 0.3),
          const Color(0xFFDD2476).withValues(alpha: 0.4),
        ];
    }
  }

  Color _getBorderColor() {
    switch (widget.type) {
      case CosmicButtonType.primary:
        return const Color(0xFF00F2FE).withValues(alpha: 0.5);
      case CosmicButtonType.secondary:
        return const Color(0xFF7000FF).withValues(alpha: 0.5);
      case CosmicButtonType.destructive:
        return const Color(0xFFFF512F).withValues(alpha: 0.5);
    }
  }

  Color _getTextColor() {
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    // If subtitle exists, ensuring enough height if not manually overridden (though users should pass adequate height)
    final double effectiveHeight = widget.subtitle != null && widget.height < 80 
        ? 84.0 
        : widget.height;
        
    final borderRadius = BorderRadius.circular(effectiveHeight / 2);
    final gradientColors = _getGradientColors();

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
            width: widget.isFullWidth ? double.infinity : widget.width,
            height: effectiveHeight,
            decoration: BoxDecoration(
              boxShadow: widget.type != CosmicButtonType.secondary // Less shadow for secondary to avoid clutter
                  ? [
                      BoxShadow(
                        color: gradientColors[0].withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // 1. Blur Effect
                ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Inner Shadows & Highlights
                CustomPaint(
                  painter: GlassBevelPainter(
                    borderRadius: borderRadius,
                    borderColor: _getBorderColor(),
                    isPressed: _isPressed,
                  ),
                  child: Container(),
                ),

                // 3. Content
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: _getTextColor(),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.text.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: widget.subtitle != null ? 18 : 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: _getTextColor(),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: _getTextColor().withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

class GlassBevelPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final Color borderColor;
  final bool isPressed;

  GlassBevelPainter({
    required this.borderRadius,
    required this.borderColor,
    required this.isPressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // 1. Top/Left Highlight (White Inner Shadow)
    // (Logic moved to internal drawRRect for efficiency)
    
    // For inner shadow, we clip to the shape, then draw a shifted shape outside and blur it.
    // Standard technique:
    // a. Save layer
    // b. Clip to shape
    // c. Draw shadow-casting shape outside
    // d. Restore

    // Top-Left Highlight (Internal)
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1)), // Slight offset down
      Paint()
        ..color = Colors.white.withValues(alpha: isPressed ? 0.1 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.restore();

    // 2. Bottom/Right Shadow (Dark Inner Shadow)
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      rrect.shift(const Offset(0, -1)), // Slight offset up
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();

    // 3. Border Stroke (Gradient or Solid)
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = borderColor;

    canvas.drawRRect(rrect.deflate(0.5), borderPaint);
    
    // 4. Subtle "Shine" Overlay (Gradient from top-left)
    final Paint shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);
    
    canvas.drawRRect(rrect, shinePaint);
  }

  @override
  bool shouldRepaint(covariant GlassBevelPainter oldDelegate) {
    return oldDelegate.isPressed != isPressed ||
        oldDelegate.borderColor != borderColor;
  }
}
