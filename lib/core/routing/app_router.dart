import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stok_anandam/core/auth/app_permissions.dart';
import 'package:stok_anandam/data/models/memo.dart';
import 'package:stok_anandam/features/canvas/canvas_page.dart';
import 'package:stok_anandam/features/dashboard/dashboard_page.dart';
import 'package:stok_anandam/features/data_canvas/data_canvas_page.dart';
import 'package:stok_anandam/features/auth/bloc/screens/login_page.dart';
import 'package:stok_anandam/features/purchase/purchase_page.dart';
import 'package:stok_anandam/features/sales/sales_page.dart';
import 'package:stok_anandam/features/piutang/piutang_page.dart';
import 'package:stok_anandam/features/hutang/hutang_page.dart';
import 'package:stok_anandam/features/splash/splash_page.dart';
import 'package:stok_anandam/features/stock/stock_page.dart';
import 'package:stok_anandam/features/stock/stok_badan_page.dart';
import 'package:stok_anandam/features/tkdn/tkdn_page.dart';
import 'package:stok_anandam/features/servis/pages/servis_page.dart';
import 'package:stok_anandam/features/servis/pages/servis_detail_page.dart';
import 'package:stok_anandam/features/servis/pages/servis_scanner_page.dart';
import 'package:stok_anandam/features/memo/pages/memo_page.dart';
import 'package:stok_anandam/features/memo/pages/create_memo_page.dart';
import 'package:stok_anandam/features/memo/pages/memo_detail_page.dart';
import 'package:stok_anandam/features/item_sn/item_sn_page.dart';
import 'package:stok_anandam/features/penjadwalan/manual_request_page.dart';
import 'package:stok_anandam/features/users/users_page.dart';
import 'package:stok_anandam/features/activity_log/activity_log_page.dart';
import 'package:stok_anandam/features/assembly/assembly_page.dart';
import 'package:stok_anandam/features/auth/bloc/screens/access_denied_page.dart';
import 'package:stok_anandam/features/data_warehouse/data_warehouse_page.dart';
import 'package:stok_anandam/features/data_warehouse/old_sales_page.dart';
import 'package:stok_anandam/features/data_warehouse/old_purchase_page.dart';
import 'package:stok_anandam/features/data_warehouse/old_item_sn_page.dart';
import 'package:stok_anandam/features/profile/pages/profile_page.dart';
import 'package:stok_anandam/features/memo/pages/scanner_page.dart';
import 'package:stok_anandam/features/memo/pages/pengiriman_page.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/features/shared/widgets/camera_screen.dart';
import 'package:stok_anandam/features/memo/pages/delivery_detail_page.dart';
// KOMENTAR: PetaPengantaranPage dinonaktifkan sementara
// import 'package:stok_anandam/features/memo/pages/peta_pengantaran_page.dart';
import 'package:stok_anandam/features/memo/pages/manual_task_detail_page.dart';
import 'package:stok_anandam/features/memo/pages/delivery_scanner_page.dart';
import 'package:stok_anandam/features/penjadwalan/request_delivery_page.dart';
import 'package:stok_anandam/features/memo/pages/create_request_delivery_page.dart';
import 'package:stok_anandam/features/announcement/pages/announcement_page.dart';
import 'package:stok_anandam/features/announcement/pages/announcement_form_page.dart';
import 'package:stok_anandam/data/models/announcement.dart';
import 'package:stok_anandam/features/simulasi/simulasi_page.dart';
import 'package:stok_anandam/features/ijin_import/ijin_import_page.dart';
import 'package:stok_anandam/features/shbj/shbj_page.dart';
import 'package:stok_anandam/features/laporan_marketing/laporan_marketing_page.dart';
import 'package:stok_anandam/features/reminder_canvasing/reminder_canvasing_page.dart';
import 'package:stok_anandam/features/Biometric/screens/biometric_login_screen.dart';
import 'package:stok_anandam/features/presence/screens/admin_presence_screen.dart';
import 'package:stok_anandam/features/presence/bloc/presence_bloc.dart';
import 'package:stok_anandam/features/layout/dashboard_shell.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Route names untuk navigasi (hindari magic string).
class AppRoutes {
  static const String userActivity = '/user-activity';
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String stok = '/stok';
  static const String penjualan = '/penjualan';
  static const String pembelian = '/pembelian';
  static const String piutang = '/piutang';
  static const String hutang = '/hutang';
  static const String tkdn = '/tkdn';
  static const String canvas = '/canvas';
  static const String dataCanvas = '/data_canvas';
  static const String users = '/users';
  static const String activityLog = '/activity-log';
  static const String itemSn = '/item-sn';
  static const String rakitan = '/rakitan';
  static const String dataWarehouse = '/data-warehouse';
  static const String oldSales = '/old-sales';
  static const String oldPurchase = '/old-purchase';
  static const String oldItemSn = '/old-item-sn';
  static const String accessDenied = '/access-denied';
  static const String memo = '/memo';
  static const String memoCreate = '/memo/create';
  static const String memoDetail = '/memo/detail/:id';
  static const String camera = '/camera';
  static const String profile = '/profile';
  static const String scanner = '/scanner';
  static const String pengiriman = '/pengiriman';
  // KOMENTAR: Route Peta Pengantaran dinonaktifkan sementara
  // static const String mapPengantaran = '/map-pengantaran';
  static const String deliveryDetail = '/pengantaran/detail/:id';
  static const String manualRequest = '/penjadwalan/manual';
  static const String requestDelivery = '/request-delivery';
  static const String requestDeliveryCreate = '/request-delivery/create';
  static const String manualTaskDetail = '/manual-task/:id';
  static const String announcement = '/announcement';
  static const String announcementForm = '/announcement/form';
  static const String simulasi = '/simulasi';
  static const String shbj = '/shbj';
  static const String ijinImport = '/ijin-import';
  static const String servis = '/servis';
  static const String servisCreate = '/servis/create';
  static const String servisDetail = '/servis/detail/:id';
  static const String servisScanner = '/servis/scanner';
  static const String laporan = '/laporan';
  static const String laporanOmset = '/laporan-omset-marketing';
  static const String reminderCanvasing = '/reminder-canvasing';
  static const String stokBadan = '/stok-badan';
  static const String biometricLogin = '/biometric-login';
  static const String deliveryScanner = '/pengiriman/delivery-scan';
}

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: Listenable.merge([
    getIt<TokenStorage>(),
    getIt<CurrentUserStore>(),
  ]),
  redirect: (BuildContext context, GoRouterState state) {
    final location = state.uri.path;

    // Don't redirect from splash screen - let it handle navigation
    if (location == AppRoutes.splash) return null;

    final token = getIt<TokenStorage>().token;
    final hasToken = token != null && token.isNotEmpty;
    final isLoginRoute = location == AppRoutes.login;
    final isAccessDeniedRoute = location == AppRoutes.accessDenied;
    final isBiometricLoginRoute = location == AppRoutes.biometricLogin;

    if (!hasToken &&
        !isLoginRoute &&
        !isAccessDeniedRoute &&
        !isBiometricLoginRoute) {
      return AppRoutes.login;
    }

    // If logged in and on login/splash, redirect to appropriate home page.
    if (hasToken && (isLoginRoute || location == AppRoutes.splash)) {
      final userStore = getIt<CurrentUserStore>();
      final userRole = userStore.userRole?.toUpperCase();

      // If role not yet loaded, don't redirect yet - let the app finish loading user info.
      if (userRole == null) return null;

      if (userStore.hasPermission(AppPermission.dashboard)) {
        return AppRoutes.dashboard;
      }
      if (userStore.hasPermission(AppPermission.memo)) {
        return AppRoutes.memo;
      }
      if (userStore.hasPermission(AppPermission.stok)) {
        return AppRoutes.stok;
      }
      if (userStore.hasPermission(AppPermission.pengiriman)) {
        return AppRoutes.pengiriman;
      }
      if (userStore.hasPermission(AppPermission.servis)) {
        return AppRoutes.servis;
      }
      if (userStore.hasPermission(AppPermission.pembelian)) {
        return AppRoutes.pembelian;
      }
      if (userStore.hasPermission(AppPermission.penjualan)) {
        return AppRoutes.penjualan;
      }
      if (userStore.hasPermission(AppPermission.piutang)) {
        return AppRoutes.piutang;
      }

      // Default for other logged-in users who don't have a specific home page
      return AppRoutes.stok;
    }

    // From here on, we assume the user is logged in and not on login/splash.
    final userStore = getIt<CurrentUserStore>();
    final userRole = userStore.userRole?.toUpperCase();

    // If role not loaded yet, allow progress (page will handle loading)
    if (userRole == null) return null;

    if (location == AppRoutes.accessDenied) return null;

    // Common pages accessible by any logged-in user
    if (location == AppRoutes.profile ||
        location == AppRoutes.scanner ||
        location == AppRoutes.camera ||
        location == AppRoutes.biometricLogin) {
      return null;
    }

    // Manager & Admin always have full access
    if (userRole == 'MANAGER' || userRole == 'ADMIN') {
      return null;
    }

    // Checklist-based Permission Evaluation
    bool can(String perm) => userStore.hasPermission(perm);

    // 1. Dashboard & Laporan
    if (location == AppRoutes.dashboard) {
      return can(AppPermission.dashboard) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.laporanOmset) {
      return can(AppPermission.laporanOmset) ? null : AppRoutes.accessDenied;
    }

    // 2. Stok & Logistik
    if (location == AppRoutes.stok) {
      return can(AppPermission.stok) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.stokBadan) {
      return can(AppPermission.stokBadan) || can(AppPermission.stok)
          ? null
          : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.tkdn) {
      return can(AppPermission.tkdn) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.canvas) {
      return can(AppPermission.canvas) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.rakitan) {
      return can(AppPermission.rakitan) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.simulasi) {
      return can(AppPermission.simulasiSpj) ? null : AppRoutes.accessDenied;
    }

    // 3. Memo
    if (location == AppRoutes.memo ||
        location == AppRoutes.memoCreate ||
        location.startsWith('/memo/detail/')) {
      return can(AppPermission.memo) ? null : AppRoutes.accessDenied;
    }

    // 4. Request Delivery & Pengiriman
    if (location == AppRoutes.requestDelivery ||
        location == AppRoutes.requestDeliveryCreate) {
      return can(AppPermission.requestDelivery) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.pengiriman ||
        location == '/pengiriman' ||
        location == AppRoutes.deliveryScanner ||
        location.startsWith('/pengantaran/detail/')) {
      return can(AppPermission.pengiriman) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.manualRequest ||
        location.startsWith('/manual-task/')) {
      return can(AppPermission.penjadwalan) || can(AppPermission.pengiriman)
          ? null
          : AppRoutes.accessDenied;
    }

    // 5. Pembelian & Penjualan
    if (location == AppRoutes.pembelian || location == AppRoutes.oldPurchase) {
      return can(AppPermission.pembelian) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.penjualan || location == AppRoutes.oldSales) {
      return can(AppPermission.penjualan) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.piutang) {
      return can(AppPermission.piutang) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.hutang) {
      return can(AppPermission.pembelian) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.itemSn || location == AppRoutes.oldItemSn) {
      return can(AppPermission.itemSn) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.dataWarehouse) {
      return can(AppPermission.dataWarehouse) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.dataCanvas) {
      return can(AppPermission.dataCanvas) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.ijinImport) {
      return can(AppPermission.ijinImport) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.shbj) {
      return can(AppPermission.shbj) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.reminderCanvasing) {
      return can(AppPermission.reminder) ? null : AppRoutes.accessDenied;
    }

    // 6. Servis
    if (location == AppRoutes.servis ||
        location == AppRoutes.servisCreate ||
        location == AppRoutes.servisScanner ||
        location.startsWith('/servis/detail/')) {
      return can(AppPermission.servis) ? null : AppRoutes.accessDenied;
    }

    // 7. Sistem & Pengaturan
    if (location == AppRoutes.users) {
      return can(AppPermission.users) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.userActivity) {
      return can(AppPermission.userActivity) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.activityLog) {
      return can(AppPermission.activityLog) ? null : AppRoutes.accessDenied;
    }
    if (location == AppRoutes.announcement ||
        location == AppRoutes.announcementForm) {
      return can(AppPermission.announcement) ? null : AppRoutes.accessDenied;
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.splash,
      name: AppRoutes.splash,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.splash, const SplashPage()),
    ),
    GoRoute(
      path: '/pengiriman',
      name: 'pengiriman',
      pageBuilder: (context, state) =>
          _buildPage(state, '/pengiriman', const PengirimanPage()),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: AppRoutes.login,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.login, const LoginPage()),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      name: AppRoutes.dashboard,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.dashboard, const DashboardPage()),
    ),
    GoRoute(
      path: AppRoutes.stok,
      name: AppRoutes.stok,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.stok, const StockPage()),
    ),
    GoRoute(
      path: AppRoutes.stokBadan,
      name: AppRoutes.stokBadan,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.stokBadan, const StokBadanPage()),
    ),
    GoRoute(
      path: AppRoutes.penjualan,
      name: AppRoutes.penjualan,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.penjualan, const SalesPage()),
    ),
    GoRoute(
      path: AppRoutes.piutang,
      name: AppRoutes.piutang,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.piutang, const PiutangPage()),
    ),
    GoRoute(
      path: AppRoutes.hutang,
      name: AppRoutes.hutang,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.hutang, const HutangPage()),
    ),
    GoRoute(
      path: AppRoutes.laporanOmset,
      name: AppRoutes.laporanOmset,
      pageBuilder: (context, state) => _buildPage(
          state, AppRoutes.laporanOmset, const LaporanMarketingPage()),
    ),
    GoRoute(
      path: AppRoutes.reminderCanvasing,
      name: AppRoutes.reminderCanvasing,
      pageBuilder: (context, state) => _buildPage(
          state, AppRoutes.reminderCanvasing, const ReminderCanvasingPage()),
    ),
    GoRoute(
      path: AppRoutes.pembelian,
      name: AppRoutes.pembelian,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.pembelian, const PurchasePage()),
    ),
    GoRoute(
      path: AppRoutes.tkdn,
      name: AppRoutes.tkdn,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.tkdn, const TkdnPage()),
    ),
    GoRoute(
      path: AppRoutes.itemSn,
      name: AppRoutes.itemSn,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.itemSn, const ItemSnPage()),
    ),
    GoRoute(
      path: AppRoutes.canvas,
      name: AppRoutes.canvas,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.canvas, const CanvasPage()),
    ),
    GoRoute(
      path: AppRoutes.dataCanvas,
      name: AppRoutes.dataCanvas,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.dataCanvas, const DataCanvasPage()),
    ),
    GoRoute(
      path: AppRoutes.users,
      name: AppRoutes.users,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.users, const UsersPage()),
    ),
    GoRoute(
      path: AppRoutes.activityLog,
      name: AppRoutes.activityLog,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.activityLog, const ActivityLogPage()),
    ),
    GoRoute(
      path: AppRoutes.rakitan,
      name: AppRoutes.rakitan,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.rakitan, const AssemblyPage()),
    ),
    GoRoute(
      path: AppRoutes.dataWarehouse,
      name: AppRoutes.dataWarehouse,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.dataWarehouse, const DataWarehousePage()),
    ),
    GoRoute(
      path: AppRoutes.oldSales,
      name: AppRoutes.oldSales,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.oldSales, const OldSalesPage()),
    ),
    GoRoute(
      path: AppRoutes.oldPurchase,
      name: AppRoutes.oldPurchase,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.oldPurchase, const OldPurchasePage()),
    ),
    GoRoute(
      path: AppRoutes.oldItemSn,
      name: AppRoutes.oldItemSn,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.oldItemSn, const OldItemSnPage()),
    ),
    GoRoute(
      path: AppRoutes.accessDenied,
      name: AppRoutes.accessDenied,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.accessDenied, const AccessDeniedPage()),
    ),
    GoRoute(
      path: AppRoutes.memo,
      name: AppRoutes.memo,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.memo, const MemoPage()),
    ),
    GoRoute(
      path: AppRoutes.memoCreate,
      name: AppRoutes.memoCreate,
      pageBuilder: (context, state) {
        final memoType = state.uri.queryParameters['type'] ?? 'BIASA';
        final continuationId = state.uri.queryParameters['continuationId'];
        final isNewDuplicate =
            state.uri.queryParameters['isNewDuplicate'] == 'true';
        final initialData =
            state.extra is MemoDetail ? state.extra as MemoDetail : null;

        return _buildPage(
            state,
            AppRoutes.memoCreate,
            CreateMemoPage(
              memoType: memoType,
              initialData: initialData,
              continuationId: continuationId,
              isNewDuplicate: isNewDuplicate,
            ));
      },
    ),
    GoRoute(
      path: AppRoutes.memoDetail,
      name: AppRoutes.memoDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _buildPage(state, AppRoutes.memoDetail, MemoDetailPage(id: id));
      },
    ),
    GoRoute(
      path: AppRoutes.camera,
      name: AppRoutes.camera,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.camera, const CameraScreen()),
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: AppRoutes.profile,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.profile, const ProfilePage()),
    ),
    GoRoute(
      path: AppRoutes.scanner,
      name: AppRoutes.scanner,
      pageBuilder: (context, state) {
        final returnResult = state.extra as bool? ?? false;
        return _buildPage(
          state,
          AppRoutes.scanner,
          ScannerPage(returnResult: returnResult),
        );
      },
    ),
    // KOMENTAR: Route Peta Pengantaran dinonaktifkan sementara
    // GoRoute(
    //   path: AppRoutes.mapPengantaran,
    //   name: AppRoutes.mapPengantaran,
    //   pageBuilder: (context, state) => _buildPage(
    //       state, AppRoutes.mapPengantaran, const PetaPengantaranPage()),
    // ),
    GoRoute(
      path: AppRoutes.deliveryDetail,
      name: AppRoutes.deliveryDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _buildPage(
            state, AppRoutes.deliveryDetail, DeliveryDetailPage(id: id));
      },
    ),
    // Route untuk Delivery Scan QR (fitur baru)
    GoRoute(
      path: AppRoutes.deliveryScanner,
      name: AppRoutes.deliveryScanner,
      pageBuilder: (context, state) => _buildPage(
          state, AppRoutes.deliveryScanner, const DeliveryScannerPage()),
    ),

    GoRoute(
      path: AppRoutes.manualRequest,
      name: AppRoutes.manualRequest,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.manualRequest, const ManualRequestPage()),
    ),
    GoRoute(
      path: AppRoutes.manualTaskDetail,
      name: AppRoutes.manualTaskDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _buildPage(
            state, AppRoutes.manualTaskDetail, ManualTaskDetailPage(id: id));
      },
    ),
    GoRoute(
      path: AppRoutes.requestDelivery,
      name: AppRoutes.requestDelivery,
      pageBuilder: (context, state) => _buildPage(
          state, AppRoutes.requestDelivery, const RequestDeliveryPage()),
    ),
    GoRoute(
      path: AppRoutes.requestDeliveryCreate,
      name: AppRoutes.requestDeliveryCreate,
      pageBuilder: (context, state) => _buildPage(state,
          AppRoutes.requestDeliveryCreate, const CreateRequestDeliveryPage()),
    ),
    GoRoute(
      path: AppRoutes.announcement,
      name: AppRoutes.announcement,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.announcement, const AnnouncementPage()),
    ),
    GoRoute(
      path: AppRoutes.announcementForm,
      name: AppRoutes.announcementForm,
      pageBuilder: (context, state) {
        final announcement =
            state.extra is Announcement ? state.extra as Announcement : null;
        return _buildPage(state, AppRoutes.announcementForm,
            AnnouncementFormPage(announcement: announcement));
      },
    ),
    GoRoute(
      path: AppRoutes.simulasi,
      name: AppRoutes.simulasi,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.simulasi, const SimulasiPage()),
    ),
    GoRoute(
      path: AppRoutes.ijinImport,
      name: AppRoutes.ijinImport,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.ijinImport, const IjinImportPage()),
    ),
    GoRoute(
      path: AppRoutes.shbj,
      name: AppRoutes.shbj,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.shbj, const ShbjPage()),
    ),
    GoRoute(
      path: AppRoutes.servis,
      name: AppRoutes.servis,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.servis, const ServisPage()),
    ),
    GoRoute(
      path: AppRoutes.servisDetail,
      name: AppRoutes.servisDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _buildPage(
            state, AppRoutes.servisDetail, ServisDetailPage(id: id));
      },
    ),
    GoRoute(
      path: AppRoutes.servisScanner,
      name: AppRoutes.servisScanner,
      pageBuilder: (context, state) =>
          _buildPage(state, AppRoutes.servisScanner, const ServisScannerPage()),
    ),
    GoRoute(
      path: AppRoutes.biometricLogin,
      name: AppRoutes.biometricLogin,
      pageBuilder: (context, state) => _buildPage(
          state, AppRoutes.biometricLogin, const BiometricLoginScreen()),
    ),
    GoRoute(
      path: AppRoutes.userActivity,
      name: AppRoutes.userActivity,
      pageBuilder: (context, state) => _buildPage(
        state,
        AppRoutes.userActivity,
        BlocProvider(
          create: (_) => PresenceBloc(),
          child: DashboardShell(
            currentRoute: AppRoutes.userActivity,
            userName: getIt<CurrentUserStore>().displayName,
            userRole: getIt<CurrentUserStore>().userRole,
            onNavigate: (route) {
              context.go(route);
            },
            onLogout: () {
              getIt<TokenStorage>().clear();
              getIt<CurrentUserStore>().clear();
              context.go(AppRoutes.login);
            },
            title: 'User Activity Monitor',
            child: const AdminPresenceScreen(),
          ),
        ),
      ),
    ),
  ],
);

CustomTransitionPage<void> _buildPage(
    GoRouterState state, String name, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: name,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const curve = Curves.easeInOutCubic;
      final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
      final opacity = Tween<double>(begin: 0, end: 1).animate(curvedAnimation);
      final offset =
          Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
              .animate(curvedAnimation);
      return FadeTransition(
        opacity: opacity,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}
