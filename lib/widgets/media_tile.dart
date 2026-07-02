import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_file.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class MediaTile extends StatefulWidget {
  final MediaFile media;
  final VoidCallback onTap;
  final bool showFavoriteButton;

  const MediaTile({
    Key? key,
    required this.media,
    required this.onTap,
    this.showFavoriteButton = true,
  }) : super(key: key);

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
    _checkFavorite();
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _checkFavorite() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    setState(() {
      _isFavorite = db.isFavorite(widget.media.id);
    });
  }

  Future<void> _toggleFavorite() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    if (_isFavorite) {
      await db.removeFavorite(widget.media.id);
      setState(() => _isFavorite = false);
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
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      await db.addFavorite(widget.media);
      setState(() => _isFavorite = true);
      _heartController.forward().then((_) => _heartController.reverse());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.favorite, color: Colors.white),
                SizedBox(width: 8),
                Text('Ajouté aux favoris ❤️'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showAddToPlaylistMenu() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final settings = Provider.of<SettingsService>(context, listen: false);
    final playlists = db.getPlaylistNames();

    showModalBottomSheet(
      context: context,
      backgroundColor: settings.darkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: settings.darkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ajouter à une playlist',
              style: TextStyle(
                color: settings.darkMode ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.media.title,
              style: TextStyle(
                color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune playlist créée',
                  style: TextStyle(
                    color: settings.darkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              )
            else
              ...playlists.map((name) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.queue_music,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: settings.darkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      await db.addMediaToPlaylist(name, widget.media);
                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ajouté à "$name"'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                  )),
            const SizedBox(height: 12),
            Divider(color: settings.darkMode ? Colors.grey[700] : Colors.grey[300]),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.green),
              ),
              title: Text(
                'Créer une nouvelle playlist',
                style: TextStyle(
                  color: settings.darkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _createNewPlaylist();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewPlaylist() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final settings = Provider.of<SettingsService>(context, listen: false);
    final controller = TextEditingController();

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
      await db.createPlaylist(name);
      await db.addMediaToPlaylist(name, widget.media);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playlist "$name" créée et média ajouté'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ✅ NOUVEAU : Widget pour afficher l'artwork (sans on_audio_query)
  Widget _buildArtwork(BuildContext context, Color accentColor) {
    if (widget.media.isVideo) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.movie, color: Colors.blue, size: 28),
      );
    }

    // Si on a une URL de thumbnail
    if (widget.media.thumbnailUrl != null && widget.media.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          widget.media.thumbnailUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultArtwork(accentColor),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      );
    }

    // Sinon, artwork par défaut
    return _buildDefaultArtwork(accentColor);
  }

  Widget _buildDefaultArtwork(Color accentColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.music_note, color: accentColor, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: _buildArtwork(context, accentColor), // ✅ Utilisation du nouveau widget
        title: Text(
          widget.media.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.media.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('•', style: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400])),
              ),
              Text(
                widget.media.formattedDuration,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('•', style: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400])),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.media.isVideo
                      ? Colors.blue.withOpacity(0.2)
                      : accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.media.format.toUpperCase(),
                  style: TextStyle(
                    color: widget.media.isVideo ? Colors.blue : accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showFavoriteButton)
              AnimatedBuilder(
                animation: _heartScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heartScale.value,
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        size: 22,
                      ),
                      onPressed: _toggleFavorite,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  );
                },
              ),
            PopupMenuButton<String>(
              color: isDark ? Colors.grey[850] : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Icon(Icons.more_vert, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              onSelected: (value) {
                if (value == 'playlist') _showAddToPlaylistMenu();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                      const SizedBox(width: 12),
                      Text(
                        'Ajouter à une playlist',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}