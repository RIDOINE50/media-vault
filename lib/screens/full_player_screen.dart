import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← AJOUTE CETTE LIGNE
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/media_file.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';

class FullPlayerScreen extends StatefulWidget {
  final AudioService audioService;

  const FullPlayerScreen({
    Key? key,
    required this.audioService,
  }) : super(key: key);

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isShuffle = false;
  int _loopModeIndex = 0;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
    _checkIfFavorite();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkIfFavorite() {
    final currentMedia = widget.audioService.currentMedia;
    if (currentMedia != null) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      setState(() {
        _isFavorite = db.isFavorite(currentMedia.id);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final currentMedia = widget.audioService.currentMedia;
    if (currentMedia == null) return;

    final db = Provider.of<DatabaseService>(context, listen: false);
    
    setState(() {
      _isFavorite = !_isFavorite;
    });

    if (_isFavorite) {
      await db.addFavorite(currentMedia);
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
            duration: Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      await db.removeFavorite(currentMedia.id);
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
            backgroundColor: Colors.grey[800]!,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showFavoritesList() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final favorites = db.getFavorites();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Mes Favoris',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${favorites.length}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
            Expanded(
              child: favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: isDark ? Colors.grey[700] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun favori',
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clique sur ❤️ pour ajouter',
                            style: TextStyle(
                              color: isDark ? Colors.grey[600] : Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final media = favorites[index];
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor.withOpacity(0.3),
                                  Theme.of(context).primaryColor.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              media.isVideo ? Icons.movie : Icons.music_note,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            media.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            media.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.play_circle, color: Theme.of(context).primaryColor),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.audioService.setPlaylist(favorites, index);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistMenu() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final playlists = db.getPlaylistNames();
    final currentMedia = widget.audioService.currentMedia;
    if (currentMedia == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Ajouter à une playlist',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune playlist créée',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            else
              ...playlists.map((name) => ListTile(
                    leading: Icon(Icons.queue_music, color: Theme.of(context).primaryColor),
                    title: Text(
                      name,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    onTap: () async {
                      await db.addMediaToPlaylist(name, currentMedia);
                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ajouté à "$name"'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  )),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.add, color: Colors.green),
              title: Text(
                'Créer une nouvelle playlist',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              onTap: () async {
                Navigator.pop(context);
                final controller = TextEditingController();
                final newName = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                    title: Text(
                      'Nouvelle playlist',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Nom de la playlist',
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, controller.text.trim()),
                        child: Text('Créer'),
                      ),
                    ],
                  ),
                );
                if (newName != null && newName.isNotEmpty) {
                  await db.createPlaylist(newName);
                  await db.addMediaToPlaylist(newName, currentMedia);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playlist "$newName" créée'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ AMÉLIORÉ : Partager le média avec gestion d'erreur
    // ✅ AMÉLIORÉ : Partager avec fallback sur presse-papier
  void _shareMedia() async {
    final currentMedia = widget.audioService.currentMedia;
    if (currentMedia == null) return;
    
    final text = 'J\'écoute "${currentMedia.title}" de ${currentMedia.artist} sur MediaVault ! 🎵';
    
    try {
      // Essayer le partage normal
      await Share.share(
        text,
        subject: 'MediaVault - ${currentMedia.title}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.share, color: Colors.white),
                SizedBox(width: 8),
                Text('Partage réussi'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // ✅ FALLBACK : Copier dans le presse-papier si le partage échoue
      try {
        await Clipboard.setData(ClipboardData(text: text));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.content_copy, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Texte copié dans le presse-papier',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Partage non disponible. Tu peux maintenant coller le texte où tu veux.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.blue[700],
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (clipboardError) {
        // Si même le presse-papier échoue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Impossible de partager')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _showDetails() {
    final currentMedia = widget.audioService.currentMedia;
    if (currentMedia == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Détails du fichier',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Titre', currentMedia.title, isDark),
            _buildDetailRow('Artiste', currentMedia.artist, isDark),
            _buildDetailRow('Format', currentMedia.format.toUpperCase(), isDark),
            _buildDetailRow('Durée', currentMedia.formattedDuration, isDark),
            _buildDetailRow('Type', currentMedia.isVideo ? 'Vidéo' : 'Audio', isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  // ✅ AMÉLIORÉ : Shuffle fonctionnel
  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
    });
    
    // Connecter au vrai lecteur
    widget.audioService.setShuffle(_isShuffle);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_isShuffle ? Icons.shuffle : Icons.swap_vert, color: Colors.white),
              SizedBox(width: 8),
              Text(_isShuffle ? 'Lecture aléatoire activée 🔀' : 'Lecture aléatoire désactivée'),
            ],
          ),
          backgroundColor: _isShuffle ? Theme.of(context).primaryColor : Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ✅ AMÉLIORÉ : Loop fonctionnel
  void _toggleLoop() {
    setState(() {
      _loopModeIndex = (_loopModeIndex + 1) % 3;
    });
    
    // Connecter au vrai lecteur
    widget.audioService.setLoopMode(_loopModeIndex);
    
    if (mounted) {
      String message;
      IconData icon;
      switch (_loopModeIndex) {
        case 0:
          message = 'Répétition désactivée';
          icon = Icons.repeat;
          break;
        case 1:
          message = 'Répéter toute la playlist 🔁';
          icon = Icons.repeat;
          break;
        case 2:
          message = 'Répéter un morceau 🔂';
          icon = Icons.repeat_one;
          break;
        default:
          message = '';
          icon = Icons.repeat;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: _loopModeIndex > 0 ? Theme.of(context).primaryColor : Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isDark = settings.darkMode;
        final accentColor = Theme.of(context).primaryColor;
        
        return Scaffold(
          backgroundColor: isDark ? Colors.grey[950] : Colors.grey[100],
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white : Colors.black87, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Lecture en cours',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87),
                onPressed: _showFavoritesList,
              ),
            ],
          ),
          body: StreamBuilder<PlayerState>(
            stream: widget.audioService.playerStateStream,
            builder: (context, snapshot) {
              final currentMedia = widget.audioService.currentMedia;
              if (currentMedia == null) {
                return Center(
                  child: Text(
                    'Aucun média en lecture',
                    style: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                  ),
                );
              }

              return FadeTransition(
                opacity: _animationController,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        height: MediaQuery.of(context).size.width * 0.75,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withOpacity(0.8),
                              accentColor.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Icon(
                          currentMedia.isVideo ? Icons.movie : Icons.music_note,
                          size: 100,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 48),

                      Text(
                        currentMedia.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              currentMedia.artist.isNotEmpty ? currentMedia.artist : 'Artiste inconnu',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              size: 26,
                            ),
                            onPressed: _toggleFavorite,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      StreamBuilder<Duration>(
                        stream: widget.audioService.positionStream,
                        builder: (context, positionSnapshot) {
                          final position = positionSnapshot.data ?? Duration.zero;
                          final duration = widget.audioService.player.duration ?? Duration.zero;
                          final progress = duration.inMilliseconds > 0 
                              ? position.inMilliseconds / duration.inMilliseconds 
                              : 0.0;

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: accentColor,
                                  inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                                  thumbColor: accentColor,
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: SliderComponentShape.noOverlay,
                                ),
                                child: Slider(
                                  value: progress.clamp(0.0, 1.0),
                                  onChanged: (value) {
                                    final newPosition = duration * value;
                                    widget.audioService.seek(newPosition);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: _isShuffle ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              size: 28,
                            ),
                            onPressed: _toggleShuffle,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_previous, color: isDark ? Colors.white : Colors.black87, size: 40),
                            onPressed: widget.audioService.previous,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 48,
                              ),
                              onPressed: () {
                                if (widget.audioService.isPlaying) {
                                  widget.audioService.pause();
                                } else {
                                  widget.audioService.play();
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next, color: isDark ? Colors.white : Colors.black87, size: 40),
                            onPressed: widget.audioService.next,
                          ),
                          IconButton(
                            icon: Icon(
                              _loopModeIndex == 2 ? Icons.repeat_one : Icons.repeat,
                              color: _loopModeIndex > 0 ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              size: 28,
                            ),
                            onPressed: _toggleLoop,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(Icons.queue_music, 'Playlist', isDark, _showAddToPlaylistMenu),
                          _buildActionButton(Icons.info_outline, 'Détails', isDark, _showDetails),
                          _buildActionButton(Icons.share, 'Partager', isDark, _shareMedia),
                          _buildActionButton(Icons.lyrics, 'Paroles', isDark, () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fonctionnalité bientôt disponible'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }),
                        ],
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool isDark, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: isDark ? Colors.grey[300] : Colors.grey[700], size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}