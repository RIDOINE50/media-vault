import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_file.dart';

class DownloadService {
  late final Directory _downloadDir;
  final yt = YoutubeExplode();

  static const List<String> audioExtensions = [
    'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma', 'opus', 
    'amr', 'aiff', 'alac', 'm4b', 'ape', 'mid', 'midi', 'mka', 'mp4'
  ];
  
  static const List<String> videoExtensions = [
    'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'm4v', 
    '3gp', 'ts', 'm2ts', 'mpg', 'mpeg', 'vob', 'ogv'
  ];

  DownloadService() {
    _initDownloadDir();
  }

  Future<void> _initDownloadDir() async {
    try {
      if (Platform.isAndroid) {
        _downloadDir = Directory('/storage/emulated/0/Music/MediaVault');
      } else if (Platform.isWindows) {
        _downloadDir = Directory('downloads');
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        _downloadDir = Directory('${docDir.path}/MediaVault');
      }

      if (!_downloadDir.existsSync()) {
        _downloadDir.createSync(recursive: true);
      }
    } catch (e) {
      _downloadDir = Directory('downloads');
      if (!_downloadDir.existsSync()) {
        _downloadDir.createSync(recursive: true);
      }
    }
  }

  Future<List<MediaFile>> getDownloadedFiles() async {
    List<MediaFile> files = [];
    
    try {
      if (!_downloadDir.existsSync()) {
        print('⚠️ Dossier inexistant: ${_downloadDir.path}');
        return files;
      }

      final entities = _downloadDir.listSync();
      print('📁 Scan MediaVault: ${entities.length} éléments');
      
      for (var entity in entities) {
        if (entity is File) {
          final path = entity.path;
          final fileName = path.split(Platform.pathSeparator).last;
          
          final dotIndex = fileName.lastIndexOf('.');
          if (dotIndex == -1) continue;
          final extension = fileName.substring(dotIndex + 1).toLowerCase();
          
          final isMediaExt = audioExtensions.contains(extension) || videoExtensions.contains(extension);
          
          if (isMediaExt) {
            try {
              final stat = await entity.stat();
              if (stat.size <= 0) continue;
              
              String title = fileName.substring(0, dotIndex);
              String artist = 'Artiste inconnu';
              
              bool isVideo = videoExtensions.contains(extension);
              
              if (extension == 'mp4') {
                if (fileName.contains('_Audio')) {
                  isVideo = false;
                } else {
                  isVideo = true;
                }
              }
              
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

              if (!files.any((f) => f.path == path)) {
                files.add(MediaFile(
                  id: path.hashCode.toString(),
                  title: title,
                  artist: artist,
                  album: 'Téléchargements',
                  path: path,
                  duration: Duration.zero,
                  format: extension,
                  isVideo: isVideo,
                  downloadDate: stat.modified,
                  isFromYouTube: true,
                ));
              }
            } catch (e) {
              continue;
            }
          }
        }
      }
      
      print('✅ ${files.length} fichiers téléchargés trouvés');
    } catch (e) {
      print('❌ Erreur scan: $e');
    }
    
    return files;
  }

  Future<String?> downloadFromYouTube({
    required String videoId,
    required bool isAudioOnly,
    required void Function(double progress) onProgress,
  }) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('🎬 Tentative $attempt/3: $videoId');
        
