import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/music_screen.dart';
import 'screens/videos_screen.dart';
import 'screens/search_screen.dart';
import 'screens/downloaded_screen.dart';
import 'screens/full_player_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/playlists_screen.dart';
import 'services/audio_service.dart';
import 'services/connectivity_service.dart';
import 'services/settings_service.dart';
import 'services/database_service.dart';
import 'services/download_manager.dart'; // ✅ NOUVEAU IMPORT
import 'utils/permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('favorites');
  await Hive.openBox('playlists');
  await Hive.openBox('search_history');
  await Hive.openBox('playback_positions');
  await Hive.openBox('custom_albums');
  await Hive.openBox('file_cache'); // ✅ AJOUTÉ POUR LE CACHE
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final settingsService = SettingsService();
  await settingsService.init();
  
  final databaseService = DatabaseService();
  final audioService = AudioService(settingsService);
  audioService.databaseService = databaseService;
  await audioService.init();
  
  // ✅ CRÉATION DU DOWNLOAD MANAGER
  final downloadManager = DownloadManager();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        Provider.value(value: databaseService),
        Provider.value(value: audioService),
        ChangeNotifierProvider.value(value: downloadManager), // ✅ AJOUTÉ
      ],
      child: const MediaVaultApp(),
    ),
  );
}

class MediaVaultApp extends StatefulWidget {
  const MediaVaultApp({Key? key}) : super(key: key);

  @override
  State<MediaVaultApp> createState() => _MediaVaultAppState();
}

class _MediaVaultAppState extends State<MediaVaultApp> {
  final ConnectivityService _connectivityService = ConnectivityService();
  int _currentIndex = 0;
  bool _permissionsGranted = false;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _connectivityService.init();

    bool permissions;
    try {
      permissions = await PermissionService.requestAllPermissions()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (e) {
      print('⚠️ Timeout permissions: $e');
      permissions = false;
    }

    if (!mounted) return;

    setState(() {
      _permissionsGranted = true;
    });
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    // ✅ DISPOSER LE DOWNLOAD MANAGER
    final downloadManager = Provider.of<DownloadManager>(context, listen: false);
    downloadManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final audioService = Provider.of<AudioService>(context, listen: false);
        
        return MaterialApp(
          title: 'BoomMedia',
          debugShowCheckedModeBanner: false,
          theme: settings.currentTheme,
          builder: (context, child) => child!,
          home: _permissionsGranted
              ? _buildMainScreen(audioService)
              : _buildPermissionScreen(),
          routes: {
            '/player': (context) => FullPlayerScreen(
              audioService: Provider.of<AudioService>(context, listen: false),
            ),
            '/settings': (context) => const SettingsScreen(),
            '/favorites': (context) => FavoritesScreen(
              audioService: Provider.of<AudioService>(context, listen: false),
            ),
            '/playlists': (context) => const PlaylistsScreen(),
          },
        );
      },
    );
  }

  Widget _buildPermissionScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.music_note,
                      size: 64,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'MediaVault',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Votre bibliothèque musicale',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 48),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6200EE),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chargement...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Passage automatique dans 3 secondes...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScreen(AudioService audioService) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MusicScreen(audioService: audioService),
          VideosScreen(audioService: audioService),
          SearchScreen(
            connectivityService: _connectivityService,
            audioService: audioService,
          ),
          DownloadedScreen(audioService: audioService),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: 'Musique',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Vidéos',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Rechercher',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_done),
            label: 'Téléchargés',
          ),
        ],
      ),
    );
  }
}