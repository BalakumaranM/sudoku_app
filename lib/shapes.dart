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
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
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
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
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
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
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

class PlanetPainter extends CustomPainter {
  final int planetId;
  PlanetPainter(this.planetId);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final Paint paint = Paint();
    List<Color> colors;
    switch(planetId) {
      case 1: colors = [Colors.grey, Colors.brown]; break;
      case 2: colors = [Colors.yellow[100]!, Colors.orangeAccent]; break; 
      case 3: colors = [Colors.blue, Colors.green]; break; 
      case 4: colors = [Colors.red, Colors.redAccent[700]!]; break; 
      case 5: colors = [Colors.orange, Colors.brown]; break; 
      case 6: colors = [Colors.amber, Colors.yellow[200]!]; break; 
      case 7: colors = [Colors.cyan[100]!, Colors.cyan]; break; 
      case 8: colors = [Colors.orangeAccent, Colors.yellow]; break; 
      case 9: colors = [Colors.grey[300]!, Colors.white]; break; 
      default: colors = [Colors.white, Colors.grey];
    }
    paint.shader = RadialGradient(colors: colors, center: Alignment.topLeft, radius: 1.2).createShader(Rect.fromCircle(center: center, radius: radius));
    if (planetId == 8) {
       canvas.drawCircle(center, radius + 4, Paint()..color = Colors.orange.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    canvas.drawCircle(center, radius, paint);
    if (planetId == 6 || planetId == 7) {
       final ringPaint = Paint()..color = Colors.white.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 3;
       canvas.drawOval(Rect.fromCenter(center: center, width: size.width + 4, height: size.height / 2), ringPaint);
    }
    if (planetId == 1 || planetId == 4 || planetId == 9) {
       final craterPaint = Paint()..color = Colors.black12;
       canvas.drawCircle(center + Offset(radius*0.3, -radius*0.3), radius*0.2, craterPaint);
       canvas.drawCircle(center + Offset(-radius*0.4, radius*0.2), radius*0.15, craterPaint);
    }
  }
  @override
  bool shouldRepaint(covariant PlanetPainter oldDelegate) => oldDelegate.planetId != planetId;
}

class CosmicPainter extends CustomPainter {
  final int cosmicId;
  CosmicPainter(this.cosmicId);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 2;
    
    switch (cosmicId) {
      case 1: _drawSun(canvas, center, radius); break;
      case 2: _drawCrescentMoon(canvas, center, radius); break;
      case 3: _drawStar(canvas, center, radius); break;
      case 4: _drawBolt(canvas, center, radius); break;
      case 5: _drawGalaxy(canvas, center, radius); break;
      case 6: _drawComet(canvas, center, radius); break;
      case 7: _drawRocket(canvas, center, radius); break;
      case 8: _drawBlackHole(canvas, center, radius); break;
      case 9: _drawNebula(canvas, center, radius); break;
      default: _drawSun(canvas, center, radius);
    }
  }
  
  void _drawSun(Canvas canvas, Offset center, double radius) {
    // Sun: RadialGradient (White→Yellow→Orange), blurred corona
    final Paint sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.yellow, Colors.orange],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    // Corona glow
    final Paint coronaPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(center, radius * 1.2, coronaPaint);
    
