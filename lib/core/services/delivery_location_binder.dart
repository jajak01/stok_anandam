import 'package:flutter/material.dart';

import 'package:stok_anandam/core/services/delivery_location_service.dart';

/// DeliveryLocationBinder — menghubungkan status delivery/task dengan
/// DeliveryLocationService (plan #19, #22, #38).
///
/// - Saat `active == true` → mulai tracking utk deliveryId (task lifecycle).
/// - Saat `active == false` (selesai/batal) → hentikan tracking utk deliveryId.
/// - Tracking TIDAK dihentikan saat screen ditinggalkan bila delivery masih
///   berlangsung (plan #22: task state = source of truth), jadi binder hanya
///   berhenti ketika status terminal terlihat atau aplikasi logout.
class DeliveryLocationBinder extends StatefulWidget {
  const DeliveryLocationBinder({
    super.key,
    required this.deliveryId,
    this.menuCode = 'DELIVERY',
    required this.active,
    required this.child,
  });

  final String deliveryId;
  final String menuCode;
  final bool active;
  final Widget child;

  @override
  State<DeliveryLocationBinder> createState() => _DeliveryLocationBinderState();
}

class _DeliveryLocationBinderState extends State<DeliveryLocationBinder>
    with WidgetsBindingObserver {
  bool _lastActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(DeliveryLocationBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deliveryId != widget.deliveryId ||
        oldWidget.active != widget.active) {
      _sync(widget.active);
    }
  }

  void _sync(bool active) {
    final service = DeliveryLocationService.instance;
    if (active) {
      if (!_lastActive) {
        _lastActive = true;
        service.startTracking(
          deliveryId: widget.deliveryId,
          menuCode: widget.menuCode,
        );
      }
    } else {
      // Status terminal: delivery ini selesai/batal — hentikan tracking-nya.
      if (_lastActive || service.hasActiveDelivery) {
        service.stopTracking(widget.deliveryId);
      }
      _lastActive = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_lastActive) {
        DeliveryLocationService.instance.startTracking(
          deliveryId: widget.deliveryId,
          menuCode: widget.menuCode,
        );
      }
      DeliveryLocationService.instance.syncNow();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      DeliveryLocationService.instance.syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Jangan hentikan tracking di sini: bila delivery masih DALAM_PENGIRIMAN
    // tracking harus lanjut walau user pindah screen. Akan dihentikan saat
    // status terminal tampil lagi atau AuthService.logout() memanggil stop().
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
