import 'dart:async';
import 'package:flutter/foundation.dart';
import 'download_service.dart';
import 'file_service.dart'; // ✅ AJOUTER
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
  final int _maxConcurrentDownloads = 3; // ✅ Limite de téléchargements simultanés
  int _activeDownloads = 0;
  
  List<DownloadTask> get downloads => List.unmodifiable(_downloads);
  
  List<DownloadTask> get activeDownloads => 
    _downloads.where((d) => d.status == DownloadStatus.downloading).toList();
  
  List<DownloadTask> get completedDownloads => 
    _downloads.where((d) => d.status == DownloadStatus.completed).toList();
  
  List<DownloadTask> get failedDownloads => 
    _downloads.where((d) => d.status == DownloadStatus.failed).toList();

  // ✅ AJOUTER UN NOUVEAU TÉLÉCHARGEMENT
  String addDownload(String videoId, String title, bool isAudioOnly) {
    // Vérifier si déjà en cours
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
    
    // Lancer le téléchargement si on n'a pas atteint la limite
    _processQueue();
    
    return task.videoId;
  }

  // ✅ PROCESSUS DE FILE D'ATTENTE
  Future<void> _processQueue() async {
    if (_activeDownloads >= _maxConcurrentDownloads) return;
    
    final queued = _downloads.where((d) => d.status == DownloadStatus.queued).toList();
    
    if (queued.isEmpty) return;
    
    final task = queued.first;
    await _startDownload(task);
  }

  // ✅ DÉMARRER UN TÉLÉCHARGEMENT
    // ✅ DÉMARRER UN TÉLÉCHARGEMENT
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
        
        // ✅ FORCER LA MISE À JOUR DU CACHE APRÈS TÉLÉCHARGEMENT
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
      
      // Lancer le prochain téléchargement en file d'attente
      _processQueue();
    }
  }

  // ✅ METTRE À JOUR LE CACHE
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

  // ✅ ANNULER UN TÉLÉCHARGEMENT
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

  // ✅ SUPPRIMER UN TÉLÉCHARGEMENT TERMINÉ/ÉCHOUÉ
  void removeDownload(String videoId) {
    _downloads.removeWhere((d) => d.videoId == videoId);
    notifyListeners();
  }

  // ✅ EFFACER TOUS LES TÉLÉCHARGEMENTS TERMINÉS/ÉCHOUÉS
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