    canvas.drawCircle(center, radius, sunPaint);
  }
  
  void _drawCrescentMoon(Canvas canvas, Offset center, double radius) {
    // Crescent Moon: Path.combine difference, silvery-white, earthshine
    final Paint moonPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..style = PaintingStyle.fill;
    
    final Path outerPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final Path innerPath = Path()..addOval(Rect.fromCircle(center: center + Offset(radius * 0.3, 0), radius: radius * 0.8));
    final Path crescentPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    
    // Earthshine (subtle glow on dark side)
    final Paint earthshinePaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(crescentPath, earthshinePaint);
    
    canvas.drawPath(crescentPath, moonPaint);
  }
  
  void _drawStar(Canvas canvas, Offset center, double radius) {
    // Star: 5-pointed rounded, Gold→Amber gradient, glow
    final double outerRadius = radius * 0.7;
    final double innerRadius = radius * 0.3;
    final int points = 5;
    final double step = math.pi / points;
    
    final Path path = Path();
    double angle = -math.pi / 2;
    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += step;
    }
    path.close();
    
    // Glow
    final Paint glowPaint = Paint()
      ..color = Colors.amber.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(path, glowPaint);
    
    // Star with gradient
    final Paint starPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.amber, Colors.orange],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawPath(path, starPaint);
  }
  
  void _drawBolt(Canvas canvas, Offset center, double radius) {
    // Bolt: Lightning, neon (thick blurred cyan + thin white)
    final Path boltPath = Path()
      ..moveTo(center.dx - radius * 0.3, center.dy - radius * 0.5)
      ..lineTo(center.dx + radius * 0.1, center.dy - radius * 0.1)
      ..lineTo(center.dx - radius * 0.1, center.dy)
      ..lineTo(center.dx + radius * 0.3, center.dy + radius * 0.5)
      ..lineTo(center.dx - radius * 0.1, center.dy + radius * 0.3)
      ..lineTo(center.dx + radius * 0.1, center.dy + radius * 0.1)
      ..close();
    
    // Thick blurred cyan
    final Paint thickPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.15
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(boltPath, thickPaint);
    
    // Thin white
    final Paint thinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05;
    canvas.drawPath(boltPath, thinPaint);
  }
  
  void _drawGalaxy(Canvas canvas, Offset center, double radius) {
    // Galaxy: Spiral with SweepGradient (Pink→Purple→Blue), two arms, star dots
    final Paint spiralPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.pink, Colors.purple, Colors.blue, Colors.pink],
        stops: const [0.0, 0.33, 0.66, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    // Draw spiral arms
    final Path spiralPath = Path();
    for (double angle = 0; angle < math.pi * 4; angle += 0.1) {
      final double r = radius * (0.2 + (angle / (math.pi * 4)) * 0.6);
      final double x = center.dx + math.cos(angle) * r;
      final double y = center.dy + math.sin(angle) * r;
      if (angle == 0) {
        spiralPath.moveTo(x, y);
      } else {
        spiralPath.lineTo(x, y);
      }
    }
    spiralPaint.style = PaintingStyle.stroke;
    spiralPaint.strokeWidth = radius * 0.1;
    canvas.drawPath(spiralPath, spiralPaint);
    
    // Star dots
    final Paint starPaint = Paint()..color = Colors.white;
    for (int i = 0; i < 8; i++) {
      final double angle = (i / 8) * math.pi * 2;
      final double r = radius * (0.3 + (i % 3) * 0.15);
      canvas.drawCircle(
        center + Offset(math.cos(angle) * r, math.sin(angle) * r),
        radius * 0.05,
        starPaint,
      );
    }
  }
  
  void _drawComet(Canvas canvas, Offset center, double radius) {
    // Comet: Ice blue/white ball, LinearGradient tail (Blue→Transparent)
    final double cometRadius = radius * 0.3;
    final Offset cometCenter = center + Offset(-radius * 0.2, 0);
    
    // Tail
    final Paint tailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [Colors.blue, Colors.blue.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(center.dx - radius, center.dy - radius * 0.2, radius * 1.5, radius * 0.4));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - radius, center.dy - radius * 0.2, radius * 1.5, radius * 0.4),
        Radius.circular(radius * 0.2),
      ),
      tailPaint,
    );
    
    // Comet head
    final Paint cometPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.lightBlue, Colors.blue],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: cometCenter, radius: cometRadius));
    canvas.drawCircle(cometCenter, cometRadius, cometPaint);
  }
  
  void _drawRocket(Canvas canvas, Offset center, double radius) {
    // Rocket: Retro rocket (silver gradient, red fins, window, flame)
    final double rocketWidth = radius * 0.4;
    final double rocketHeight = radius * 1.2;
    
    // Body (silver gradient)
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white70, Colors.grey, Colors.white70],
      ).createShader(Rect.fromCenter(center: center, width: rocketWidth, height: rocketHeight));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: rocketWidth, height: rocketHeight),
        Radius.circular(rocketWidth / 4),
      ),
      bodyPaint,
    );
    
    // Window
    final Paint windowPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(center + Offset(0, -rocketHeight * 0.2), radius * 0.08, windowPaint);
    
    // Fins (red)
    final Paint finPaint = Paint()..color = Colors.red;
    final Path finPath = Path()
      ..moveTo(center.dx - rocketWidth / 2, center.dy + rocketHeight / 2)
      ..lineTo(center.dx - rocketWidth / 2 - radius * 0.15, center.dy + rocketHeight / 2 + radius * 0.2)
      ..lineTo(center.dx - rocketWidth / 2, center.dy + rocketHeight / 2 + radius * 0.15)
      ..close();
    canvas.drawPath(finPath, finPaint);
    final Path finPath2 = Path()
      ..moveTo(center.dx + rocketWidth / 2, center.dy + rocketHeight / 2)
      ..lineTo(center.dx + rocketWidth / 2 + radius * 0.15, center.dy + rocketHeight / 2 + radius * 0.2)
      ..lineTo(center.dx + rocketWidth / 2, center.dy + rocketHeight / 2 + radius * 0.15)
      ..close();
    canvas.drawPath(finPath2, finPaint);
    
    // Flame
    final Paint flamePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.orange, Colors.red, Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center + Offset(0, rocketHeight / 2 + radius * 0.2), radius: radius * 0.15));
    canvas.drawCircle(center + Offset(0, rocketHeight / 2 + radius * 0.2), radius * 0.15, flamePaint);
  }
  
  void _drawBlackHole(Canvas canvas, Offset center, double radius) {
    // Black Hole: Black circle, glowing accretion disk (SweepGradient Orange→Red→Transparent)
    // Accretion disk
    final Paint diskPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.orange, Colors.red, Colors.transparent, Colors.transparent],
        stops: const [0.0, 0.3, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.8));
    canvas.drawCircle(center, radius * 0.8, diskPaint);
    
    // Black hole center
    final Paint blackPaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, radius * 0.4, blackPaint);
    
    // Glow
    final Paint glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(center, radius * 0.9, glowPaint);
  }
  
  void _drawNebula(Canvas canvas, Offset center, double radius) {
    // Nebula: Amorphous cloud (3-4 blurred circles Deep Purple/Magenta, 3 white stars)
    final Paint nebulaPaint = Paint()
      ..color = Colors.deepPurple.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    
    // Draw 3-4 blurred circles
    canvas.drawCircle(center + Offset(-radius * 0.2, -radius * 0.1), radius * 0.5, nebulaPaint);
    canvas.drawCircle(center + Offset(radius * 0.2, radius * 0.1), radius * 0.4, nebulaPaint);
    canvas.drawCircle(center + Offset(0, radius * 0.2), radius * 0.35, nebulaPaint);
    
    final Paint magentaPaint = Paint()
      ..color = Colors.pink.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(center + Offset(radius * 0.15, -radius * 0.15), radius * 0.3, magentaPaint);
    
    // 3 white stars
    final Paint starPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center + Offset(-radius * 0.3, -radius * 0.2), radius * 0.06, starPaint);
    canvas.drawCircle(center + Offset(radius * 0.25, radius * 0.15), radius * 0.05, starPaint);
    canvas.drawCircle(center + Offset(0, -radius * 0.3), radius * 0.07, starPaint);
  }
  
  @override
  bool shouldRepaint(covariant CosmicPainter oldDelegate) => oldDelegate.cosmicId != cosmicId;
}
