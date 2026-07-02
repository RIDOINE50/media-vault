import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/media_file.dart';
import '../services/file_service.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/player_bar.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  final AudioService audioService;

  const AlbumsScreen({
    Key? key,
    required this.audioService,
  }) : super(key: key);

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> with TickerProviderStateMixin {
  final FileService _fileService = FileService();
  final DownloadService _downloadService = DownloadService();
  List<MediaFile> _allFiles = [];
  Map<String, List<MediaFile>> _autoAlbums = {};
  Map<String, List<String>> _customAlbums = {};
  bool _isLoading = true;
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadAlbums();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _fileService.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);

    final localFiles = await _fileService.scanAllFiles();
    final downloadedFiles = await _downloadService.getDownloadedFiles();

    _allFiles.clear();
    _allFiles.addAll(localFiles);

    for (var downloaded in downloadedFiles) {
      bool alreadyExists = _allFiles.any((f) => f.path == downloaded.path);
      if (!alreadyExists) {
        _allFiles.add(downloaded);
      }
    }

    // ✅ 1. Albums automatiques (depuis métadonnées) - AUDIO ET VIDÉO
    _autoAlbums = {};
    for (var file in _allFiles) {
      final albumName = file.album.isNotEmpty ? file.album : 'Album inconnu';
      if (!_autoAlbums.containsKey(albumName)) {
        _autoAlbums[albumName] = [];
      }
      _autoAlbums[albumName]!.add(file);
    }

    // ✅ 2. Albums personnalisés (depuis Hive)
    final box = Hive.box('custom_albums');
    _customAlbums = box.toMap().map((key, value) => MapEntry(key, List<String>.from(value)));

    setState(() => _isLoading = false);
    _listAnimationController.forward(from: 0);
  }

  void _createCustomAlbum() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nouvel Album',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Nom de l\'album',
            hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[500] : Colors.grey[400]),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final box = Hive.box('custom_albums');
                box.put(controller.text.trim(), <String>[]);
                _loadAlbums();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Album "${controller.text.trim()}" créé !'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomAlbum(String albumName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer l\'album', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer "$albumName" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final box = Hive.box('custom_albums');
              box.delete(albumName);
              _loadAlbums();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Album "$albumName" supprimé'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  IconData _getContentTypeIcon(List<MediaFile> files) {
    if (files.isEmpty) return Icons.album_rounded;
    
    final hasAudio = files.any((f) => !f.isVideo);
    final hasVideo = files.any((f) => f.isVideo);
    
    if (hasAudio && hasVideo) return Icons.library_music;
    if (hasVideo) return Icons.movie_rounded;
    return Icons.music_note_rounded;
  }

  String _getContentTypeLabel(List<MediaFile> files) {
    if (files.isEmpty) return 'Vide';
    
    final hasAudio = files.any((f) => !f.isVideo);
    final hasVideo = files.any((f) => f.isVideo);
    
    if (hasAudio && hasVideo) return 'Mixte';
    if (hasVideo) return 'Vidéo';
    return 'Audio';
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
              'Albums',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w900,
                fontSize: 34,
                letterSpacing: -1,
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_autoAlbums.length + _customAlbums.length} album${(_autoAlbums.length + _customAlbums.length) > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _isLoading
                    ? _buildShimmerLoading(isDark)
                    : (_autoAlbums.isEmpty && _customAlbums.isEmpty)
                        ? _buildEmptyState(isDark)
                        : RefreshIndicator(
                            onRefresh: _loadAlbums,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (_customAlbums.isNotEmpty) ...[
                                  _buildSectionHeader('Mes Albums', isDark),
                                  const SizedBox(height: 12),
                                  _buildAlbumsGrid(_customAlbums.keys.toList(), true, isDark, primaryColor),
                                  const SizedBox(height: 32),
                                ],

                                if (_autoAlbums.isNotEmpty) ...[
                                  _buildSectionHeader('Bibliothèque', isDark),
                                  const SizedBox(height: 12),
                                  _buildAlbumsGrid(_autoAlbums.keys.toList(), false, isDark, primaryColor),
                                ],
                              ],
                            ),
                          ),
              ),

              PlayerBar(
                audioService: widget.audioService,
                onTap: () => Navigator.pushNamed(context, '/player'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _createCustomAlbum,
            backgroundColor: primaryColor,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumsGrid(List<String> albumNames, bool isCustom, bool isDark, Color primaryColor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: albumNames.length,
      itemBuilder: (context, index) {
        final albumName = albumNames[index];
        if (isCustom) {
          final fileIds = _customAlbums[albumName] ?? [];
          final files = _allFiles.where((f) => fileIds.contains(f.id)).toList();
          return _buildAnimatedAlbumCard(albumName, files, isDark, primaryColor, index, isCustom);
        } else {
          return _buildAnimatedAlbumCard(albumName, _autoAlbums[albumName] ?? [], isDark, primaryColor, index, isCustom);
        }
      },
    );
  }

  Widget _buildAnimatedAlbumCard(
    String albumName,
    List<MediaFile> files,
    bool isDark,
    Color primaryColor,
    int index,
    bool isCustom,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _buildAlbumCard(albumName, files, isDark, primaryColor, isCustom),
    );
  }

  Widget _buildAlbumCard(String albumName, List<MediaFile> files, bool isDark, Color primaryColor, bool isCustom) {
    final artist = files.isNotEmpty ? files.first.artist : 'Artiste inconnu';
    final thumbnailUrl = files.isNotEmpty ? files.first.thumbnailUrl : null;

    return GestureDetector(
      onTap: () {
        if (files.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlbumDetailScreen(
                albumName: albumName,
                files: files,
                audioService: widget.audioService,
              ),
            ),
          );
        } else if (isCustom) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Va dans "Fichiers" et utilise le menu (⋮) pour ajouter des fichiers à "$albumName"'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      onLongPress: isCustom ? () => _deleteCustomAlbum(albumName) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withOpacity(0.4),
                      primaryColor.withOpacity(0.2),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          thumbnailUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _buildDefaultAlbumCover(primaryColor, isCustom),
                        ),
                      )
                    else
                      _buildDefaultAlbumCover(primaryColor, isCustom),

                    // Badge type de contenu
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getContentTypeIcon(files),
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getContentTypeLabel(files),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Badge nombre de pistes
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${files.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bouton play ou add
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          files.isEmpty ? Icons.add : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isCustom)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.folder_special,
                            size: 14,
                            color: primaryColor,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          albumName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAlbumCover(Color primaryColor, bool isCustom) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.4),
            primaryColor.withOpacity(0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isCustom ? Icons.folder_special : Icons.album_rounded,
          size: 60,
          color: primaryColor,
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
            child: Icon(Icons.album_rounded, size: 100, color: isDark ? Colors.grey[700] : Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun album',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Appuie sur le bouton + pour créer un album',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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
            child: Icon(Icons.album_rounded, size: 80, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement des albums...',
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
}