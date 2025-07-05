// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamController<bool> _connectivityChangeController = StreamController<bool>.broadcast();

  // Stream to listen for connectivity changes (true for online, false for offline)
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivity.onConnectivityChanged;
  ConnectivityService() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool isOnline = _isResultOnline(results);
      _connectivityChangeController.add(isOnline);
      print('Connectivity changed: Is Online? $isOnline');
    });
  }

  // Check the current connectivity status
  Future<bool> isOnline() async {
    final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    return _isResultOnline(result);
  }

  // Helper to determine online status from ConnectivityResult list
  bool _isResultOnline(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.mobile) ||
           results.contains(ConnectivityResult.wifi) ||
           results.contains(ConnectivityResult.ethernet);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityChangeController.close();
  }
}