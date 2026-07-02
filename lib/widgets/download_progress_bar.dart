import 'package:flutter/material.dart';

class DownloadProgressBar extends StatelessWidget {
  final double progress;
  final String fileName;
  final bool isComplete;

  const DownloadProgressBar({
    Key? key,
    required this.progress,
    required this.fileName,
    this.isComplete = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isComplete ? Icons.check_circle : Icons.download, color: isComplete ? Colors.green : Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
                if (!isComplete) Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            if (!isComplete) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                minHeight: 6,
              ),
            ],
          ],
        ),
      ),
    );
  }
}