import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      var searchList = await _yt.search.search(query);
      return searchList.map((video) {
        return {
          'id': video.id.toString(),
          'title': video.title,
          'author': video.author,
          'duration': video.duration ?? Duration.zero,
          'thumbnail': video.thumbnails.highResUrl,
          'url': video.url,
        };
      }).toList();
    } catch (e) {
      print('Erreur recherche YouTube: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getVideoInfo(String videoId) async {
    try {
      var video = await _yt.videos.get(videoId);
      return {
        'id': video.id.toString(),
        'title': video.title,
        'author': video.author,
        'duration': video.duration ?? Duration.zero,
        'thumbnail': video.thumbnails.highResUrl,
      };
    } catch (e) {
      print('Erreur récupération infos: $e');
      return null;
    }
  }

  Future<String?> getAudioUrl(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      var audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      print('Erreur URL audio: $e');
      return null;
    }
  }

  Future<String?> getVideoUrl(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      var videoStream = manifest.muxed.first;
      return videoStream.url.toString();
    } catch (e) {
      print('Erreur URL vidéo: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}