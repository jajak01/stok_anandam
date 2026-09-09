import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';

/// Heartbeat periodik untuk menjaga status user = ONLINE (plan #13, #14, #37).
///
/// Frontend mengirim POST /api/v1/auth/heartbeat setiap ±25 detik selama ada
/// token login. Jika gagal (401/network), timer tetap berjalan dan mencoba lagi
/// saat siklus berikutnya — penanganan logout dilakukan oleh auth interceptor.
class HeartbeatService {
  HeartbeatService._internal();

  static final HeartbeatService instance = HeartbeatService._internal();

  static const Duration _interval = Duration(seconds: 25);

  Timer? _timer;
  bool _running = false;
  bool _busy = false;

  bool get isRunning => _running;

  /// Mulai heartbeat periodik (dipanggil sekali dari main()).
  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(_interval, (_) => _tick());
    debugPrint('[HeartbeatService] started (every ${_interval.inSeconds}s)');
  }

  Future<void> _tick() async {
    if (_busy) return;
    // Hanya kirim bila ada token login yang aktif.
    final token = getIt<TokenStorage>().token;
    if (token == null || token.isEmpty) return;

    _busy = true;
    try {
      await getIt<ApiNewEndpoints>().heartbeat();
    } catch (e) {
      // 401 ditangani oleh interceptor; kegagalan jaringan ditoleransi.
      debugPrint('[HeartbeatService] heartbeat failed: $e');
    } finally {
      _busy = false;
    }
  }

  /// Stop heartbeat (misal saat logout / test).
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Kirim satu heartbeat segera (misal setelah login).
  Future<void> pingNow() => _tick();
}
