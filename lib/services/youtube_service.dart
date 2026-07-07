import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final yt = YoutubeExplode();
  
  static const int _maxResults = 100;

  // ✅ AJOUT DU PARAMÈTRE maxResults
  Future<List<Map<String, dynamic>>> search(String query, {int maxResults = 30}) async {
    List<Map<String, dynamic>> results = [];
    
    try {
      print('🔍 Recherche: "$query" (max: $maxResults résultats)');
      
      final searchList = await yt.search.search(query);
      
      int count = 0;
      for (final video in searchList) {
        if (count >= maxResults) break;
        
        results.add({
          'id': video.id.value,
          'title': video.title,
          'author': video.author,
          'duration': video.duration?.toString() ?? '0:00',
          'thumbnail': video.thumbnails.highResUrl ?? video.thumbnails.mediumResUrl,
          'viewCount': video.engagement.viewCount,
        });
        
        count++;
      }
      
      print('✅ ${results.length} résultats trouvés');
    } catch (e) {
      print('❌ Erreur recherche: $e');
    }
    
    return results;
  }

  Future<String?> getVideoUrl(String videoId) async {
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final videoStreams = manifest.muxed;
      if (videoStreams.isEmpty) {
        print('❌ Aucun stream vidéo trouvé');
        return null;
      }
      
      final bestStream = videoStreams.last;
      return bestStream.url.toString();
    } catch (e) {
      print('❌ Erreur getVideoUrl: $e');
      return null;
    }
  }

  void dispose() {
    yt.close();
  }
}