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
    // Radius covers 90% of the cell (0.45 * 2 = 0.9)
    final double radius = size.width * 0.45;
    final Offset center = size.center(Offset.zero);

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Helper paint for rounded corners on polygons
    final Paint roundedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.15
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    switch (id) {
      case 1: _drawCircle(canvas, center, radius, paint); break;
      case 2: _drawRoundedSquare(canvas, center, radius, paint); break;
      case 3: _drawTriangle(canvas, center, radius, paint, roundedPaint); break;
      case 4: _drawCapsule(canvas, center, radius, paint); break;
      case 5: _drawDiamond(canvas, center, radius, paint, roundedPaint); break;
      case 6: _drawFatStar(canvas, center, radius, paint, roundedPaint); break;
      case 7: _drawHexagon(canvas, center, radius, paint, roundedPaint); break;
      case 8: _drawTeardrop(canvas, center, radius, paint, roundedPaint); break;
      case 9: _drawPentagon(canvas, center, radius, paint, roundedPaint); break;
      default: _drawCircle(canvas, center, radius, paint);
    }
  }

  void _drawCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
  }

  void _drawRoundedSquare(Canvas canvas, Offset center, double radius, Paint paint) {
    final double side = radius * 1.8;
    final Rect rect = Rect.fromCenter(center: center, width: side, height: side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(side * 0.2)),
      paint,
    );
  }

  void _drawTriangle(Canvas canvas, Offset center, double radius, Paint paint, Paint roundedPaint) {
    // Equilateral triangle pointing UP
    final double h = radius * 1.8;
    final double w = h * 1.155; // h / (sqrt(3)/2)
    final double yTop = center.dy - (2/3 * h * 0.6); // Adjust visual center
    final double yBottom = yTop + h;
    
    final Path path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy + radius * 0.8)
      ..lineTo(center.dx - radius, center.dy + radius * 0.8)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, roundedPaint);
  }

  void _drawCapsule(Canvas canvas, Offset center, double radius, Paint paint) {
    final double w = radius * 1.2;
    final double h = radius * 2.0;
    final Rect rect = Rect.fromCenter(center: center, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w / 2)),
      paint,
    );
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Paint paint, Paint roundedPaint) {
    final Path path = Path()
      ..moveTo(center.dx, center.dy - radius) // Top
      ..lineTo(center.dx + radius, center.dy) // Right
      ..lineTo(center.dx, center.dy + radius) // Bottom
      ..lineTo(center.dx - radius, center.dy) // Left
      ..close();
      
    canvas.drawPath(path, paint);
    canvas.drawPath(path, roundedPaint);
  }

  void _drawFatStar(Canvas canvas, Offset center, double radius, Paint paint, Paint roundedPaint) {
    final double outerRadius = radius;
    final double innerRadius = radius * 0.55; // Chubby
    final int points = 5;
    final double step = math.pi / points;
    
    final Path path = Path();
    double angle = -math.pi / 2;
    
    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      angle += step;
    }
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, roundedPaint);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint, Paint roundedPaint) {
    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = -math.pi / 2 + (i * math.pi / 3); // Start at top
      final double x = center.dx + math.cos(angle) * radius;
      final double y = center.dy + math.sin(angle) * radius;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, roundedPaint);
  }

  void _drawTeardrop(Canvas canvas, Offset center, double radius, Paint paint, Paint roundedPaint) {
    // Circular bottom, pointy top
    final double r = radius * 0.7;
    final double cy = center.dy + radius * 0.25;
    
    final Path path = Path();
    path.moveTo(center.dx, center.dy - radius); // Top point
    
    // Draw cone sides + bottom circle
    // Tangent points on circle are slightly below 0 and 180 degrees relative to circle center?
    // Simple approximation: Line to 3 o'clock, Arc to 9 o'clock, Line to Top
    
    path.lineTo(center.dx + r, cy);
    path.arcTo(Rect.fromCircle(center: Offset(center.dx, cy), radius: r), 0, math.pi, false);
    path.lineTo(center.dx, center.dy - radius);
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, roundedPaint);
  }

  void _drawPentagon(Canvas canvas, Offset center, double radius, Paint paint, Paint roundedPaint) {
    // Pointy top (House shape)
    final Path path = Path();
    for (int i = 0; i < 5; i++) {
      final double angle = -math.pi / 2 + (i * 2 * math.pi / 5);
      final double x = center.dx + math.cos(angle) * radius;
      final double y = center.dy + math.sin(angle) * radius;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, roundedPaint);
  }

  @override
  bool shouldRepaint(covariant _SudokuShapePainter oldDelegate) {
    return oldDelegate.id != id || oldDelegate.color != color;
  }
}
