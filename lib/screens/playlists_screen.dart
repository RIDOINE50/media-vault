import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({Key? key}) : super(key: key);

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<String> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    setState(() {
      _playlists = db.getPlaylistNames();
      _isLoading = false;
    });
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final settings = Provider.of<SettingsService>(context, listen: false);
    
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: settings.darkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Nouvelle playlist',
          style: TextStyle(color: settings.darkMode ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: settings.darkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Nom de la playlist',
            hintStyle: TextStyle(color: settings.darkMode ? Colors.grey[500] : Colors.grey[400]),
            filled: true,
            fillColor: settings.darkMode ? Colors.grey[800] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: settings.darkMode ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (name != null) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.createPlaylist(name);
      await _loadPlaylists();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playlist "$name" créée'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deletePlaylist(String name) async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: settings.darkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Supprimer la playlist',
          style: TextStyle(color: settings.darkMode ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "$name" ?',
          style: TextStyle(color: settings.darkMode ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: settings.darkMode ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.deletePlaylist(name);
      await _loadPlaylists();
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
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.queue_music, color: Theme.of(context).primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Playlists',
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
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
                onPressed: _createPlaylist,
                tooltip: 'Créer une playlist',
              ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                )
              : _playlists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.queue_music,
                              size: 64,
                              color: Theme.of(context).primaryColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Aucune playlist',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: settings.darkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crée ta première playlist\npour organiser tes musiques',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _createPlaylist,
                            icon: const Icon(Icons.add),
                            label: const Text('Créer une playlist'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final name = _playlists[index];
                        final db = Provider.of<DatabaseService>(context, listen: false);
                        final mediaCount = db.getPlaylistMedia(name).length;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: settings.darkMode ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: settings.darkMode ? Colors.grey[800]! : Colors.grey[300]!),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).primaryColor.withOpacity(0.3),
                                    Theme.of(context).primaryColor.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.queue_music,
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: settings.darkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '$mediaCount morceau${mediaCount > 1 ? 'x' : ''}',
                              style: TextStyle(
                                color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              color: settings.darkMode ? Colors.grey[850] : Colors.white,
                              icon: Icon(Icons.more_vert, color: settings.darkMode ? Colors.grey[400] : Colors.grey[600]),
                              onSelected: (value) {
                                if (value == 'delete') _deletePlaylist(name);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text('Supprimer', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlaylistDetailScreen(playlistName: name),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}