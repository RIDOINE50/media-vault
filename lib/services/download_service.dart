import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_file.dart';

class DownloadService {
  late final Directory _downloadDir;
  final yt = YoutubeExplode();

  DownloadService() {
    _initDownloadDir();
  }

  // ✅ DÉTECTER LA PLATEFORME ET CRÉER LE BON DOSSIER
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

  // ✅ RÉCUPÉRER TOUS LES FICHIERS TÉLÉCHARGÉS
  Future<List<MediaFile>> getDownloadedFiles() async {
    List<MediaFile> files = [];
    
    try {
      if (!_downloadDir.existsSync()) {
        print('⚠️ Dossier inexistant: ${_downloadDir.path}');
        return files;
      }

      final entities = _downloadDir.listSync();
      print('📁 Scan du dossier: ${_downloadDir.path}');
      
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
            String artist = 'Artiste inconnu';
            
            if (title.contains('_')) {
              final parts = title.split('_');
              title = parts[0].trim();
              if (parts.length > 1) artist = parts[1].trim();
            }

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
        }
      }
      
      print('✅ ${files.length} fichiers trouvés');
    } catch (e) {
      print('❌ Erreur scan: $e');
    }
    
    return files;
  }

  // ✅ TÉLÉCHARGEMENT YOUTUBE
  Future<String?> downloadFromYouTube({
    required String videoId,
    required bool isAudioOnly,
    required void Function(double progress) onProgress,
  }) async {
    try {
      print('🎬 Début téléchargement: $videoId');
      
      final video = await yt.videos.get(videoId);
      final title = video.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      print('📹 Titre: $title');

      if (isAudioOnly) {
        // ✅ AUDIO
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        final audioStreamInfo = manifest.audioOnly.last;
        
        final fileName = '${title}_Audio.mp3';
        final filePath = '${_downloadDir.path}${Platform.pathSeparator}$fileName';
        
        print('🎵 Téléchargement: $fileName');
        
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
        
        await fileStream.close();
        print('✅ Audio terminé: $filePath');
        return filePath;
        
      } else {
        // ✅ VIDÉO
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        final videoStreamInfo = manifest.videoOnly.last;
        
        final fileName = '${title}_Video.mp4';
        final filePath = '${_downloadDir.path}${Platform.pathSeparator}$fileName';
        
        print('🎬 Téléchargement: $fileName');
        
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
        
        await fileStream.close();
        print('✅ Vidéo terminée: $filePath');
        return filePath;
      }
      
    } catch (e) {
      print('❌ Erreur: $e');
      return null;
    }
  }

  void dispose() {
    yt.close();
  }
}