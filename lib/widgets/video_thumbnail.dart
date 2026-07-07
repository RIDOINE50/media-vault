import 'dart:io';
import 'package:flutter/material.dart';
import '../models/media_file.dart';

class VideoThumbnail extends StatelessWidget {
  final MediaFile mediaFile;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const VideoThumbnail({
    Key? key,
    required this.mediaFile,
    this.width = 200,
    this.height = 200,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: _buildThumbnail(),
    );
  }

  Widget _buildThumbnail() {
    // ✅ Si on a une URL de thumbnail (YouTube), l'utiliser
    if (mediaFile.thumbnailUrl != null && mediaFile.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        mediaFile.thumbnailUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) {
          return _buildPlaceholder();
        },
      );
    }
    
    // ✅ Sinon, afficher une icône par défaut
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: mediaFile.isVideo
              ? [Colors.blue.withOpacity(0.4), Colors.blue.withOpacity(0.2)]
              : [Colors.purple.withOpacity(0.4), Colors.purple.withOpacity(0.2)],
        ),
      ),
      child: Icon(
        mediaFile.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}