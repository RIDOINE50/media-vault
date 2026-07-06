import 'dart:async';
import 'package:flutter/foundation.dart';
import 'download_service.dart';
import 'file_service.dart';

class DownloadTask {
  final String videoId;
  final String title;
  final bool isAudioOnly;
  double progress = 0;
  DownloadStatus status = DownloadStatus.queued;
  String? filePath;
  String? error;
  
  DownloadTask({
    required this.videoId,
    required this.title,
    required this.isAudioOnly,
  });
}

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadManager extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final List<DownloadTask> _downloads = [];
  final int _maxConcurrentDownloads = 3;
  int _activeDownloads = 0;
  bool _isProcessing = false; // ✅ AJOUTER CE FLAG
  
  List<DownloadTask> get downloads => List.unmodifiable(_downloads);
  
  List<DownloadTask> get activeDownloads => 
    _downloads.where((d) => d.status == DownloadStatus.downloading).toList();
  
  List<DownloadTask> get completedDownloads => 
    _downloads.where((d) => d.status == DownloadStatus.completed).toList();
  
  List<DownloadTask> get failedDownloads => 
    _downloads.where((d) => d.status == DownloadStatus.failed).toList();

  String addDownload(String videoId, String title, bool isAudioOnly) {
    final existing = _downloads.firstWhere(
      (d) => d.videoId == videoId,
      orElse: () => DownloadTask(videoId: '', title: '', isAudioOnly: false),
    );
    
    if (existing.videoId.isNotEmpty) {
      return 'already_exists';
    }
    
    final task = DownloadTask(
      videoId: videoId,
      title: title,
      isAudioOnly: isAudioOnly,
    );
    
    _downloads.add(task);
    notifyListeners();
    
    // ✅ LANCER LE TRAITEMENT DE LA FILE
    _processQueue();
    
    return task.videoId;
  }

  // ✅ CORRIGÉ : ÉVITER LA RÉCURSION
  Future<void> _processQueue() async {
    if (_isProcessing) return; // ✅ SI DÉJÀ EN COURS, SORTIR
    if (_activeDownloads >= _maxConcurrentDownloads) return;
    
    final queued = _downloads.where((d) => d.status == DownloadStatus.queued).toList();
    if (queued.isEmpty) return;
    
    _isProcessing = true; // ✅ MARQUER COMME EN COURS
    
    for (var task in queued) {
      if (_activeDownloads >= _maxConcurrentDownloads) break;
      
      // ✅ LANCER SANS ATTENDRE (fire and forget)
      _startDownload(task);
    }
    
    _isProcessing = false; // ✅ MARQUER COMME TERMINÉ
  }

  // ✅ CORRIGÉ : NE PLUS APPELER _processQueue DANS FINALLY
  Future<void> _startDownload(DownloadTask task) async {
    _activeDownloads++;
    task.status = DownloadStatus.downloading;
    notifyListeners();
    
    try {
      final filePath = await _downloadService.downloadFromYouTube(
        videoId: task.videoId,
        isAudioOnly: task.isAudioOnly,
        onProgress: (progress) {
          task.progress = progress;
          notifyListeners();
        },
      );
      
      if (filePath != null) {
        task.filePath = filePath;
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        
        print('🔄 Mise à jour du cache après téléchargement...');
        await _forceCacheUpdate();
        
        print('✅ Téléchargement terminé: $filePath');
      } else {
        task.status = DownloadStatus.failed;
        task.error = 'Échec du téléchargement';
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
    } finally {
      _activeDownloads--;
      notifyListeners();
      
      // ✅ RELANCER LE TRAITEMENT DE LA FILE (MAIS PAS DE RÉCURSION)
      Future.delayed(const Duration(milliseconds: 100), () {
        _processQueue();
      });
    }
  }

  Future<void> _forceCacheUpdate() async {
    try {
      final fileService = FileService();
      await fileService.clearCache();
      await fileService.scanAllFiles(forceRescan: true);
      print('✅ Cache mis à jour');
    } catch (e) {
      print('⚠️ Erreur mise à jour cache: $e');
    }
  }

  void cancelDownload(String videoId) {
    final task = _downloads.firstWhere(
      (d) => d.videoId == videoId,
      orElse: () => DownloadTask(videoId: '', title: '', isAudioOnly: false),
    );
    
    if (task.videoId.isNotEmpty && task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.cancelled;
      notifyListeners();
    }
  }

  void removeDownload(String videoId) {
    _downloads.removeWhere((d) => d.videoId == videoId);
    notifyListeners();
  }

  void clearCompleted() {
    _downloads.removeWhere((d) => 
      d.status == DownloadStatus.completed || 
      d.status == DownloadStatus.failed ||
      d.status == DownloadStatus.cancelled
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}