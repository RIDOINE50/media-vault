import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> init() async {
    List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool hasConnection = results.any((result) => result != ConnectivityResult.none);
    if (_isConnected != hasConnection) {
      _isConnected = hasConnection;
      _connectionController.add(_isConnected);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectionController.close();
  }
}