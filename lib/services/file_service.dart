import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart'; // ✅ UTILISER JUST_AUDIO
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

  // ✅ EXTRAIRE LA DURÉE AVEC JUST_AUDIO
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

  Future<List<MediaFile>> scanAllFiles() async {
    List<MediaFile> allFiles = [];
    final directories = <String>[];
    
    if (Platform.isAndroid) {
      directories.addAll([
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/MediaVault',
        '/storage/emulated/0/Music/MediaVault',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Recordings',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Audiobooks',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
        '/storage/emulated/0/Telegram/Telegram Video',
        '/storage/emulated/0/Telegram/Telegram Audio',
      ]);
    } else if (Platform.isWindows) {
      directories.addAll([
        'downloads',
        'Music',
        'Downloads',
        'Videos',
        'Documents',
      ]);
    }
    
    final uniqueDirs = directories.toSet();
    
    for (var dirPath in uniqueDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final files = await _scanDirectory(dir);
        allFiles.addAll(files);
      }
    }
    
    final uniqueFiles = <String, MediaFile>{};
    for (var file in allFiles) {
      uniqueFiles[file.path] = file;
    }
    
    print('✅ ${uniqueFiles.length} fichiers uniques trouvés au total');
    return uniqueFiles.values.toList();
  }

  Future<List<MediaFile>> _scanDirectory(Directory dir) async {
    List<MediaFile> files = [];
    
    try {
      print('📁 Scan: ${dir.path}');
      final entities = dir.listSync(recursive: true, followLinks: false);
      
      for (var entity in entities) {
        if (entity is File) {
          final path = entity.path;
          final fileName = path.split(Platform.pathSeparator).last;
          
          if (fileName.startsWith('.')) continue;
          
          final extension = fileName.split('.').last.toLowerCase();
          
          final isVideo = videoExtensions.contains(extension);
          final isAudio = audioExtensions.contains(extension);
          
          if (isVideo || isAudio) {
            String title = fileName.replaceAll('.$extension', '');
            String artist = 'Inconnu';

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