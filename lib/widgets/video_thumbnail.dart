class VideoThumbnail extends StatefulWidget {
  final MediaFile mediaFile;  // ← Au lieu de videoPath
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const VideoThumbnail({
    Key? key,
    required this.mediaFile,
    this.width = 200,
    this.height = 200,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) : super(key: key);

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  String? _thumbnailPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // ✅ Si thumbnailPath existe déjà, l'utiliser directement
    if (widget.mediaFile.thumbnailPath != null) {
      setState(() {
        _thumbnailPath = widget.mediaFile.thumbnailPath;
        _isLoading = false;
      });
      return;
    }
    
    // ✅ Sinon, générer la miniature
    final thumbnail = await ThumbnailService.generateThumbnail(widget.mediaFile.path);
    if (mounted) {
      setState(() {
        _thumbnailPath = thumbnail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: _isLoading
          ? Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            )
          : _thumbnailPath != null
              ? Image.file(
                  File(_thumbnailPath!),
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.cover,
                )
              : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.mediaFile.isVideo
              ? [Colors.blue.withOpacity(0.4), Colors.blue.withOpacity(0.2)]
              : [Colors.purple.withOpacity(0.4), Colors.purple.withOpacity(0.2)],
        ),
      ),
      child: Icon(
        widget.mediaFile.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}