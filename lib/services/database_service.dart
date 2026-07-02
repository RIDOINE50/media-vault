import 'dart:io';
import 'package:hive/hive.dart';
import '../models/media_file.dart';

class DatabaseService {
  // Boîtes Hive
  Box get _favoritesBox => Hive.box('favorites');
  Box get _playlistsBox => Hive.box('playlists');
  Box get _searchHistoryBox => Hive.box('search_history');
  Box get _playbackPositionsBox => Hive.box('playback_positions');

  // ===== FAVORIS =====
  
  Future<void> addFavorite(MediaFile media) async {
    await _favoritesBox.put(media.id, {
      'id': media.id,
      'title': media.title,
      'artist': media.artist,
      'path': media.path,
      'duration': media.duration.inMilliseconds,
      'format': media.format,
      'isVideo': media.isVideo,
      'thumbnailUrl': media.thumbnailUrl,
      'addedDate': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFavorite(String mediaId) async {
    await _favoritesBox.delete(mediaId);
  }

  bool isFavorite(String mediaId) {
    return _favoritesBox.containsKey(mediaId);
  }

  List<MediaFile> getFavorites() {
    List<MediaFile> favorites = [];
    for (var key in _favoritesBox.keys) {
      final data = _favoritesBox.get(key);
      if (data != null) {
        favorites.add(MediaFile(
          id: data['id'],
          title: data['title'],
          artist: data['artist'],
          path: data['path'],
          duration: Duration(milliseconds: data['duration']),
          format: data['format'],
          isVideo: data['isVideo'],
          thumbnailUrl: data['thumbnailUrl'],
        ));
      }
    }
    return favorites;
  }

  // ✅ NOUVEAU : Nettoyer les favoris (supprime les fichiers inexistants)
  Future<List<MediaFile>> getValidFavorites() async {
    final favorites = getFavorites();
    final validFavorites = <MediaFile>[];
    
    for (var favorite in favorites) {
      final file = File(favorite.path);
      if (await file.exists()) {
        validFavorites.add(favorite);
      } else {
        // Supprime le favori si le fichier n'existe plus
        await removeFavorite(favorite.id);
        print('🗑️ Favori supprimé (fichier inexistant): ${favorite.title}');
      }
    }
    
    return validFavorites;
  }

  // ✅ NOUVEAU : Nettoyer les favoris d'un coup
  Future<void> cleanFavorites() async {
    await getValidFavorites();
    print('✅ Les favoris ont été nettoyés');
  }

  // ===== HISTORIQUE DE RECHERCHE =====
  
  Future<void> addSearchQuery(String query) async {
    final history = List<String>.from(_searchHistoryBox.get('queries') ?? []);
    history.remove(query); // Supprimer si existe déjà
    history.insert(0, query); // Ajouter au début
    if (history.length > 20) history.removeLast(); // Limiter à 20
    await _searchHistoryBox.put('queries', history);
  }

  List<String> getSearchHistory() {
    return List<String>.from(_searchHistoryBox.get('queries') ?? []);
  }

  Future<void> clearSearchHistory() async {
    await _searchHistoryBox.delete('queries');
  }

  // ===== PLAYLISTS =====
  
  Future<void> createPlaylist(String name) async {
    final playlists = Map<String, dynamic>.from(_playlistsBox.get('playlists') ?? {});
    playlists[name] = {
      'name': name,
      'mediaIds': [],
      'createdDate': DateTime.now().toIso8601String(),
    };
    await _playlistsBox.put('playlists', playlists);
  }

  Future<void> deletePlaylist(String name) async {
    final playlists = Map<String, dynamic>.from(_playlistsBox.get('playlists') ?? {});
    playlists.remove(name);
    await _playlistsBox.put('playlists', playlists);
  }

  Future<void> addMediaToPlaylist(String playlistName, MediaFile media) async {
    final playlists = Map<String, dynamic>.from(_playlistsBox.get('playlists') ?? {});
    if (playlists.containsKey(playlistName)) {
      final playlist = playlists[playlistName];
      final mediaIds = List<String>.from(playlist['mediaIds']);
      if (!mediaIds.contains(media.id)) {
        mediaIds.add(media.id);
        playlist['mediaIds'] = mediaIds;
        await _playlistsBox.put('playlists', playlists);
        
        // Sauvegarder aussi les données du média
        await _playlistsBox.put('media_${media.id}', {
          'id': media.id,
          'title': media.title,
          'artist': media.artist,
          'path': media.path,
          'duration': media.duration.inMilliseconds,
          'format': media.format,
          'isVideo': media.isVideo,
        });
      }
    }
  }

  Future<void> removeMediaFromPlaylist(String playlistName, String mediaId) async {
    final playlists = Map<String, dynamic>.from(_playlistsBox.get('playlists') ?? {});
    if (playlists.containsKey(playlistName)) {
      final playlist = playlists[playlistName];
      final mediaIds = List<String>.from(playlist['mediaIds']);
      mediaIds.remove(mediaId);
      playlist['mediaIds'] = mediaIds;
      await _playlistsBox.put('playlists', playlists);
    }
  }

  List<String> getPlaylistNames() {
    final playlists = Map<String, dynamic>.from(_playlistsBox.get('playlists') ?? {});
    return playlists.keys.toList();
  }

  List<MediaFile> getPlaylistMedia(String playlistName) {
    final playlists = Map<String, dynamic>.from(_playlistsBox.get('playlists') ?? {});
    if (!playlists.containsKey(playlistName)) return [];
    
    final playlist = playlists[playlistName];
    final mediaIds = List<String>.from(playlist['mediaIds']);
    
    List<MediaFile> mediaList = [];
    for (var mediaId in mediaIds) {
      final data = _playlistsBox.get('media_$mediaId');
      if (data != null) {
        mediaList.add(MediaFile(
          id: data['id'],
          title: data['title'],
          artist: data['artist'],
          path: data['path'],
          duration: Duration(milliseconds: data['duration']),
          format: data['format'],
          isVideo: data['isVideo'],
        ));
      }
    }
    return mediaList;
  }

  // ✅ NOUVEAU : Nettoyer les playlists (supprime les fichiers inexistants)
  Future<List<MediaFile>> getValidPlaylistMedia(String playlistName) async {
    final mediaList = getPlaylistMedia(playlistName);
    final validMediaList = <MediaFile>[];
    
    for (var media in mediaList) {
      final file = File(media.path);
      if (await file.exists()) {
        validMediaList.add(media);
      } else {
        // Supprime de la playlist si le fichier n'existe plus
        await removeMediaFromPlaylist(playlistName, media.id);
        print('🗑️ Média supprimé de la playlist (fichier inexistant): ${media.title}');
      }
    }
    
    return validMediaList;
  }

  // ✅ NOUVEAU : Nettoyer TOUTES les playlists d'un coup
  Future<void> cleanAllPlaylists() async {
    final playlistNames = getPlaylistNames();
    for (var name in playlistNames) {
      await getValidPlaylistMedia(name);
    }
    print('✅ Toutes les playlists ont été nettoyées');
  }

  // ===== REPRISE DE LECTURE =====
  
  Future<void> savePlaybackPosition(String mediaId, Duration position) async {
    await _playbackPositionsBox.put(mediaId, position.inMilliseconds);
  }

  Duration? getPlaybackPosition(String mediaId) {
    final position = _playbackPositionsBox.get(mediaId);
    if (position != null) {
      return Duration(milliseconds: position);
    }
    return null;
  }

  Future<void> clearPlaybackPosition(String mediaId) async {
    await _playbackPositionsBox.delete(mediaId);
  }
}