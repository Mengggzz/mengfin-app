import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../constants/config.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _heartbeatTimer;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(result);
    } catch (_) {
      _isOnline = true;
    }

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final hasInterface = _isConnected(results);
      if (!hasInterface) {
        _setOnline(false);
      } else {
        checkConnection();
      }
    });

    // Pengecekan awal dan periodic heartbeat
    checkConnection();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkConnection();
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.other);
  }

  void _setOnline(bool online) {
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(_isOnline);
    }
  }

  /// Dipanggil saat request HTTP berhasil.
  void reportOnline() {
    _setOnline(true);
  }

  /// Dipanggil saat request HTTP gagal karena jaringan terputus.
  void reportOffline() {
    _setOnline(false);
  }

  /// Pengecekan aktif ke endpoint server
  Future<bool> checkConnection() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/health')).timeout(const Duration(seconds: 3));
      final ok = res.statusCode >= 200 && res.statusCode < 500;
      _setOnline(ok);
      return ok;
    } catch (_) {
      _setOnline(false);
      return false;
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _sub?.cancel();
    _controller.close();
  }
}
