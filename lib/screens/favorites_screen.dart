import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_file.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../widgets/media_tile.dart';

class FavoritesScreen extends StatefulWidget {
  final AudioService audioService;

  const FavoritesScreen({
    Key? key,
    required this.audioService,
  }) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<MediaFile> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // ✅ Utilise getValidFavorites() au lieu de getFavorites()
    final favorites = await db.getValidFavorites();
    
    setState(() {
      _favorites = favorites;
      _isLoading = false;
    });
  }

  void _playFavorite(int index) {
    widget.audioService.setPlaylist(_favorites, index);
  }

  Future<void> _removeFavorite(MediaFile media) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.removeFavorite(media.id);
    await _loadFavorites();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        return Scaffold(
          backgroundColor: settings.darkMode ? Colors.grey[950] : Colors.grey[50],
          appBar: AppBar(
            backgroundColor: settings.darkMode ? Colors.grey[950] : Colors.grey[100],
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Favoris',
                  style: TextStyle(
                    color: settings.darkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            centerTitle: false,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: settings.darkMode ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite_border,
                              size: 64,
                              color: Colors.red[300],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Aucun favori',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: settings.darkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajoute des musiques à tes favoris\nen cliquant sur le ❤️',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Stats
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.2),
                                Theme.of(context).primaryColor.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.music_note, color: Colors.red, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                '${_favorites.length} favori${_favorites.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: settings.darkMode ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  if (_favorites.isNotEmpty) {
                                    widget.audioService.setPlaylist(_favorites, 0);
                                  }
                                },
                                icon: Icon(Icons.play_arrow, color: Theme.of(context).primaryColor),
                                label: Text(
                                  'Tout lire',
                                  style: TextStyle(color: Theme.of(context).primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _favorites.length,
                            itemBuilder: (context, index) {
                              final media = _favorites[index];
                              return Dismissible(
                                key: Key(media.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (_) => _removeFavorite(media),
                                child: MediaTile(
                                  media: media,
                                  onTap: () => _playFavorite(index),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}