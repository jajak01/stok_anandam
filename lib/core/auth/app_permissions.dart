import 'package:flutter/material.dart';

/// Permission constants matching backend Permission.java
class AppPermission {
  // Dashboard & Laporan
  static const String dashboard = 'DASHBOARD';
  static const String laporanOmset = 'LAPORAN_OMSET';

  // Stok & Logistik
  static const String stok = 'STOK';
  static const String stokBadan = 'STOK_BADAN';
  static const String tkdn = 'TKDN';
  static const String canvas = 'CANVAS';
  static const String rakitan = 'RAKITAN';
  static const String simulasiSpj = 'SIMULASI_SPJ';

  // Alur Memo & Distribusi
  static const String memo = 'MEMO';
  static const String requestDelivery = 'REQUEST_DELIVERY';
  static const String pengiriman = 'PENGIRIMAN';
  static const String penjadwalan = 'PENJADWALAN';

  // Transaksi & Gudang
  static const String pembelian = 'PEMBELIAN';
  static const String penjualan = 'PENJUALAN';
  static const String piutang = 'PIUTANG';
  static const String paymentStatus = 'PAYMENT_STATUS';
  static const String itemSn = 'ITEM_SN';
  static const String dataWarehouse = 'DATA_WAREHOUSE';
  static const String dataCanvas = 'DATA_CANVAS';
  static const String ijinImport = 'IJIN_IMPORT';
  static const String shbj = 'SHBJ';
  static const String reminder = 'REMINDER';

  // Servis & Perbaikan
  static const String servis = 'SERVIS';

  // Lokasi & Tracking
  static const String locationTrack = 'LOCATION_TRACK';
  static const String locationView = 'LOCATION_VIEW';

  // Sistem & Manajemen
  static const String users = 'USERS';
  static const String userActivity = 'USER_ACTIVITY';
  static const String activityLog = 'ACTIVITY_LOG';
  static const String announcement = 'ANNOUNCEMENT';
  static const String printer = 'PRINTER';

  /// All permissions with user-friendly Indonesian labels and icons
  static const List<PermissionItem> allItems = [
    // Dashboard & Laporan
    PermissionItem(
      key: dashboard,
      label: 'Dashboard',
      category: 'Dashboard & Laporan',
      icon: Icons.dashboard_rounded,
    ),
    PermissionItem(
      key: laporanOmset,
      label: 'Laporan Omset Marketing',
      category: 'Dashboard & Laporan',
      icon: Icons.assessment_rounded,
    ),

    // Stok & Logistik
    PermissionItem(
      key: stok,
      label: 'Stok',
      category: 'Stok & Logistik',
      icon: Icons.inventory_2_rounded,
    ),
    PermissionItem(
      key: stokBadan,
      label: 'Stok Badan',
      category: 'Stok & Logistik',
      icon: Icons.apartment_rounded,
    ),
    PermissionItem(
      key: tkdn,
      label: 'TKDN',
      category: 'Stok & Logistik',
      icon: Icons.verified_rounded,
    ),
    PermissionItem(
      key: canvas,
      label: 'Canvas',
      category: 'Stok & Logistik',
      icon: Icons.palette_rounded,
    ),
    PermissionItem(
      key: rakitan,
      label: 'Rakitan',
      category: 'Stok & Logistik',
      icon: Icons.computer_rounded,
    ),
    PermissionItem(
      key: simulasiSpj,
      label: 'Simulasi SPJ',
      category: 'Stok & Logistik',
      icon: Icons.calculate_rounded,
    ),

    // Alur Memo & Distribusi
    PermissionItem(
      key: memo,
      label: 'Memo',
      category: 'Alur Memo & Distribusi',
      icon: Icons.assignment_rounded,
    ),
    PermissionItem(
      key: requestDelivery,
      label: 'Request Delivery',
      category: 'Alur Memo & Distribusi',
      icon: Icons.local_shipping_outlined,
    ),
    PermissionItem(
      key: pengiriman,
      label: 'Pengiriman / Pengantaran',
      category: 'Alur Memo & Distribusi',
      icon: Icons.local_shipping_rounded,
    ),
    PermissionItem(
      key: penjadwalan,
      label: 'Penjadwalan',
      category: 'Alur Memo & Distribusi',
      icon: Icons.calendar_month_rounded,
    ),

    // Transaksi & Gudang
    PermissionItem(
      key: pembelian,
      label: 'Pembelian',
      category: 'Transaksi & Gudang',
      icon: Icons.shopping_bag_rounded,
    ),
    PermissionItem(
      key: penjualan,
      label: 'Penjualan',
      category: 'Transaksi & Gudang',
      icon: Icons.shopping_cart_rounded,
    ),
    PermissionItem(
      key: piutang,
      label: 'Piutang',
      category: 'Transaksi & Gudang',
      icon: Icons.receipt_long_rounded,
    ),
    PermissionItem(
      key: paymentStatus,
      label: 'Status Pembayaran (Paid/Unpaid)',
      category: 'Transaksi & Gudang',
      icon: Icons.payments_rounded,
    ),
    PermissionItem(
      key: itemSn,
      label: 'Item SN',
      category: 'Transaksi & Gudang',
      icon: Icons.qr_code_scanner_rounded,
    ),
    PermissionItem(
      key: dataWarehouse,
      label: 'Data Warehouse',
      category: 'Transaksi & Gudang',
      icon: Icons.warehouse_rounded,
    ),
    PermissionItem(
      key: dataCanvas,
      label: 'Data Canvas',
      category: 'Transaksi & Gudang',
      icon: Icons.analytics_rounded,
    ),
    PermissionItem(
      key: ijinImport,
      label: 'Ijin Import',
      category: 'Transaksi & Gudang',
      icon: Icons.directions_boat_filled_outlined,
    ),
    PermissionItem(
      key: shbj,
      label: 'SHBJ',
      category: 'Transaksi & Gudang',
      icon: Icons.task,
    ),
    PermissionItem(
      key: reminder,
      label: 'Reminder Canvasing',
      category: 'Transaksi & Gudang',
      icon: Icons.alarm_rounded,
    ),

    // Servis
    PermissionItem(
      key: servis,
      label: 'Servis',
      category: 'Servis & Perbaikan',
      icon: Icons.miscellaneous_services_rounded,
    ),

    // Lokasi & Tracking
    PermissionItem(
      key: locationTrack,
      label: 'Tracking Lokasi (Rekam)',
      category: 'Lokasi & Tracking',
      icon: Icons.my_location_rounded,
    ),
    PermissionItem(
      key: locationView,
      label: 'Tracking Lokasi (Lihat Riwayat)',
      category: 'Lokasi & Tracking',
      icon: Icons.map_rounded,
    ),

    // Sistem & Manajemen
    PermissionItem(
      key: users,
      label: 'Manajemen User',
      category: 'Sistem & Manajemen',
      icon: Icons.people_rounded,
    ),
    PermissionItem(
      key: userActivity,
      label: 'User Activity',
      category: 'Sistem & Manajemen',
      icon: Icons.people_alt_rounded,
    ),
    PermissionItem(
      key: activityLog,
      label: 'Log Aktivitas',
      category: 'Sistem & Manajemen',
      icon: Icons.history_rounded,
    ),
    PermissionItem(
      key: announcement,
      label: 'Pengumuman',
      category: 'Sistem & Manajemen',
      icon: Icons.campaign_rounded,
    ),
    PermissionItem(
      key: printer,
      label: 'Printer',
      category: 'Sistem & Manajemen',
      icon: Icons.print_rounded,
    ),
  ];

