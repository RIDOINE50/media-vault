import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final yt = YoutubeExplode();
  
  // ✅ AUGMENTER À 100 RÉSULTATS
  static const int maxResults = 100;

  Future<List<Map<String, dynamic>>> search(String query, {int limit = maxResults}) async {
    List<Map<String, dynamic>> results = [];
    
    try {
      print('🔍 Recherche: "$query" (max: $limit résultats)');
      
      // ✅ RECHERCHER AVEC PLUS DE RÉSULTATS
      final searchList = await yt.search.search(query);
      
      int count = 0;
      for (final video in searchList) {
        if (count >= limit) break;
        
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