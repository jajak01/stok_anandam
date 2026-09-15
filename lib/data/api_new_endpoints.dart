import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:stok_anandam/core/network/stock_summary_row.dart';
import 'package:stok_anandam/data/models/delivery_scan_response.dart';
import 'package:stok_anandam/data/models/memo.dart';
import 'package:stok_anandam/data/models/penjadwalan.dart';
import 'package:stok_anandam/data/models/request_delivery.dart';
import 'package:stok_anandam/data/models/announcement.dart';

import 'package:stok_anandam/features/stock/stok_badan_models.dart';
import 'package:stok_anandam/core/auth/app_permissions.dart';

/// Endpoint baru dari API (lihat docs/API_INTEGRATION.md) yang belum ada di client generated.
/// Memakai Dio yang sama (baseUrl + auth) dari injection.
class ApiNewEndpoints {
  ApiNewEndpoints(this._dio);

  final Dio _dio;
  String get baseUrl => _dio.options.baseUrl;

  // ─── Cache ringan untuk Stok per Badan ─────────────────────────────────────
  // Data disimpan dalam memori (per session app) agar tidak re-fetch saat
  // buka detail item berikutnya. TTL 5 menit.
  List<StokBadanGroup>? _stokPerBadanCache;
  DateTime? _stokPerBadanCacheTime;
  static const _stokPerBadanCacheTTL = Duration(minutes: 5);

  bool get _stokBadanCacheValid =>
      _stokPerBadanCache != null &&
      _stokPerBadanCacheTime != null &&
      DateTime.now().difference(_stokPerBadanCacheTime!) < _stokPerBadanCacheTTL;

  void invalidateStokBadanCache() {
    _stokPerBadanCache = null;
    _stokPerBadanCacheTime = null;
  }

  /// GET /api/v1/auth/me
  /// Returns data user yang login (nama, username, role) untuk header.
  Future<AuthMeResult?> getMe() async {
    final response = await _dio.get<Object>('/api/v1/auth/me');
    final data = response.data;
    debugPrint('[ApiNewEndpoints] getMe raw response: $data');
    if (data == null || data is! Map) return null;
    final inner = (data)['data'];
    if (inner is! Map) return null;
    return AuthMeResult.fromJson(Map<String, dynamic>.from(inner));
  }

