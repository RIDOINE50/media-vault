import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import '../services/connectivity_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../widgets/no_connection_banner.dart';
import '../widgets/download_progress_bar.dart';
import '../widgets/player_bar.dart';
import 'video_player_screen.dart';

class SearchScreen extends StatefulWidget {
  final ConnectivityService connectivityService;
  final AudioService audioService;

  const SearchScreen({
    Key? key,
    required this.connectivityService,
    required this.audioService,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  final DownloadService _downloadService = DownloadService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadingFileName = '';
  bool _downloadComplete = false;

  // ✅ Catégories colorées
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Musique', 'icon': Icons.music_note, 'color': const Color(0xFF7C4DFF), 'query': 'musique tendance'},
    {'name': 'Afrobeat', 'icon': Icons.album, 'color': const Color(0xFFFF6B6B), 'query': 'afrobeat 2024'},
    {'name': 'Hip-Hop', 'icon': Icons.mic, 'color': const Color(0xFFFFA726), 'query': 'hip hop'},
    {'name': 'Coupé-Décalé', 'icon': Icons.queue_music, 'color': const Color(0xFF66BB6A), 'query': 'coupé décalé'},
    {'name': 'RnB', 'icon': Icons.headphones, 'color': const Color(0xFFEC407A), 'query': 'rnb'},
    {'name': 'Gospel', 'icon': Icons.church, 'color': const Color(0xFF42A5F5), 'query': 'gospel'},
    {'name': 'Vidéo', 'icon': Icons.movie, 'color': const Color(0xFFEF5350), 'query': 'clip vidéo'},
    {'name': 'Live', 'icon': Icons.live_tv, 'color': const Color(0xFF26C6DA), 'query': 'concert live'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _youtubeService.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  void _loadSearchHistory() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    setState(() {
      _searchHistory = db.getSearchHistory();
    });
  }

  void _clearHistory() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.clearSearchHistory();
    _loadSearchHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.white),
              SizedBox(width: 8),
              Text('Historique effacé'),
            ],
          ),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _search([String? overrideQuery]) async {
    if (!widget.connectivityService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pas de connexion internet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String query = overrideQuery ?? _searchController.text.trim();
    if (query.isEmpty) return;

    _searchController.text = query;
    _searchFocusNode.unfocus();

    setState(() {
      _isSearching = true;
      _downloadComplete = false;
    });

    _searchResults = await _youtubeService.search(query);

    final db = Provider.of<DatabaseService>(context, listen: false);
    db.addSearchQuery(query);
    _loadSearchHistory();

    setState(() => _isSearching = false);
  }

  Future<void> _playVideo(String videoId, String title, String author) async {
    if (!widget.connectivityService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion internet requise'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      String? videoUrl = await _youtubeService.getVideoUrl(videoId);

      if (videoUrl != null && mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoPath: videoUrl,
              title: title,
            ),
          ),
        );
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de lire cette vidéo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _download(String videoId, String title, bool isAudioOnly) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadingFileName = title;
      _downloadComplete = false;
    });

    var result = await _downloadService.downloadFromYouTube(
      videoId: videoId,
      isAudioOnly: isAudioOnly,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
    );

    setState(() {
      _isDownloading = false;
      _downloadComplete = result != null;
    });

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Téléchargement terminé !'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _downloadComplete = false;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du téléchargement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDownloadOptions(String videoId, String title) {
    final settings = Provider.of<SettingsService>(context, listen: false);
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
              'Télécharger',
              style: TextStyle(
                color: settings.darkMode ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                style: TextStyle(
                  color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.audiotrack, color: Colors.purple, size: 24),
              ),
              title: Text(
                'Audio MP3',
                style: TextStyle(
                  color: settings.darkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Meilleure qualité audio',
                style: TextStyle(color: settings.darkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _download(videoId, title, true);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.movie, color: Colors.blue, size: 24),
              ),
              title: Text(
                'Vidéo MP4',
                style: TextStyle(
                  color: settings.darkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Vidéo complète avec son',
                style: TextStyle(color: settings.darkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _download(videoId, title, false);
              },
            ),
            const SizedBox(height: 20),
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

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
            elevation: 0,
            title: Text(
              'Rechercher',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ),
          body: Column(
            children: [
              // Bannière pas de connexion
              StreamBuilder<bool>(
                stream: widget.connectivityService.connectionStream,
                initialData: widget.connectivityService.isConnected,
                builder: (context, snapshot) {
                  if (snapshot.data == false) {
                    return const NoConnectionBanner();
                  }
                  return const SizedBox.shrink();
                },
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔍 GRANDE BARRE DE RECHERCHE
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un son, une vidéo, un artiste...',
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),

                      // 🎨 GRILLE DE CATÉGORIES
                      if (_searchResults.isEmpty && _searchController.text.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Explorer',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.8,
                            children: _categories.map((cat) => _buildCategoryCard(cat, isDark)).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 🕐 HISTORIQUE
                        if (_searchHistory.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recherches récentes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _clearHistory,
                                  icon: Icon(Icons.delete_outline, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  label: Text(
                                    'Effacer',
                                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._searchHistory.take(5).map((query) => _buildHistoryItem(query, isDark)),
                        ],
                      ],

                      // ⏳ RECHERCHE EN COURS
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Recherche en cours...',
                                  style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 📥 TÉLÉCHARGEMENT EN COURS
                      if (_isDownloading)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: DownloadProgressBar(
                            progress: _downloadProgress,
                            fileName: _downloadingFileName,
                          ),
                        ),

                      // ✅ TÉLÉCHARGEMENT TERMINÉ
                      if (_downloadComplete)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Téléchargement terminé !',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 🎵 RÉSULTATS
                      if (!_isSearching && _searchResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            '${_searchResults.length} résultat${_searchResults.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ..._searchResults.map((result) => _buildResultCard(result, isDark)),
                        const SizedBox(height: 100),
                      ],
                    ],
                  ),
                ),
              ),
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

  // ✅ Carte de catégorie colorée
  Widget _buildCategoryCard(Map<String, dynamic> cat, bool isDark) {
    return Material(
      color: (cat['color'] as Color),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _search(cat['query'] as String),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  cat['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cat['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Élément d'historique
  Widget _buildHistoryItem(String query, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(
            Icons.history,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          title: Text(
            query,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
          trailing: Icon(
            Icons.north_west,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
            size: 18,
          ),
          onTap: () => _search(query),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ✅ Carte de résultat améliorée
  Widget _buildResultCard(Map<String, dynamic> result, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _playVideo(
            result['id'],
            result['title'],
            result['author'],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        result['thumbnail'],
                        width: 110,
                        height: 62,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) {
                          return Container(
                            width: 110,
                            height: 62,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: Icon(
                              Icons.video_library,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                          );
                        },
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['title'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result['author'],
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
                // Bouton télécharger
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.download,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    onPressed: () => _showDownloadOptions(
                      result['id'],
                      result['title'],
                    ),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}