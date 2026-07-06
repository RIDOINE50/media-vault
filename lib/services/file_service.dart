import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
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

  // ✅ Dossiers à exclure (système, cache, etc.)
  static const List<String> excludedDirs = [
    r'$Recycle.Bin',           // ✅ Raw string pour éviter l'erreur
    r'$RECYCLE.BIN',
    'System Volume Information',
    '.thumbnails',
    '.Trash',
    'LOST.DIR',
    '.temp',
    'cache',
    '.cache',
    'thumb',
    '.thumb',
    'Android/data',
    'Android/obb',
    'WhatsApp/.Shared',
    'Tencent',
    '.facebook_cache',
    '.instagram',
    '.tiktok',
    'DCIM/.thumbnails',
  ];

  // ✅ CHARGER DEPUIS LE CACHE
  Future<List<MediaFile>> loadFromCache() async {
    try {
      final box = await Hive.openBox('file_cache');
      final cachedData = box.get('scanned_files');
      
      if (cachedData != null && cachedData is List && cachedData.isNotEmpty) {
        print('✅ Cache trouvé: ${cachedData.length} fichiers');
        return cachedData.map((data) {
          return MediaFile.fromLocal(
            id: data['id'] ?? '',
            title: data['title'] ?? '',
            artist: data['artist'] ?? 'Inconnu',
            album: data['album'] ?? 'Album inconnu',
            path: data['path'] ?? '',
            duration: Duration(milliseconds: data['duration_ms'] ?? 0),
            format: data['format'] ?? '',
            isVideo: data['is_video'] ?? false,
          );
        }).toList();
      }
    } catch (e) {
      print('⚠️ Erreur lecture cache: $e');
    }
    
    return [];
  }

  // ✅ SAUVEGARDER DANS LE CACHE
  Future<void> saveToCache(List<MediaFile> files) async {
    try {
      final box = await Hive.openBox('file_cache');
      final cacheData = files.map((file) {
        return {
          'id': file.id,
          'title': file.title,
          'artist': file.artist,
          'album': file.album,
          'path': file.path,
          'duration_ms': file.duration.inMilliseconds,
          'format': file.format,
          'is_video': file.isVideo,
        };
      }).toList();
      
      await box.put('scanned_files', cacheData);
      print('✅ Cache sauvegardé: ${files.length} fichiers');
    } catch (e) {
      print('⚠️ Erreur sauvegarde cache: $e');
    }
  }

  // ✅ VIDER LE CACHE
  Future<void> clearCache() async {
    try {
      final box = await Hive.openBox('file_cache');
      await box.delete('scanned_files');
      print('✅ Cache vidé');
    } catch (e) {
      print('⚠️ Erreur vidage cache: $e');
    }
  }

  bool _isExcluded(String path) {
    final lowerPath = path.toLowerCase();
    for (var excluded in excludedDirs) {
      if (lowerPath.contains(excluded.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  // ✅ GET SCAN DIRECTORIES - Android et Windows
  static List<String> getScanDirectories() {
    if (Platform.isAndroid) {
      return [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/MediaVault',
        '/storage/emulated/0/Music/MediaVault',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Recordings',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Audiobooks',
        '/storage/emulated/0/Ringtones',
        '/storage/emulated/0/Notifications',
        '/storage/emulated/0/Alarms',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/Telegram/Telegram Audio',
        '/storage/emulated/0/Telegram/Telegram Video',
        '/storage/emulated/0/Bluetooth',
      ];
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return [
        if (userProfile.isNotEmpty) ...[
          '$userProfile\\Music',
          '$userProfile\\Downloads',
          '$userProfile\\Videos',
        ],
      ];
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return [
        if (home.isNotEmpty) ...[
          '$home/Music',
          '$home/Downloads',
          '$home/Videos',
        ],
      ];
    }
    return [];
  }

  // ✅ SCAN COMPLET AVEC CACHE
  Future<List<MediaFile>> scanAllFiles({bool forceRescan = false}) async {
    if (!forceRescan) {
      final cached = await loadFromCache();
      if (cached.isNotEmpty) {
        print('✅ Utilisation du cache: ${cached.length} fichiers');
        return cached;
      }
    }
    
    print('🔄 Scan complet en cours...');
    List<MediaFile> allFiles = [];
    
    final scanDirs = getScanDirectories();
    print('📁 Dossiers à scanner: ${scanDirs.length}');
    
    for (var dirPath in scanDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        print('📁 Scan: $dirPath');
        try {
          final files = await _scanDirectoryRecursive(dir, depth: 0, maxDepth: 10);
          print('✅ ${files.length} fichiers dans $dirPath');
          allFiles.addAll(files);
        } catch (e) {
          print('⚠️ Erreur scan $dirPath: $e');
        }
      }
    }
    
    // ✅ SUPPRIMER LES DOUBLONS
    final uniqueFiles = <String, MediaFile>{};
    for (var file in allFiles) {
      uniqueFiles[file.path] = file;
    }
    
    print('✅ ${uniqueFiles.length} fichiers uniques trouvés');
    
    await saveToCache(uniqueFiles.values.toList());
    
    return uniqueFiles.values.toList();
  }

  Future<List<MediaFile>> _scanDirectoryRecursive(Directory dir, {required int depth, required int maxDepth}) async {
    List<MediaFile> files = [];
    
    if (depth > maxDepth) return files;
    if (_isExcluded(dir.path)) return files;
    
    try {
      final entities = dir.listSync(followLinks: false);
      
      for (var entity in entities) {
        if (entity is Directory) {
          final subFiles = await _scanDirectoryRecursive(entity, depth: depth + 1, maxDepth: maxDepth);
          files.addAll(subFiles);
        } 
        else if (entity is File) {
          final path = entity.path;
          final fileName = path.split(Platform.pathSeparator).last;
          
          if (fileName.startsWith('.')) continue;
          
          final dotIndex = fileName.lastIndexOf('.');
          if (dotIndex == -1) continue;
          final extension = fileName.substring(dotIndex + 1).toLowerCase();
          
          final isVideo = videoExtensions.contains(extension);
          final isAudio = audioExtensions.contains(extension);
          
          if (isVideo || isAudio) {
            try {
              final stat = await entity.stat();
              if (stat.size <= 0) continue;
            } catch (e) {
              continue;
            }
            
            String title = fileName.substring(0, dotIndex);
            String artist = 'Inconnu';

            // ✅ DÉTECTION AUDIO/VIDÉO POUR LES MP4
            bool finalIsVideo = isVideo;
            
            if (extension == 'mp4') {
              if (fileName.contains('_Audio')) {
                finalIsVideo = false; // C'est de l'audio malgré l'extension mp4
              }
            }

            // ✅ NETTOYER LE TITRE
            title = title.replaceAll('_Audio', '').replaceAll('_Video', '');
            
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
            
            files.add(MediaFile.fromLocal(
              id: path.hashCode.toString(),
              title: title,
              artist: artist,
              album: 'Album inconnu',
              path: path,
              duration: Duration.zero,
              format: extension,
              isVideo: finalIsVideo,
            ));
          }
        }
      }
    } catch (e) {
      // ✅ Ignorer les erreurs de permission
      print('⚠️ Erreur scan ${dir.path}: ${e.toString().split('\n').first}');
    }
    
    return files;
  }

  Future<List<MediaFile>> getDownloadedFiles() async {
    String downloadDir;
    
    if (Platform.isAndroid) {
      downloadDir = '/storage/emulated/0/Music/MediaVault';
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      downloadDir = '$userProfile\\Downloads\\MediaVault';
    } else {
      return [];
    }
    
    final dir = Directory(downloadDir);
    if (await dir.exists()) {
      return await _scanDirectoryRecursive(dir, depth: 0, maxDepth: 5);
    }
    return [];
  }

  // ✅ MÉTHODES DE TRI (STATIC)
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