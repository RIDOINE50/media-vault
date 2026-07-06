import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_file.dart';
import '../services/download_service.dart';
import '../services/download_manager.dart'; // ✅ AJOUTER
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/player_bar.dart';
import 'video_player_screen.dart';
import '../services/file_service.dart';

class DownloadedScreen extends StatefulWidget {
  final AudioService audioService;

  const DownloadedScreen({
    Key? key,
    required this.audioService,
  }) : super(key: key);

  @override
  State<DownloadedScreen> createState() => _DownloadedScreenState();
}

class _DownloadedScreenState extends State<DownloadedScreen> with TickerProviderStateMixin {
  final DownloadService _downloadService = DownloadService();
  String _currentFilter = 'audio';
  List<MediaFile> _downloadedFiles = [];
  bool _isLoading = true;
  
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadDownloads();
    
    // ✅ ÉCOUTER LES CHANGEMENTS DU DOWNLOAD MANAGER
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final downloadManager = Provider.of<DownloadManager>(context, listen: false);
      downloadManager.addListener(_onDownloadChanged);
    });
  }

  @override
  void dispose() {
    // ✅ SUPPRIMER L'ÉCOUTEUR
    final downloadManager = Provider.of<DownloadManager>(context, listen: false);
    downloadManager.removeListener(_onDownloadChanged);
    
    _downloadService.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  // ✅ APPELÉ QUAND UN TÉLÉCHARGEMENT CHANGE D'ÉTAT
  void _onDownloadChanged() {
    final downloadManager = Provider.of<DownloadManager>(context, listen: false);
    final completedDownloads = downloadManager.completedDownloads;
    
    // Si des téléchargements viennent de se terminer, recharger
    if (completedDownloads.isNotEmpty) {
      print('🔄 Téléchargements terminés détectés: ${completedDownloads.length}');
      _loadDownloads();
    }
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);
    
    final files = await _downloadService.getDownloadedFiles();
    
    final uniqueFiles = <String, MediaFile>{};
    for (var file in files) {
      uniqueFiles[file.path] = file;
      print('📁 Fichier téléchargé: ${file.title} | isVideo: ${file.isVideo}');
    }
    
    setState(() {
      _downloadedFiles = uniqueFiles.values.toList();
      _isLoading = false;
    });
    _listAnimationController.forward(from: 0);
  }

  void _playFile(MediaFile file) {
    print('🎵 Lecture: ${file.title} | isVideo: ${file.isVideo} | format: ${file.format}');
    
    int index = _filteredFiles.indexOf(file);
    if (index != -1) {
      if (file.isVideo) {
        print('🎬 Ouverture VideoPlayerScreen');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoPath: file.path,
              title: file.title,
            ),
          ),
        );
      } else {
        print('🎵 Ouverture lecteur audio');
        widget.audioService.setPlaylist(_filteredFiles, index);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pushNamed(context, '/player');
          }
        });
      }
    }
  }

  void _switchFilter(String type) {
    if (_currentFilter != type) {
      setState(() => _currentFilter = type);
      _listAnimationController.forward(from: 0);
    }
  }

  List<MediaFile> get _filteredFiles {
    return _downloadedFiles
        .where((file) => _currentFilter == 'audio' ? !file.isVideo : file.isVideo)
        .toList();
  }

  int _getFileSize(MediaFile file) {
    try {
      final f = File(file.path);
      if (f.existsSync()) {
        return f.lengthSync();
      }
    } catch (e) {
      print('⚠️ Erreur lecture taille: ${file.path}');
    }
    return 0;
  }

  String _getTotalSize() {
    int totalBytes = 0;
    for (var file in _downloadedFiles) {
      totalBytes += _getFileSize(file);
    }
    return _formatBytes(totalBytes);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isDark = settings.darkMode;
        final primaryColor = Theme.of(context).primaryColor;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Téléchargements',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w900,
                fontSize: 34,
                letterSpacing: -1,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded, 
                  color: isDark ? Colors.white : Colors.black87, 
                  size: 28,
                ),
                onPressed: _loadDownloads,
                tooltip: 'Actualiser',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildAnimatedTabs(isDark, primaryColor),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 10 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filteredFiles.length} fichier${_filteredFiles.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: _isLoading
                    ? _buildShimmerLoading(isDark)
                    : _filteredFiles.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredFiles.length,
                            itemBuilder: (context, index) {
                              return _buildAnimatedDownloadTile(
                                _filteredFiles[index],
                                isDark,
                                primaryColor,
                                index,
                              );
                            },
                          ),
              ),

              _buildStorageInfo(isDark, primaryColor),

              PlayerBar(
                audioService: widget.audioService,
                onTap: () => Navigator.pushNamed(context, '/player'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTabs(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Audio', 'audio', Icons.music_note_rounded, isDark, primaryColor)),
          Expanded(child: _buildTab('Vidéo', 'video', Icons.movie_rounded, isDark, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String type, IconData icon, bool isDark, Color primaryColor) {
    bool isSelected = _currentFilter == type;
    
    return GestureDetector(
      onTap: () => _switchFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                key: ValueKey(isSelected),
                size: 20,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Icon(
              Icons.cloud_download_rounded,
              size: 100,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun téléchargement',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Va dans l\'onglet Rechercher pour télécharger',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Transform.rotate(angle: value * 2 * 3.14159, child: child);
            },
            child: Icon(
              Icons.download_rounded,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement des téléchargements...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDownloadTile(MediaFile file, bool isDark, Color primaryColor, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildDownloadTile(file, isDark, primaryColor),
      ),
    );
  }

  Widget _buildDownloadTile(MediaFile file, bool isDark, Color primaryColor) {
    final fileSize = _getFileSize(file);
    
    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _playFile(file),
        splashColor: primaryColor.withOpacity(0.2),
        highlightColor: primaryColor.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildThumbnail(file, isDark, primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor.withOpacity(0.3),
                                primaryColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            file.format.toUpperCase(),
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.storage_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatBytes(fileSize),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.3),
                      Colors.green.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.green,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(MediaFile file, bool isDark, Color primaryColor) {
    if (file.thumbnailUrl != null && file.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          file.thumbnailUrl!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultThumbnail(file, isDark, primaryColor);
          },
        ),
      );
    }
    return _buildDefaultThumbnail(file, isDark, primaryColor);
  }

  Widget _buildDefaultThumbnail(MediaFile file, bool isDark, Color primaryColor) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: file.isVideo
              ? [Colors.blue.withOpacity(0.4), Colors.blue.withOpacity(0.2)]
              : [primaryColor.withOpacity(0.4), primaryColor.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: file.isVideo ? Colors.blue.withOpacity(0.3) : primaryColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (file.isVideo ? Colors.blue : primaryColor).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        file.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
        color: file.isVideo ? Colors.blue : primaryColor,
        size: 36,
      ),
    );
  }

  Widget _buildStorageInfo(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF1A1A1A) : Colors.white,
            isDark ? const Color(0xFF1A1A1A) : Colors.grey[100]!,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Espace utilisé',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.3),
                  primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${_getTotalSize()} / 10 Go',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}