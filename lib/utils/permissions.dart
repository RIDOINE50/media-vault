import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.audio,
      Permission.videos,
    ].request();
    bool allGranted = statuses.values.every((status) => status.isGranted);
    return allGranted;
  }

  static Future<bool> checkPermissions() async {
    bool storageGranted = await Permission.storage.isGranted;
    bool audioGranted = await Permission.audio.isGranted;
    bool videosGranted = await Permission.videos.isGranted;
    return storageGranted && audioGranted && videosGranted;
  }
}