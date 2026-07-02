import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import '../models/media_file.dart';
import 'settings_service.dart';
import 'database_service.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final SettingsService _settings;
  DatabaseService? _databaseService;
  audio_service.AudioHandler? _audioHandler;
  List<MediaFile> _playlist = [];
  int _currentIndex = 0;
  Timer? _positionSaveTimer;
  String? _currentMediaId;

  AudioService(this._settings);

  set databaseService(DatabaseService db) {
    _databaseService = db;
  }

  AudioPlayer get player => _player;
  List<MediaFile> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  MediaFile? get currentMedia => _playlist.isNotEmpty ? _playlist[_currentIndex] : null;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;

  Future<void> init() async {
    await _player.setVolume(_settings.defaultVolume);

    if (_settings.loopPlayback) {
      await _player.setLoopMode(LoopMode.all);
    }

    _settings.addListener(_onSettingsChanged);

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });

    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentPosition();
    });
  }

  Future<void> initAudioHandler() async {
    _audioHandler = await audio_service.AudioService.init(
      builder: () => MediaHandler(_player, this),
      config: const audio_service.AudioServiceConfig(
        androidNotificationChannelId: 'com.mediavault.channel.audio',
        androidNotificationChannelName: 'MediaVault Audio',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  void _onSettingsChanged() {
    _player.setVolume(_settings.defaultVolume);
    if (_settings.loopPlayback) {
      _player.setLoopMode(LoopMode.all);
    } else {
      _player.setLoopMode(LoopMode.off);
    }
  }

  Future<void> setPlaylist(List<MediaFile> files, int startIndex) async {
    if (startIndex >= 0 && startIndex < files.length) {
      final fileToCheck = File(files[startIndex].path);
      if (!await fileToCheck.exists()) {
        print('⚠️ Fichier introuvable: ${files[startIndex].path}');
        if (startIndex + 1 < files.length) {
          return setPlaylist(files, startIndex + 1);
        }
        return;
      }
    }

    _playlist = List.from(files);

    if (_settings.shufflePlayback) {
      _playlist.shuffle();
    }

    _currentIndex = startIndex;

    List<AudioSource> sources = [];
    for (var file in _playlist) {
      final f = File(file.path);
      if (await f.exists()) {
        sources.add(AudioSource.file(file.path, tag: file.title));
      } else {
        print('⚠️ Fichier ignoré (inexistant): ${file.path}');
      }
    }

    if (sources.isEmpty) {
      print('⚠️ Aucun fichier valide dans la playlist');
      return;
    }

    ConcatenatingAudioSource playlist = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(playlist, initialIndex: startIndex);

    final media = _playlist[startIndex];
    _currentMediaId = media.id;
    
    if (_databaseService != null) {
      final savedPosition = _databaseService!.getPlaybackPosition(media.id);
      if (savedPosition != null && savedPosition > Duration.zero) {
        await _player.seek(savedPosition);
      }
    }

    updateMediaItem(media); // ✅ APPEL PUBLIC
    await play();
  }

  Future<void> playFile(MediaFile file) async {
    final f = File(file.path);
    if (!await f.exists()) {
      print('⚠️ Fichier introuvable: ${file.path}');
      return;
    }

    _playlist = [file];
    _currentIndex = 0;
    _currentMediaId = file.id;
    await _player.setFilePath(file.path);
    
    if (_databaseService != null) {
      final savedPosition = _databaseService!.getPlaybackPosition(file.id);
      if (savedPosition != null && savedPosition > Duration.zero) {
        await _player.seek(savedPosition);
      }
    }
    
    updateMediaItem(file); // ✅ APPEL PUBLIC
    await play();
  }

  // ✅ MÉTHODE PUBLIQUE (plus de _)
  void updateMediaItem(MediaFile media) {
    if (_audioHandler != null && _audioHandler is MediaHandler) {
      (_audioHandler as MediaHandler).updateMedia(media);
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    _saveCurrentPosition();
  }

  Future<void> next() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await _player.seekToNext();
      _currentMediaId = _playlist[_currentIndex].id;
      updateMediaItem(_playlist[_currentIndex]); // ✅ APPEL PUBLIC
    } else if (_settings.loopPlayback) {
      _currentIndex = 0;
      await _player.seek(Duration.zero);
      _currentMediaId = _playlist[_currentIndex].id;
      updateMediaItem(_playlist[_currentIndex]); // ✅ APPEL PUBLIC
    } else {
      _saveCurrentPosition();
    }
  }

  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _player.seekToPrevious();
      _currentMediaId = _playlist[_currentIndex].id;
      updateMediaItem(_playlist[_currentIndex]); // ✅ APPEL PUBLIC
    }
  }

  Future<void> seek(Duration position) async => await _player.seek(position);

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
    await _settings.setDefaultVolume(volume);
  }

  Future<void> setShuffle(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> setLoopMode(int modeIndex) async {
    switch (modeIndex) {
      case 0:
        await _player.setLoopMode(LoopMode.off);
        break;
      case 1:
        await _player.setLoopMode(LoopMode.all);
        break;
      case 2:
        await _player.setLoopMode(LoopMode.one);
        break;
    }
  }

  void _saveCurrentPosition() {
    if (_databaseService != null && _currentMediaId != null) {
      _databaseService!.savePlaybackPosition(_currentMediaId!, _player.position);
    }
  }

  Future<void> dispose() async {
    _positionSaveTimer?.cancel();
    _saveCurrentPosition();
    _settings.removeListener(_onSettingsChanged);
    await _player.dispose();
  }

  bool get isPlaying => _player.playing;
}

// Handler pour les notifications en arrière-plan
class MediaHandler extends audio_service.BaseAudioHandler {
  final AudioPlayer _player;
  final AudioService _audioService;

  MediaHandler(this._player, this._audioService) {
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;
      
      playbackState.add(playbackState.value.copyWith(
        controls: [
          audio_service.MediaControl.skipToPrevious,
          if (playing) audio_service.MediaControl.pause else audio_service.MediaControl.play,
          audio_service.MediaControl.skipToNext,
        ],
        systemActions: const {
          audio_service.MediaAction.seek,
          audio_service.MediaAction.seekForward,
          audio_service.MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: audio_service.AudioProcessingState.idle,
          ProcessingState.loading: audio_service.AudioProcessingState.loading,
          ProcessingState.buffering: audio_service.AudioProcessingState.buffering,
          ProcessingState.ready: audio_service.AudioProcessingState.ready,
          ProcessingState.completed: audio_service.AudioProcessingState.completed,
        }[processingState]!,
        playing: playing,
        updatePosition: _player.position,
      ));
    });

    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  void updateMedia(MediaFile media) {
    mediaItem.add(audio_service.MediaItem(
      id: media.id,
      title: media.title,
      artist: media.artist,
      duration: media.duration,
      artUri: media.thumbnailUrl != null 
          ? Uri.parse(media.thumbnailUrl!) 
          : null,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _audioService.next();

  @override
  Future<void> skipToPrevious() => _audioService.previous();
}