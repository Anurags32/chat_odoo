import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Pink and Orange shades
  static const Color pink1 = Color(0xFFFEBFD4); // rgba(254, 191, 212, 1)
  static const Color pink2 = Color(0xFFFFC7F2); // rgba(255, 199, 242, 1)
  static const Color orange1 = Color(0xFFF6921E); // rgba(246, 146, 30, 1)
  static const Color orange2 = Color(0xFFF89B44); // rgba(248, 155, 68, 1)
  static const Color purple1 = Color(
    0xFF965086,
  ); // rgb(150, 80, 134) - for buttons
  static const Color pinkLight = Color(0xFFFFD9E8);
  static const Color pinkDark = Color(0xFFFF9FD0);

  // White and neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F5);
  static const Color lightGrey = Color(0xFFE0E0E0);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF424242);
  static const Color black = Color(0xFF000000);

  // Functional colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color tealGreen = Color(0xFF2EC4B6);
  static const Color orange = Color(0xFFF5B544);
  static const Color purple = Color(0xFF8E4A7E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [pink1, pink2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [pink2, pinkLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Button gradient: linear-gradient(135deg, rgb(150, 80, 134) 2%, rgb(246, 146, 30) 100%)
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.02, 1.0],
    colors: [
      Color(0xFF965086), // rgb(150, 80, 134)
      Color(0xFFF6921E), // rgb(246, 146, 30)
    ],
  );

  // New background gradient matching the CSS linear-gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.24, 0.77, 1.0],
    colors: [
      Color(0x00F6921E), // rgba(246, 146, 30, 0) - transparent orange
      Color(0x52F89B44), // rgba(248, 155, 68, 0.32) - 32% opacity orange
      Color(0xB8FEBFD4), // rgba(254, 191, 212, 0.72) - 72% opacity pink
      Color(0x00FFC7F2), // rgba(255, 199, 242, 0) - transparent pink
    ],
  );
}