  /// POST /api/v1/auth/change-password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post('/api/v1/auth/change-password', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  /// PUT /api/v1/auth/profile/phone
  Future<AuthMeResult?> updateProfilePhone(String noHp) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/auth/profile/phone',
      data: {'noHp': noHp},
    );
    final data = response.data?['data'];
    if (data == null) return null;
    return AuthMeResult.fromJson(Map<String, dynamic>.from(data));
  }

  /// GET /api/v1/sales/employee-codes
  /// Returns daftar kode karyawan untuk dropdown filter.
  Future<List<EmployeeOption>> getEmployeeCodes() async {
    final response = await _dio.get<Object>('/api/v1/sales/employee-codes');
    final data = response.data;
    if (data == null) return [];
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => EmployeeOption.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// GET /api/v1/canvasing/options?search=&limit=50
  /// Returns options ringan (id, namaInstansi) untuk dropdown.
  Future<List<CanvasingOption>> getCanvasingOptions({
    String? search,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': limit,
    };
    final response = await _dio.get<Object>(
      '/api/v1/canvasing/options',
      queryParameters: queryParams,
    );
    final data = response.data;
    if (data == null) return [];
    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      return list
          .map((e) {
            if (e is Map) {
              return CanvasingOption.fromJson(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<CanvasingOption>()
          .where((o) =>
              o.id != null ||
              (o.namaInstansi != null && o.namaInstansi!.isNotEmpty))
          .toList();
    }
    return [];
  }

  /// GET /api/v1/tkdn/categories
  /// Returns daftar kategori unik untuk dropdown filter.
  Future<List<String>> getTkdnCategories() async {
    final response = await _dio.get<Object>('/api/v1/tkdn/categories');
    final data = response.data;
    if (data == null) return [];
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return [];
  }

  /// GET /api/v1/stock/summary-by-category?groupBy=
  /// Returns ringkasan stok per kategori (flat list).
  Future<List<StockSummaryRow>> getStockSummaryByCategory({
    String groupBy = 'kategori_itemcode',
  }) async {
    final response = await _dio.get<Object>(
      '/api/v1/stock/summary-by-category',
      queryParameters: {'groupBy': groupBy},
    );
    final data = response.data;
    if (data == null) return [];
    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      return list
          .map((e) => e is Map
              ? StockSummaryRow.fromJson(Map<String, dynamic>.from(e))
              : null)
          .whereType<StockSummaryRow>()
          .toList();
    }
    return [];
  }

  /// GET /api/v1/stock/summary-by-category/hierarchy?groupBy=
  /// Returns ringkasan stok 2 level (parent + children).
  Future<List<StockSummaryRow>> getStockSummaryHierarchy({
    String groupBy = 'kategori_itemcode',
  }) async {
    final response = await _dio.get<Object>(
      '/api/v1/stock/summary-by-category/hierarchy',
      queryParameters: {'groupBy': groupBy},
    );
    final data = response.data;
    if (data == null) return [];
    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      return list
          .map((e) => e is Map
              ? StockSummaryRow.fromJson(Map<String, dynamic>.from(e))
              : null)
          .whereType<StockSummaryRow>()
          .toList();
    }
    return [];
  }

  /// GET /api/v1/activity-logs/last-sync
  /// Returns data log terakhir migrasi.
  Future<DateTime?> getLastSync() async {
    try {
      final response =
          await _dio.get<Object>('/api/v1/activity-logs/last-sync');
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final timestampStr = data['data']['timestamp']?.toString();
        if (timestampStr != null) {
          return DateTime.parse(timestampStr);
        }
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/v1/old-data/meta
  /// Returns max year per category and min year for Data Warehouse labels.
  Future<OldDataMeta> getOldDataMeta() async {
    try {
      final response = await _dio.get<Object>('/api/v1/old-data/meta');
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final d = data['data'] as Map;
        return OldDataMeta(
          minYear: (d['minYear'] as num?)?.toInt() ?? 2016,
          salesMaxYear: (d['salesMaxYear'] as num?)?.toInt(),
          purchaseMaxYear: (d['purchaseMaxYear'] as num?)?.toInt(),
          itemSnMaxYear: (d['itemSnMaxYear'] as num?)?.toInt(),
        );
      }
    } catch (_) {}
    return const OldDataMeta(minYear: 2016);
  }

  /// GET /api/v1/activity-logs
  Future<Map<String, dynamic>> getActivityLogs({
    int page = 0,
    int size = 20,
    String? username,
    String? action,
    String sortBy = 'timestamp',
    String direction = 'desc',
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (username != null && username.isNotEmpty) 'username': username,
      if (action != null && action.isNotEmpty) 'action': action,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/activity-logs',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  /// GET /api/sn/masuk
  Future<Map<String, dynamic>> getSnMasuk({
    int page = 0,
    int size = 20,
    String sortBy = 'tanggal',
    String direction = 'desc',
    String? search,
    String? docId,
    String? user,
    String? itemName,
    String? sn,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (search != null && search.isNotEmpty) 'search': search,
      if (docId != null && docId.isNotEmpty) 'docId': docId,
      if (user != null && user.isNotEmpty) 'user': user,
      if (itemName != null && itemName.isNotEmpty) 'itemName': itemName,
      if (sn != null && sn.isNotEmpty) 'sn': sn,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/sn/masuk',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  /// GET /api/sn/keluar
  Future<Map<String, dynamic>> getSnKeluar({
    int page = 0,
    int size = 20,
    String sortBy = 'tanggal',
    String direction = 'desc',
    String? search,
    String? docId,
    String? user,
    String? itemName,
    String? sn,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (search != null && search.isNotEmpty) 'search': search,
      if (docId != null && docId.isNotEmpty) 'docId': docId,
      if (user != null && user.isNotEmpty) 'user': user,
      if (itemName != null && itemName.isNotEmpty) 'itemName': itemName,
      if (sn != null && sn.isNotEmpty) 'sn': sn,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/sn/keluar',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  /// GET /api/v1/old-data/sales
  Future<Map<String, dynamic>> getOldSales({
    int page = 0,
    int size = 20,
    String sortBy = 'docDate',
    String direction = 'desc',
    String? search,
    String? startDate,
    String? endDate,
    String? empCode,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (search != null && search.isNotEmpty) 'search': search,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (empCode != null && empCode.isNotEmpty) 'empCode': empCode,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/old-data/sales',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  /// GET /api/v1/old-data/purchase
  Future<Map<String, dynamic>> getOldPurchase({
    int page = 0,
    int size = 20,
    String sortBy = 'docDate',
    String direction = 'desc',
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (search != null && search.isNotEmpty) 'search': search,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/old-data/purchase',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  /// GET /api/v1/old-data/item-sn
  Future<Map<String, dynamic>> getOldItemSn({
    int page = 0,
    int size = 20,
    String sortBy = 'tanggal',
    String direction = 'desc',
    String? search,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (search != null && search.isNotEmpty) 'search': search,
      if (type != null && type.isNotEmpty) 'type': type,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/old-data/item-sn',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  /// GET /api/v1/old-data/employee-codes
  Future<List<String>> getOldEmployeeCodes() async {
    final response = await _dio.get<Object>('/api/v1/old-data/employee-codes');
    final data = response.data;
    if (data == null) return [];
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return [];
  }

  // --- MIGRATION TRIGGERS ---
  Future<void> startStockMigration() async {
    await _dio.post('/api/v1/migration/stock');
  }

  Future<void> startSalesMigration() async {
    await _dio.post('/api/v1/migration/sales');
  }

  Future<void> startPurchaseMigration() async {
    await _dio.post('/api/v1/migration/purchase');
  }

  Future<void> startSnMigration() async {
    await _dio.post('/api/v1/migration/sn');
  }

  Future<void> startCanvasingMigration() async {
    await _dio.post('/api/v1/migration/canvasing');
  }

  Future<void> startTkdnMigration() async {
    await _dio.post('/api/v1/migration/tkdn');
  }

  Future<void> startPricelistMigration() async {
    await _dio.post('/api/v1/migration/pricelist');
  }

  Future<void> startPelangganMigration() async {
    await _dio.post('/api/v1/migration/pelanggan');
  }

  /// GET /api/v1/sales/export
  /// Returns raw bytes of the Excel file.
  Future<List<int>> exportSales({
    String? startDate,
    String? endDate,
    String? empCode,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (empCode != null) 'empCode': empCode,
      if (search != null) 'search': search,
    };
    final response = await _dio.get<List<int>>(
      '/api/v1/sales/export',
      queryParameters: queryParams,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// GET /api/v1/purchases/export
  /// Returns raw bytes of the Excel file.
  Future<List<int>> exportPurchases({
    String? startDate,
    String? endDate,
    String? empCode,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (empCode != null) 'empCode': empCode,
      if (search != null) 'search': search,
    };
    final response = await _dio.get<List<int>>(
      '/api/v1/purchases/export',
      queryParameters: queryParams,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  // --- MEMO ENDPOINTS ---

  /// POST /api/v1/memos
  Future<String?> createMemo(Map<String, dynamic> request) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/api/v1/memos', data: request);
    return response.data?['data']?.toString();
  }

  /// PUT /api/v1/memos/{id}
  Future<void> updateMemo(String id, Map<String, dynamic> request) async {
    await _dio.put('/api/v1/memos/$id', data: request);
  }

  /// POST /api/v1/memos/{id}/duplicate-revision
  Future<MemoDetail?> duplicateRevision(String memoId) async {
    final response = await _dio
        .post<Map<String, dynamic>>('/api/v1/memos/$memoId/duplicate-revision');
    final data = response.data?['data'];
    if (data == null) return null;
    return MemoDetail.fromJson(Map<String, dynamic>.from(data));
  }

  /// POST /api/v1/memos/{id}/duplicate-header
  Future<MemoDetail?> duplicateHeader(String memoId) async {
    final response = await _dio
        .post<Map<String, dynamic>>('/api/v1/memos/$memoId/duplicate-header');
    final data = response.data?['data'];
    if (data == null) return null;
    return MemoDetail.fromJson(Map<String, dynamic>.from(data));
  }

  /// POST /api/v1/memos/pending
  Future<String?> createPendingMemo(Map<String, dynamic> request) async {
    final response = await _dio
        .post<Map<String, dynamic>>('/api/v1/memos/pending', data: request);
    return response.data?['data']?.toString();
  }

  /// GET /api/v1/memos
  Future<List<MemoDetail>> getListMemo(
      {String? status, String? memoType, List<String>? statuses}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/memos',
      queryParameters: {
        if (status != null) 'status': status,
        if (memoType != null) 'memoType': memoType,
        if (statuses != null && statuses.isNotEmpty) 'statuses': statuses.join(','),
      },
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) => MemoDetail.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
  }

  /// GET /api/v1/memos/counts
  Future<Map<String, int>> getMemoCounts() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/v1/memos/counts');
    final data = response.data?['data'];
    if (data is Map) {
      return Map<String, int>.from(data.map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt())));
    }
    return {};
  }

  /// GET /api/v1/memos/{id}
  Future<MemoDetail?> getMemoDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/memos/$id');
    final data = response.data?['data'];
    if (data == null) return null;
    return MemoDetail.fromJson(Map<String, dynamic>.from(data));
  }

  /// GET /api/v1/memos/search/by-resi?resi=
  Future<List<MemoDetail>> searchMemoByResi(String resi) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/memos/search/by-resi',
      queryParameters: {'resi': resi.trim()},
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) => MemoDetail.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
  }

  /// GET /api/v1/memos/search/by-order-id?orderId=
  Future<List<MemoDetail>> searchMemoByOrderId(String orderId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/memos/search/by-order-id',
      queryParameters: {'orderId': orderId.trim()},
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) => MemoDetail.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
  }

  /// GET /api/v1/memos/search/by-barcode?code=
  /// Smart search: exact resi → exact orderId → exact nomorMemo → partial resi → partial orderId
  Future<List<MemoDetail>> searchMemoByBarcode(String code) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/memos/search/by-barcode',
      queryParameters: {'code': code.trim()},
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) => MemoDetail.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
  }

  /// PUT /api/v1/memos/pending/{id}/approve
  Future<void> approvePending(String id) async {
    await _dio.put('/api/v1/memos/pending/$id/approve');
  }

  /// PUT /api/v1/memos/pending/{id}/reject
  Future<void> rejectPending(String id) async {
    await _dio.put('/api/v1/memos/pending/$id/reject');
  }

  /// PUT /api/v1/memos/pending/{id}/release
  Future<void> releasePending(String id) async {
    await _dio.put('/api/v1/memos/pending/$id/release');
  }

  /// PUT /api/v1/memos/pending/{id}/continue
  Future<void> continuePendingMemo(
      String id, Map<String, dynamic> request) async {
    await _dio.put(
      '/api/v1/memos/pending/$id/continue',
      data: {'details': request},
    );
  }

  /// PUT /api/v1/memos/pending/{id}/finish-pending
  Future<void> finishPendingMemo(String id) async {
    await _dio.put('/api/v1/memos/pending/$id/finish-pending');
  }

  /// POST /api/v1/memos/{id}/penjadwalan
  Future<String?> createPenjadwalan(
      String memoId, Map<String, dynamic> request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/memos/$memoId/penjadwalan',
      data: request,
    );
    return response.data?['data']?.toString();
  }

  /// PUT /api/v1/memos/{id}/finalize
  Future<void> finalizeMemo(String id) async {
    await _dio.put('/api/v1/memos/$id/finalize');
  }

  /// GET /api/v1/kodepos?search=
  Future<List<Map<String, dynamic>>> searchKodepos(String search) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/kodepos',
      queryParameters: {'search': search},
    );
    final list = response.data?['data'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// PUT /api/v1/memos/items/{itemId}/catatan
  Future<void> updateItemCatatan(int itemId, String catatan) async {
    await _dio.put(
      '/api/v1/memos/items/$itemId/catatan',
      data: {'catatanGudang': catatan},
    );
  }

  /// GET /api/v1/users?role=&size=500
  Future<List<UserAccount>> getUsersByRole(String role) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users',
      queryParameters: {'role': role, 'size': 500},
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) =>
                UserAccount.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
  }

  Future<List<UserAccount>> getAllUsers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users',
      queryParameters: {'size': 500},
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) =>
                UserAccount.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
  }

  /// GET /api/v1/users/{id}/emp-scope
  /// Mengambil daftar EMP_Code yang boleh dilihat/ditangani user.
  Future<Set<String>> getUserEmpScope(Object id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/v1/users/$id/emp-scope');
    final data = response.data?['data'];
    if (data is List) {
      return data
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet();
    }
    return <String>{};
  }

  /// PUT /api/v1/users/{id}/emp-scope
  Future<void> updateUserEmpScope(Object id, Set<String> empCodes) async {
    await _dio.put(
      '/api/v1/users/$id/emp-scope',
      data: empCodes.toList(),
    );
  }

  /// PUT /api/v1/users/{id}/toggle-status
  Future<void> toggleUserStatus(Object id) async {
    await _dio.patch('/api/v1/users/$id/toggle-status');
  }

  /// POST /api/v1/users/{id}/clear-sessions
  Future<void> clearUserSessions(Object id) async {
    await _dio.post('/api/v1/users/$id/clear-sessions');
  }

  /// PUT /api/v1/memos/{id}/gudang-finish (Sekarang tanpa request body)
  Future<void> finishWarehouseProcess(String id) async {
    await _dio.put('/api/v1/memos/$id/gudang-finish');
  }

  /// PUT /api/v1/memos/{id}/invoice-finish (Input JL)
  Future<void> finishInvoicingProcess(
      String id, Map<String, dynamic> data) async {
    await _dio.put('/api/v1/memos/$id/invoice-finish', data: data);
  }

  /// PUT /api/v1/memos/{id}/delivery-route
  Future<void> confirmDeliveryRoute(
      String id, Map<String, dynamic> request) async {
    await _dio.put(
      '/api/v1/memos/$id/delivery-route',
      data: request,
    );
  }

  /// PUT /api/v1/memos/{id}/pickup-route
  Future<void> confirmPickupRoute(String id,
      {required String filePath, required String fileName}) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    await _dio.put('/api/v1/memos/$id/pickup-route', data: formData);
  }

  /// PUT /api/v1/memos/{id}/pickup-final
  Future<void> confirmPickupFinal(String id) async {
    await _dio.put('/api/v1/memos/$id/pickup-final');
  }

  /// PUT /api/v1/memos/{id}/report-issue
  Future<void> reportPhysicalIssue(String id, String catatan) async {
    await _dio.put(
      '/api/v1/memos/$id/report-issue',
      data: {
        'targetStatus': 'KENDALA_BARANG',
        'keteranganLog': catatan,
      },
    );
  }

  /// PUT /api/v1/memos/{id}/force-complete
  Future<void> forceComplete(String id, String alasan) async {
    await _dio.put(
      '/api/v1/memos/$id/force-complete',
      data: {
        'targetStatus': 'SELESAI',
        'keteranganLog': alasan,
      },
    );
  }

  /// PUT /api/v1/memos/{id}/technician-finish
  Future<void> finishTechnicianProcess(String id) async {
    await _dio.put('/api/v1/memos/$id/technician-finish');
  }

  /// PUT /api/v1/memos/{id}/delivery-finish
  Future<void> finishDeliveryProcess(String id,
      {required String filePath,
      required String fileName,
      String? catatan}) async {
    debugPrint(
        '[ApiNewEndpoints] finishDeliveryProcess - id: $id, path: $filePath, name: $fileName');
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[ApiNewEndpoints] ERROR: File does not exist at $filePath');
      throw Exception('File tidak ditemukan di sistem: $filePath');
    }
    final size = await file.length();
    debugPrint('[ApiNewEndpoints] File size: ${size / 1024} KB');

    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: fileName),
      if (catatan != null) 'catatan': catatan,
    });
    try {
      await _dio.put('/api/v1/memos/$id/delivery-finish', data: formData);
      debugPrint('[ApiNewEndpoints] finishDeliveryProcess success');
    } catch (e) {
      debugPrint('[ApiNewEndpoints] finishDeliveryProcess ERROR: $e');
      if (e is DioException) {
        debugPrint('[ApiNewEndpoints] Response: ${e.response?.data}');
      }
      rethrow;
    }
  }

  /// PUT /api/v1/memos/{id}/photo-evidence
  /// Upload foto bukti (evidence) tanpa mengubah status memo
  Future<void> uploadEvidencePhoto(String id,
      {required String filePath, required String fileName}) async {
    debugPrint(
        '[ApiNewEndpoints] uploadEvidencePhoto - id: $id, path: $filePath, name: $fileName');
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[ApiNewEndpoints] ERROR: File does not exist at $filePath');
      throw Exception('File tidak ditemukan di sistem: $filePath');
    }
    final size = await file.length();
    debugPrint('[ApiNewEndpoints] File size: ${size / 1024} KB');

    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    try {
      await _dio.put('/api/v1/memos/$id/photo-evidence', data: formData);
      debugPrint('[ApiNewEndpoints] uploadEvidencePhoto success');
    } catch (e) {
      debugPrint('[ApiNewEndpoints] uploadEvidencePhoto ERROR: $e');
      if (e is DioException) {
        debugPrint('[ApiNewEndpoints] Response: ${e.response?.data}');
      }
      rethrow;
    }
  }

  /// PUT /api/v1/memos/{id}/status

  Future<void> updateStatus(
      String id, String targetStatus, String keterangan) async {
    await _dio.put(
      '/api/v1/memos/$id/status',
      data: {
        'targetStatus': targetStatus,
        'keteranganLog': keterangan,
      },
    );
  }

  /// PUT /api/v1/memos/{id}/resi
  Future<void> updateResi(String id, String resi) async {
    await _dio.put(
      '/api/v1/memos/$id/resi',
      data: {'resi': resi},
    );
  }

  /// PUT /api/v1/memos/{id}/complete
  Future<void> completeMemo(String id) async {
    await _dio.put('/api/v1/memos/$id/complete');
  }

  /// DELETE /api/v1/memos/{id}
  Future<void> deleteMemo(String id) async {
    await _dio.delete('/api/v1/memos/$id');
  }

  /// PUT /api/v1/memos/{id}/retry-auto-jl
  Future<void> retryAutoMatchJl(String id) async {
    await _dio.put('/api/v1/memos/$id/retry-auto-jl');
  }

  /// PUT /api/v1/memos/retry-auto-jl-bulk
  Future<String?> retryAutoMatchJlBulk() async {
    final response = await _dio
        .put<Map<String, dynamic>>('/api/v1/memos/retry-auto-jl-bulk');
    return response.data?['message'] as String?;
  }

  /// GET /api/v1/customers/options?search=
  Future<List<CustomerOption>> searchCustomers(String search) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/customers/options',
      queryParameters: {'search': search},
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) =>
                CustomerOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
  }

  /// POST /api/v1/memos/{id}/konfirmasi-kirim
  Future<void> konfirmasiKirim(String memoId, List<Map<String, dynamic>> items,
      {required XFile photo}) async {
    final formData = FormData.fromMap({
      'itemsJson': jsonEncode({'items': items}),
      'photo': await MultipartFile.fromFile(photo.path, filename: photo.name),
    });

    await _dio.post(
      '/api/v1/memos/$memoId/konfirmasi-kirim',
      data: formData,
    );
  }

  /// GET /api/v1/penjadwalan
  /// Returns list tugas (Memo-based or Manual) based on tipe & status.
  Future<List<PenjadwalanResponse>> getListTugas({
    String tipe = 'SEMUA',
    String status = 'SEMUA',
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (tipe != 'SEMUA') queryParams['tipe'] = tipe;
    if (status != 'SEMUA') queryParams['status'] = status;

    final response = await _dio.get<Object>(
      '/api/v1/penjadwalan',
      queryParameters: queryParams,
    );
    final data = response.data;
    if (data == null) return [];
    if (data is Map && data['data'] is List) {
      final list = data['data'] as List;
      return list
          .map((e) => e is Map
              ? PenjadwalanResponse.fromJson(Map<String, dynamic>.from(e))
              : null)
          .whereType<PenjadwalanResponse>()
          .toList();
    }
    return [];
  }

  /// GET /api/v1/penjadwalan/{id}
  Future<PenjadwalanResponse?> getTugasDetail(String id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/v1/penjadwalan/$id');
    final data = response.data?['data'];
    if (data == null) return null;
    return PenjadwalanResponse.fromJson(Map<String, dynamic>.from(data));
  }

  /// PUT /api/v1/penjadwalan/{id}
  Future<void> updateManualTask(String id, Map<String, dynamic> request) async {
    await _dio.put(
      '/api/v1/penjadwalan/$id',
      data: request,
    );
  }

  /// PUT /api/v1/penjadwalan/{id}/selesai
  Future<void> startManualTask(String id) async {
    await _dio.put('/api/v1/penjadwalan/$id/mulai');
  }

  Future<void> finishManualTask(String id,
      {required String filePath,
      required String fileName,
      required String namaPenerima,
      String? catatanOperasional}) async {
    debugPrint('[ApiNewEndpoints] finishManualTask - id: $id, path: $filePath');
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[ApiNewEndpoints] ERROR: File does not exist at $filePath');
      throw Exception('File tidak ditemukan di sistem: $filePath');
    }

    final formData = FormData.fromMap({
      'nama_penerima': namaPenerima,
      'catatan_operasional': catatanOperasional ?? '',
      'photo': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    try {
      await _dio.put('/api/v1/penjadwalan/$id/selesai', data: formData);
      debugPrint('[ApiNewEndpoints] finishManualTask success');
    } catch (e) {
      debugPrint('[ApiNewEndpoints] finishManualTask ERROR: $e');
      rethrow;
    }
  }

  // --- REQUEST DELIVERY ENDPOINTS ---

  Future<List<RequestDelivery>> getListRequestDelivery({String? status}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/request-delivery',
      queryParameters: {if (status != null) 'status': status},
    );
    final list = response.data?['data'] as List?;
    return list
            ?.map((e) => RequestDelivery.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
  }

  Future<void> createBulkPenjadwalan({
    List<String>? memoIds,
    List<int>? requestDeliveryIds,
    required int personelId,
    required DateTime tanggalRencana,
  }) async {
    await _dio.post(
      '/api/v1/penjadwalan/bulk',
      data: {
        if (memoIds != null) 'memoIds': memoIds,
        if (requestDeliveryIds != null)
          'requestDeliveryIds': requestDeliveryIds,
        'personelId': personelId,
        'tanggalRencana': tanggalRencana.toIso8601String(),
      },
    );
  }

  Future<void> createRequestDelivery(Map<String, dynamic> request) async {
    await _dio.post('/api/v1/request-delivery', data: request);
  }

  Future<RequestDelivery?> getRequestDeliveryDetail(int id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/v1/request-delivery/$id');
    final data = response.data?['data'];
    if (data == null) return null;
    return RequestDelivery.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> createBatchDropOff({
    List<String>? memoIds,
    List<int>? requestDeliveryIds,
    required int personelId,
    required DateTime tanggalRencana,
    required String expeditionName,
  }) async {
    await _dio.post(
      '/api/v1/penjadwalan/batch-drop-off',
      data: {
        if (memoIds != null) 'memoIds': memoIds,
        if (requestDeliveryIds != null)
          'requestDeliveryIds': requestDeliveryIds,
        'personelId': personelId,
        'tanggalRencana': tanggalRencana.toIso8601String(),
        'expeditionName': expeditionName,
      },
    );
  }

  /// PUT /api/v1/penjadwalan/bulk/mulai
  Future<void> bulkMulaiTugas(List<int> ids) async {
    await _dio.put('/api/v1/penjadwalan/bulk/mulai', data: ids);
  }

  /// PUT /api/v1/penjadwalan/bulk/selesai
  Future<void> bulkSelesaikanTugas(
    List<int> ids, {
    required String filePath,
    required String fileName,
    required String namaPenerima,
    String? catatanOperasional,
  }) async {
    debugPrint(
        '[ApiNewEndpoints] bulkSelesaikanTugas - ids: $ids, path: $filePath');
    final formData = FormData.fromMap({
      'ids': ids,
      'photo': await MultipartFile.fromFile(filePath, filename: fileName),
      'nama_penerima': namaPenerima,
      if (catatanOperasional != null) 'catatan_operasional': catatanOperasional,
    });
    try {
      await _dio.put('/api/v1/penjadwalan/bulk/selesai', data: formData);
      debugPrint('[ApiNewEndpoints] bulkSelesaikanTugas success');
    } catch (e) {
      debugPrint('[ApiNewEndpoints] bulkSelesaikanTugas ERROR: $e');
      rethrow;
    }
  }

  /// GET /api/v1/stock & /api/v1/tkdn (Combined Search for Suggestions)
  Future<List<ItemSuggestion>> searchItemSuggestions(String search) async {
    final List<ItemSuggestion> results = [];
    final searchLower = search.toLowerCase().trim();

    // 1. Search in Stock
    try {
      final stockRes = await _dio.get<Map<String, dynamic>>(
        '/api/v1/stock',
        queryParameters: {'search': searchLower, 'size': 15},
      );
      final stockData = stockRes.data?['data'];
      if (stockData is List) {
        for (var item in stockData) {
          final itemName = item['itemName']?.toString() ?? '';
          if (itemName.isNotEmpty) {
            results.add(ItemSuggestion(
              itemName: itemName,
              itemCode: item['itemCode']?.toString(),
              // Mengambil harga dari final_pricelist (tabel pricelist)
              price: num.tryParse(item['final_pricelist']?.toString() ??
                  item['finalPricelist']?.toString() ??
                  ''),
              source: 'STOK',
            ));
          }
        }
      } else if (stockData is Map && stockData['content'] is List) {
        for (var item in stockData['content']) {
          final itemName = item['itemName']?.toString() ?? '';
          if (itemName.isNotEmpty) {
            results.add(ItemSuggestion(
              itemName: itemName,
              itemCode: item['itemCode']?.toString(),
              price: num.tryParse(item['final_pricelist']?.toString() ??
                  item['finalPricelist']?.toString() ??
                  ''),
              source: 'STOK',
            ));
          }
        }
      }
    } catch (_) {}

    // 2. Search in TKDN
    try {
      final tkdnRes = await _dio.get<Map<String, dynamic>>(
        '/api/v1/tkdn',
        queryParameters: {'search': searchLower, 'size': 15, 'isTkdn': true},
      );
      final tkdnData = tkdnRes.data?['data'];
      if (tkdnData is List) {
        for (var item in tkdnData) {
          final itemName =
              item['nama']?.toString() ?? item['namaBarang']?.toString() ?? '';
          if (itemName.isNotEmpty) {
            results.add(ItemSuggestion(
              itemName: itemName,
              itemCode: item['itemCode']?.toString(),
              price: null, // TKDN tidak perlu harga
              source: 'TKDN',
            ));
          }
        }
      } else if (tkdnData is Map && tkdnData['content'] is List) {
        for (var item in tkdnData['content']) {
          final itemName =
              item['nama']?.toString() ?? item['namaBarang']?.toString() ?? '';
          if (itemName.isNotEmpty) {
            results.add(ItemSuggestion(
              itemName: itemName,
              itemCode: item['itemCode']?.toString(),
              price: null, // TKDN tidak perlu harga
              source: 'TKDN',
            ));
          }
        }
      }
    } catch (_) {}

    // Remove duplicates by name (case-insensitive) and prioritize STOK
    final seen = <String>{};
    final uniqueResults = <ItemSuggestion>[];

    // Process STOK first
    for (var res in results.where((r) => r.source == 'STOK')) {
      if (seen.add(res.itemName.toLowerCase())) {
        uniqueResults.add(res);
      }
    }
    // Then TKDN
    for (var res in results.where((r) => r.source == 'TKDN')) {
      if (seen.add(res.itemName.toLowerCase())) {
        uniqueResults.add(res);
      }
    }

    return uniqueResults;
  }

  // --- ANNOUNCEMENTS ---
  Future<List<Announcement>> getAnnouncements() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/v1/announcements');
      final list = response.data?['data'] as List?;
      return list
              ?.map((e) =>
                  Announcement.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [];
    } catch (_) {
      return [];
    }
  }

  Future<void> createAnnouncement(Map<String, dynamic> data) async {
    await _dio.post('/api/v1/announcements', data: data);
  }

  Future<void> updateAnnouncement(int id, Map<String, dynamic> data) async {
    await _dio.put('/api/v1/announcements/$id', data: data);
  }

  Future<void> deleteAnnouncement(int id) async {
    await _dio.delete('/api/v1/announcements/$id');
  }

  Future<Map<String, dynamic>> getShbj({
    int page = 0,
    int size = 50,
    String sortBy = 'id',
    String direction = 'asc',
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/shbj',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> getIjinImport({
    int page = 0,
    int size = 50,
    String sortBy = 'no',
    String direction = 'asc',
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/ijin-import',
      queryParameters: queryParams,
    );
    return response.data ?? {};
  }

  // --- PRINTER ENDPOINTS ---

  /// GET /api/v1/printer/available
  /// Returns daftar printer yang terdeteksi oleh server (String).
  Future<String> getAvailablePrinters() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/v1/printer/available');
    return response.data?['data']?.toString() ?? '';
  }

  /// POST /api/v1/printer/print
  /// Mengirim byte PDF ke server untuk dicetak langsung.
  Future<void> printDocument({
    required List<int> pdfBytes,
    String? printerName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(pdfBytes, filename: 'document.pdf'),
      if (printerName != null) 'printerName': printerName,
    });
    await _dio.post(
      '/api/v1/printer/print',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
  }
  /// GET /api/v1/activity-logs/active-today
  Future<ActiveUsersToday?> getActiveUsersToday() async {
    try {
      final response = await _dio.get<Object>('/api/v1/activity-logs/active-today');
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return ActiveUsersToday.fromJson(Map<String, dynamic>.from(data['data']));
      }
    } catch (e) {
      debugPrint('[ApiNewEndpoints] getActiveUsersToday ERROR: $e');
    }
    return null;
  }

  /// GET /api/v1/activity-logs/daily-stats?days=30
  Future<List<DailyActiveUserStat>> getDailyActiveUserStats({int days = 30}) async {    try {
      final response = await _dio.get<Object>(
        '/api/v1/activity-logs/daily-stats',
        queryParameters: {'days': days},
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => DailyActiveUserStat.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('[ApiNewEndpoints] getDailyActiveUserStats ERROR: $e');
    }
    return [];
  }

  // ─── STOK PER BADAN ─────────────────────────────────────────

  /// GET /api/stok (dengan fallback ke /api/v1/stocks/badan dan aggregasi purchases & sales).
  /// Data di-cache 5 menit di memori agar fetch berikutnya (saat buka detail) langsung dari cache.
  Future<List<StokBadanGroup>> getStokPerBadan({bool forceRefresh = false}) async {
    // Cache hit
    if (!forceRefresh && _stokBadanCacheValid) {
      debugPrint('[StokBadan] Cache hit, skip network fetch.');
      return _stokPerBadanCache!;
    }

    List<StokBadanGroup>? result;

    // 1. Coba endpoint utama /api/stok
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/stok');
      final data = response.data;
      if (data != null && data['data'] is List) {
        final groups = (data['data'] as List)
            .map((e) => StokBadanGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        final activeGroups =
            groups.where((g) => g.totalQty > 0 || g.items.isNotEmpty).length;
        if (activeGroups > 0) result = groups;
      }
    } catch (e) {
      debugPrint('[ApiNewEndpoints] getStokPerBadan /api/stok error: $e');
    }

    // 2. Fallback ke /api/v1/stocks/badan
    if (result == null) {
      try {
        final response =
            await _dio.get<Map<String, dynamic>>('/api/v1/stocks/badan');
        final data = response.data;
        if (data != null && data['data'] is List) {
          final groups = (data['data'] as List)
              .map((e) => StokBadanGroup.fromJson(e as Map<String, dynamic>))
              .toList();
          final activeGroups =
              groups.where((g) => g.totalQty > 0 || g.items.isNotEmpty).length;
          if (activeGroups > 1) result = groups;
        }
      } catch (e) {
        debugPrint(
            '[ApiNewEndpoints] getStokPerBadan /api/v1/stocks/badan error: $e');
      }
    }

    // 3. Fallback berat: kalkulasi dari purchases & sales
    result ??= await _buildStokPerBadanFromTransactions();

    // Simpan ke cache
    _stokPerBadanCache = result;
    _stokPerBadanCacheTime = DateTime.now();
    return result;
  }

  /// Mengambil rincian stok per badan untuk item tertentu (itemCode / itemName).
  /// Ringan: hanya memanggil endpoint per-item atau menggunakan cache dari getStokPerBadan().
  /// TIDAK akan memicu _buildStokPerBadanFromTransactions() saat dipanggil dari detail sheet.
  Future<Map<String, int>> getStokPerBadanForItem(String itemCode,
      {String? itemName}) async {
    // 1. Coba endpoint ringan per item
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/v1/stocks/$itemCode/badan');
      if (response.data != null &&
          response.data!['status'] == 200 &&
          response.data!['data'] is Map) {
        final dataMap = response.data!['data'] as Map<String, dynamic>;
        final map = dataMap.map((k, v) => MapEntry(k, (v as num).toInt()));
        final activeBadans = map.values.where((qty) => qty > 0).length;
        if (activeBadans > 1) return map;
        // Jika hanya 1 badan aktif (kemungkinan data server belum ter-split), lanjut ke cache
      }
    } catch (e) {
      debugPrint(
          '[ApiNewEndpoints] getStokPerBadanForItem endpoint error: $e');
    }

    // 2. Gunakan cache /api/stok jika tersedia; jika belum, fetch tapi TIDAK fallback ke transaksi
    try {
      List<StokBadanGroup> groups;
      if (_stokBadanCacheValid) {
        groups = _stokPerBadanCache!;
      } else {
        // Hanya fetch dari server — jika gagal atau kosong, kembalikan kosong (jangan ke transaksi)
        final response = await _dio.get<Map<String, dynamic>>('/api/stok');
        final data = response.data;
        if (data == null || data['data'] is! List) return {};
        groups = (data['data'] as List)
            .map((e) => StokBadanGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        // Simpan ke cache juga
        _stokPerBadanCache = groups;
        _stokPerBadanCacheTime = DateTime.now();
      }

      final Map<String, int> result = {};
      final itmLower = itemCode.toLowerCase().trim();
      final nameLower = itemName?.toLowerCase().trim() ?? '';

      for (final group in groups) {
        int qty = 0;
        for (final item in group.items) {
          final codeMatch = item.itemCode.toLowerCase().trim() == itmLower;
          final nameMatch = nameLower.isNotEmpty &&
              item.itemName != null &&
              item.itemName!.toLowerCase().trim() == nameLower;
          if (codeMatch || nameMatch) qty += item.stokQty;
        }
        if (qty > 0) result[group.badan] = qty;
      }

      return result;
    } catch (e) {
      debugPrint('[ApiNewEndpoints] getStokPerBadanForItem cache/fallback error: $e');
    }

    return {};
  }

  static const List<String> _knownBadans = [
    'SGI',
    'SSS',
    'GBH',
    'MGC',
    'PDB',
    'ANC'
  ];

  /// Mendeteksi kode badan dari teks menggunakan regex boundary (setara PostgreSQL \mBADAN\M).
  /// Prioritas: SGI > SSS > GBH > MGC > PDB > ANC
  String? _detectBadanBadge(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final upper = text.toUpperCase().trim();

    for (final b in _knownBadans) {
      if (upper == b) return b;
    }

    for (final b in _knownBadans) {
      final regex = RegExp('(^|[^A-Z0-9])$b([^A-Z0-9]|\$)');
      if (regex.hasMatch(upper)) return b;
    }

    return null;
  }

  /// Mendeteksi kode badan dari transaksi Pembelian (purchases.par_name)
  String _detectBadanFromPur(Map<String, dynamic> pur) {
    // a. Dari purchases.par_name (format: "SGI-PT ...", "MGC-...", "GBH ...")
    final parName = pur['parName']?.toString() ?? pur['par_name']?.toString();
    final badgeFromPar = _detectBadanBadge(parName);
    if (badgeFromPar != null) return badgeFromPar;

    // Tambahan pendukung jika par_name tidak ada badge: cek dep_code, doc_no, badanUsaha
    final explicit = _detectBadanBadge(
      pur['badan']?.toString() ??
          pur['badanUsaha']?.toString() ??
          pur['badan_usaha']?.toString() ??
          pur['depCode']?.toString() ??
          pur['dep_code']?.toString() ??
          pur['docNoP']?.toString() ??
          pur['doc_nop']?.toString(),
    );
    if (explicit != null) return explicit;

    return 'ANC';
  }

  /// Mendeteksi kode badan dari transaksi Penjualan (sales.code)
  String _detectBadanFromSales(Map<String, dynamic> sls) {
    // b. Dari sales.code (kolom code mengandung badge, misal "YGY-SGI", "XXX-MGC")
    final code = sls['code']?.toString();
    final badgeFromCode = _detectBadanBadge(code);
    if (badgeFromCode != null) return badgeFromCode;

    // Tambahan pendukung jika code tidak ada badge: cek dep_code, doc_no, badanUsaha
    final explicit = _detectBadanBadge(
      sls['badan']?.toString() ??
          sls['badanUsaha']?.toString() ??
          sls['badan_usaha']?.toString() ??
          sls['depCode']?.toString() ??
          sls['dep_code']?.toString() ??
          sls['docNo']?.toString() ??
          sls['doc_no']?.toString() ??
          sls['empCode']?.toString(),
    );
    if (explicit != null) return explicit;

    return 'ANC';
  }

  /// Fallback: menghitung stok per badan dari data purchases & sales
  /// dengan algoritma SQL Aggregation & TypeScript Redistribution Service.
  Future<List<StokBadanGroup>> _buildStokPerBadanFromTransactions() async {
    const maxFetch = 10000;

    // --- A. Fetch semua purchases ---
    debugPrint('[StokBadan] Fetching purchases...');
    final allPurchases = await _fetchAllPages('/api/v1/purchases', maxFetch);
    debugPrint('[StokBadan] Purchases fetched: ${allPurchases.length}');

    // --- B. Fetch semua sales ---
    debugPrint('[StokBadan] Fetching sales...');
    final allSales = await _fetchAllPages('/api/v1/sales', maxFetch);
    debugPrint('[StokBadan] Sales fetched: ${allSales.length}');

    // --- C. pur_agg: GROUP BY badan, dep_code, item_code, item_name ---
    final Map<String, _StokLine> aggMap = {};
    for (final pur in allPurchases) {
      final badan = _detectBadanFromPur(pur);
      final depCode = (pur['depCode'] ?? pur['dep_code'])?.toString().trim() ?? '';
      final itemCode = (pur['itemCode'] ?? pur['item_code'])?.toString().trim() ?? '';
      final itemName = (pur['itemName'] ?? pur['item_name'])?.toString().trim() ?? '';
      final qty = int.tryParse(pur['qty']?.toString() ?? '0') ?? 0;
      if (itemCode.isEmpty && itemName.isEmpty) continue;

      final key = '$badan|$depCode|${itemCode.isNotEmpty ? itemCode : itemName}';
      aggMap.putIfAbsent(
        key,
        () => _StokLine(
          badan: badan,
          depCode: depCode,
          itemCode: itemCode.isNotEmpty ? itemCode : itemName,
          itemName: itemName.isNotEmpty ? itemName : itemCode,
        ),
      );
      aggMap[key]!.stokQty += qty;
      aggMap[key]!.lineCount += 1;
    }

    // --- D. sls_agg: Kurangi sales per (badan, dep_code, item_code) ---
    for (final sls in allSales) {
      final badan = _detectBadanFromSales(sls);
      final depCode = (sls['depCode'] ?? sls['dep_code'])?.toString().trim() ?? '';
      final itemCode = (sls['itemCode'] ?? sls['item_code'] ?? sls['ite_code'] ?? sls['code'])?.toString().trim() ?? '';
      final itemName = (sls['itemName'] ?? sls['item_name'])?.toString().trim() ?? '';
      final qty = int.tryParse(sls['qty']?.toString() ?? '0') ?? 0;
      if (itemCode.isEmpty && itemName.isEmpty) continue;

      final matchKey = '$badan|$depCode|${itemCode.isNotEmpty ? itemCode : itemName}';
      if (aggMap.containsKey(matchKey)) {
        aggMap[matchKey]!.stokQty -= qty;
      } else {
        // Cari matching key berdasarkan itemCode atau itemName di badan yang sama
        String? foundKey;
        for (final k in aggMap.keys) {
          final line = aggMap[k]!;
          if (line.badan == badan &&
              ((itemCode.isNotEmpty && line.itemCode.toLowerCase() == itemCode.toLowerCase()) ||
                  (itemName.isNotEmpty && line.itemName.toLowerCase() == itemName.toLowerCase()))) {
            foundKey = k;
            break;
          }
        }

        if (foundKey != null) {
          aggMap[foundKey]!.stokQty -= qty;
        } else {
          aggMap.putIfAbsent(
            matchKey,
            () => _StokLine(
              badan: badan,
              depCode: depCode,
              itemCode: itemCode.isNotEmpty ? itemCode : itemName,
              itemName: itemName.isNotEmpty ? itemName : itemCode,
            ),
          );
          aggMap[matchKey]!.stokQty -= qty;
          aggMap[matchKey]!.lineCount += 1;
        }
      }
    }

    // --- E. Redistribusi Stok (TypeScript Service Algorithm) ---
    // for setiap item_code:
    //   1. Hitung total deficit badan non-ANC (stok_qty < 0)
    //   2. Jika ada deficit:
    //      a. Ambil stok ANC positif untuk item_code tersebut, urut dari terbesar
    //      b. Kurangi stok ANC sampai deficit habis
    //      c. Set stok non-ANC yang minus menjadi 0
    final allItemCodes = aggMap.values.map((l) => l.itemCode).toSet();
    for (final itmCode in allItemCodes) {
      final nonAncForCode = aggMap.values
          .where((l) => l.itemCode.toLowerCase() == itmCode.toLowerCase() && l.badan != 'ANC' && l.stokQty < 0)
          .toList();

      var totalDeficit = nonAncForCode.fold<int>(0, (sum, l) => sum + (-l.stokQty));
      if (totalDeficit > 0) {
        final ancForCode = aggMap.values
            .where((l) => l.itemCode.toLowerCase() == itmCode.toLowerCase() && l.badan == 'ANC' && l.stokQty > 0)
            .toList()
          ..sort((a, b) => b.stokQty.compareTo(a.stokQty));

        for (final ancLine in ancForCode) {
          if (totalDeficit <= 0) break;
          final take = totalDeficit < ancLine.stokQty ? totalDeficit : ancLine.stokQty;
          ancLine.stokQty -= take;
          totalDeficit -= take;
        }

        for (final nonAncLine in nonAncForCode) {
          nonAncLine.stokQty = 0;
        }
      }
    }

    // --- F. Filter stok_qty != 0 & konversi ke list ---
    final lines = aggMap.values
        .where((l) => l.stokQty > 0)
        .map((l) => StokBadanItem(
              badan: l.badan,
              depCode: l.depCode,
              itemCode: l.itemCode,
              itemName: l.itemName,
              stokQty: l.stokQty,
              lineCount: l.lineCount,
            ))
        .toList();
    debugPrint('[StokBadan] Total lines dengan stok > 0: ${lines.length}');

    // --- G. Kelompokkan per badan (6 badan selalu muncul) ---
    final Map<String, List<StokBadanItem>> grouped = {};
    for (final badan in ['ANC', 'PDB', 'MGC', 'GBH', 'SSS', 'SGI']) {
      grouped[badan] = [];
    }
    for (final line in lines) {
      grouped.putIfAbsent(line.badan, () => []).add(line);
    }

    return grouped.entries.map((entry) {
      final items = entry.value
        ..sort((a, b) => b.stokQty.compareTo(a.stokQty));
      final totalQty = items.fold<int>(0, (sum, i) => sum + i.stokQty);
      return StokBadanGroup(
        badan: entry.key,
        totalItems: items.length,
        totalQty: totalQty,
        items: items,
      );
    }).toList()
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));
  }

  /// Helper: fetch semua halaman dari endpoint paginated, return list of raw JSON maps.
  Future<List<Map<String, dynamic>>> _fetchAllPages(
      String endpoint, int maxFetch) async {
    final allData = <Map<String, dynamic>>[];
    int page = 0;
    while (allData.length < maxFetch) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          endpoint,
          queryParameters: {
            'page': page, 'size': 5000, 'sortBy': 'id', 'direction': 'asc',
          },
        );
        final data = response.data;
        if (data == null) break;
        final dataPayload = data['data'];
        final pagingPayload = data['paging'] as Map?;
        List<dynamic>? items;
        if (dataPayload is List) {
          items = dataPayload;
        } else if (dataPayload is Map) {
          items = dataPayload['content'] as List?;
        }
        if (items == null || items.isEmpty) break;
        for (final item in items) {
          if (item is Map<String, dynamic>) allData.add(item);
        }
        final totalPages = pagingPayload?['totalPage'] ??
            pagingPayload?['totalPages'] ?? 0;
        final totalPagesInt = totalPages is int
            ? totalPages : int.tryParse(totalPages.toString()) ?? 0;
        page++;
        if (page >= totalPagesInt) break;
      } catch (e) {
        debugPrint('[StokBadan] Fetch error $endpoint page $page: $e');
        break;
      }
    }
    return allData;
  }

  // ─── LAPORAN MARKETING (OLD DATA) ───────────────────────────

  /// GET /api/v1/old-data/reports/marketing/overview
  Future<Map<String, dynamic>> getOldMarketingOverview({
    required String period,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? empCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/old-data/reports/marketing/overview',
      queryParameters: {
        'period': period,
        if (date != null) 'date': date.toIso8601String().split('T').first,
        if (startDate != null) 'startDate': startDate.toIso8601String().split('T').first,
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
        if (empCode != null && empCode.isNotEmpty) 'empCode': empCode,
      },
    );
    final body = response.data;
    if (body == null) return const {};
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// GET /api/v1/old-data/reports/marketing/notas
  Future<Map<String, dynamic>> getOldMarketingNotas({
    required String period,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? empCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/old-data/reports/marketing/notas',
      queryParameters: {
        'period': period,
        if (date != null) 'date': date.toIso8601String().split('T').first,
        if (startDate != null) 'startDate': startDate.toIso8601String().split('T').first,
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
        if (empCode != null && empCode.isNotEmpty) 'empCode': empCode,
      },
    );
    final body = response.data;
    if (body == null) return const {};
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// GET /api/v1/old-data/reports/marketing/items
  Future<Map<String, dynamic>> getOldMarketingItems({
    required String period,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? empCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/old-data/reports/marketing/items',
      queryParameters: {
        'period': period,
        if (date != null) 'date': date.toIso8601String().split('T').first,
        if (startDate != null) 'startDate': startDate.toIso8601String().split('T').first,
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
        if (empCode != null && empCode.isNotEmpty) 'empCode': empCode,
      },
    );
    final body = response.data;
    if (body == null) return const {};
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// GET /api/v1/old-data/reports/marketing/timeline
  Future<Map<String, dynamic>> getOldMarketingTimeline({
    required String period,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? empCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/old-data/reports/marketing/timeline',
      queryParameters: {
        'period': period,
        if (date != null) 'date': date.toIso8601String().split('T').first,
        if (startDate != null) 'startDate': startDate.toIso8601String().split('T').first,
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
        if (empCode != null && empCode.isNotEmpty) 'empCode': empCode,
      },
    );
    final body = response.data;
    if (body == null) return const {};
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  // ─── DELIVERY SCAN QR ────────────────────────────────────────────

  /// POST /api/v1/delivery/scan
  /// Delivery scan QR Code => otomatis ditugaskan mengirim barang
  Future<DeliveryScanResponse?> deliveryScan(String qrCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/delivery/scan',
        data: {'qrCode': qrCode},
      );
      final data = response.data?['data'];
      if (data != null) {
        return DeliveryScanResponse.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('[ApiNewEndpoints] deliveryScan ERROR: $e');
      rethrow;
    }
    return null;
  }

  /// POST /api/v1/delivery/{penjadwalanId}/release
  /// Delivery melepas tugas pengiriman (unassign)
  Future<void> deliveryRelease(int penjadwalanId) async {
    await _dio.post('/api/v1/delivery/$penjadwalanId/release');
  }

  /// POST /api/v1/delivery/memo/{memoId}/release
  /// Delivery melepas tugas pengiriman berdasarkan ID Memo (unassign)
  Future<void> deliveryReleaseByMemoId(String memoId) async {
    await _dio.post('/api/v1/delivery/memo/$memoId/release');
  }

  // ─── AUTH HEARTBEAT ───────────────────────────────────────────────
  /// POST /api/v1/auth/heartbeat — kirim sinyal user masih aktif (online).
  Future<void> heartbeat() async {
    await _dio.post('/api/v1/auth/heartbeat');
  }

  // ─── PIUTANG ──────────────────────────────────────────────────────
  /// GET /api/v1/piutang — row-level sales (seperti list Penjualan) + tab PAID/UNPAID
  Future<PiutangListResult> getPiutang({
    required String tab,
    int page = 0,
    int size = 50,
    String sortBy = 'docDate',
    String direction = 'desc',
    DateTime? startDate,
    DateTime? endDate,
    List<String> empCodes = const [],
    List<String> categories = const [],
    String? search,
    String? searchColumn,
  }) async {
    final query = <String, dynamic>{
      'tab': tab,
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (startDate != null)
        'startDate': startDate.toIso8601String().split('T').first,
      if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
      if (empCodes.isNotEmpty) 'empCode': empCodes.join(','),
      if (categories.isNotEmpty) 'categories': categories,
      if (search != null && search.trim().isNotEmpty)
        'search': search.trim(),
      if (searchColumn != null && searchColumn.trim().isNotEmpty)
        'searchColumn': searchColumn.trim(),
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/piutang',
      queryParameters: query,
    );
    return PiutangListResult.fromJson(response.data);
  }

  /// GET /api/v1/piutang/export — export Excel (ADMIN/MANAGER only).
  Future<List<int>> exportPiutang({
    required String tab,
    DateTime? startDate,
    DateTime? endDate,
    List<String> empCodes = const [],
    List<String> categories = const [],
    String? search,
    String? searchColumn,
  }) async {
    final query = <String, dynamic>{
      'tab': tab,
      if (startDate != null)
        'startDate': startDate.toIso8601String().split('T').first,
      if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
      if (empCodes.isNotEmpty) 'empCode': empCodes.join(','),
      if (categories.isNotEmpty) 'categories': categories,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (searchColumn != null && searchColumn.trim().isNotEmpty)
        'searchColumn': searchColumn.trim(),
    };
    final response = await _dio.get<List<int>>(
      '/api/v1/piutang/export',
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// GET /api/v1/piutang/employee-codes
  Future<List<EmployeeOption>> getPiutangEmployeeCodes() async {
    final response =
        await _dio.get<Object>('/api/v1/piutang/employee-codes');
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => EmployeeOption.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// GET /api/v1/piutang/categories
  Future<List<String>> getPiutangCategories() async {
    final response = await _dio.get<Object>('/api/v1/piutang/categories');
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return [];
  }

  // ─── HUTANG ──────────────────────────────────────────────────────
  /// GET /api/v1/hutang — row-level purchase (seperti list Pembelian) + tab PAID/UNPAID
  Future<HutangListResult> getHutang({
    required String tab,
    int page = 0,
    int size = 50,
    String sortBy = 'docDate',
    String direction = 'desc',
    DateTime? startDate,
    DateTime? endDate,
    List<String> empCodes = const [],
    List<String> categories = const [],
    String? search,
    String? searchColumn,
  }) async {
    final query = <String, dynamic>{
      'tab': tab,
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'direction': direction,
      if (startDate != null)
        'startDate': startDate.toIso8601String().split('T').first,
      if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
      if (empCodes.isNotEmpty) 'empCode': empCodes.join(','),
      if (categories.isNotEmpty) 'categories': categories,
      if (search != null && search.trim().isNotEmpty)
        'search': search.trim(),
      if (searchColumn != null && searchColumn.trim().isNotEmpty)
        'searchColumn': searchColumn.trim(),
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/hutang',
      queryParameters: query,
    );
    return HutangListResult.fromJson(response.data);
  }

  /// GET /api/v1/hutang/export — export Excel (ADMIN/MANAGER only).
  Future<List<int>> exportHutang({
    required String tab,
    DateTime? startDate,
    DateTime? endDate,
    List<String> empCodes = const [],
    List<String> categories = const [],
    String? search,
    String? searchColumn,
  }) async {
    final query = <String, dynamic>{
      'tab': tab,
      if (startDate != null)
        'startDate': startDate.toIso8601String().split('T').first,
      if (endDate != null) 'endDate': endDate.toIso8601String().split('T').first,
      if (empCodes.isNotEmpty) 'empCode': empCodes.join(','),
      if (categories.isNotEmpty) 'categories': categories,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (searchColumn != null && searchColumn.trim().isNotEmpty)
        'searchColumn': searchColumn.trim(),
    };
    final response = await _dio.get<List<int>>(
      '/api/v1/hutang/export',
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// GET /api/v1/hutang/employee-codes
  Future<List<EmployeeOption>> getHutangEmployeeCodes() async {
    final response =
        await _dio.get<Object>('/api/v1/hutang/employee-codes');
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => EmployeeOption.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// GET /api/v1/hutang/categories
  Future<List<String>> getHutangCategories() async {
    final response = await _dio.get<Object>('/api/v1/hutang/categories');
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return [];
  }

  // ─── LOCATION TRACKING ────────────────────────────────────────────
  /// POST /api/v1/locations/track — kirim satu titik lokasi.
  Future<Map<String, dynamic>?> trackLocation({
    String? deliveryId,
    String? menuCode,
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? recordedAt,
    String? clientEventId,
  }) async {
    final body = <String, dynamic>{
      if (deliveryId != null && deliveryId.isNotEmpty) 'deliveryId': deliveryId,
      if (menuCode != null && menuCode.isNotEmpty) 'menuCode': menuCode,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (recordedAt != null) 'recordedAt': recordedAt.toIso8601String(),
      if (clientEventId != null && clientEventId.isNotEmpty)
        'clientEventId': clientEventId,
    };
    final response =
        await _dio.post<Map<String, dynamic>>('/api/v1/locations/track',
            data: body);
    final data = response.data?['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// POST /api/v1/locations/track/batch — kirim batch titik lokasi (offline queue).
  Future<void> trackLocationBatch(
      List<Map<String, dynamic>> points) async {
    if (points.isEmpty) return;
    await _dio.post('/api/v1/locations/track/batch', data: points);
  }

  /// GET /api/v1/locations/history?deliveryId=&page=&size=
  Future<List<LocationPoint>> getLocationHistory(
    String deliveryId, {
    int page = 0,
    int size = 100,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/locations/history',
      queryParameters: {'deliveryId': deliveryId, 'page': page, 'size': size},
    );
    final data = response.data?['data'];
    final content = data is Map ? data['content'] : null;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((e) => LocationPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

/// Hasil GET /api/v1/piutang — konten per-doc + metadata paging.
class PiutangListResult {
  final List<PiutangItem> content;
  final Object? totalGrandSum;
  final int totalPages;
  final int totalElements;

  PiutangListResult({
    required this.content,
    this.totalGrandSum,
    required this.totalPages,
    required this.totalElements,
  });

  factory PiutangListResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PiutangListResult(content: [], totalPages: 0, totalElements: 0);
    final data = json['data'];
    if (data is! Map) {
      return PiutangListResult(content: [], totalPages: 0, totalElements: 0);
    }
    final rawList = data['content'];
    final items = rawList is List
        ? rawList
            .whereType<Map>()
            .map((e) => PiutangItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <PiutangItem>[];
    final paging = json['paging'];
    int totalPages = 0;
    int totalElements = 0;
    if (paging is Map) {
      totalPages = int.tryParse(paging['totalPage']?.toString() ?? '0') ?? 0;
      totalElements = int.tryParse(paging['totalItem']?.toString() ?? '0') ?? 0;
    }
    return PiutangListResult(
      content: items,
      totalGrandSum: data['totalGrandSum'],
      totalPages: totalPages,
      totalElements: totalElements,
    );
  }
}

/// Satu baris piutang = satu baris data penjualan (row-level, seperti list Penjualan).
class PiutangItem {
  final String? docNo;
  final String? docDate;
  final String? code;
  final String? parName;
  final String? depCode;
  final String? depName;
  final String? itemName;
  final Object? qty;
  final Object? price;
  final Object? grandTotal;
  final Object? paidTotal;
  final String? statusBayar;
  final String? empCode;
  final String? empName;

  PiutangItem({
    this.docNo,
    this.docDate,
    this.code,
    this.parName,
    this.depCode,
    this.depName,
    this.itemName,
    this.qty,
    this.price,
    this.grandTotal,
    this.paidTotal,
    this.statusBayar,
    this.empCode,
    this.empName,
  });

  factory PiutangItem.fromJson(Map<String, dynamic> json) {
    return PiutangItem(
      docNo: json['docNo']?.toString(),
      docDate: json['docDate']?.toString(),
      code: json['code']?.toString(),
      parName: json['parName']?.toString(),
      depCode: json['depCode']?.toString(),
      depName: json['depName']?.toString(),
      itemName: json['itemName']?.toString(),
      qty: json['qty'],
      price: json['price'],
      grandTotal: json['grandTotal'],
      paidTotal: json['paidTotal'],
      statusBayar: json['statusBayar']?.toString(),
      empCode: json['empCode']?.toString(),
      empName: json['empName']?.toString(),
    );
  }
}

/// Hasil GET /api/v1/hutang — konten row-level purchase + metadata paging.
class HutangListResult {
  final List<HutangItem> content;
  final Object? totalGrandSum;
  final int totalPages;
  final int totalElements;

  HutangListResult({
    required this.content,
    this.totalGrandSum,
    required this.totalPages,
    required this.totalElements,
  });

  factory HutangListResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return HutangListResult(content: [], totalPages: 0, totalElements: 0);
    }
    final data = json['data'];
    if (data is! Map) {
      return HutangListResult(content: [], totalPages: 0, totalElements: 0);
    }
    final rawList = data['content'];
    final items = rawList is List
        ? rawList
            .whereType<Map>()
            .map((e) => HutangItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <HutangItem>[];
    final paging = json['paging'];
    int totalPages = 0;
    int totalElements = 0;
    if (paging is Map) {
      totalPages = int.tryParse(paging['totalPage']?.toString() ?? '0') ?? 0;
      totalElements = int.tryParse(paging['totalItem']?.toString() ?? '0') ?? 0;
    }
    return HutangListResult(
      content: items,
      totalGrandSum: data['totalGrandSum'],
      totalPages: totalPages,
      totalElements: totalElements,
    );
  }
}

/// Satu baris hutang = satu baris data pembelian (row-level, seperti list Pembelian).
class HutangItem {
  final String? docNoP;
  final String? docDate;
  final String? parName;
  final String? depCode;
  final String? depName;
  final String? itemCode;
  final String? itemName;
  final Object? qty;
  final Object? price;
  final Object? grandTotal;
  final Object? paidTotal;
  final String? statusBayar;
  final String? empCode;
  final String? empName;

  HutangItem({
    this.docNoP,
    this.docDate,
    this.parName,
    this.depCode,
    this.depName,
    this.itemCode,
    this.itemName,
    this.qty,
    this.price,
    this.grandTotal,
    this.paidTotal,
    this.statusBayar,
    this.empCode,
    this.empName,
  });

  factory HutangItem.fromJson(Map<String, dynamic> json) {
    return HutangItem(
      docNoP: json['docNoP']?.toString(),
      docDate: json['docDate']?.toString(),
      parName: json['parName']?.toString(),
      depCode: json['depCode']?.toString(),
      depName: json['depName']?.toString(),
      itemCode: json['itemCode']?.toString(),
      itemName: json['itemName']?.toString(),
      qty: json['qty'],
      price: json['price'],
      grandTotal: json['grandTotal'],
      paidTotal: json['paidTotal'],
      statusBayar: json['statusBayar']?.toString(),
      empCode: json['empCode']?.toString(),
      empName: json['empName']?.toString(),
    );
  }
}

/// Satu titik lokasi dari riwayat /api/v1/locations/history.
class LocationPoint {
  final int? id;
  final int? userId;
  final String? username;
  final String? deliveryId;
  final String? menuCode;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? recordedAt;
  final DateTime? receivedAt;

  LocationPoint({
    this.id,
    this.userId,
    this.username,
    this.deliveryId,
    this.menuCode,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.recordedAt,
    this.receivedAt,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      id: int.tryParse(json['id']?.toString() ?? ''),
      userId: int.tryParse(json['userId']?.toString() ?? ''),
      username: json['username']?.toString(),
      deliveryId: json['deliveryId']?.toString(),
      menuCode: json['menuCode']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      accuracy: double.tryParse(json['accuracy']?.toString() ?? ''),
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'].toString())
          : null,
      receivedAt: json['receivedAt'] != null
          ? DateTime.tryParse(json['receivedAt'].toString())
          : null,
    );
  }
}

class ItemSuggestion {
  final String itemName;
  final String? itemCode;
  final num? price;
  final String source;

  ItemSuggestion({
    required this.itemName,
    this.itemCode,
    this.price,
    required this.source,
  });
}

/// Model Customer Option (id + namaPelanggan + noHp)
class CustomerOption {
  final int? id;
  final String? namaPelanggan;
  final String? noHp;
  final String? source;
  final String? kodePartner;
  final String? kodeMarketing;
  final String? namaMarketing;
  final double? limitPiutang;
  final int? terminPiutang;
  final double? limitHutang;
  final int? terminHutang;
  final String? npwp;
  final String? alamat;

  CustomerOption({
    this.id,
    this.namaPelanggan,
    this.noHp,
    this.source,
    this.kodePartner,
    this.kodeMarketing,
    this.namaMarketing,
    this.limitPiutang,
    this.terminPiutang,
    this.limitHutang,
    this.terminHutang,
    this.npwp,
    this.alamat,
  });

  factory CustomerOption.fromJson(Map<String, dynamic> json) {
    return CustomerOption(
      id: int.tryParse(json['id']?.toString() ?? ''),
      namaPelanggan: json['namaPelanggan']?.toString(),
      noHp: json['noHp']?.toString(),
      source: json['source']?.toString(),
      kodePartner: json['kodePartner']?.toString(),
      kodeMarketing: json['kodeMarketing']?.toString(),
      namaMarketing: json['namaMarketing']?.toString(),
      limitPiutang: double.tryParse(json['limitPiutang']?.toString() ?? ''),
      terminPiutang: int.tryParse(json['terminPiutang']?.toString() ?? ''),
      limitHutang: double.tryParse(json['limitHutang']?.toString() ?? ''),
      terminHutang: int.tryParse(json['terminHutang']?.toString() ?? ''),
      npwp: json['npwp']?.toString(),
      alamat: json['alamat']?.toString(),
    );
  }
}

/// Model Activity Log
class ActivityLog {
  final int id;
  final String? username;
  final String? action;
  final String? details;
  final String? ipAddress;
  final DateTime? timestamp;

  ActivityLog({
    required this.id,
    this.username,
    this.action,
    this.details,
    this.ipAddress,
    this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString(),
      action: json['action']?.toString(),
      details: json['details']?.toString(),
      ipAddress: json['ipAddress']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : null,
    );
  }
}

/// Hasil GET /api/v1/auth/me (nama, username, role, noHp).
class AuthMeResult {
  AuthMeResult({
    this.id,
    this.nama,
    this.username,
    this.role,
    this.employeeCode,
    this.noHp,
    this.permissions = const [],
  });

  final int? id;
  final String? nama;
  final String? username;
  final String? role;
  final String? employeeCode;
  final String? noHp;
  final List<String> permissions;

  factory AuthMeResult.fromJson(Map<String, dynamic> json) {
    debugPrint('[ApiNewEndpoints] AuthMeResult.fromJson: $json');

    final rawPerms = json['permissions'];
    List<String> perms = [];
    if (rawPerms is List) {
      perms = rawPerms.map((e) => e.toString()).toList();
    } else if (json['authorities'] is List) {
      perms = (json['authorities'] as List)
          .map((e) => e.toString().replaceAll('ROLE_', ''))
          .toList();
    }
    final roleStr = json['role']?.toString().trim();
    if (perms.isEmpty && roleStr != null) {
      perms = AppPermission.getDefaultPermissions(roleStr);
    }

    return AuthMeResult(
      id: int.tryParse(json['id']?.toString() ?? ''),
      nama: json['nama']?.toString().trim(),
      username: json['username']?.toString().trim(),
      role: roleStr,
      employeeCode: json['employeeCode']?.toString().trim(),
      noHp: json['noHp']?.toString().trim(),
      permissions: perms,
    );
  }

  String get displayName =>
      (nama != null && nama!.isNotEmpty) ? nama! : (username ?? 'User');
}

/// Satu option dari GET /api/v1/canvasing/options (id + namaInstansi).
class CanvasingOption {
  CanvasingOption({this.id, this.namaInstansi});

  final Object? id;
  final String? namaInstansi;

  factory CanvasingOption.fromJson(Map<String, dynamic> json) {
    return CanvasingOption(
      id: json['id'],
      namaInstansi: json['namaInstansi']?.toString(),
    );
  }
}

/// Model Item SN Response
class ItemSerialNumberResponse {
  final DateTime? tanggal;
  final String? docId;
  final String? user;
  final String? itemName;
  final String? sn;

  ItemSerialNumberResponse({
    this.tanggal,
    this.docId,
    this.user,
    this.itemName,
    this.sn,
  });

  factory ItemSerialNumberResponse.fromJson(Map<String, dynamic> json) {
    return ItemSerialNumberResponse(
      tanggal: json['tanggal'] != null
          ? DateTime.tryParse(json['tanggal'].toString())
          : null,
      docId: json['docId']?.toString(),
      user: json['user_name']?.toString() ??
          json['userName']?.toString() ??
          json['user']?.toString(),
      itemName: json['itemName']?.toString(),
      sn: json['sn']?.toString(),
    );
  }
}

/// Model for date range meta returned by /api/v1/old-data/meta.
class OldDataMeta {
  final int minYear;
  final int? salesMaxYear;
  final int? purchaseMaxYear;
  final int? itemSnMaxYear;

  const OldDataMeta({
    this.minYear = 2016,
    this.salesMaxYear,
    this.purchaseMaxYear,
    this.itemSnMaxYear,
  });

  String get salesRange => '$minYear - ${salesMaxYear ?? '...'}';
  String get purchaseRange => '$minYear - ${purchaseMaxYear ?? '...'}';
  String get itemSnRange => '$minYear - ${itemSnMaxYear ?? '...'}';
}

/// Model User (from GET /api/v1/users)
class UserAccount {
  final int id;
  final String nama;
  final String username;
  final String role;
  final String? employeeCode;
  final String? noHp;

  UserAccount({
    required this.id,
    required this.nama,
    required this.username,
    required this.role,
    this.employeeCode,
    this.noHp,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nama: json['nama']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString().trim(),
      noHp: json['noHp']?.toString().trim(),
    );
  }
}

class ActiveUsersToday {
  final int count;
  final List<String> usernames;

  ActiveUsersToday({
    required this.count,
    required this.usernames,
  });

  factory ActiveUsersToday.fromJson(Map<String, dynamic> json) {
    return ActiveUsersToday(
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      usernames: (json['usernames'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class DailyActiveUserStat {
  final String date;
  final int userCount;

  DailyActiveUserStat({
    required this.date,
    required this.userCount,
  });

  factory DailyActiveUserStat.fromJson(Map<String, dynamic> json) {
    return DailyActiveUserStat(
      date: json['date']?.toString() ?? '',
      userCount: int.tryParse(json['userCount']?.toString() ?? '0') ?? 0,
    );
  }
}
/// Internal helper untuk aggregasi stok per badan.
class _StokLine {
  final String badan;
  final String depCode;
  final String itemCode;
  final String itemName;
  int stokQty = 0;
  int lineCount = 0;

  _StokLine({
    required this.badan,
    required this.depCode,
    required this.itemCode,
    required this.itemName,
  });
}
