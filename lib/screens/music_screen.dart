import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/media_file.dart';
import '../services/file_service.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../widgets/player_bar.dart';
import 'settings_screen.dart';

class MusicScreen extends StatefulWidget {
  final AudioService audioService;

  const MusicScreen({
    Key? key,
    required this.audioService,
  }) : super(key: key);

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> with TickerProviderStateMixin {
  final FileService _fileService = FileService();
  final TextEditingController _searchController = TextEditingController();
  
  static const MethodChannel _ringtoneChannel = MethodChannel('com.mediavault/ringtone');

  List<MediaFile> _allMusic = [];
  List<MediaFile> _recentMusic = [];
  List<MediaFile> _filteredMusic = [];
  
  bool _isLoading = true;
  String _currentSort = 'recent_desc';
  
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};
  
  late AnimationController _listAnimationController;
  
  @override
  void initState() { 
    super.initState();
    
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _loadMusic();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadMusic() async {
    setState(() => _isLoading = true);
    
    final allFiles = await _fileService.scanAllFiles(forceRescan: false);
    
    _allMusic = allFiles.where((file) => !file.isVideo).toList();
    _recentMusic = FileService.sortByRecentDesc(_allMusic).take(10).toList();
    
    _applyFilter();
    
    setState(() => _isLoading = false);
    
    _listAnimationController.forward(from: 0);
  }

  void _applyFilter() {
    setState(() {
      var filtered = _allMusic.where((file) {
        if (_searchController.text.isEmpty) return true;
        
        String query = _searchController.text.toLowerCase();
        return file.title.toLowerCase().contains(query) ||
               file.artist.toLowerCase().contains(query);
      }).toList();
      
      switch (_currentSort) {
        case 'recent_desc':
          filtered = FileService.sortByRecentDesc(filtered);
          break;
        case 'recent_asc':
          filtered = FileService.sortByRecentAsc(filtered);
          break;
        case 'name_asc':
          filtered = FileService.sortByNameAsc(filtered);
          break;
        case 'name_desc':
          filtered = FileService.sortByNameDesc(filtered);
          break;
        case 'artist':
          filtered = FileService.sortByArtist(filtered);
          break;
      }
      
      _filteredMusic = filtered;
    });
    
    _listAnimationController.forward(from: 0);
  }

  void _playFile(MediaFile file) {
    if (_isSelectionMode) {
      _toggleSelection(file.id);
      return;
    }
    
    int index = _filteredMusic.indexOf(file);
    if (index != -1) {
      widget.audioService.setPlaylist(_filteredMusic, index);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pushNamed(context, '/player');
      });
    }
  }

  void _showSortMenu() {
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
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Trier par',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildSortOption('recent_desc', 'Plus récent d\'abord', Icons.schedule),
            _buildSortOption('recent_asc', 'Plus ancien d\'abord', Icons.history),
            _buildSortOption('name_asc', 'Nom A → Z', Icons.sort_by_alpha),
            _buildSortOption('name_desc', 'Nom Z → A', Icons.sort),
            _buildSortOption('artist', 'Artiste', Icons.person),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _currentSort == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
      onTap: () {
        setState(() => _currentSort = value);
        _applyFilter();
        Navigator.pop(context);
      },
    );
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case 'recent_desc': return 'Plus récent';
      case 'recent_asc': return 'Plus ancien';
      case 'name_asc': return 'A → Z';
      case 'name_desc': return 'Z → A';
      case 'artist': return 'Artiste';
      default: return '';
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _filteredMusic.map((f) => f.id).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
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
              _isSelectionMode ? '${_selectedIds.length} sélectionné${_selectedIds.length > 1 ? 's' : ''}' : 'Musique',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 32,
                letterSpacing: -0.5,
              ),
            ),
                      actions: [
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  onPressed: _selectAll,
                  tooltip: 'Tout sélectionner',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _deselectAll,
                  tooltip: 'Annuler',
                ),
              ] // Dans actions, remplace par :
