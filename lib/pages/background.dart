import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0xEF000000),
      child: OMeshGradient(
        mesh: OMeshRect(
          width: 3,
          height: 3,
          vertices: [
            (0.0, 0.0).v, (0.5, 0.0).v, (1.0, 0.0).v, // Row 1
            (-0.4, 0.4).v, (0.5, 0.4).v, (1.4, 0.4).v, // Row 2
            (0.0, 0.8).v, (0.5, 0.8).v, (1.0, 0.8).v, // Row 3
            (0.0, 1.0).v, (0.5, 1.0).v, (1.0, 1.0).v, // Row 4
          ],
          colors: const [
            Colors.transparent, Colors.transparent, Colors.transparent, // Row 1
            Colors.transparent, primaryColor,
            Colors.transparent, // Row 2
            Colors.transparent, Colors.transparent, Colors.transparent, // Row 3
            Colors.transparent, Colors.transparent, Colors.transparent, // Row 4
          ],
        ),
      ),
    );
  }
}