        final result = await _downloadInternal(
          videoId: videoId,
          isAudioOnly: isAudioOnly,
          onProgress: onProgress,
        ).timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            print('❌ TIMEOUT global (10 min)');
            return null;
          },
        );
        
        if (result != null) {
          print('✅ Téléchargement réussi !');
          return result;
        }
        
        print('⚠️ Échec tentative $attempt, réessai...');
        await Future.delayed(const Duration(seconds: 3));
        
      } catch (e) {
        print('❌ Erreur tentative $attempt: $e');
        if (attempt == 3) return null;
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    return null;
  }

  Future<String?> _downloadInternal({
    required String videoId,
    required bool isAudioOnly,
    required void Function(double progress) onProgress,
  }) async {
    final video = await yt.videos.get(videoId);
    final title = video.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    print('📹 Titre: $title');

    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    
    if (isAudioOnly) {
      final progressiveStreams = manifest.muxed.toList();
      
      if (progressiveStreams.isEmpty) {
        print('❌ Aucun stream trouvé');
        return null;
      }
      
      final bestStream = progressiveStreams.last;
      
      print('🎵 Stream trouvé: ${bestStream.qualityLabel}');
      
      final fileName = '${title}_Audio.mp4';
      final filePath = '${_downloadDir.path}${Platform.pathSeparator}$fileName';
      
      final stream = yt.videos.streamsClient.get(bestStream);
      final file = File(filePath);
      final fileStream = file.openWrite();
      
      int totalBytes = bestStream.size.totalBytes;
      int downloadedBytes = 0;
      int lastProgressUpdate = 0;
      
      print('📊 Taille: ${totalBytes ~/ 1024 ~/ 1024} MB');
      
      try {
        // ✅ TIMEOUT PLUS LONG POUR ANDROID (120s au lieu de 60s)
        await for (final data in stream.timeout(const Duration(seconds: 120))) {
          fileStream.add(data);
          downloadedBytes += data.length;
          
          // ✅ CLAMPER LE PROGRESS À 1.0 MAX
          final progress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
          final progressPercent = (progress * 100).toInt();
          
          if (progressPercent - lastProgressUpdate >= 5 || progressPercent == 100) {
            print('📥 Progress: $progressPercent%');
            lastProgressUpdate = progressPercent;
          }
          
          onProgress(progress);
        }
      } catch (e) {
        print('❌ Erreur stream: $e');
        await fileStream.close();
        if (file.existsSync()) {
          await file.delete();
        }
        return null;
      }
      
      // ✅ FLUSH ET CLOSE AVEC GESTION D'ERREUR
      try {
        await fileStream.flush();
        await fileStream.close();
      } catch (e) {
        print('⚠️ Erreur flush/close: $e');
      }
      
      // ✅ DÉLAI PLUS LONG POUR ANDROID (2s au lieu de 500ms)
      await Future.delayed(const Duration(seconds: 2));
      
      if (!file.existsSync()) {
        print('❌ Fichier non créé');
        return null;
      }
      
      try {
        final finalSize = await file.length();
        print('📊 Taille finale: ${finalSize ~/ 1024} KB');
        
        if (finalSize <= 0) {
          print('❌ Fichier vide');
          await file.delete();
          return null;
        }
      } catch (e) {
        print('⚠️ Erreur lecture taille: $e');
        return null;
      }
      
      print('✅ Audio terminé: $filePath');
      return filePath;
      
    } else {
      final progressiveStreams = manifest.muxed.toList();
      
      if (progressiveStreams.isEmpty) {
        print('❌ Aucun stream vidéo trouvé');
        return null;
      }
      
      final bestStream = progressiveStreams.last;
      
      print('🎬 Stream vidéo: ${bestStream.qualityLabel}');
      
      final fileName = '${title}_Video.mp4';
      final filePath = '${_downloadDir.path}${Platform.pathSeparator}$fileName';
      
      final stream = yt.videos.streamsClient.get(bestStream);
      final file = File(filePath);
      final fileStream = file.openWrite();
      
      int totalBytes = bestStream.size.totalBytes;
      int downloadedBytes = 0;
      int lastProgressUpdate = 0;
      
      try {
        await for (final data in stream.timeout(const Duration(seconds: 120))) {
          fileStream.add(data);
          downloadedBytes += data.length;
          
          final progress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
          final progressPercent = (progress * 100).toInt();
          
          if (progressPercent - lastProgressUpdate >= 5 || progressPercent == 100) {
            print('📥 Progress: $progressPercent%');
            lastProgressUpdate = progressPercent;
          }
          
          onProgress(progress);
        }
      } catch (e) {
        print('❌ Erreur stream: $e');
        await fileStream.close();
        if (file.existsSync()) {
          await file.delete();
        }
        return null;
      }
      
      try {
        await fileStream.flush();
        await fileStream.close();
      } catch (e) {
        print('⚠️ Erreur flush/close: $e');
      }
      
      await Future.delayed(const Duration(seconds: 2));
      
      if (!file.existsSync()) {
        print('❌ Fichier non créé');
        return null;
      }
      
      try {
        final finalSize = await file.length();
        
        if (finalSize <= 0) {
          await file.delete();
          return null;
        }
      } catch (e) {
        print('⚠️ Erreur lecture taille: $e');
        return null;
      }
      
      print('✅ Vidéo terminée: $filePath');
      return filePath;
    }
  }

  void dispose() {
    yt.close();
  }
}