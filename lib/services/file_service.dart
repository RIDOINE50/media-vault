import 'dart:io';
import '../models/media_file.dart';
import 'package:path_provider/path_provider.dart';
class FileService {
  static const List<String> audioExtensions = [
  // ✅ Formats courants
  'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma', 'opus', 
  'amr', 'aiff', 'alac', 'm4b', 'ape', 'mid', 'midi', 'mka',
  // ✅ Formats moins courants mais importants
  'ac3', 'dts', 'aif', 'aifc', 'au', 'snd', 'ra', 'ram', 
  '3ga', 'aa', 'aacp', 'wv', 'tta', 'mpc', 'shn', 'tak',
  // ✅ Formats professionnels
  'bwf', 'caf', 'ds2', 'dvf', 'gsm', 'm4p', 'mmf', 'mpc'
];
  
  static const List<String> videoExtensions = [
  // ✅ Formats courants
  'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'm4v', 
  '3gp', 'ts', 'm2ts', 'mpg', 'mpeg', 'vob', 'ogv',
  // ✅ Formats moins courants
  'asf', 'divx', 'f4v', 'm2v', 'm4b', 'mjp', 'mts', 
  'rm', 'rmvb', 'swf', 'tp', 'trp', 'vro', 'wtv',
  // ✅ Formats professionnels/rares
  '264', '265', 'h264', 'h265', 'hevc', 'avc', 'mxf',
  'prores', 'dnxhd', 'r3d', 'braw'
];

  // ✅ PLUS DE CACHE - ON SCANNE TOUJOURS
  
  bool _isExcluded(String path) {
    final lowerPath = path.toLowerCase();
    final excluded = [
      'android/data', 'android/obb', '.thumbnails', '.trash', 
      'lost.dir', '.temp', 'cache', '.cache', 'thumb', '.thumb',
      'whatsapp/.shared', 'tencent', '.facebook_cache', '.instagram', '.tiktok'
    ];
    for (var ex in excluded) {
      if (lowerPath.contains(ex)) return true;
    }
    return false;
  }

    Future<List<MediaFile>> scanAllFiles({bool forceRescan = false}) async {
    print('🔄 SCAN COMPLET DÉMARRÉ...');
    List<MediaFile> allFiles = [];
    
    if (Platform.isAndroid) {
      // ✅ SCANNER LE STOCKAGE PRINCIPAL
      final root = Directory('/storage/emulated/0');
      if (await root.exists()) {
        print('📱 Scan de /storage/emulated/0');
        final files = await _scanRecursive(root, 0, 15);
        allFiles.addAll(files);
      }
      
      // ✅ SCANNER AUSSI LE DOSSIER DE L'APP (MediaVault)
      try {
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          final mediaVaultDir = Directory('${appDir.path}/MediaVault');
          if (await mediaVaultDir.exists()) {
            print('📁 Scan du dossier MediaVault: ${mediaVaultDir.path}');
            final files = await _scanRecursive(mediaVaultDir, 0, 5);
            allFiles.addAll(files);
            print('✅ ${files.length} fichiers trouvés dans MediaVault');
          }
        }
      } catch (e) {
        print('⚠️ Erreur scan MediaVault: $e');
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final dirs = [
        '$userProfile\\Music',
        '$userProfile\\Downloads',
        '$userProfile\\Videos',
        '$userProfile\\Downloads\\MediaVault', // ✅ AJOUTÉ
      ];
      for (var dirPath in dirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final files = await _scanRecursive(dir, 0, 10);
          allFiles.addAll(files);
        }
      }
    }
    
    print('✅ ${allFiles.length} fichiers trouvés au total');
    print('🎵 Audio: ${allFiles.where((f) => !f.isVideo).length}');
    print('🎬 Vidéo: ${allFiles.where((f) => f.isVideo).length}');
    
    return allFiles;
  }

  Future<List<MediaFile>> _scanRecursive(Directory dir, int depth, int maxDepth) async {
    List<MediaFile> files = [];
    if (depth > maxDepth) return files;
    if (_isExcluded(dir.path)) return files;
    
    try {
      final entities = dir.listSync(followLinks: false);
      
      for (var entity in entities) {
        if (entity is Directory) {
          final subFiles = await _scanRecursive(entity, depth + 1, maxDepth);
          files.addAll(subFiles);
        } 
        else if (entity is File) {
          final path = entity.path;
          final fileName = path.split(Platform.pathSeparator).last;
          if (fileName.startsWith('.')) continue;
          
          final dotIndex = fileName.lastIndexOf('.');
          if (dotIndex == -1) continue;
          final ext = fileName.substring(dotIndex + 1).toLowerCase();
          
          bool isVideo = videoExtensions.contains(ext);
          bool isAudio = audioExtensions.contains(ext);
          
          // ✅ DÉTECTION SPÉCIALE POUR MP4
          if (ext == 'mp4') {
            if (fileName.contains('_Audio')) {
              isAudio = true;
              isVideo = false;
            }
          }
          
          if (isVideo || isAudio) {
            try {
              final stat = await entity.stat();
              if (stat.size <= 0) continue;
              
              String title = fileName.substring(0, dotIndex);
              String artist = 'Inconnu';
              title = title.replaceAll('_Audio', '').replaceAll('_Video', '');
              
              if (title.contains(' - ')) {
                final idx = title.indexOf(' - ');
                artist = title.substring(0, idx).trim();
                title = title.substring(idx + 3).trim();
              } else if (title.contains('_')) {
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
                format: ext,
                isVideo: isVideo,
              ));
            } catch (e) {
              continue;
            }
          }
        }
      }
    } catch (e) {
      // Ignorer les erreurs de permission
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
    if (!await dir.exists()) {
      print('⚠️ Dossier inexistant: $downloadDir');
      return [];
    }
    
    print('📁 Scan MediaVault: $downloadDir');
    return await _scanRecursive(dir, 0, 5);
  }

  // ✅ MÉTHODES DE TRI
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