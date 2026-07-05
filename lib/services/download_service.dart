import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_file.dart';

class DownloadService {
  late final Directory _downloadDir;
  final yt = YoutubeExplode();

  static const List<String> audioExtensions = [
    'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma', 'opus', 
    'amr', 'aiff', 'alac', 'm4b', 'ape', 'mid', 'midi', 'mka'
  ];
  
  static const List<String> videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'm4v', 
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
        print('✅ Dossier créé: ${_downloadDir.path}');
      }
    } catch (e) {
      print('⚠️ Erreur création dossier: $e');
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
      print('📁 Scan du dossier: ${_downloadDir.path}');
      print('📁 ${entities.length} éléments trouvés');
      
      for (var entity in entities) {
        if (entity is File) {
          final path = entity.path;
          final fileName = path.split(Platform.pathSeparator).last;
          final extension = fileName.split('.').last.toLowerCase();
          
          print('🔍 Vérification: $fileName (.$extension)');
          
          final isVideo = videoExtensions.contains(extension);
          final isAudio = audioExtensions.contains(extension);
          
          print('🎵 isAudio: $isAudio, 🎬 isVideo: $isVideo');
          
          if (isVideo || isAudio) {
            try {
              final stat = await entity.stat();
              final fileSize = stat.size;
              
              print('📊 Taille: $fileSize bytes');
              
              if (fileSize <= 0) {
                print('⚠️ Fichier vide ignoré: $fileName');
                continue;
              }
              
              String title = fileName.replaceAll('.$extension', '');
              String artist = 'Artiste inconnu';
              
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
                  duration: Duration.zero, // Sera extrait par le lecteur
                  format: extension,
                  isVideo: isVideo, // ✅ IMPORTANT POUR LA LECTURE
                  downloadDate: stat.modified,
                  isFromYouTube: true,
                ));
                print('✅ Fichier ajouté: $title');
              }
            } catch (e) {
              print('❌ Erreur lecture fichier: $e');
            }
          }
        }
      }
      
      print('✅ ${files.length} fichiers valides trouvés');
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
    try {
      print('🎬 Début téléchargement: $videoId (audio: $isAudioOnly)');
      
      final video = await yt.videos.get(videoId);
      final title = video.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      print('📹 Titre: $title');

      if (isAudioOnly) {
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        final audioStreamInfo = manifest.audioOnly.last;
        
        final fileName = '${title}_Audio.mp3';
        final filePath = '${_downloadDir.path}${Platform.pathSeparator}$fileName';
        
        print('🎵 Téléchargement audio: $fileName');
        
        final stream = yt.videos.streamsClient.get(audioStreamInfo);
        final file = File(filePath);
        final fileStream = file.openWrite();
        
        int totalBytes = audioStreamInfo.size.totalBytes;
        int downloadedBytes = 0;
        
        await for (final data in stream) {
          fileStream.add(data);
          downloadedBytes += data.length;
          onProgress(downloadedBytes / totalBytes);
        }
        
        await fileStream.flush();
        await fileStream.close();
        
        // ✅ VÉRIFICATION APRÈS TÉLÉCHARGEMENT
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!file.existsSync()) {
          print('❌ Fichier non créé: $filePath');
          return null;
        }
        
        final finalSize = await file.length();
        print('📊 Taille finale: $finalSize bytes');
        
        if (finalSize <= 0) {
          print('❌ Fichier vide: $filePath');
          await file.delete();
          return null;
        }
        
        print('✅ Audio terminé: $filePath (${finalSize} bytes)');
        return filePath;
        
      } else {
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        final videoStreamInfo = manifest.videoOnly.last;
        
        final fileName = '${title}_Video.mp4';
        final filePath = '${_downloadDir.path}${Platform.pathSeparator}$fileName';
        
        print('🎬 Téléchargement vidéo: $fileName');
        
        final stream = yt.videos.streamsClient.get(videoStreamInfo);
        final file = File(filePath);
        final fileStream = file.openWrite();
        
        int totalBytes = videoStreamInfo.size.totalBytes;
        int downloadedBytes = 0;
        
        await for (final data in stream) {
          fileStream.add(data);
          downloadedBytes += data.length;
          onProgress(downloadedBytes / totalBytes);
        }
        
        await fileStream.flush();
        await fileStream.close();
        
        // ✅ VÉRIFICATION APRÈS TÉLÉCHARGEMENT
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!file.existsSync()) {
          print('❌ Fichier non créé: $filePath');
          return null;
        }
        
        final finalSize = await file.length();
        print('📊 Taille finale: $finalSize bytes');
        
        if (finalSize <= 0) {
          print('❌ Fichier vide: $filePath');
          await file.delete();
          return null;
        }
        
        print('✅ Vidéo terminée: $filePath (${finalSize} bytes)');
        return filePath;
      }
      
    } catch (e, stackTrace) {
      print('❌ Erreur téléchargement: $e');
      print('📋 Stack trace: $stackTrace');
      return null;
    }
  }

  void dispose() {
    yt.close();
  }
}