else ...[
  IconButton(
    icon: Icon(Icons.checklist_outlined, color: isDark ? Colors.white : Colors.black87),
    onPressed: _toggleSelectionMode,
    tooltip: 'Sélection multiple',
  ),
  IconButton(
    icon: Icon(Icons.sort_rounded, color: isDark ? Colors.white : Colors.black87),
    onPressed: _showSortMenu,
    tooltip: 'Trier',
  ),
  _buildAppBarIcon(Icons.favorite_outline, 'Favoris', () => Navigator.pushNamed(context, '/favorites'), isDark),
  _buildAppBarIcon(Icons.settings, 'Paramètres', () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const SettingsScreen()),
  ), isDark),
  // ✅ Déplacé à la fin
  _buildAppBarIcon(Icons.queue_music, 'Playlists', () => Navigator.pushNamed(context, '/playlists'), isDark),
],
            ],
          ),
          body: _isLoading
              ? _buildShimmerLoading(isDark)
              : RefreshIndicator(
                  onRefresh: _loadMusic,
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

                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildAnimatedCounter(isDark),
                        ),

                        const SizedBox(height: 24),

                        if (_recentMusic.isNotEmpty && !_isSelectionMode) ...[
                          _buildSectionHeader('Récemment ajouté', isDark),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _recentMusic.length,
                              itemBuilder: (context, index) {
                                return _buildAnimatedMediaCard(_recentMusic[index], isDark, primaryColor, index);
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        _buildSectionHeader('Toutes les musiques', isDark),
                        
                        if (_filteredMusic.isEmpty)
                          _buildEmptyState(isDark)
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredMusic.length,
                              itemBuilder: (context, index) {
                                return _buildAnimatedListTile(_filteredMusic[index], isDark, primaryColor, index);
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
    return TextField(
      controller: _searchController,
      onChanged: (_) => _applyFilter(),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Rechercher une musique...',
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
    );
  }

  Widget _buildAnimatedCounter(bool isDark) {
    return Row(
      children: [
        Text(
          '${_filteredMusic.length} musiques',
          style: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.sort_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          _getSortLabel(),
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                    colors: [primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 48,
                        color: primaryColor,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              file.artist,
              maxLines: 2,
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
    final isSelected = _selectedIds.contains(file.id);
    
    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _playFile(file),
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() => _isSelectionMode = true);
          }
          _toggleSelection(file.id);
        },
        splashColor: primaryColor.withOpacity(0.1),
        highlightColor: primaryColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isSelected 
                ? Border.all(color: primaryColor, width: 2)
                : null,
          ),
          child: Row(
            children: [
              if (_isSelectionMode) ...[
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? primaryColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  size: 28,
                ),
                const SizedBox(width: 12),
              ],
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: primaryColor,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              if (!_isSelectionMode)
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
                    _buildMenuItem(Icons.music_note_rounded, 'Définir comme sonnerie', 'ringtone'),
                    const PopupMenuDivider(),
                    _buildMenuItem(Icons.favorite_rounded, 'Ajouter aux favoris', 'favorite', textColor: Colors.red),
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
            Icon(Icons.music_off_rounded, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune musique trouvée',
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
          Icon(
            Icons.music_note_rounded,
            size: 64,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement de ta musique...',
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
        title: Text(
          'Renommer',
          style: TextStyle(
            color: settings.darkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: settings.darkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Nouveau nom',
            filled: true,
            fillColor: settings.darkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
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
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.isNotEmpty && newName != file.title) {
      try {
        final oldFile = File(file.path);
        
        // ✅ VÉRIFIER SI LE FICHIER EXISTE
        if (!await oldFile.exists()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Fichier introuvable'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
        
        final directory = oldFile.parent;
        final extension = file.format;
        final newPath = '${directory.path}${Platform.pathSeparator}$newName.$extension';
        
        final newFile = File(newPath);
        
        // ✅ VÉRIFIER SI LE NOUVEAU NOM EXISTE DÉJÀ
        if (await newFile.exists()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Un fichier avec ce nom existe déjà'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
        
        print(' Renommage de: ${file.path}');
        print('📝 Vers: $newPath');
        
        // ✅ MÉTHODE COMPATIBLE ANDROID 11+ : COPIER PUIS SUPPRIMER
        await oldFile.copy(newPath);
        await oldFile.delete();
        
        print('✅ Fichier renommé avec succès');
        
        // ✅ METTRE À JOUR LA LISTE
        setState(() {
          final index = _allMusic.indexWhere((f) => f.id == file.id);
          if (index != -1) {
            _allMusic[index] = MediaFile(
              id: newPath.hashCode.toString(),
              title: newName,
              artist: file.artist,
              album: file.album,
              path: newPath,
              duration: file.duration,
              format: file.format,
              isVideo: file.isVideo,
              downloadDate: file.downloadDate,
              isFromYouTube: file.isFromYouTube,
              thumbnailUrl: file.thumbnailUrl,
            );
          }
          _applyFilter();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Renommé en "$newName"')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        print('❌ Erreur renommage: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _shareFile(MediaFile file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        text: 'Écoute "${file.title}" via MediaVault ',
        subject: file.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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
    try {
      final fileToDelete = File(file.path);
      // ✅ VÉRIFIER SI LE FICHIER EXISTE AVANT DE SUPPRIMER
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
        print('✅ Fichier supprimé: ${file.path}');
      } else {
        print('⚠️ Fichier déjà supprimé ou inexistant: ${file.path}');
      }
    } catch (e) {
      print('⚠️ Erreur suppression fichier: $e');
    }
    
    await db.removeFavorite(file.id);
    setState(() {
      _allMusic.removeWhere((f) => f.id == file.id);
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
    try {
      final canWrite = await _ringtoneChannel.invokeMethod<bool>('canWriteSettings') ?? false;
      
      if (!canWrite) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Permission requise', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Pour définir une sonnerie, tu dois autoriser l\'application à modifier les paramètres système.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _ringtoneChannel.invokeMethod('openWriteSettings');
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Autoriser'),
              ),
            ],
          ),
        );
        
        if (openSettings != true) return;
        await Future.delayed(const Duration(seconds: 2));
      }

      final success = await _ringtoneChannel.invokeMethod<bool>(
        'setAsRingtone',
        {
          'filePath': file.path,
          'fileName': file.title,
        },
      );

      if (mounted) {
        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('"${file.title}" défini comme sonnerie 🎵')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Impossible de définir comme sonnerie'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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