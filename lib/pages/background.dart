import 'package:flutter/material.dart';
import 'package:mesh/mesh.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:zeniq_swap_frontend/theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final background = context.isDark ? Color(0xff141414) : Colors.white;
    return ColoredBox(
      color: background,
      child: OMeshGradient(
        tessellation: 2,
        mesh: OMeshRect(
          width: 3,
          height: 3,
          vertices: [
            (0.0, 0.0).v, (0.55, 0.0).v, (1.0, 0.0).v, // Row 1
            (-0.4, 0.4).v, (0.51, 0.4).v, (1.4, 0.4).v, // Row 2
            (0.0, 0.8).v, (0.49, 0.8).v, (1.0, 0.8).v, // Row 3
            (0.0, 1.0).v, (0.45, 1.0).v, (1.0, 1.0).v, // Row 4
          ],
          colors: [
            background, background, background, // Row 1
            background, primaryColor,
            background, // Row 2
            background, background, background, // Row 3
            background, background, background, // Row 4
          ],
          smoothColors: true,
          backgroundColor: background,
          colorSpace: OMeshColorSpace.lab,
        ),
      ),
    );
  }
}
