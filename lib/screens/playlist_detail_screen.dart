import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_file.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../widgets/media_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistName;

  const PlaylistDetailScreen({
    Key? key,
    required this.playlistName,
  }) : super(key: key);

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<MediaFile> _mediaList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
  setState(() => _isLoading = true);
  final db = Provider.of<DatabaseService>(context, listen: false);
  
  // ✅ Utilise getValidPlaylistMedia() au lieu de getPlaylistMedia()
  final mediaList = await db.getValidPlaylistMedia(widget.playlistName);
  
  setState(() {
    _mediaList = mediaList;
    _isLoading = false;
  });
}

  Future<void> _removeMedia(MediaFile media) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.removeMediaFromPlaylist(widget.playlistName, media.id);
    await _loadMedia();
  }

  void _playMedia(int index) {
    final audioService = Provider.of<AudioService>(context, listen: false);
    audioService.setPlaylist(_mediaList, index);
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
            title: Text(
              widget.playlistName,
              style: TextStyle(
                color: settings.darkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: settings.darkMode ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
              : _mediaList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_off,
                            size: 80,
                            color: settings.darkMode ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Playlist vide',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: settings.darkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajoute des musiques depuis\nl\'écran Fichiers',
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.2),
                                Theme.of(context).primaryColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.music_note, color: Theme.of(context).primaryColor, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                '${_mediaList.length} morceau${_mediaList.length > 1 ? 'x' : ''}',
                                style: TextStyle(
                                  color: settings.darkMode ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  if (_mediaList.isNotEmpty) {
                                    final audioService = Provider.of<AudioService>(context, listen: false);
                                    audioService.setPlaylist(_mediaList, 0);
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
                            itemCount: _mediaList.length,
                            itemBuilder: (context, index) {
                              final media = _mediaList[index];
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
                                onDismissed: (_) => _removeMedia(media),
                                child: MediaTile(
                                  media: media,
                                  onTap: () => _playMedia(index),
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