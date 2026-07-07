import 'dart:io';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static final Map<String, String> _thumbnailCache = {};

  // ✅ GÉNÉRER UNE THUMBNAIL POUR UNE VIDÉO
  static Future<String?> generateThumbnail(String videoPath) async {
    // Vérifier le cache
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    try {
      // Générer la thumbnail
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        maxWidth: 200,
        quality: 75,
      );

      if (thumbnail != null) {
        _thumbnailCache[videoPath] = thumbnail;
        return thumbnail;
      }
    } catch (e) {
      print('⚠️ Erreur thumbnail: $e');
    }

    return null;
  }

  // ✅ OBTENIR LES BYTES DE LA THUMBNAIL (pour affichage rapide)
  static Future<Uint8List?> getThumbnailBytes(String videoPath) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        maxWidth: 200,
        quality: 75,
      );
      return thumbnail;
    } catch (e) {
      print('⚠️ Erreur thumbnail bytes: $e');
      return null;
    }
  }

  // ✅ VIDER LE CACHE
  static void clearCache() {
    _thumbnailCache.clear();
  }
}