import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';

class FileService {
  Future<List<MediaFile>> scanAllFiles() async {
    List<MediaFile> allFiles = [];
    
    // ✅ TOUS LES DOSSIERS À SCANNER
    final directories = <String>[];
    
    if (Platform.isAndroid) {
      directories.addAll([
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/MediaVault',
        '/storage/emulated/0/Music/MediaVault', // ← Dossier des téléchargements
      ]);
    } else if (Platform.isWindows) {
      directories.addAll([
        'downloads', // ← Dossier des téléchargements Windows
        'Music',
        'Downloads',
      ]);
    }
    
    for (var dirPath in directories) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final files = await _scanDirectory(dir);
        allFiles.addAll(files);
      }
    }
    
    print('✅ ${allFiles.length} fichiers trouvés au total');
    return allFiles;
  }

  Future<List<MediaFile>> _scanDirectory(Directory dir) async {
    List<MediaFile> files = [];
    
    try {
      print('📁 Scan: ${dir.path}');
      final entities = dir.listSync(recursive: true);
      
      for (var entity in entities) {
        if (entity is File) {
          final path = entity.path;
          final fileName = path.split(Platform.pathSeparator).last;
          final extension = fileName.split('.').last.toLowerCase();
          
          final isVideo = ['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(extension);
          final isAudio = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(extension);
          
          if (isVideo || isAudio) {
            final stat = await entity.stat();
            
            String title = fileName.replaceAll('.$extension', '');
            String artist = 'Inconnu';
            
            if (title.contains('_')) {
              final parts = title.split('_');
              title = parts[0].trim();
              if (parts.length > 1) artist = parts[1].trim();
            }
            
            // Éviter les doublons
            if (!files.any((f) => f.path == path)) {
              files.add(MediaFile.fromLocal(
                id: path.hashCode.toString(),
                title: title,
                artist: artist,
                album: 'Album inconnu',
                path: path,
                duration: const Duration(seconds: 0),
                format: extension,
                isVideo: isVideo,
              ));
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Erreur scan ${dir.path}: $e');
    }
    
    return files;
  }

  Future<List<MediaFile>> getDownloadedFiles() async {
    final dir = Directory(Platform.isAndroid 
        ? '/storage/emulated/0/Music/MediaVault' 
        : 'downloads');
    if (await dir.exists()) {
      return await _scanDirectory(dir);
    }
    return [];
  }

  void dispose() {}
}