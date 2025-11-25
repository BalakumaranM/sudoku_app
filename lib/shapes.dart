import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders one of nine abstract shapes to represent Sudoku symbols.
class SudokuShape extends StatelessWidget {
  const SudokuShape({super.key, required this.id, required this.color});

  /// Shape identifier, using values 1-9.
  final int id;

  /// Primary fill color used to render the shape.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _SudokuShapePainter(id: id, color: color),
        isComplex: true,
      ),
    );
  }
}

class _SudokuShapePainter extends CustomPainter {
  const _SudokuShapePainter({required this.id, required this.color});

  final int id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double minSide = math.min(size.width, size.height);
    final Rect bounds = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: minSide,
      height: minSide,
    );

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Shapes: Square, Rectangle, Circle, Triangle, Star, Ellipse, Dot, Line, Pentagon
    switch (id) {
      case 1: _drawSquare(canvas, bounds, paint); break;
      case 2: _drawRectangle(canvas, bounds, paint); break;
      case 3: _drawCircle(canvas, bounds, paint, radiusFactor: 0.38); break;
      case 4: _drawTriangle(canvas, bounds, paint); break;
      case 5: _drawStar(canvas, bounds, paint); break;
      case 6: _drawEllipse(canvas, bounds, paint); break;
      case 7: _drawCircle(canvas, bounds, paint, radiusFactor: 0.15); break; // Dot
      case 8: _drawLine(canvas, bounds, paint); break;
      case 9: _drawPentagon(canvas, bounds, paint); break;
      default: _drawCircle(canvas, bounds, paint, radiusFactor: 0.1);
    }
  }

  void _drawSquare(Canvas canvas, Rect bounds, Paint paint) {
    final double inset = bounds.width * 0.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.deflate(inset),
        Radius.circular(bounds.width * 0.05),
      ),
      paint,
    );
  }

  void _drawRectangle(Canvas canvas, Rect bounds, Paint paint) {
    final double width = bounds.width * 0.7;
    final double height = bounds.height * 0.4;
    final Rect rect = Rect.fromCenter(
      center: bounds.center,
      width: width,
      height: height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(bounds.width * 0.05)),
      paint,
    );
  }

  void _drawCircle(Canvas canvas, Rect bounds, Paint paint, {required double radiusFactor}) {
    canvas.drawCircle(bounds.center, bounds.width * radiusFactor, paint);
  }

  void _drawTriangle(Canvas canvas, Rect bounds, Paint paint) {
    final double padding = bounds.width * 0.2;
    final Path path = Path()
      ..moveTo(bounds.center.dx, bounds.top + padding)
      ..lineTo(bounds.right - padding, bounds.bottom - padding)
      ..lineTo(bounds.left + padding, bounds.bottom - padding)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Rect bounds, Paint paint) {
    final double cx = bounds.center.dx;
    final double cy = bounds.center.dy;
    final double outerRadius = bounds.width * 0.35;
    final double innerRadius = bounds.width * 0.15;
    final int points = 5;
    final double step = math.pi / points;
    
    final Path path = Path();
    // Start at top (-pi/2)
    double angle = -math.pi / 2;
    
    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double x = cx + math.cos(angle) * r;
      final double y = cy + math.sin(angle) * r;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      angle += step;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawEllipse(Canvas canvas, Rect bounds, Paint paint) {
    final double width = bounds.width * 0.8;
    final double height = bounds.height * 0.5;
    canvas.drawOval(
      Rect.fromCenter(center: bounds.center, width: width, height: height),
      paint,
    );
  }

  void _drawLine(Canvas canvas, Rect bounds, Paint paint) {
    final double width = bounds.width * 0.15;
    final Rect rect = Rect.fromCenter(
      center: bounds.center,
      width: width,
      height: bounds.height * 0.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width / 2)),
      paint,
    );
  }

  void _drawPentagon(Canvas canvas, Rect bounds, Paint paint) {
    final double cx = bounds.center.dx;
    final double cy = bounds.center.dy;
    final double radius = bounds.width * 0.35;
    final int sides = 5;
    
    final Path path = Path();
    for (int i = 0; i < sides; i++) {
      final double angle = -math.pi / 2 + (i * 2 * math.pi / sides);
      final double x = cx + math.cos(angle) * radius;
      final double y = cy + math.sin(angle) * radius;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SudokuShapePainter oldDelegate) {
    return oldDelegate.id != id || oldDelegate.color != color;
  }
}
