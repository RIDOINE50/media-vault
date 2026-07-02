import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  const VideoPlayerScreen({
    Key? key,
    required this.videoPath,
    required this.title,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isUrl = false;

  @override
  void initState() {
    super.initState();
    
    // ✅ DÉTECTER SI C'EST UNE URL OU UN FICHIER LOCAL
    _isUrl = widget.videoPath.startsWith('http://') || 
             widget.videoPath.startsWith('https://');
    
    if (_isUrl) {
      // ✅ URL YouTube ou autre
      _controller = VideoPlayerController.network(widget.videoPath);
    } else {
      // ✅ Fichier local
      _controller = VideoPlayerController.file(File(widget.videoPath));
    }
    
    _controller.initialize().then((_) {
      setState(() {});
      _controller.play();
      _isPlaying = true;
    }).catchError((error) {
      print('❌ Erreur chargement vidéo: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de lire cette vidéo'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _seekForward() {
    final pos = _controller.value.position;
    _controller.seekTo(pos + const Duration(seconds: 10));
  }

  void _seekBackward() {
    final pos = _controller.value.position;
    _controller.seekTo(pos - const Duration(seconds: 10));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CircularProgressIndicator(),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showControls = !_showControls);
                  },
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Column(
                        children: [
                          AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            title: Text(
                              widget.title,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                VideoProgressIndicator(
                                  _controller,
                                  allowScrubbing: true,
                                  colors: VideoProgressColors(
                                    playedColor: Theme.of(context).primaryColor,
                                    bufferedColor: Colors.grey[600]!,
                                    backgroundColor: Colors.grey[800]!,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                                      onPressed: _seekBackward,
                                    ),
                                    const SizedBox(width: 24),
                                    IconButton(
                                      icon: Icon(
                                        _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                      onPressed: _togglePlayPause,
                                    ),
                                    const SizedBox(width: 24),
                                    IconButton(
                                      icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                                      onPressed: _seekForward,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}