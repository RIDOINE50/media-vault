import 'dart:io';
import 'package:just_audio/just_audio.dart';
import '../models/media_file.dart';

class FileService {
  static const List<String> audioExtensions = [
    'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma', 'opus', 
    'amr', 'aiff', 'alac', 'm4b', 'ape', 'mid', 'midi', 'mka'
  ];
  
  static const List<String> videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'm4v', 
    '3gp', 'ts', 'm2ts', 'mpg', 'mpeg', 'vob', 'ogv'
  ];

  // ✅ DOSSIERS À EXCLURE (système, cache, etc.)
  static const List<String> excludedDirs = [
    'Android',
    '.thumbnails',
    '.Trash',
    'LOST.DIR',
    '.temp',
    'cache',
    '.cache',
    'thumb',
    '.thumb',
    'WhatsApp/.Shared',
    'Tencent',
    '.facebook_cache',
    '.instagram',
    '.tiktok',
    'DCIM/.thumbnails',
  ];

  Future<Duration> _getAudioDuration(String filePath) async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(filePath);
      final duration = player.duration ?? Duration.zero;
      await player.dispose();
      return duration;
    } catch (e) {
      print('⚠️ Erreur lecture durée: $e');
      return Duration.zero;
    }
  }

  // ✅ VÉRIFIER SI UN DOSSIER DOIT ÊTRE EXCLU
  bool _isExcluded(String path) {
    final lowerPath = path.toLowerCase();
    for (var excluded in excludedDirs) {
      if (lowerPath.contains(excluded.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  Future<List<MediaFile>> scanAllFiles() async {
    List<MediaFile> allFiles = [];
    
    // ✅ SCANNER TOUT LE STOCKAGE PRINCIPAL
    final rootDir = Directory('/storage/emulated/0');
    
    if (await rootDir.exists()) {
      print('📱 Scan complet de: ${rootDir.path}');
      final files = await _scanDirectoryRecursive(rootDir, depth: 0, maxDepth: 10);
      allFiles.addAll(files);
    } else {
      print('⚠️ Dossier principal introuvable, scan des dossiers connus');
      // Fallback : dossiers connus
      final fallbackDirs = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/MediaVault',
        '/storage/emulated/0/Music/MediaVault',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Recordings',
      ];
      
      for (var dirPath in fallbackDirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final files = await _scanDirectoryRecursive(dir, depth: 0, maxDepth: 10);
          allFiles.addAll(files);
        }
      }
    }
    
    // ✅ SUPPRIMER LES DOUBLONS
    final uniqueFiles = <String, MediaFile>{};
    for (var file in allFiles) {
      uniqueFiles[file.path] = file;
    }
    
    print('✅ ${uniqueFiles.length} fichiers uniques trouvés au total');
    return uniqueFiles.values.toList();
  }

  // ✅ SCAN RÉCURSIF AVEC PROFONDEUR MAXIMALE
  Future<List<MediaFile>> _scanDirectoryRecursive(Directory dir, {required int depth, required int maxDepth}) async {
    List<MediaFile> files = [];
    
    if (depth > maxDepth) return files;
    
    // Exclure les dossiers système
    if (_isExcluded(dir.path)) return files;
    
    try {
      final entities = dir.listSync(followLinks: false);
      
      for (var entity in entities) {
        if (entity is Directory) {
          // Scanner les sous-dossiers
          final subFiles = await _scanDirectoryRecursive(entity, depth: depth + 1, maxDepth: maxDepth);
          files.addAll(subFiles);
        } 
        else if (entity is File) {
          final path = entity.path;
          final fileName = path.split(Platform.pathSeparator).last;
          
          // Ignorer les fichiers cachés
          if (fileName.startsWith('.')) continue;
          
          // Récupérer l'extension
          final dotIndex = fileName.lastIndexOf('.');
          if (dotIndex == -1) continue;
          final extension = fileName.substring(dotIndex + 1).toLowerCase();
          
          final isVideo = videoExtensions.contains(extension);
          final isAudio = audioExtensions.contains(extension);
          
          if (isVideo || isAudio) {
            // Vérifier que le fichier n'est pas vide
            try {
              final stat = await entity.stat();
              if (stat.size <= 0) continue;
            } catch (e) {
              continue;
            }
            
            String title = fileName.substring(0, dotIndex);
            String artist = 'Inconnu';

            // Parser "Artiste - Titre"
            if (title.contains(' - ')) {
              final firstDashIndex = title.indexOf(' - ');
              artist = title.substring(0, firstDashIndex).trim();
              title = title.substring(firstDashIndex + 3).trim();
            } 
            else if (title.contains('_')) {
              final parts = title.split('_');
              if (parts.length >= 2) {
                artist = parts[0].trim();
                title = parts.sublist(1).join('_').trim();
              }
            }

            title = title.replaceAll(RegExp(r'^\d+\s*[-\.]?\s*'), '').trim();
            if (title.isEmpty) title = fileName;
            
            Duration duration = Duration.zero;
            if (isAudio) {
              duration = await _getAudioDuration(path);
            }
            
            files.add(MediaFile.fromLocal(
              id: path.hashCode.toString(),
              title: title,
              artist: artist,
              album: 'Album inconnu',
              path: path,
              duration: duration,
              format: extension,
              isVideo: isVideo,
            ));
          }
        }
      }
    } catch (e) {
      // Ignorer les erreurs de permission sur certains dossiers
      print('⚠️ Impossible de scanner: ${dir.path} ($e)');
    }
    
    return files;
  }

  Future<List<MediaFile>> getDownloadedFiles() async {
    final dir = Directory('/storage/emulated/0/Music/MediaVault');
    if (await dir.exists()) {
      return await _scanDirectoryRecursive(dir, depth: 0, maxDepth: 5);
    }
    return [];
  }

  static List<MediaFile> sortByRecentDesc(List<MediaFile> files) {
    final sorted = List<MediaFile>.from(files);
    sorted.sort((a, b) {
      final dateA = a.downloadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.downloadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return sorted;
  }

  static List<MediaFile> sortByRecentAsc(List<MediaFile> files) {
    final sorted = List<MediaFile>.from(files);
    sorted.sort((a, b) {
      final dateA = a.downloadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.downloadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB);
    });
    return sorted;
  }

  static List<MediaFile> sortByNameAsc(List<MediaFile> files) {
    final sorted = List<MediaFile>.from(files);
    sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return sorted;
  }

  static List<MediaFile> sortByNameDesc(List<MediaFile> files) {
    final sorted = List<MediaFile>.from(files);
    sorted.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    return sorted;
  }

  static List<MediaFile> sortByArtist(List<MediaFile> files) {
    final sorted = List<MediaFile>.from(files);
    sorted.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    return sorted;
  }

  void dispose() {}
}