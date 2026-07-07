class MediaFile {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;
  final String format;
  final bool isVideo;
  final String? thumbnailUrl;        // ✅ Pour les URLs (YouTube, etc.)
  final String? thumbnailPath;       // ✅ NOUVEAU : Pour les fichiers locaux
  final int? albumId;
  final DateTime? downloadDate;
  final bool isFromYouTube;

  MediaFile({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'Album inconnu',
    required this.path,
    required this.duration,
    required this.format,
    required this.isVideo,
    this.thumbnailUrl,
    this.thumbnailPath,              // ✅ NOUVEAU
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
    String? thumbnailPath,           // ✅ NOUVEAU
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
      thumbnailPath: thumbnailPath,  // ✅ NOUVEAU
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
    String? thumbnailPath,           // ✅ NOUVEAU
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
      thumbnailPath: thumbnailPath,  // ✅ NOUVEAU
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
    String? thumbnailPath,           // ✅ NOUVEAU
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
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,  // ✅ NOUVEAU
      albumId: albumId ?? this.albumId,
      downloadDate: downloadDate ?? this.downloadDate,
      isFromYouTube: isFromYouTube ?? this.isFromYouTube,
    );
  }

  // ✅ Méthode pour obtenir la miniature (URL ou chemin local)
  String? get thumbnail => thumbnailPath ?? thumbnailUrl;
  
  // ✅ Vérifier si une miniature existe
  bool get hasThumbnail => thumbnailPath != null || thumbnailUrl != null;
}