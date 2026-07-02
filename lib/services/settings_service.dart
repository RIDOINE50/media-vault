import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static SharedPreferences? _prefs;

  // Lecture
  double _defaultVolume = 0.8;
  bool _shufflePlayback = false;
  bool _loopPlayback = false;
  bool _backgroundPlayback = true;
  bool _sleepTimer = false;
  int _sleepTimerMinutes = 30;

  // Téléchargement
  String _audioQuality = '128';
  bool _wifiOnly = true;
  bool _downloadNotification = true;

  // Apparence
  bool _darkMode = true;
  String _accentColor = 'purple';
  String _listDisplay = 'compact';

  // Confidentialité
  bool _appLock = false;
  bool _shareStats = false;

  // Getters
  double get defaultVolume => _defaultVolume;
  bool get shufflePlayback => _shufflePlayback;
  bool get loopPlayback => _loopPlayback;
  bool get backgroundPlayback => _backgroundPlayback;
  bool get sleepTimer => _sleepTimer;
  int get sleepTimerMinutes => _sleepTimerMinutes;
  String get audioQuality => _audioQuality;
  bool get wifiOnly => _wifiOnly;
  bool get downloadNotification => _downloadNotification;
  bool get darkMode => _darkMode;
  String get accentColor => _accentColor;
  String get listDisplay => _listDisplay;
  bool get appLock => _appLock;
  bool get shareStats => _shareStats;

  // Thème dynamique
  ThemeData get currentTheme => _darkMode ? _darkTheme : _lightTheme;

  ThemeData get _darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: _getAccentColor(),
    scaffoldBackgroundColor: Colors.grey[950],
    colorScheme: ColorScheme.dark(
      primary: _getAccentColor(),
      secondary: _getAccentColor(),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[950],
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.grey[900],
      elevation: 2,
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );

  ThemeData get _lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: _getAccentColor(),
    scaffoldBackgroundColor: Colors.grey[100],
    colorScheme: ColorScheme.light(
      primary: _getAccentColor(),
      secondary: _getAccentColor(),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 1,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
    ),
  );

  Color _getAccentColor() {
    switch (_accentColor) {
      case 'blue':
        return const Color(0xFF2196F3);
      case 'green':
        return const Color(0xFF4CAF50);
      case 'red':
        return const Color(0xFFF44336);
      case 'orange':
        return const Color(0xFFFF9800);
      case 'teal':
        return const Color(0xFF009688);
      default:
        return const Color(0xFF6200EE); // violet par défaut
    }
  }

  // Initialisation
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    _defaultVolume = _prefs?.getDouble('default_volume') ?? 0.8;
    _shufflePlayback = _prefs?.getBool('shuffle_playback') ?? false;
    _loopPlayback = _prefs?.getBool('loop_playback') ?? false;
    _backgroundPlayback = _prefs?.getBool('background_playback') ?? true;
    _sleepTimer = _prefs?.getBool('sleep_timer') ?? false;
    _sleepTimerMinutes = _prefs?.getInt('sleep_timer_minutes') ?? 30;
    _audioQuality = _prefs?.getString('audio_quality') ?? '128';
    _wifiOnly = _prefs?.getBool('wifi_only') ?? true;
    _downloadNotification = _prefs?.getBool('download_notification') ?? true;
    _darkMode = _prefs?.getBool('dark_mode') ?? true;
    _accentColor = _prefs?.getString('accent_color') ?? 'purple';
    _listDisplay = _prefs?.getString('list_display') ?? 'compact';
    _appLock = _prefs?.getBool('app_lock') ?? false;
    _shareStats = _prefs?.getBool('share_stats') ?? false;
    notifyListeners();
  }

  // Setters avec sauvegarde
  Future<void> setDefaultVolume(double value) async {
    _defaultVolume = value;
    await _prefs?.setDouble('default_volume', value);
    notifyListeners();
  }

  Future<void> setShufflePlayback(bool value) async {
    _shufflePlayback = value;
    await _prefs?.setBool('shuffle_playback', value);
    notifyListeners();
  }

  Future<void> setLoopPlayback(bool value) async {
    _loopPlayback = value;
    await _prefs?.setBool('loop_playback', value);
    notifyListeners();
  }

  Future<void> setBackgroundPlayback(bool value) async {
    _backgroundPlayback = value;
    await _prefs?.setBool('background_playback', value);
    notifyListeners();
  }

  Future<void> setSleepTimer(bool value) async {
    _sleepTimer = value;
    await _prefs?.setBool('sleep_timer', value);
    notifyListeners();
  }

  Future<void> setSleepTimerMinutes(int value) async {
    _sleepTimerMinutes = value;
    await _prefs?.setInt('sleep_timer_minutes', value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    _audioQuality = value;
    await _prefs?.setString('audio_quality', value);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    await _prefs?.setBool('wifi_only', value);
    notifyListeners();
  }

  Future<void> setDownloadNotification(bool value) async {
    _downloadNotification = value;
    await _prefs?.setBool('download_notification', value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _prefs?.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setAccentColor(String value) async {
    _accentColor = value;
    await _prefs?.setString('accent_color', value);
    notifyListeners();
  }

  Future<void> setListDisplay(String value) async {
    _listDisplay = value;
    await _prefs?.setString('list_display', value);
    notifyListeners();
  }

  Future<void> setAppLock(bool value) async {
    _appLock = value;
    await _prefs?.setBool('app_lock', value);
    notifyListeners();
  }

  Future<void> setShareStats(bool value) async {
    _shareStats = value;
    await _prefs?.setBool('share_stats', value);
    notifyListeners();
  }
}