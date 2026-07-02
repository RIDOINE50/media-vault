import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_file.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/player_bar.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final List<MediaFile> files;
  final AudioService audioService;

  const AlbumDetailScreen({
    Key? key,
    required this.albumName,
    required this.files,
    required this.audioService,
  }) : super(key: key);

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> with TickerProviderStateMixin {
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  void _playAlbum() {
    widget.audioService.setPlaylist(widget.files, 0);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.pushNamed(context, '/player');
    });
  }

  void _playFile(int index) {
    widget.audioService.setPlaylist(widget.files, index);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.pushNamed(context, '/player');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isDark = settings.darkMode;
        final primaryColor = Theme.of(context).primaryColor;
        final artist = widget.files.isNotEmpty ? widget.files.first.artist : 'Artiste inconnu';
        final thumbnailUrl = widget.files.isNotEmpty ? widget.files.first.thumbnailUrl : null;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
          body: CustomScrollView(
            slivers: [
              // ✅ HEADER AVEC COVER
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image de fond
                      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                        Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _buildHeaderBackground(primaryColor),
                        )
                      else
                        _buildHeaderBackground(primaryColor),

                      // Overlay gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5)).withOpacity(0.8),
                              isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
                            ],
                          ),
                        ),
                      ),

                      // Infos de l'album
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.albumName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              artist,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.files.length} piste${widget.files.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ BOUTONS D'ACTION
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Bouton Play
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _playAlbum,
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: const Text(
                            'Lecture',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                            shadowColor: primaryColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bouton Shuffle
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            final shuffled = List<MediaFile>.from(widget.files)..shuffle();
                            widget.audioService.setPlaylist(shuffled, 0);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted) Navigator.pushNamed(context, '/player');
                            });
                          },
                          icon: Icon(Icons.shuffle_rounded, color: primaryColor, size: 24),
                          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ LISTE DES PISTES
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildAnimatedTrack(widget.files[index], index, isDark, primaryColor);
                    },
                    childCount: widget.files.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar: PlayerBar(
            audioService: widget.audioService,
            onTap: () => Navigator.pushNamed(context, '/player'),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBackground(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.6),
            primaryColor.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.album_rounded, size: 120, color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildAnimatedTrack(MediaFile file, int index, bool isDark, Color primaryColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildTrackTile(file, index, isDark, primaryColor),
      ),
    );
  }

  Widget _buildTrackTile(MediaFile file, int index, bool isDark, Color primaryColor) {
    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _playFile(index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Numéro de piste
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Infos
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
                      file.formattedDuration,
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton play
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}