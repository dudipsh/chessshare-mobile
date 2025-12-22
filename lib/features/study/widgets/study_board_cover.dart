import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class StudyBoardCover extends StatelessWidget {
  final String imageUrl;
  final bool isDark;

  const StudyBoardCover({
    super.key,
    required this.imageUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        child: const Center(child: Icon(Icons.image, size: 32, color: Colors.grey)),
      ),
      errorWidget: (_, __, ___) => Container(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.library_books,
            size: 40,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
