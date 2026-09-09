import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/routing/app_router.dart';
import 'app_sidebar_modern.dart';
import '../dashboard/widgets/dashboard_header.dart';

import '../../core/services/app_update_service.dart';
import '../../core/widgets/update_dialog.dart';
import 'package:stok_anandam/injection.dart';
import '../../data/repositories/announcement_repository.dart';
import '../../core/auth/global_state_resetter.dart';
import '../../features/announcement/widgets/announcement_dialog.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.currentRoute,
    required this.child,
    this.onNavigate,
    this.onLogout,
    this.userName = 'User',
    this.userRole,
    this.headerActionLabel = 'Sync Migrasi',
    this.headerActionIcon,
    this.onHeaderAction,
    this.onRefresh,
    this.showHeaderActionInAppBar = true,
    this.lastSync = '',
    this.headerActions = const [],
    this.title,
    this.onScan,
    this.floatingActionButton,
    this.showSidebar = true,
  });

  final String currentRoute;
  final Widget child;
  final void Function(String route)? onNavigate;
  final VoidCallback? onLogout;
  final String userName;
  final String? userRole;
  final String headerActionLabel;
  final IconData? headerActionIcon;
  final VoidCallback? onHeaderAction;
  final VoidCallback? onRefresh;
  final bool showHeaderActionInAppBar;
  final String lastSync;
  final List<HeaderAction> headerActions;
  final String? title;
  final VoidCallback? onScan;
  final Widget? floatingActionButton;
  final bool showSidebar;

  static const double _breakpoint = 720;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  static bool _hasShownAnnouncementsInSession = false;

  @override
  void initState() {
    super.initState();
    GlobalStateResetter.register(() {
      _hasShownAnnouncementsInSession = false;
    });
    _checkForAppUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAnnouncements();
    });
  }

  /// Cek update untuk semua platform (Android & Desktop) via AppUpdateService
  Future<void> _checkForAppUpdate() async {
    try {
      final service = AppUpdateService();
      final info = await service.checkForUpdate();
      if (info != null && mounted) {
        UpdateDialog.show(context, info);
      }
    } catch (e) {
      debugPrint('[AppUpdate] Check update failed: $e');
    }
  }

  /// Cek pengumuman aktif dan tampilkan di depan semua dialog
  /// Menggunakan AnnouncementRepository yang hybrid: coba backend dulu,
  /// fallback ke SharedPreferences jika backend belum tersedia.
  Future<void> _checkForAnnouncements() async {
    if (_hasShownAnnouncementsInSession) return;

    try {
      final repo = getIt<AnnouncementRepository>();
      final announcements = await repo.getAnnouncements();
      final now = DateTime.now();
      final active = announcements.where((a) {
        final afterStart = a.startDate == null || now.isAfter(a.startDate!);
        final beforeExpiry =
            a.expiredDate == null || now.isBefore(a.expiredDate!);
        return afterStart && beforeExpiry;
      }).toList();

      // Sedikit delay agar UI sudah render sempurna sebelum popup muncul
      await Future.delayed(const Duration(milliseconds: 600));

      for (final announcement in active) {
        if (!mounted) break;
        await AnnouncementDialog.show(context, announcement);
        // Jeda antar popup jika ada lebih dari satu
        if (active.indexOf(announcement) < active.length - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      _hasShownAnnouncementsInSession = true;
    } catch (e) {
      debugPrint('[Announcement] Check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= DashboardShell._breakpoint;

    if (isDesktop) {
      return _DesktopLayout(
        currentRoute: widget.currentRoute,
        onNavigate: widget.onNavigate,
        onLogout: widget.onLogout,
        userName: widget.userName,
        userRole: widget.userRole,
        headerActionLabel: widget.headerActionLabel,
        headerActionIcon: widget.headerActionIcon,
        onHeaderAction: widget.onHeaderAction,
        onRefresh: widget.onRefresh,
        lastSync: widget.lastSync,
        headerActions: widget.headerActions,
        title: widget.title,
        onScan: widget.onScan,
        floatingActionButton: widget.floatingActionButton,
        showSidebar: widget.showSidebar,
        child: widget.child,
      );
    } else {
      return _MobileLayout(
        currentRoute: widget.currentRoute,
        onNavigate: widget.onNavigate,
        onLogout: widget.onLogout,
        userName: widget.userName,
        userRole: widget.userRole,
        headerActionLabel: widget.headerActionLabel,
        headerActionIcon: widget.headerActionIcon,
        onHeaderAction: widget.onHeaderAction,
        onRefresh: widget.onRefresh,
        showHeaderActionInAppBar: widget.showHeaderActionInAppBar,
        lastSync: widget.lastSync,
        headerActions: widget.headerActions,
        title: widget.title,
        showSidebar: widget.showSidebar,
        onScan: widget.onScan,
        floatingActionButton: widget.floatingActionButton,
        child: widget.child,
      );
    }
  }
}

class _DesktopLayout extends StatefulWidget {
  const _DesktopLayout({
    required this.currentRoute,
    required this.child,
    this.onNavigate,
    this.onLogout,
    this.userName = 'User',
    this.userRole,
    this.headerActionLabel = 'Sync Migrasi',
    this.headerActionIcon,
    this.onHeaderAction,
    this.onRefresh,
    this.lastSync = '',
    this.headerActions = const [],
    this.title,
    this.onScan,
    this.floatingActionButton,
    this.showSidebar = true,
  });

  final String? title;
  final String currentRoute;
  final Widget child;
  final void Function(String route)? onNavigate;
  final VoidCallback? onLogout;
  final String userName;
  final String? userRole;
  final String headerActionLabel;
  final IconData? headerActionIcon;
  final VoidCallback? onHeaderAction;
  final VoidCallback? onRefresh;
  final String lastSync;
  final List<HeaderAction> headerActions;
  final VoidCallback? onScan;
  final Widget? floatingActionButton;
  final bool showSidebar;

  @override
  State<_DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<_DesktopLayout> {
  bool _isCollapsed = true;
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentBg =
        theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5);

    // Lebar fixed
    const double collapsedWidth = 70.0;
    const double expandedWidth = 250.0;

    // Jika sidebar tidak perlu ditampilkan, gunakan layout sederhana
    if (!widget.showSidebar) {
      return Scaffold(
        floatingActionButton: widget.floatingActionButton,
        body: widget.child,
      );
    }

    return Scaffold(
      floatingActionButton: widget.floatingActionButton,
      body: Stack(
        children: [
          Positioned.fill(
            left: collapsedWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardHeader(
                  userName: widget.userName,
                  userRole: widget.userRole,
                  actionLabel: widget.headerActionLabel,
                  actionIcon: widget.headerActionIcon,
                  onAction: (widget.userRole?.toUpperCase() == 'ADMIN' ||
                          widget.userRole?.toUpperCase() == 'SPV_MARKETING' ||
                          widget.userRole?.toUpperCase() == 'GUDANG' ||
                          widget.userRole?.toUpperCase() == 'SPV_GUDANG' ||
                          widget.userRole?.toUpperCase() == 'NOTA' ||
                          (widget.userRole?.toUpperCase() != null &&
                              widget.userRole!
                                  .toUpperCase()
                                  .startsWith('MARKETING')))
                      ? widget.onHeaderAction
                      : null,
                  onRefresh: widget.onRefresh,
                  onLogout: widget.onLogout,
                  onProfileTap: () =>
                      widget.onNavigate?.call(AppRoutes.profile),
                  lastSync: widget.lastSync,
                  actions: widget.headerActions,
                  onScan: widget.onScan,
                ),
                Expanded(
                  child: Container(
                    color: contentBg,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),

          // 2. SIDEBAR OVERLAY (Layer Atas)
          Align(
            alignment: Alignment.centerLeft,
            child: MouseRegion(
              onEnter: (_) {
                _hoverTimer?.cancel();
                _hoverTimer = Timer(const Duration(milliseconds: 100), () {
                  if (mounted && _isCollapsed) {
                    setState(() => _isCollapsed = false);
                  }
                });
              },
              onExit: (_) {
                _hoverTimer?.cancel();
                _hoverTimer = Timer(const Duration(milliseconds: 200), () {
                  if (mounted && !_isCollapsed) {
                    setState(() => _isCollapsed = true);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                // Lebar berubah dari 70 ke 250
                width: _isCollapsed ? collapsedWidth : expandedWidth,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: _isCollapsed
                      ? []
                      : [
                          const BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(2, 0))
                        ],
                ),
                child: AppSidebarModern(
                  currentRoute: widget.currentRoute,
                  onNavigate: widget.onNavigate,
                  onLoginTap: widget.onLogout,
                  isLoggedIn: true,
                  isCollapsed: _isCollapsed,
                  userRole: widget.userRole,
                  onToggle: () {
                    _hoverTimer?.cancel();
                    setState(() => _isCollapsed = !_isCollapsed);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.currentRoute,
    required this.child,
    this.onNavigate,
    this.onLogout,
    this.userName = 'User',
    this.userRole,
    this.headerActionLabel = 'Sync Migrasi',
    this.headerActionIcon,
    this.onHeaderAction,
    this.onRefresh,
    this.showHeaderActionInAppBar = true,
    this.lastSync = '',
    this.headerActions = const [],
    this.title,
    this.onScan,
    this.floatingActionButton,
    this.showSidebar = true,
  });

  final String? title;
  final String currentRoute;
  final Widget child;
  final void Function(String route)? onNavigate;
  final VoidCallback? onLogout;
  final String userName;
  final String? userRole;
  final String headerActionLabel;
  final IconData? headerActionIcon;
  final VoidCallback? onHeaderAction;
  final VoidCallback? onRefresh;
  final bool showHeaderActionInAppBar;
  final String lastSync;
  final List<HeaderAction> headerActions;
  final VoidCallback? onScan;
  final Widget? floatingActionButton;
  final bool showSidebar;

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required String? currentRoute,
    required Function(String)? onNavigate,
    Color? iconColor,
  }) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? Colors.blue : (iconColor ?? Colors.grey)),
      title: Text(label,
          style: TextStyle(
              color: isSelected ? Colors.blue : (iconColor ?? Colors.black87))),
      selected: isSelected,
      selectedTileColor:
          Colors.blue.withValues(alpha: 0.1), // Efek highlight biru muda
      onTap: () {
        Navigator.pop(context);
        onNavigate?.call(route);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Jika sidebar tidak perlu ditampilkan, gunakan layout sederhana
    if (!showSidebar) {
      return Scaffold(
        floatingActionButton: floatingActionButton,
        body: child,
      );
    }

    return Scaffold(
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: title != null
            ? Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color.fromARGB(223, 9, 5, 89),
                ),
              )
            : const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Movva ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color.fromARGB(223, 9, 5, 89),
                      ),
                    ),
                    TextSpan(
                      text: 'by Anandam.id',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                        color: Color.fromARGB(255, 53, 205, 15),
                      ),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'User Menu',
            offset: const Offset(0, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade100, width: 1.5),
              ),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.transparent,
                child: Icon(Icons.person_rounded, size: 20),
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.person_outline_rounded,
                          size: 18, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 12),
                    const Text('Profil Saya',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    if (userRole != null)
                      Text(userRole!,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (onHeaderAction != null &&
                  (userRole?.toUpperCase() == 'ADMIN' ||
                      userRole?.toUpperCase() == 'SPV_MARKETING' ||
                      userRole?.toUpperCase() == 'GUDANG' ||
                      userRole?.toUpperCase() == 'SPV_GUDANG' ||
                      userRole?.toUpperCase() == 'NOTA' ||
                      (userRole?.toUpperCase() != null &&
                          userRole!
                              .toUpperCase()
                              .startsWith('MARKETING')))) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(headerActionIcon ?? Icons.sync_rounded,
                            size: 18, color: Colors.blue.shade700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(headerActionLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (lastSync.isNotEmpty)
                              Text(
                                lastSync,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (onLogout != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.logout_rounded,
                            size: 18, color: Colors.red.shade700),
                      ),
                      const SizedBox(width: 12),
                      const Text('Logout',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
            onSelected: (value) {
              if (value == 1) onHeaderAction?.call();
              if (value == 2) onLogout?.call();
              if (value == 3) onNavigate?.call(AppRoutes.profile);
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
      ),
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width > 0
            ? (MediaQuery.sizeOf(context).width * 0.85).clamp(256.0, 360.0)
            : 304.0,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/images/anandamid-logo.svg',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: () {
                  // Define groups similarly to AppSidebarModern
                  final groups = <List<Widget>>[
                    // --- GROUP 0: Dashboard ---
                    if (userRole == 'MANAGER' ||
                        userRole == 'ADMIN' ||
                        (userRole != null && userRole!.startsWith('SPV_')))
                      [
                        _buildMenuItem(
                          context,
                          icon: Icons.dashboard_rounded,
                          label: 'Dashboard',
                          route: AppRoutes.dashboard,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      ],

                    // --- GROUP 1: STOK, TKDN, CANVAS, RAKITAN ---
                    [
                      if (userRole != 'DELIVERY' &&
                          userRole != 'NOTA' &&
                          userRole != 'TEKNISI') ...[
                        _buildMenuItem(
                          context,
                          icon: Icons.inventory_2_rounded,
                          label: 'Stok',
                          route: AppRoutes.stok,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.apartment_rounded,
                          label: 'Stok per Badan',
                          route: AppRoutes.stokBadan,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      ],
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING' ||
                          (userRole != null &&
                              userRole!.startsWith('MARKETING')))
                        _buildMenuItem(
                          context,
                          icon: Icons.verified_rounded,
                          label: 'TKDN',
                          route: AppRoutes.tkdn,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING' ||
                          (userRole != null &&
                              userRole!.startsWith('MARKETING')))
                        _buildMenuItem(
                          context,
                          icon: Icons.palette_rounded,
                          label: 'Canvas',
                          route: AppRoutes.canvas,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SUPERVISOR' ||
                          userRole == 'SPV_MARKETING' ||
                          (userRole != null &&
                              userRole!.startsWith('MARKETING')))
                        _buildMenuItem(
                          context,
                          icon: Icons.computer_rounded,
                          label: 'Rakitan',
                          route: AppRoutes.rakitan,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING' ||
                          (userRole != null &&
                              userRole!.startsWith('MARKETING')))
                        _buildMenuItem(
                          context,
                          icon: Icons.calculate_rounded,
                          label: 'Simulasi SPJ',
                          route: AppRoutes.simulasi,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                    ],

                    // --- GROUP 2: MEMO, REQUEST DELIVERY, PENGIRIMAN, PETA PENGANTARAN ---
                    [
                      if (userRole != 'DELIVERY')
                        _buildMenuItem(
                          context,
                          icon: Icons.assignment_rounded,
                          label: 'Memo',
                          route: AppRoutes.memo,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'TEKNISI')
                        _buildMenuItem(
                          context,
                          icon: Icons.miscellaneous_services_rounded,
                          label: 'Manajemen Servis',
                          route: AppRoutes.servis,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole != null && userRole!.startsWith('MARKETING'))
                        _buildMenuItem(
                          context,
                          icon: Icons.local_shipping_outlined,
                          label: 'Request Delivery',
                          route: AppRoutes.requestDelivery,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == null ||
                          (userRole != 'NOTA' && userRole != 'TEKNISI'))
                        _buildMenuItem(
                          context,
                          icon: Icons.local_shipping_rounded,
                          label: (userRole == 'DELIVERY' ||
                                  (userRole != null &&
                                      userRole!.startsWith('MARKETING')))
                              ? 'Pengantaran'
                              : 'Pengiriman',
                          route: AppRoutes.pengiriman,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      // KOMENTAR: Menu Peta Pengantaran dinonaktifkan sementara
                      // if (userRole == 'ADMIN' ||
                      //     userRole == 'MANAGER' ||
                      //     userRole == 'GUDANG' ||
                      //     userRole == 'SPV_GUDANG' ||
                      //     userRole == 'DELIVERY')
                      //   _buildMenuItem(
                      //     context,
                      //     icon: Icons.map_rounded,
                      //     label: 'Peta Pengantaran',
                      //     route: AppRoutes.mapPengantaran,
                      //     currentRoute: currentRoute,
                      //     onNavigate: onNavigate,
                      //   ),
                    ],

                    // --- GROUP 3: PEMBELIAN, PENJUALAN, ITEM SN, DATA WAREHOUSE ---
                    [
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SUPERVISOR' ||
                          userRole == 'TEKNISI' ||
                          userRole == 'SPV_MARKETING')
                        _buildMenuItem(
                          context,
                          icon: Icons.shopping_bag_rounded,
                          label: 'Pembelian',
                          route: AppRoutes.pembelian,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SUPERVISOR' ||
                          userRole == 'TEKNISI' ||
                          userRole == 'SPV_MARKETING')
                        _buildMenuItem(
                          context,
                          icon: Icons.shopping_cart_rounded,
                          label: 'Penjualan',
                          route: AppRoutes.penjualan,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SUPERVISOR' ||
                          userRole == 'TEKNISI' ||
                          userRole == 'SPV_MARKETING')
                        _buildMenuItem(
                          context,
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Hutang',
                          route: AppRoutes.hutang,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING' ||
                          (userRole != null &&
                              userRole!.startsWith('MARKETING')))
                        _buildMenuItem(
                          context,
                          icon: Icons.receipt_long_rounded,
                          label: 'Piutang',
                          route: AppRoutes.piutang,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING' ||
                          userRole == 'TEKNISI')
                        _buildMenuItem(
                          context,
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Item SN',
                          route: AppRoutes.itemSn,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING')
                        _buildMenuItem(
                          context,
                          icon: Icons.assignment_turned_in_rounded,
                          label: 'Ijin Import',
                          route: AppRoutes.ijinImport,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING')
                        _buildMenuItem(
                          context,
                          icon: Icons.construction_rounded,
                          label: 'SHBJ',
                          route: AppRoutes.shbj,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'TEKNISI')
                        _buildMenuItem(
                          context,
                          icon: Icons.warehouse_rounded,
                          label: 'Data Warehouse',
                          route: AppRoutes.dataWarehouse,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                    ],

                    // --- GROUP 4: DATA CANVAS, USER, LOG AKTIVITAS ---
                    [
                      if (userRole == 'ADMIN' ||
                          userRole == 'MANAGER' ||
                          userRole == 'SPV_MARKETING')
                        _buildMenuItem(
                          context,
                          icon: Icons.analytics_rounded,
                          label: 'Data Canvas',
                          route: AppRoutes.dataCanvas,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' || userRole == 'MANAGER')
                        _buildMenuItem(
                          context,
                          icon: Icons.people_rounded,
                          label: 'User',
                          route: AppRoutes.users,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' || userRole == 'MANAGER')
                        _buildMenuItem(
                          context,
                          icon: Icons.people_alt_rounded,
                          label: 'User Activity',
                          route: AppRoutes.userActivity,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' || userRole == 'MANAGER')
                        _buildMenuItem(
                          context,
                          icon: Icons.history_rounded,
                          label: 'Log Aktivitas',
                          route: AppRoutes.activityLog,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' || userRole == 'MANAGER')
                        _buildMenuItem(
                          context,
                          icon: Icons.campaign_rounded,
                          label: 'Pengumuman',
                          route: AppRoutes.announcement,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'ADMIN' || userRole == 'MANAGER')
                        _buildMenuItem(
                          context,
                          icon: Icons.notifications_active_rounded,
                          label: 'Reminder Canvasing',
                          route: AppRoutes.reminderCanvasing,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                      if (userRole == 'MANAGER')
                        _buildMenuItem(
                          context,
                          icon: Icons.assessment_rounded,
                          label: 'Laporan Omset Marketing',
                          route: AppRoutes.laporanOmset,
                          currentRoute: currentRoute,
                          onNavigate: onNavigate,
                        ),
                    ],
                  ];

                  final validGroups =
                      groups.where((group) => group.isNotEmpty).toList();
                  final List<Widget> menuWidgets = [];

                  for (int i = 0; i < validGroups.length; i++) {
                    menuWidgets.addAll(validGroups[i]);
                    if (i < validGroups.length - 1) {
                      menuWidgets.add(const Divider(height: 16, thickness: 1));
                    }
                  }

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: menuWidgets,
                  );
                }(),
              ),

              // --- FOOTER (LOGOUT) ---
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Logout',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  onLogout?.call();
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: child,
      ),
    );
  }
}

class HeaderAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const HeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });
}
