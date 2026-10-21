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
    if (base64String == null ||
        base64String!.isEmpty ||
        base64String == 'false' ||
        base64String == 'null' ||
        base64String!.length < 50) {
      return null;
    }

    try {
      // Remove data:image prefix if present
      String cleanBase64 = base64String!.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

      final bytes = base64Decode(cleanBase64);
      if (bytes.length < 8 || !_isValidImageHeader(bytes)) {
        return null;
      }
      return bytes;
    } catch (e) {
      return null;
    }
  }

  static bool _isValidImageHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // GIF: 47 49 46 (GIF87a / GIF89a)
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP: 52 49 46 46 ... 57 45 42 50 (RIFF....WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }
    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;

    return false;
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
