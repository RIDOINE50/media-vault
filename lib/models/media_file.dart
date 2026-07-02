class MediaFile {
  final String id;
  final String title;
  final String artist;
  final String album; // ← NOUVEAU CHAMP
  final String path;
  final Duration duration;
  final String format;
  final bool isVideo;
  final String? thumbnailUrl;
  final int? albumId;
  final DateTime? downloadDate;
  final bool isFromYouTube;

  MediaFile({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'Album inconnu', // ← Valeur par défaut
    required this.path,
    required this.duration,
    required this.format,
    required this.isVideo,
    this.thumbnailUrl,
    this.albumId,
    this.downloadDate,
    this.isFromYouTube = false,
  });

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ✅ Constructeur pour fichiers locaux
  factory MediaFile.fromLocal({
    required String id,
    required String title,
    required String artist,
    String album = 'Album inconnu',
    required String path,
    required Duration duration,
    required String format,
    required bool isVideo,
    String? thumbnailUrl,
    int? albumId,
  }) {
    return MediaFile(
      id: id,
      title: title,
      artist: artist,
      album: album,
      path: path,
      duration: duration,
      format: format,
      isVideo: isVideo,
      thumbnailUrl: thumbnailUrl,
      albumId: albumId,
    );
  }

  // ✅ Constructeur pour fichiers YouTube
  factory MediaFile.fromYouTube({
    required String id,
    required String title,
    required String artist,
    String album = 'Téléchargements',
    required String path,
    required Duration duration,
    required String format,
    required bool isVideo,
    String? thumbnailUrl,
    DateTime? downloadDate,
  }) {
    return MediaFile(
      id: id,
      title: title,
      artist: artist,
      album: album,
      path: path,
      duration: duration,
      format: format,
      isVideo: isVideo,
      thumbnailUrl: thumbnailUrl,
      downloadDate: downloadDate,
      isFromYouTube: true,
    );
  }

  // ✅ Copie avec modifications
  MediaFile copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    Duration? duration,
    String? format,
    bool? isVideo,
    String? thumbnailUrl,
    int? albumId,
    DateTime? downloadDate,
    bool? isFromYouTube,
  }) {
    return MediaFile(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      format: format ?? this.format,
      isVideo: isVideo ?? this.isVideo,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      albumId: albumId ?? this.albumId,
      downloadDate: downloadDate ?? this.downloadDate,
      isFromYouTube: isFromYouTube ?? this.isFromYouTube,
    );
  }
}