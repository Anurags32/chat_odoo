import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class Base64Avatar extends StatelessWidget {
  final String? base64String;
  final double radius;
  final String fallbackText;
  final Color? backgroundColor;
  final Color? textColor;

  const Base64Avatar({
    super.key,
    required this.base64String,
    this.radius = 20,
    this.fallbackText = '?',
    this.backgroundColor,
    this.textColor,
  });

  Uint8List? _decodeBase64() {
    if (base64String == null || base64String!.isEmpty) {
      return null;
    }

    try {
      // Remove data:image prefix if present
      String cleanBase64 = base64String!;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

      return base64Decode(cleanBase64);
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeBase64();

    if (imageBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(imageBytes),
        backgroundColor: backgroundColor ?? Colors.grey[300],
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('Error loading avatar image: $exception');
        },
      );
    }

    // Fallback to text avatar
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.blue,
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
