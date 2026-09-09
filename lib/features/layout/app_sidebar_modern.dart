import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/auth/app_permissions.dart';
import 'package:stok_anandam/injection.dart';

class AppSidebarModern extends StatelessWidget {
  const AppSidebarModern({
    super.key,
    required this.currentRoute,
    this.onNavigate,
    this.onLoginTap,
    this.isLoggedIn = true,
    this.isCollapsed = false,
    this.onToggle,
    this.userRole,
  });

  final String currentRoute;
  final void Function(String route)? onNavigate;
  final VoidCallback? onLoginTap;
  final bool isLoggedIn;
  final bool isCollapsed;
  final VoidCallback? onToggle;
  final String? userRole;

  static const double fullWidth = 220;
  static const double collapsedWidth = 72;

  // Helper function untuk menyederhanakan pembuatan menu
  Widget _buildMenu(
      {required IconData icon,
      required String label,
      required String route,
      Color? iconColor}) {
    return _NavTile(
      icon: icon,
      label: label,
      isSelected: currentRoute == route,
      isCollapsed: isCollapsed,
      iconColor: iconColor,
      onTap: () => onNavigate?.call(route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final userStore = getIt<CurrentUserStore>();
    bool can(String perm) => userStore.hasPermission(perm);

    // 1. Definisikan kelompok menu sesuai hak akses granular (checklist permissions)
    final groups = <List<Widget>>[
      // --- GROUP 0: Dashboard & Laporan (Tetap ditaruh paling atas) ---
      [
        if (can(AppPermission.dashboard))
          _buildMenu(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              route: '/dashboard'),
        if (can(AppPermission.laporanOmset))
          _buildMenu(
              icon: Icons.assessment_rounded,
              label: 'Laporan Omset Marketing',
              route: AppRoutes.laporanOmset),
      ],

      // --- GROUP 1: STOK, TKDN, CANVAS, RAKITAN ---
      [
        if (can(AppPermission.stok))
          _buildMenu(
              icon: Icons.inventory_2_rounded, label: 'Stok', route: '/stok'),
        if (can(AppPermission.stokBadan))
          _buildMenu(
              icon: Icons.apartment_rounded,
              label: 'Stok Badan',
              route: AppRoutes.stokBadan),
        if (can(AppPermission.tkdn))
          _buildMenu(
              icon: Icons.verified_rounded, label: 'TKDN', route: '/tkdn'),
        if (can(AppPermission.canvas))
          _buildMenu(
              icon: Icons.palette_rounded, label: 'Canvas', route: '/canvas'),
        if (can(AppPermission.rakitan))
          _buildMenu(
              icon: Icons.computer_rounded,
              label: 'Rakitan',
              route: '/rakitan'),
        if (can(AppPermission.simulasiSpj))
          _buildMenu(
              icon: Icons.calculate_rounded,
              label: 'Simulasi SPJ',
              route: '/simulasi'),
      ],

      // --- GROUP 2: MEMO, REQUEST DELIVERY, PENGIRIMAN, PETA PENGANTARAN ---
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
              label: (userRole == 'DELIVERY' ||
                      (userRole != null && userRole!.startsWith('MARKETING')))
                  ? 'Pengantaran'
                  : 'Pengiriman',
              route: '/pengiriman'),
      ],

      // --- GROUP 3: PEMBELIAN, PENJUALAN, ITEM SN, DATA WAREHOUSE ---
      [
        if (can(AppPermission.pembelian))
          _buildMenu(
              icon: Icons.shopping_bag_rounded,
              label: 'Pembelian',
              route: '/pembelian'),
        if (can(AppPermission.penjualan))
          _buildMenu(
              icon: Icons.shopping_cart_rounded,
              label: 'Penjualan',
              route: '/penjualan'),
        if (can(AppPermission.piutang))
          _buildMenu(
              icon: Icons.receipt_long_rounded,
              label: 'Piutang',
              route: AppRoutes.piutang),
        if (can(AppPermission.pembelian))
          _buildMenu(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Hutang',
              route: AppRoutes.hutang),
        if (can(AppPermission.itemSn))
          _buildMenu(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Item SN',
              route: '/item-sn'),
        if (can(AppPermission.ijinImport))
          _buildMenu(
              icon: Icons.directions_boat_filled_outlined,
              label: 'Ijin Import',
              route: AppRoutes.ijinImport),
        if (can(AppPermission.shbj))
          _buildMenu(icon: Icons.task, label: 'SHBJ', route: AppRoutes.shbj),
        if (can(AppPermission.dataWarehouse))
          _buildMenu(
              icon: Icons.warehouse_rounded,
              label: 'Data Warehouse',
              route: AppRoutes.dataWarehouse),
      ],

      // --- GROUP 4: DATA CANVAS, USER, LOG AKTIVITAS ---
      [
        if (can(AppPermission.dataCanvas))
          _buildMenu(
              icon: Icons.analytics_rounded,
              label: 'Data Canvas',
              route: '/data_canvas'),
        if (can(AppPermission.users))
          _buildMenu(
              icon: Icons.people_rounded, label: 'User', route: '/users'),
        if (can(AppPermission.userActivity))
          _buildMenu(
              icon: Icons.people_alt_rounded,
              label: 'User Activity',
              route: AppRoutes.userActivity),
        if (can(AppPermission.activityLog))
          _buildMenu(
              icon: Icons.history_rounded,
              label: 'Log Aktivitas',
              route: '/activity-log'),
        if (can(AppPermission.announcement))
          _buildMenu(
              icon: Icons.campaign_rounded,
              label: 'Pengumuman',
              route: AppRoutes.announcement),
        if (can(AppPermission.reminder))
          _buildMenu(
            icon: Icons.notifications_active_rounded,
            label: 'Reminder Canvasing',
            route: AppRoutes.reminderCanvasing,
          ),
      ],
    ];

    // 2. Buang grup yang kosong (jika user tidak punya akses sama sekali di grup tersebut)
    final validGroups = groups.where((group) => group.isNotEmpty).toList();

    // 3. Susun widget menu dan sisipkan garis pembatas (Divider)
    final menuWidgets = <Widget>[];
    for (int i = 0; i < validGroups.length; i++) {
      menuWidgets.addAll(validGroups[i]);

      // Tambahkan pembatas antar grup, kecuali untuk grup terakhir
      if (i < validGroups.length - 1) {
        menuWidgets.add(
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 24,
              vertical: 8,
            ),
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
        );
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed ? collapsedWidth : fullWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Branding & Toggle Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 16),
            child: isCollapsed
                ? Column(
                    children: [
                      _SidebarBranding(isCollapsed: isCollapsed),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _SidebarBranding(isCollapsed: isCollapsed),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Bagian Menu yang bisa di-scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: menuWidgets,
              ),
            ),
          ),

          // Bagian Bawah (Logout/Login)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (!isCollapsed) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: NeverScrollableScrollPhysics(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: isCollapsed
                      ? IconButton(
                          onPressed: onLoginTap,
                          icon: Icon(
                            isLoggedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: isLoggedIn ? 'Logout' : 'Login',
                        )
                      : OutlinedButton.icon(
                          onPressed: onLoginTap,
                          icon: Icon(
                            isLoggedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: Text(
                            isLoggedIn ? 'Logout' : 'Login',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isCollapsed = false,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: isCollapsed ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : (iconColor ?? theme.colorScheme.onSurfaceVariant),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarBranding extends StatelessWidget {
  const _SidebarBranding({required this.isCollapsed});
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(),
          child: Center(
            child: SvgPicture.asset(
              'assets/images/icon-anandam.svg',
              width: 24,
              height: 24,
            ),
          ),
        ),
        if (!isCollapsed) ...[
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Movva',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Color.fromARGB(223, 9, 5, 89),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
