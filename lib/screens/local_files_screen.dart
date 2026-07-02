import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/media_file.dart';
import '../services/file_service.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/download_service.dart';
import '../services/database_service.dart';
import '../widgets/player_bar.dart';
import 'settings_screen.dart';

class LocalFilesScreen extends StatefulWidget {
  final AudioService audioService;

  const LocalFilesScreen({
    Key? key,
    required this.audioService,
  }) : super(key: key);

  @override
  State<LocalFilesScreen> createState() => _LocalFilesScreenState();
}

class _LocalFilesScreenState extends State<LocalFilesScreen> with TickerProviderStateMixin {
  final FileService _fileService = FileService();
  final DownloadService _downloadService = DownloadService();
  final TextEditingController _searchController = TextEditingController();
  
  List<MediaFile> _allFiles = [];
  List<MediaFile> _recentFiles = [];
  List<MediaFile> _filteredFiles = [];
  
  bool _isLoading = true;
  String _currentFilter = 'music';
  
  late AnimationController _tabAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _tabAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _tabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tabAnimation = CurvedAnimation(
      parent: _tabAnimationController,
      curve: Curves.easeInOut,
    );
    
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _downloadService.dispose();
    _tabAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
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
    
    _allFiles.sort((a, b) {
      final dateA = a.downloadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.downloadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    _recentFiles = _allFiles.take(10).toList();
    
    _applyFilter();
    
    setState(() => _isLoading = false);
    
    _listAnimationController.forward(from: 0);
  }

  void _applyFilter() {
    setState(() {
      _filteredFiles = _allFiles.where((file) {
        bool matchesType = _currentFilter == 'music' ? !file.isVideo : file.isVideo;
        
        if (_searchController.text.isEmpty) return matchesType;
        
        String query = _searchController.text.toLowerCase();
        return matchesType && (
          file.title.toLowerCase().contains(query) ||
          file.artist.toLowerCase().contains(query)
        );
      }).toList();
    });
    
    _listAnimationController.forward(from: 0);
  }

  void _playFile(MediaFile file) {
    int index = _filteredFiles.indexOf(file);
    if (index != -1) {
      widget.audioService.setPlaylist(_filteredFiles, index);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pushNamed(context, '/player');
      });
    }
  }

  void _switchTab(String type) {
    if (_currentFilter != type) {
      setState(() => _currentFilter = type);
      _tabAnimationController.forward(from: 0);
      _applyFilter();
    }
  }

  void _showAddToAlbumDialog(MediaFile file) {
    final box = Hive.box('custom_albums');
    final albums = box.keys.toList();

    if (albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Crée d\'abord un album dans l\'onglet Albums !'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ajouter à un album',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                file.title,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final albumName = albums[index];
                  final List<String> currentFiles = List<String>.from(box.get(albumName) ?? []);
                  final bool alreadyInAlbum = currentFiles.contains(file.id);
                  
                  return ListTile(
                    leading: Icon(
                      Icons.album_rounded,
                      color: alreadyInAlbum ? Colors.green : Theme.of(context).primaryColor,
                    ),
                    title: Text(albumName),
                    subtitle: Text(
                      alreadyInAlbum ? 'Déjà dans cet album' : '${currentFiles.length} fichiers',
                      style: TextStyle(
                        color: alreadyInAlbum ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    enabled: !alreadyInAlbum,
                    onTap: () {
                      currentFiles.add(file.id);
                      box.put(albumName, currentFiles);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ajouté à "$albumName"'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isDark = settings.darkMode;
        final primaryColor = Theme.of(context).primaryColor;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Accueil',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 32,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              _buildAppBarIcon(Icons.queue_music, 'Playlists', () => Navigator.pushNamed(context, '/playlists'), isDark),
              _buildAppBarIcon(Icons.favorite_outline, 'Favoris', () => Navigator.pushNamed(context, '/favorites'), isDark),
              _buildAppBarIcon(Icons.settings, 'Paramètres', () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ), isDark),
            ],
          ),
          body: _isLoading
              ? _buildShimmerLoading(isDark)
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _buildSearchBar(isDark),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildAnimatedTabs(isDark, primaryColor),
                        ),

                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildAnimatedCounter(isDark),
                        ),

                        const SizedBox(height: 24),

                        if (_recentFiles.isNotEmpty) ...[
                          _buildSectionHeader('Récemment ajouté', isDark),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _recentFiles.length,
                              itemBuilder: (context, index) {
                                return _buildAnimatedMediaCard(_recentFiles[index], isDark, primaryColor, index);
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        _buildSectionHeader(
                          _currentFilter == 'music' ? 'Toutes les musiques' : 'Toutes les vidéos',
                          isDark,
                        ),
                        
                        if (_filteredFiles.isEmpty)
                          _buildEmptyState(isDark)
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredFiles.length,
                              itemBuilder: (context, index) {
                                return _buildAnimatedListTile(_filteredFiles[index], isDark, primaryColor, index);
                              },
                            ),
                          ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: PlayerBar(
            audioService: widget.audioService,
            onTap: () => Navigator.pushNamed(context, '/player'),
          ),
        );
      },
    );
  }

  Widget _buildAppBarIcon(IconData icon, String tooltip, VoidCallback onTap, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: IconButton(
            icon: Icon(icon, color: isDark ? Colors.white : Colors.black87),
            onPressed: onTap,
            tooltip: tooltip,
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _applyFilter(),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Rechercher dans ta bibliothèque...',
          hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAnimatedTabs(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Musique', 'music', Icons.music_note_rounded, isDark, primaryColor)),
          Expanded(child: _buildTab('Vidéos', 'video', Icons.movie_rounded, isDark, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String type, IconData icon, bool isDark, Color primaryColor) {
    bool isSelected = _currentFilter == type;
    
    return GestureDetector(
      onTap: () => _switchTab(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 8,
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
                size: 18,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCounter(bool isDark) {
    return TweenAnimationBuilder<double>(
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
      child: Text(
        '${_filteredFiles.length} ${_currentFilter == 'music' ? 'musiques' : 'vidéos'}',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMediaCard(MediaFile file, bool isDark, Color primaryColor, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: _buildMediaCard(file, isDark, primaryColor),
    );
  }

  Widget _buildMediaCard(MediaFile file, bool isDark, Color primaryColor) {
    return GestureDetector(
      onTap: () => _playFile(file),
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'media_${file.id}',
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: file.isVideo
                        ? [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.1)]
                        : [primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (file.isVideo ? Colors.blue : primaryColor).withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        file.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                        size: 48,
                        color: file.isVideo ? Colors.blue : primaryColor,
                      ),
                    ),
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
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              file.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedListTile(MediaFile file, bool isDark, Color primaryColor, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 30)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildListTile(file, isDark, primaryColor),
      ),
    );
  }

  Widget _buildListTile(MediaFile file, bool isDark, Color primaryColor) {
    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _playFile(file),
        splashColor: primaryColor.withOpacity(0.1),
        highlightColor: primaryColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: file.isVideo
                        ? [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.1)]
                        : [primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  file.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                  color: file.isVideo ? Colors.blue : primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file.artist,
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
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) => _handleMenuAction(value, file),
                itemBuilder: (context) => [
                  _buildMenuItem(Icons.info_outline_rounded, 'Détails', 'details'),
                  _buildMenuItem(Icons.edit_rounded, 'Renommer', 'rename'),
                  _buildMenuItem(Icons.share_rounded, 'Envoyer', 'share'),
                  _buildMenuItem(Icons.delete_rounded, 'Supprimer', 'delete'),
                  if (!file.isVideo) _buildMenuItem(Icons.music_note_rounded, 'Définir comme sonnerie', 'ringtone'),
                  const PopupMenuDivider(),
                  _buildMenuItem(Icons.favorite_rounded, 'Ajouter aux favoris', 'favorite', textColor: Colors.red),
                  _buildMenuItem(Icons.album_rounded, 'Ajouter à un album', 'add_to_album', textColor: primaryColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(IconData icon, String label, String value, {Color? textColor}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: textColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700])),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Icon(Icons.folder_open_rounded, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun fichier trouvé',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
              return Transform.rotate(
                angle: value * 2 * 3.14159,
                child: child,
              );
            },
            child: Icon(
              Icons.music_note_rounded,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement de ta bibliothèque...',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action, MediaFile file) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final settings = Provider.of<SettingsService>(context, listen: false);
    
    switch (action) {
      case 'details':
        _showDetailsDialog(file, settings);
        break;
      case 'rename':
        await _renameFile(file);
        break;
      case 'share':
        await _shareFile(file);
        break;
      case 'delete':
        await _deleteFile(file, db);
        break;
      case 'ringtone':
        await _setAsRingtone(file);
        break;
      case 'favorite':
        await _toggleFavorite(file, db);
        break;
      case 'add_to_album':
        _showAddToAlbumDialog(file);
        break;
    }
  }

  void _showDetailsDialog(MediaFile file, SettingsService settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: settings.darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Détails du fichier',
          style: TextStyle(color: settings.darkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Titre', file.title),
            _buildDetailRow('Artiste', file.artist),
            _buildDetailRow('Format', file.format.toUpperCase()),
            _buildDetailRow('Durée', file.formattedDuration),
            _buildDetailRow('Chemin', file.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87))),
        ],
      ),
    );
  }

  Future<void> _renameFile(MediaFile file) async {
    final controller = TextEditingController(text: file.title);
    final settings = Provider.of<SettingsService>(context, listen: false);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: settings.darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Renommer', style: TextStyle(color: settings.darkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: settings.darkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Nouveau nom',
            filled: true,
            fillColor: settings.darkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier renommé en "$newName"'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _shareFile(MediaFile file) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partage du fichier...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteFile(MediaFile file, DatabaseService db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer "${file.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await db.removeFavorite(file.id);
      setState(() {
        _allFiles.removeWhere((f) => f.id == file.id);
        _applyFilter();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.title}" supprimé'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _setAsRingtone(MediaFile file) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${file.title}" défini comme sonnerie'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _toggleFavorite(MediaFile file, DatabaseService db) async {
    if (db.isFavorite(file.id)) {
      await db.removeFavorite(file.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.favorite_border, color: Colors.white),
                SizedBox(width: 8),
                Text('Retiré des favoris'),
              ],
            ),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      await db.addFavorite(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.favorite, color: Colors.white),
                SizedBox(width: 8),
                Text('Ajouté aux favoris ❤️'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}