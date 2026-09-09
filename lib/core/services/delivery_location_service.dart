import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:stok_anandam/core/auth/app_permissions.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/injection.dart';

/// Status permission lokasi (plan #26).
enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Satu titik lokasi yang menunggu dikirim ke server.
class PendingLocation {
  final String deliveryId;
  final String? menuCode;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime recordedAt;
  final String clientEventId;

  PendingLocation({
    required this.deliveryId,
    this.menuCode,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.recordedAt,
    required this.clientEventId,
  });

  Map<String, dynamic> toMap() => {
        if (deliveryId.isNotEmpty) 'deliveryId': deliveryId,
        if (menuCode != null && menuCode!.isNotEmpty) 'menuCode': menuCode,
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        'recordedAt': recordedAt.toIso8601String(),
        'clientEventId': clientEventId,
      };
}

/// DeliveryLocationService — pelacakan GPS lifecycle-based utk delivery/task
/// (plan #19-#23, #39-#40).
///
/// - Satu sesi aktif per deliveryId (paling banyak 1 subscription GPS global).
/// - Position stream kontinyu; titik terbaik per ~30 detik yang masuk queue.
/// - Akurasi > [maxAccuracyMeters] dianggap invalid (di-skip).
/// - Queue lokal (bounded) menyimpan titik saat offline; flush batch saat online.
/// - Idempotency via clientEventId sehingga retry tidak menggandakan data.
class DeliveryLocationService {
  DeliveryLocationService._internal();

  static final DeliveryLocationService instance =
      DeliveryLocationService._internal();

  static const double maxAccuracyMeters = 100;
  static const Duration _persistInterval = Duration(seconds: 30);
  static const Duration _flushInterval = Duration(seconds: 12);
  static const int _maxQueue = 300;

  StreamSubscription<Position>? _subscription;
  Timer? _persistTimer;
  Timer? _flushTimer;

  Position? _latest;

  final Set<String> _activeDeliveries = {};
  final Queue<PendingLocation> _queue = Queue<PendingLocation>();
  bool _flushing = false;

  // ── Observasi (untuk UI jika dibutuhkan) ────────────────────────
  final ValueNotifier<LocationPermissionState> permissionState =
      ValueNotifier(LocationPermissionState.denied);
  final ValueNotifier<int> queueSize = ValueNotifier(0);

  bool get isTracking => _subscription != null;
  bool get hasActiveDelivery => _activeDeliveries.isNotEmpty;

  // ── Permission handling (plan #26) ──────────────────────────────
  Future<LocationPermissionState> checkPermissionState() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      permissionState.value = LocationPermissionState.serviceDisabled;
      return LocationPermissionState.serviceDisabled;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    switch (perm) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        permissionState.value = LocationPermissionState.granted;
        return LocationPermissionState.granted;
      case LocationPermission.denied:
        permissionState.value = LocationPermissionState.denied;
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        permissionState.value = LocationPermissionState.deniedForever;
        return LocationPermissionState.deniedForever;
      case LocationPermission.unableToDetermine:
        // OS belum bisa memastikan (mis. di web/desktop) — anggap granted agar
        // GPS tetap mencoba; jika gagal, stream error akan ditangani.
        permissionState.value = LocationPermissionState.granted;
        return LocationPermissionState.granted;
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  // ── Lifecycle: start/stop per delivery/task ─────────────────────
  /// Mulai tracking utk satu delivery. Aman dipanggil berulang (idempotent).
  Future<bool> startTracking({
    required String deliveryId,
    String? menuCode,
  }) async {
    final user = getIt<CurrentUserStore>();
    if (!user.hasPermission(AppPermission.locationTrack)) {
      debugPrint('[DeliveryLocationService] tidak punya LOCATION_TRACK');
      return false;
    }

    _activeDeliveries.add(deliveryId);

    if (_subscription != null) {
      // Sudah berjalan (multi-device/session atau delivery lain) — cukup tandai.
      return true;
    }

    final state = await checkPermissionState();
    if (state != LocationPermissionState.granted) {
      return false;
    }

    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _subscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) => _latest = pos,
        onError: (e) => debugPrint('[DeliveryLocationService] gps error: $e'),
      );
    } catch (e) {
      debugPrint('[DeliveryLocationService] start stream error: $e');
      return false;
    }

    _persistTimer?.cancel();
    _persistTimer = Timer.periodic(_persistInterval, (_) => _persistTick());
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => flushQueue());
    debugPrint('[DeliveryLocationService] tracking start delivery=$deliveryId');
    return true;
  }

  /// Hentikan tracking utk satu delivery. Tracking berhenti total setelah
  /// tidak ada lagi delivery aktif yang memerlukannya.
  void stopTracking(String deliveryId) {
    _activeDeliveries.remove(deliveryId);
    if (_activeDeliveries.isEmpty) {
      _teardown();
    }
  }

  void _teardown() {
    _subscription?.cancel();
    _subscription = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _latest = null;
    // Titik tersisa tetap dikirim via flush retry timer sementara.
    _scheduleFlushRetry();
    debugPrint('[DeliveryLocationService] tracking stopped');
  }

  void _scheduleFlushRetry() {
    if (_queue.isEmpty || _flushTimer != null) return;
    _flushTimer = Timer.periodic(_flushInterval, (_) => flushQueue());
  }

  // ── Sampling & persist ±30 detik ────────────────────────────────
  void _persistTick() {
    if (_activeDeliveries.isEmpty) return;
    final pos = _latest;
    if (pos == null) return;
    final acc = pos.accuracy;
    if (acc > maxAccuracyMeters) {
      debugPrint('[DeliveryLocationService] skip low-accuracy $acc');
      return;
    }
    // Rekam utk setiap delivery aktif (biasanya 1).
    for (final deliveryId in _activeDeliveries) {
      if (_queue.length >= _maxQueue) {
        _queue.removeFirst();
      }
      final now = DateTime.now();
      _queue.add(PendingLocation(
        deliveryId: deliveryId,
        menuCode: 'DELIVERY',
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        recordedAt: pos.timestamp.isUtc
            ? pos.timestamp.toLocal()
            : pos.timestamp,
        clientEventId: '${deliveryId}_${now.microsecondsSinceEpoch}',
      ));
    }
    queueSize.value = _queue.length;
    flushQueue();
  }

  // ── Offline queue → upload batch (plan #23, #40C) ───────────────
  Future<void> flushQueue() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      final api = getIt<ApiNewEndpoints>();
      final batch = _queue.map((p) => p.toMap()).toList();
      await api.trackLocationBatch(batch);
      _queue.clear();
      queueSize.value = 0;
      // Queue kosong: hentikan retry timer bila bukan tracking aktif.
      if (_activeDeliveries.isEmpty && _flushTimer != null) {
        _flushTimer?.cancel();
        _flushTimer = null;
      }
      debugPrint('[DeliveryLocationService] flushed ${batch.length} points');
    } catch (e) {
      debugPrint('[DeliveryLocationService] flush gagal (offline?): $e');
    } finally {
      _flushing = false;
    }
  }

  /// Kirim queue sekarang & laporkan status (dipakai saat app kembali online/foreground).
  Future<void> syncNow() => flushQueue();

  /// Hentikan semua tracking (logout). Menjaga notifier tetap hidup sehingga
  /// service bisa dipakai lagi saat user login kembali.
  void stopAll() {
    _activeDeliveries.clear();
    _teardown();
  }

  void dispose() {
    _activeDeliveries.clear();
    _subscription?.cancel();
    _subscription = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    permissionState.dispose();
    queueSize.dispose();
  }
}
