import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ThumbnailService {
  static final Map<String, String> _thumbnailCache = {};

  // ✅ Pour l'instant, on utilise les thumbnails YouTube directement
  // ou on affiche une icône par défaut pour les vidéos locales
  static Future<String?> generateThumbnail(String videoPath) async {
    // Vérifier le cache
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }
    
    // Pour l'instant, retourner null (on utilisera les icônes par défaut)
    // ou les thumbnails YouTube si disponibles
    return null;
  }

  static void clearCache() {
    _thumbnailCache.clear();
  }
}