  /// Get list of all permission keys
  static List<String> getAllKeys() => allItems.map((e) => e.key).toList();

  /// Default permission template based on role
  static List<String> getDefaultPermissions(String? roleName) {
    if (roleName == null || roleName.isEmpty) return [];

    final cleanRole = roleName.contains('.') ? roleName.split('.').last : roleName;
    final r = cleanRole.toUpperCase();

    if (r == 'ADMIN' || r == 'MANAGER') {
      return getAllKeys();
    }

    if (r == 'SPV_MARKETING') {
      return [
        dashboard,
        stok,
        stokBadan,
        tkdn,
        canvas,
        rakitan,
        simulasiSpj,
        memo,
        requestDelivery,
        pengiriman,
        pembelian,
        penjualan,
        piutang,
        paymentStatus,
        itemSn,
        dataCanvas,
        locationView,
        penjadwalan,
        printer,
        reminder,
      ];
    }

    if (r.startsWith('MARKETING')) {
      return [
        stok,
        stokBadan,
        tkdn,
        canvas,
        rakitan,
        simulasiSpj,
        memo,
        requestDelivery,
        pengiriman,
        piutang,
        penjadwalan,
        printer,
      ];
    }

    if (r == 'SPV_GUDANG' || r == 'GUDANG') {
      return [
        dashboard,
        stok,
        stokBadan,
        rakitan,
        itemSn,
        memo,
        pengiriman,
        penjadwalan,
        printer,
      ];
    }

    if (r == 'SPV_TEKNISI' || r == 'TEKNISI') {
      return [
        dashboard,
        servis,
        itemSn,
        memo,
        pengiriman,
        pembelian,
        penjualan,
        dataWarehouse,
        penjadwalan,
        printer,
      ];
    }

    if (r == 'DELIVERY') {
      return [
        pengiriman,
        penjadwalan,
        locationTrack,
      ];
    }

    if (r == 'NOTA') {
      return [
        memo,
        pengiriman,
      ];
    }

    return [stok];
  }
}

class PermissionItem {
  final String key;
  final String label;
  final String category;
  final IconData icon;

  const PermissionItem({
    required this.key,
    required this.label,
    required this.category,
    required this.icon,
  });
}
