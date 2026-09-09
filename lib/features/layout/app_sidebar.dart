import 'package:flutter/material.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/auth/app_permissions.dart';
import 'package:stok_anandam/injection.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.currentRoute,
    this.onNavigate,
    this.onLoginTap,
    this.isLoggedIn = true,
    this.userRole,
  });

  final String currentRoute;
  final void Function(String route)? onNavigate;
  final VoidCallback? onLoginTap;
  final bool isLoggedIn;
  final String? userRole;

  static const double width = 240;

  // Helper untuk membuat menu tile lebih ringkas
  Widget _buildMenu({
    required IconData icon,
    required String label,
    required String route,
  }) {
    return _SidebarTile(
      icon: icon,
      label: label,
      isSelected: currentRoute == route,
      onTap: () => onNavigate?.call(route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userStore = getIt<CurrentUserStore>();
    bool can(String perm) => userStore.hasPermission(perm);

    // 1. Definisikan menu per kelompok (group)
    final groups = <List<Widget>>[
      // --- GROUP 0: Dashboard & Laporan ---
      [
        if (can(AppPermission.dashboard))
          _buildMenu(
              icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
        if (can(AppPermission.laporanOmset))
          _buildMenu(
              icon: Icons.assessment_rounded,
              label: 'Laporan Omset Marketing',
              route: AppRoutes.laporanOmset),
      ],

      // --- GROUP 1: Stok, TKDN, Canvas, Rakitan ---
      [
        if (can(AppPermission.stok))
          _buildMenu(icon: Icons.storage, label: 'Stok', route: '/stok'),
        if (can(AppPermission.tkdn))
          _buildMenu(icon: Icons.verified, label: 'TKDN', route: '/tkdn'),
        if (can(AppPermission.canvas))
          _buildMenu(icon: Icons.palette, label: 'Canvas', route: '/canvas'),
        if (can(AppPermission.rakitan))
          _buildMenu(
              icon: Icons.precision_manufacturing,
              label: 'Rakitan',
              route: '/rakitan'),
      ],

      // --- GROUP 2: Memo, Delivery, Pengiriman ---
      [
        if (can(AppPermission.memo))
          _buildMenu(
              icon: Icons.assignment_rounded, label: 'Memo', route: '/memo'),
        if (can(AppPermission.servis))
          _buildMenu(
              icon: Icons.miscellaneous_services_rounded,
              label: 'Servis',
              route: AppRoutes.servis),
        if (can(AppPermission.requestDelivery))
          _buildMenu(
              icon: Icons.local_shipping_outlined,
              label: 'Request Delivery',
              route: AppRoutes.requestDelivery),
        if (can(AppPermission.pengiriman))
          _buildMenu(
            icon: Icons.local_shipping_rounded,
            label: userRole == 'DELIVERY' ? 'Pengantaran' : 'Pengiriman',
            route: '/pengiriman',
          ),
      ],

      // --- GROUP 3: Pembelian, Penjualan, Item SN, Data Warehouse ---
      [
        if (can(AppPermission.pembelian))
          _buildMenu(
              icon: Icons.shopping_bag,
              label: 'Pembelian',
              route: '/pembelian'),
        if (can(AppPermission.penjualan))
          _buildMenu(
              icon: Icons.shopping_cart,
              label: 'Penjualan',
              route: '/penjualan'),
        if (can(AppPermission.itemSn))
          _buildMenu(
              icon: Icons.qr_code_scanner, label: 'Item SN', route: '/item-sn'),
        if (can(AppPermission.ijinImport))
          _buildMenu(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Ijin Import',
              route: AppRoutes.ijinImport),
        if (can(AppPermission.shbj))
          _buildMenu(
              icon: Icons.construction_rounded,
              label: 'SHBJ',
              route: AppRoutes.shbj),
        if (can(AppPermission.dataWarehouse))
          _buildMenu(
              icon: Icons.warehouse,
              label: 'Data Warehouse',
              route: '/data-warehouse'),
      ],

      // --- GROUP 4: Data Canvas, User, Log Aktivitas ---
      [
        if (can(AppPermission.dataCanvas))
          _buildMenu(
              icon: Icons.dataset, label: 'Data Canvas', route: '/data-canvas'),
        if (can(AppPermission.users))
          _buildMenu(icon: Icons.people, label: 'User', route: '/users'),
        if (can(AppPermission.activityLog))
          _buildMenu(
              icon: Icons.history,
              label: 'Log Aktivitas',
              route: '/activity-log'),
      ],
    ];

    // 2. Filter kelompok yang kosong (jika user tidak punya akses sama sekali di grup itu)
    final validGroups = groups.where((group) => group.isNotEmpty).toList();

    // 3. Susun widget menu beserta garis pembatasnya
    final menuWidgets = <Widget>[];
    for (int i = 0; i < validGroups.length; i++) {
      menuWidgets.addAll(validGroups[i]);

      // Tambahkan divider jika ini bukan kelompok terakhir
      if (i < validGroups.length - 1) {
        menuWidgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: Colors.white24, height: 1, thickness: 1),
          ),
        );
      }
    }

    return Container(
      width: width,
      color: Colors.blue.shade900,
      child: SafeArea(
        // Tambahkan SafeArea agar aman dari notch/status bar mobile
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.white, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stok Anandam',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Menu items dibungkus Expanded & SingleChildScrollView agar bisa di-scroll
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: menuWidgets,
                ),
              ),
            ),

            // Tombol login / logout di bawah (tetap (fixed) tidak ikut terscroll)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLoginTap,
                  icon: Icon(
                    isLoggedIn ? Icons.logout : Icons.login,
                    size: 20,
                    color: Colors.white70,
                  ),
                  label: Text(
                    isLoggedIn ? 'Logout' : 'Login',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.white12 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 12),
              Expanded(
                // Tambahkan expanded agar teks panjang tidak error/overflow
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
