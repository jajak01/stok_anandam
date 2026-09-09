import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:my_api_client/my_api_client.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/auth/global_state_resetter.dart';
import 'package:stok_anandam/core/network/response_utils.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/core/theme/app_spacing.dart';
import 'package:stok_anandam/core/network/item_categories.dart';
import '../../injection.dart';
import '../../token_storage.dart';
import '../../data/api_new_endpoints.dart';
import '../layout/dashboard_shell.dart';
import '../shared/item_deck_card.dart';
import '../shared/modern_filter.dart';
import '../shared/detail_row_with_copy.dart';
import '../shared/responsive_deck_grid.dart';
import '../shared/migration_sync_mixin.dart';
import 'package:stok_anandam/core/network/websocket_service.dart';
import 'package:stok_anandam/features/presence/mixins/presence_action_mixin.dart';

/// Satu baris stok: model API + field dari DB (modal, final_pricelist, spesifikasi).
class WarehouseStock {
  final String warehouse;
  final int stok;

  WarehouseStock({required this.warehouse, required this.stok});

  factory WarehouseStock.fromJson(Map<String, dynamic> json) {
    return WarehouseStock(
      warehouse: json['warehouse']?.toString() ?? 'Unknown',
      stok: int.tryParse(json['stok']?.toString() ?? '0') ?? 0,
    );
  }
}

class PendingStockDetail {
  final String marketingNama;
  final int qty;

  PendingStockDetail({required this.marketingNama, required this.qty});

  factory PendingStockDetail.fromJson(Map<String, dynamic> json) {
    return PendingStockDetail(
      marketingNama: json['marketingNama']?.toString() ?? 'Unknown',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
    );
  }
}

class StockRow {
  final bool? isPpn;

  StockRow({
    required this.stock,
    this.modal,
    this.hargaButtom,
    this.finalPricelist,
    this.spesifikasi,
    this.warehouses = const [],
    this.totalStok,
    this.lastSalesDate,
    this.lastPurchaseDate,
    this.parName,
    this.totalPending,
    this.pendingDetails = const [],
    this.isPpn,
  });

  final Stock stock;
  final Object? modal;
  final Object? hargaButtom;
  final Object? finalPricelist;
  final String? spesifikasi;
  final List<WarehouseStock> warehouses;
  final List<PendingStockDetail> pendingDetails;
  final int? totalStok;
  final int? totalPending;
  final String? lastSalesDate;
  final String? lastPurchaseDate;
  final String? parName;

  static StockRow fromJson(Map<String, dynamic> json) {
    final stock = Stock.fromJson(json);
    final modal = json['modal'];
    final hargaButtom = json['hargaButtom'];
    final finalPricelist = json['final_pricelist'] ?? json['finalPricelist'];
    final spesifikasi = json['spesifikasi']?.toString().trim();
    final totalStok = int.tryParse(json['totalStok']?.toString() ?? '');
    final lastSalesDate = json['lastSalesDate']?.toString().trim();

    final warehouseList = <WarehouseStock>[];
    if (json['warehouses'] is List) {
      for (final w in json['warehouses']) {
        if (w is Map<String, dynamic>) {
          warehouseList.add(WarehouseStock.fromJson(w));
        }
      }
    }

    final parName = json['parName']?.toString().trim();
    final lastPurchaseDate = json['lastPurchaseDate']?.toString().trim();
    final totalPending = int.tryParse(json['totalPending']?.toString() ?? '');

    final pendingDetailList = <PendingStockDetail>[];
    if (json['pendingDetails'] is List) {
      for (final p in json['pendingDetails']) {
        if (p is Map<String, dynamic>) {
          pendingDetailList.add(PendingStockDetail.fromJson(p));
        }
      }
    }

    final isPpn = json['isPpn'];
    if (isPpn != null && isPpn is bool) {
      // Already bool
    }

    return StockRow(
      stock: stock,
      modal: modal,
      hargaButtom: hargaButtom,
      finalPricelist: finalPricelist,
      spesifikasi: spesifikasi?.isEmpty == true ? null : spesifikasi,
      warehouses: warehouseList,
      pendingDetails: pendingDetailList,
      totalStok: totalStok,
      totalPending: totalPending,
      lastSalesDate: lastSalesDate?.isEmpty == true ? null : lastSalesDate,
      lastPurchaseDate:
          lastPurchaseDate?.isEmpty == true ? null : lastPurchaseDate,
      parName: parName?.isEmpty == true ? null : parName,
      isPpn: isPpn is bool ? isPpn : null,
    );
  }
}

/// State filter Stok disimpan agar saat pindah menu lalu balik, filter tetap.
class _StockFilterState {
  _StockFilterState._();
  static String search = '';
  static int page = 0;
  static int size = 50;
  static String sortBy = 'modal';
  static String direction = 'asc';
  static List<String> categories = [];

  static void reset() {
    search = '';
    page = 0;
    size = 50;
    sortBy = 'modal';
    direction = 'asc';
    categories = [];
  }
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with PresenceActionMixin {
  @override
  void initState() {
    super.initState();
    GlobalStateResetter.register(_StockFilterState.reset);
  }

  @override
  Widget build(BuildContext context) {
    return const _StockContent();
  }
}

class _StockContent extends StatefulWidget {
  const _StockContent();

  @override
  State<_StockContent> createState() => _StockContentState();
}

class _StockContentState extends State<_StockContent> with MigrationSyncMixin {
  bool _loading = true;

  /// Disimpan sebagai dynamic agar hot reload tidak memicu type error bila state lama masih List<Stock>.
  dynamic _itemsRaw = <StockRow>[];

  /// Selalu mengembalikan List<StockRow>; mengonversi dari List<Stock> bila perlu (state lama).
  List<StockRow> get _items {
    final r = _itemsRaw;
    if (r is List<StockRow>) return r;
    if (r is List<Stock>) {
      return (r)
          .map((s) => StockRow(
              stock: s,
              modal: null,
              finalPricelist: null,
              spesifikasi: null,
              parName: null))
          .toList();
    }
    return <StockRow>[];
  }

  int _page = 0;
  int _size = 50;
  int _totalElements = 0;
  int _totalPages = 0;
  String _search = '';
  String _sortBy = 'modal';
  String _direction = 'asc';
  List<String> _selectedCategories = [];
  List<String> _availableCategoryCodes = [];

  /// Lookup stok per badan: kode item (uppercase) -> (badan -> qty).
  Map<String, Map<String, int>> _stokBadanByItem = {};

  final _searchController = SearchController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  static const _searchDebounceDuration = Duration(milliseconds: 450);
  StreamSubscription? _wsSubscription;

  void _restoreFilterState() {
    _search = _StockFilterState.search;
    _searchController.text = _search;
    _page = _StockFilterState.page;
    _size = _StockFilterState.size;
    _sortBy = _StockFilterState.sortBy;
    _direction = _StockFilterState.direction;
    _selectedCategories = List<String>.from(_StockFilterState.categories);
  }

  void _persistFilterState() {
    _StockFilterState.search = _search;
    _StockFilterState.page = _page;
    _StockFilterState.size = _size;
    _StockFilterState.sortBy = _sortBy;
    _StockFilterState.direction = _direction;
    _StockFilterState.categories = List<String>.from(_selectedCategories);
  }

  @override
  void initState() {
    super.initState();
    _restoreFilterState();
    fetchLastSync();
    _loadStocks();
    _loadStokPerBadan();
    final excludedCategories = {
      'BRANDED',
      'MONITOR',
      'NOTEBOOK',
      'KOMPONEN',
      'CTRD TINTA TONER',
      'PRINTER SCANNER',
      'LAIN-LAIN',
    };
    _availableCategoryCodes = ItemCategories.getAllCategoryCodes()
        .where((c) => !excludedCategories.contains(c))
        .toList();
    _searchController.addListener(_onSearchChanged);

    // Listen to WebSocket for real-time updates
    _wsSubscription = getIt<WebSocketService>().memoUpdateStream.listen((data) {
      if (data.toUpperCase().contains('REFRESH')) {
        if (mounted) {
          _loadStocks();
        }
      }
    });
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      setState(() {
        _search = _searchController.text;
        _page = 0;
        _persistFilterState();
      });
      _loadStocks();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }

  static List<StockRow> _parseContent(Object? content) {
    if (content == null || content is! List) return <StockRow>[];
    final result = <StockRow>[];
    for (final e in content) {
      if (e is StockRow) {
        result.add(e);
      } else if (e is Map) {
        result.add(StockRow.fromJson(Map<String, dynamic>.from(e)));
      } else if (e is Stock) {
        result.add(StockRow(
            stock: e,
            modal: null,
            finalPricelist: null,
            spesifikasi: null,
            parName: null));
      }
    }
    return result;
  }

  Future<void> _loadStocks() async {
    setState(() {
      _loading = true;
    });
    try {
      await _loadStocksWithApi();
      _loadStokPerBadan();
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        final body = e.response!.data as Map<Object?, Object?>;
        final status = body['status'];
        final data = body['data'];
        final paging = body['paging'] as Map?;
        final dataMap = data is Map ? data : null;

        final tp = paging?['totalPage'] ??
            paging?['totalPages'] ??
            paging?['total_page'] ??
            paging?['total_pages'] ??
            dataMap?['totalPages'] ??
            dataMap?['totalPage'] ??
            dataMap?['total_pages'] ??
            dataMap?['total_page'];
        final te = paging?['totalItem'] ??
            paging?['totalElements'] ??
            paging?['total_item'] ??
            paging?['total_elements'] ??
            dataMap?['totalElements'] ??
            dataMap?['totalItem'] ??
            dataMap?['total_elements'] ??
            dataMap?['total_item'];

        final totalPages =
            (tp is int) ? tp : (int.tryParse(tp?.toString() ?? '0') ?? 1);
        final totalElements =
            (te is int) ? te : (int.tryParse(te?.toString() ?? '0') ?? 0);

        if (isResponseSuccess(status) && data is List) {
          final items = _parseContent(data);
          if (mounted) {
            setState(() {
              _itemsRaw = List<StockRow>.from(items);
              _totalElements = totalElements;
              _totalPages = totalPages < 1 ? 1 : totalPages;
              _loading = false;
              _persistFilterState();
            });
          }
          return;
        }
      }
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadStocksWithApi() async {
    final dio = getIt<MyApiClient>().dio;
    final queryParams = <String, dynamic>{
      'page': _page,
      'size': _size,
      'sortBy': _sortBy,
      'direction': _direction,
      if (_search.trim().isNotEmpty) 'search': _search.trim(),
      if (_selectedCategories.isNotEmpty) 'categories': _selectedCategories,
    };
    final response = await dio.get<Map<String, dynamic>>(
      '/api/v1/stock',
      queryParameters: queryParams,
    );
    final data = response.data;
    if (data == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final dataPayload = data['data'];
    final pagingPayload = data['paging'];
    final status = data['status'];

    final tp = pagingPayload is Map
        ? (pagingPayload['totalPage'] ??
            pagingPayload['totalPages'] ??
            pagingPayload['total_page'] ??
            pagingPayload['total_pages'])
        : null;
    final te = pagingPayload is Map
        ? (pagingPayload['totalItem'] ??
            pagingPayload['totalElements'] ??
            pagingPayload['total_item'] ??
            pagingPayload['total_elements'])
        : null;
    final dataMap = dataPayload is Map ? dataPayload : null;

    if (isResponseSuccess(status)) {
      List<StockRow> items = [];
      int totalElements = (te is int)
          ? te
          : (int.tryParse(te?.toString() ??
                  (dataMap?['totalElements'] ??
                          dataMap?['totalItem'] ??
                          dataMap?['total_elements'] ??
                          dataMap?['total_item'] ??
                          '0')
                      .toString()) ??
              0);
      int totalPages = (tp is int)
          ? tp
          : (int.tryParse(tp?.toString() ??
                  (dataMap?['totalPages'] ??
                          dataMap?['totalPage'] ??
                          dataMap?['total_pages'] ??
                          dataMap?['total_page'] ??
                          '1')
                      .toString()) ??
              1);

      if (dataPayload is List) {
        items = _parseContent(dataPayload);
      } else if (dataPayload is Map) {
        items = _parseContent(dataPayload['content']);
      }

      if (mounted) {
        setState(() {
          _itemsRaw = List<StockRow>.from(items);
          _totalElements = totalElements;
          _totalPages = totalPages < 1 ? 1 : totalPages;
          _loading = false;
          _persistFilterState();
        });
      }
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Memuat lookup stok per badan (kode item -> badan -> qty) untuk ditampilkan
  /// langsung pada deck card tanpa harus membuka detail. Memanfaatkan cache 5 menit
  /// dari getStokPerBadan() agar tidak membebani jaringan.
  Future<void> _loadStokPerBadan() async {
    try {
      final groups = await getIt<ApiNewEndpoints>().getStokPerBadan();
      final lookup = <String, Map<String, int>>{};
      for (final group in groups) {
        final badan = group.badan.trim().toUpperCase();
        if (badan.isEmpty) continue;
        for (final item in group.items) {
          if (item.stokQty <= 0) continue;
          final code = item.itemCode.trim().toUpperCase();
          if (code.isEmpty) continue;
          final map = lookup[code] ??= <String, int>{};
          final badanQty = item.badan.trim().toUpperCase();
          final key = badanQty.isNotEmpty ? badanQty : badan;
          map[key] = (map[key] ?? 0) + item.stokQty;
        }
      }
      if (mounted) {
        setState(() => _stokBadanByItem = lookup);
      }
    } catch (e) {
      debugPrint('Gagal memuat lookup stok badan: $e');
    }
  }

  void _onSearchSubmitted() {
    _search = _searchController.text;
    setState(() {
      _page = 0;
      _persistFilterState();
    });
    _loadStocks();
  }

  void _openDetail(StockRow row) async {
    final id = row.stock.id;
    final itemCode = row.stock.itemCode?.toString();
    if (id == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final api = getIt<StockControllerApi>();
      final response = await api.getStockDetail(id: id);
      if (!mounted) return;
      Navigator.of(context).pop();

      // Fetch stok per badan
      Map<String, int>? stokPerBadan;
      if (itemCode != null && itemCode.isNotEmpty) {
        try {
          stokPerBadan = await getIt<ApiNewEndpoints>().getStokPerBadanForItem(
            itemCode,
            itemName: row.stock.itemName?.toString(),
          );
        } catch (e) {
          debugPrint('Error fetch stok per badan: $e');
        }
      }

      final detail = response.data?.data;
      if (detail != null) {
        _showDetailSheet(
          detail,
          row: StockRow(
            stock: detail,
            modal: row.modal,
            hargaButtom: row.hargaButtom,
            finalPricelist: row.finalPricelist,
            spesifikasi: row.spesifikasi,
            warehouses: row.warehouses,
            totalStok: row.totalStok,
            lastSalesDate: row.lastSalesDate,
            lastPurchaseDate: row.lastPurchaseDate,
            parName: row.parName,
            totalPending: row.totalPending,
            pendingDetails: row.pendingDetails,
            isPpn: row.isPpn, // ← perbaikan: teruskan nilai isPpn dari baris daftar
          ),
          stokPerBadan: stokPerBadan,
        );
      } else {
        _showDetailSheet(
          row.stock,
          row: row,
          stokPerBadan: stokPerBadan,
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat detail: $e')),
      );
    }
  }

  void _showDetailSheet(Stock s,
      {required StockRow row, Map<String, int>? stokPerBadan}) {
    final userRole = getIt<CurrentUserStore>().userRole;
    final isMarketing = userRole?.startsWith('MARKETING') == true;
    final modal = row.modal;
    final finalPricelist = row.finalPricelist;
    final spesifikasi = row.spesifikasi;

    String formatDate(DateTime date, {bool includeTime = false}) {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      if (!includeTime) {
        return '$day/$month/$year';
      }

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: true,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          "${_str(s.itemName) ?? _str(s.itemCode) ?? '—'}\n",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1F2937),
                                            height: 1.3,
                                          ),
                                    ),
                                    if (spesifikasi != null &&
                                        spesifikasi.isNotEmpty)
                                      TextSpan(
                                        text: spesifikasi,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.content_copy_rounded,
                                  size: 18),
                              onPressed: () {
                                final String nameText =
                                    _str(s.itemName) ?? _str(s.itemCode) ?? '';
                                final String specText = (spesifikasi != null &&
                                        spesifikasi.isNotEmpty)
                                    ? spesifikasi
                                    : '';
                                final String fullText =
                                    "$nameText\n$specText".trim();
                                if (fullText.isNotEmpty && nameText != '—') {
                                  Clipboard.setData(
                                      ClipboardData(text: fullText));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Nama & Spesifikasi disalin'),
                                          duration: Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating));
                                }
                              },
                              color: Colors.blue.shade600,
                              tooltip: 'Salin Nama & Spesifikasi',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DetailRowWithCopy(
                            label: 'Master',
                            value: _str(s.itemName),
                            labelWidth: 120),
                        const Divider(),
                        if (row.hargaButtom != null) ...[
                          DetailRowWithCopy(
                              label: 'Harga Bottom',
                              value: _formatRupiah(row.hargaButtom),
                              labelWidth: 120),
                          const Divider(),
                        ],
                        if (!isMarketing) ...[
                          DetailRowWithCopy(
                              label: 'Modal Awal',
                              value: _formatRupiah(s.hargaHpp),
                              labelWidth: 120),
                          const Divider(),
                        ],
                        DetailRowWithCopy(
                            label: 'Modal Final',
                            value: _formatRupiah(modal ?? s.hargaHpp),
                            labelWidth: 120),
                        const Divider(),
                        DetailRowWithCopy(
                            label: 'Pricelist',
                            value: _formatRupiah(finalPricelist ?? s.finalPricelist),
                            labelWidth: 120),
                        const Divider(),
                        if (row.lastPurchaseDate != null)
                          DetailRowWithCopy(
                            label: 'Tanggal Pembelian Terakhir',
                            value: (DateTime.tryParse(row.lastPurchaseDate!) !=
                                    null)
                                ? formatDate(
                                    DateTime.parse(row.lastPurchaseDate!))
                                : row.lastPurchaseDate!,
                            labelWidth: 120,
                          ),
                        const Divider(),
                        if (row.parName != null)
                          DetailRowWithCopy(
                              label: 'Partner',
                              value: _str(row.parName),
                              labelWidth: 120),
                        const Divider(),
                        DetailRowWithCopy(
                            label: 'Jenis Pajak',
                            value: row.isPpn == null
                                ? '???'
                                : (row.isPpn! ? 'PPN' : 'NON PPN'),
                            labelWidth: 120),
                        const Divider(),
                        DetailRowWithCopy(
                            label: 'Total Stok',
                            value: _str(row.totalStok ?? s.finalStok),
                            labelWidth: 120),
                        if (row.totalPending != null &&
                            row.totalPending! > 0) ...[
                          const Divider(),
                          DetailRowWithCopy(
                              label: 'Total Booking',
                              value: _str(row.totalPending),
                              labelWidth: 120),
                          DetailRowWithCopy(
                              label: 'Nilai Booking',
                              value: _formatRupiah(_n(row.totalPending) *
                                  _n(modal ?? s.hargaHpp)),
                              labelWidth: 120),
                          if (row.pendingDetails.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text('Rincian Booking:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700)),
                            ),
                            ...row.pendingDetails.map((p) => Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, bottom: 2),
                                  child: Row(children: [
                                    Text('${p.marketingNama}: ',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF374151))),
                                    Text('${p.qty}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800)),
                                  ]),
                                ))
                          ],
                        ],
                        if (stokPerBadan != null &&
                            stokPerBadan.entries.any((e) => e.value > 0)) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.apartment_rounded,
                                    size: 15, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Stok per Badan Usaha:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: stokPerBadan.entries
                                  .where((e) => e.value > 0)
                                  .map((e) {
                                final color = _badgeColor(e.key);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        e.key,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 1,
                                        height: 12,
                                        color: color.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${e.value} unit',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (row.warehouses.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                            child: Text('Rincian Gudang:',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600)),
                          ),
                          ...row.warehouses.map((w) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 12, bottom: 2),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _badgeColor(w.warehouse)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(w.warehouse,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _badgeColor(w.warehouse))),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Stok: ${w.stok}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1F2937))),
                                ]),
                              )),
                          const SizedBox(height: 12),
                        ] else
                          DetailRowWithCopy(
                              label: 'Gudang',
                              value: _str(s.warehouse),
                              labelWidth: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static num _n(Object? v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0;
  }

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
  static Color _badgeColor(String badan) {
    switch (badan) {
      case 'ANC': return Colors.blue;
      case 'PDB': return Colors.green;
      case 'MGC': return Colors.orange;
      case 'GBH': return Colors.purple;
      case 'SSS': return Colors.teal;
      case 'SGI': return Colors.red;
      default: return Colors.grey;
    }
  }

  /// Formats a value into a rupiah-formatted string.
  /// Handles both Indonesian (dot = thousand separator) and plain numeric formats.
  static String _formatRupiah(Object? v) {
    if (v == null) return '—';
    final raw = v.toString().trim();
    if (raw.isEmpty) return '—';
    final n = _parseFlexibleNumber(raw);
    if (n == null) return raw;

    final String formatted = _formatNumber(n);
    return ' $formatted';
  }

  /// Tries to parse a numeric string that may use Indonesian formatting
  /// (dots as thousand separators, comma as decimal separator).
  static num? _parseFlexibleNumber(String raw) {
    // Already a plain number?
    final direct = num.tryParse(raw);
    if (direct != null) return direct;

    // Try Indonesian format: dots as thousand separators
    if (raw.contains('.') && !raw.contains(',')) {
      final parts = raw.split('.');
      if (parts.length > 1 &&
          parts.skip(1).every((p) => p.length == 3)) {
        final cleaned = raw.replaceAll('.', '');
        return num.tryParse(cleaned);
      }
    }

    // Try with comma as decimal: "60,00" → 60.00
    if (raw.contains(',') && !raw.contains('.')) {
      final cleaned = raw.replaceAll('.', '').replaceAll(',', '.');
      return num.tryParse(cleaned);
    }

    // Remove all dots as thousand separators and try
    final noDots = raw.replaceAll('.', '');
    return num.tryParse(noDots);
  }

  static String _formatNumber(num value) {
    if (value % 1 != 0) {
      final parts = value.toString().split('.');
      final integerPart = _addThousandSeparator(parts[0]);
      return '$integerPart,${parts[1]}';
    } else {
      return _addThousandSeparator(value.toInt().toString());
    }
  }

  static String _addThousandSeparator(String number) {
    final reversed = number.split('').reversed.join();
    final chunks = <String>[];
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      chunks.add(reversed.substring(i, end));
    }
    return chunks.join('.').split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;
    final theme = Theme.of(context);

    return DashboardShell(
      currentRoute: AppRoutes.stok,
      userName: getIt<CurrentUserStore>().displayName,
      userRole: getIt<CurrentUserStore>().userRole,
      headerActionLabel: 'Sync Migrasi',
      headerActionIcon: Icons.sync_rounded,
      onHeaderAction: () =>
          showSyncMigrationDialog(onCustomSuccess: _loadStocks),
      lastSync: lastSyncFormatted,
      onScan: () => context.pushNamed(AppRoutes.scanner),
      showHeaderActionInAppBar: true,
      onRefresh: _loading ? null : _loadStocks,
      onNavigate: (route) {
        if (route != AppRoutes.stok) context.go(route);
      },
      onLogout: () {
        getIt<TokenStorage>().clear();
        getIt<CurrentUserStore>().clear();
        context.go(AppRoutes.login);
      },
      child: Container(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? AppSpacing.lg : AppSpacing.xl,
            isMobile ? AppSpacing.lg : AppSpacing.xl,
            isMobile ? AppSpacing.lg : AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FiltersSection(
                  items: _items,
                  searchController: _searchController,
                  searchFocus: _searchFocus,
                  onSearchSubmitted: _onSearchSubmitted,
                  sortBy: _sortBy,
                  direction: _direction,
                  size: _size,
                  selectedCategories: _selectedCategories,
                  availableCategoryCodes: _availableCategoryCodes,
                  onApply: (sortBy, direction, size, cats) {
                    setState(() {
                      _sortBy = sortBy;
                      _direction = direction;
                      _size = size;
                      _selectedCategories = cats;
                      _page = 0;
                      _persistFilterState();
                    });
                    _loadStocks();
                  },
                  onCategoriesChanged: (v) {
                    setState(() {
                      _selectedCategories = v;
                      _page = 0;
                      _persistFilterState();
                    });
                    _loadStocks();
                  },
                  content: RefreshIndicator(
                    onRefresh: _loadStocks,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            _StockDeckView(
                                items: _items,
                                stokBadanByItem: _stokBadanByItem,
                                onTap: _openDetail),
                          if (!_loading && _items.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            _PaginationBar(
                              page: _page,
                              totalPages: _totalPages,
                              totalElements: _totalElements,
                              onPrev: (_totalPages > 0 && _page > 0)
                                  ? () {
                                      setState(() {
                                        _page--;
                                        _persistFilterState();
                                      });
                                      _loadStocks();
                                    }
                                  : null,
                              onNext:
                                  (_totalPages > 0 && _page < _totalPages - 1)
                                      ? () {
                                          setState(() {
                                            _page++;
                                            _persistFilterState();
                                          });
                                          _loadStocks();
                                        }
                                      : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersSection extends StatefulWidget {
  const _FiltersSection({
    required this.items,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchSubmitted,
    required this.sortBy,
    required this.direction,
    required this.size,
    this.selectedCategories = const [],
    this.availableCategoryCodes = const [],
    required this.onApply,
    required this.onCategoriesChanged,
    required this.content,
  });

  final List<StockRow> items;
  final SearchController searchController;
  final FocusNode searchFocus;
  final VoidCallback onSearchSubmitted;
  final String sortBy;
  final String direction;
  final int size;
  final List<String> selectedCategories;
  final List<String> availableCategoryCodes;
  final void Function(
    String sortBy,
    String direction,
    int size,
    List<String> categories,
  ) onApply;
  final void Function(List<String>) onCategoriesChanged;
  final Widget content;

  @override
  State<_FiltersSection> createState() => _FiltersSectionState();
}

class _FiltersSectionState extends State<_FiltersSection> {
  late String _sortBy;
  late String _direction;
  late int _size;
  List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _resetToCurrent();
  }

  void _resetToCurrent() {
    _sortBy = widget.sortBy;
    _direction = widget.direction;
    _size = widget.size;
    _selectedCategories = List<String>.from(widget.selectedCategories);
  }

  @override
  void didUpdateWidget(_FiltersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortBy != widget.sortBy ||
        oldWidget.direction != widget.direction ||
        oldWidget.size != widget.size ||
        oldWidget.selectedCategories != widget.selectedCategories) {
      _resetToCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return FixedSearchFilterLayout(
      searchBar: SearchAnchor(
        isFullScreen: false,
        searchController: widget.searchController,
        viewHintText: 'Cari kode, nama, kategori...',
        builder: (context, controller) {
          return ModernSearchBar(
            controller: widget.searchController,
            focusNode: widget.searchFocus,
            onSubmitted: widget.onSearchSubmitted,
            hintText: 'Cari kode, nama, kategori...',
            onChanged: (val) {
              if (val.isEmpty) {
                widget.onSearchSubmitted();
              }
            },
          );
        },
        suggestionsBuilder: (context, controller) {
          final query = controller.text.trim().toLowerCase();

          final suggestions = widget.items
              .where((item) {
                final name =
                    item.stock.itemName?.toString().toLowerCase() ?? '';
                final code =
                    item.stock.itemCode?.toString().toLowerCase() ?? '';
                final cat =
                    item.stock.kategoriNama?.toString().toLowerCase() ?? '';
                return name.contains(query) ||
                    code.contains(query) ||
                    cat.contains(query);
              })
              .take(6)
              .toList();

          return [
            if (query.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.search, color: Colors.blue),
                title: Text("Cari '$query' di semua kolom..."),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                  },
                ),
                onTap: () {
                  controller.closeView(query);
                  widget.onSearchSubmitted();
                },
              ),
            const Divider(height: 1),
            ...suggestions.map((item) {
              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined,
                    color: Colors.orange),
                title: Text(item.stock.itemName?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "${item.stock.itemCode} • ${item.stock.kategoriNama ?? ''}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Stok: ${item.totalStok ?? 0}",
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                    if (item.modal != null)
                      Text("Rp ${item.modal}",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                  ],
                ),
                onTap: () {
                  final selectedName = item.stock.itemName?.toString() ?? '';
                  controller.closeView(selectedName);
                  widget.onSearchSubmitted();
                },
              );
            }),
          ];
        },
      ),
      filterTitle: 'Filter & Urutkan',
      activeFilterBadges: widget.selectedCategories.isNotEmpty
          ? [
              FilterBadge(
                label: 'Kategori: ${widget.selectedCategories.length} Terpilih',
                onRemove: () => widget.onCategoriesChanged([]),
              ),
            ]
          : null,
      filterContentBuilder: (close, refresh) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const FilterLabel('Kategori'),
              widget.availableCategoryCodes.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Memuat kategori...',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : MultiSelectSearchableDropdown<String>(
                      hintText: 'Semua Kategori',
                      values: _selectedCategories,
                      options: widget.availableCategoryCodes,
                      displayText: (code) => code,
                      onChanged: (v) {
                        setState(() => _selectedCategories = v);
                        refresh();
                      },
                    ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const FilterLabel('Item per halaman'),
              CompactFilterDropdown<int>(
                label: 'Item per halaman',
                value: _size,
                options: const [10, 20, 50, 100],
                displayText: (s) => '$s item',
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _size = v);
                    refresh();
                  }
                },
              ),
            ],
          ),
          FilterFooter(
            onApply: () {
              widget.onApply(
                _sortBy,
                _direction,
                _size,
                _selectedCategories,
              );
              close();
            },
            onReset: () {
              widget.onCategoriesChanged([]);
              setState(() {
                _sortBy = 'modal';
                _direction = 'asc';
                _size = 50;
                _selectedCategories = [];
              });
              widget.onApply(
                _sortBy,
                _direction,
                _size,
                _selectedCategories,
              );
              close();
            },
          ),
        ],
      ),
      child: widget.content,
    );
  }
}

class _StockDeckView extends StatelessWidget {
  const _StockDeckView({
    required this.items,
    this.stokBadanByItem = const {},
    required this.onTap,
  });

  final List<StockRow> items;
  final Map<String, Map<String, int>> stokBadanByItem;
  final void Function(StockRow) onTap;

  static String _v(Object? x) =>
      x?.toString().trim().isEmpty ?? true ? '—' : x.toString();

  /// Parses a value into a rupiah-formatted string.
  /// Handles both Indonesian (dot = thousand separator) and plain numeric formats.
  static String _rp(Object? x) {
    if (x == null) return '—';
    final raw = x.toString().trim();
    if (raw.isEmpty) return '—';
    final parsed = _parseFlexibleNumber(raw);
    if (parsed == null) return raw;
    final String formatted = _formatNumber(parsed);
    return ' $formatted';
  }

  /// Tries to parse a numeric string that may use Indonesian formatting
  /// (dots as thousand separators, comma as decimal separator).
  static num? _parseFlexibleNumber(String raw) {
    // Already a plain number?
    final direct = num.tryParse(raw);
    if (direct != null) return direct;

    // Try Indonesian format: remove dots (thousand separators)
    if (raw.contains('.') && !raw.contains(',')) {
      final parts = raw.split('.');
      if (parts.length > 1 &&
          parts.skip(1).every((p) => p.length == 3)) {
        final cleaned = raw.replaceAll('.', '');
        return num.tryParse(cleaned);
      }
    }

    // Try with comma as decimal: "60,00" → 60.00
    if (raw.contains(',') && !raw.contains('.')) {
      final cleaned = raw.replaceAll('.', '').replaceAll(',', '.');
      return num.tryParse(cleaned);
    }

    // Remove all dots as thousand separators and try
    final noDots = raw.replaceAll('.', '');
    return num.tryParse(noDots);
  }

  static String _formatNumber(num value) {
    if (value % 1 != 0) {
      final parts = value.toString().split('.');
      final integerPart = _addThousandSeparator(parts[0]);
      return '$integerPart,${parts[1]}';
    }
    return _addThousandSeparator(value.toInt().toString());
  }

  static String _addThousandSeparator(String number) {
    final reversed = number.split('').reversed.join();
    final chunks = <String>[];
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      chunks.add(reversed.substring(i, end));
    }
    return chunks.join('.').split('').reversed.join();
  }

  static String _fd(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

static Widget _buildChip(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor)),
    );
  }

  static Color _badgeColor(String badan) {
    switch (badan) {
      case 'ANC': return Colors.blue;
      case 'PDB': return Colors.green;
      case 'MGC': return Colors.orange;
      case 'GBH': return Colors.purple;
      case 'SSS': return Colors.teal;
      case 'SGI': return Colors.red;
      default: return Colors.grey;
    }
  }

  /// Membangun badge "stok per badan" (ANC, GBH, PDB, dll) untuk satu baris.
  /// Hanya badan dengan qty > 0 yang ditampilkan.
  Widget? _buildBadanBadges(StockRow row) {
    final code = row.stock.itemCode?.toString().trim().toUpperCase() ?? '';
    if (code.isEmpty) return null;
    final badanMap = stokBadanByItem[code];
    if (badanMap == null || badanMap.isEmpty) return null;
    final entries =
        badanMap.entries.where((e) => e.value > 0).toList(growable: false);
    if (entries.isEmpty) return null;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: entries.map((e) {
        final color = _badgeColor(e.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Text('${e.key} ${e.value}',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color)),
        );
      }).toList(),
    );
  }

  /// Membangun konten header kanan atas: badge stok badan (sebelum) + pembatas
  /// "|" + badge PPN/NON PPN.
  Widget? _buildHeaderBadges(StockRow row) {
    final badanBadges = _buildBadanBadges(row);
    Widget ppnChip;
    if (row.isPpn == true) {
      ppnChip =
          _buildChip('PPN', Colors.green.shade700, Colors.green.shade50);
    } else if (row.isPpn == false) {
      ppnChip = _buildChip(
        'NON PPN',
        const Color.fromARGB(255, 255, 254, 253),
        const Color.fromARGB(255, 255, 10, 10),
      );
    } else {
      ppnChip = _buildChip(
        '???',
        const Color.fromARGB(255, 255, 101, 18),
        Colors.grey.shade100,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badanBadges != null) ...[
          badanBadges,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('|',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
          ),
        ],
        ppnChip,
      ],
    );
  }

  /// Membangun banner "Total Booking" bila ada booking pada item.
  Widget? _buildBookingBanner(StockRow row) {
    if (row.totalPending == null || row.totalPending! <= 0) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_outline, size: 14, color: Colors.orange.shade800),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Total Booking: ${row.totalPending}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveDeckGrid(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final row = items[i];
        final s = row.stock;
        final modalStr = _rp(row.modal ?? s.hargaHpp);
        final pricelistStr = _rp(row.finalPricelist ?? s.finalPricelist);
        return DataDeckCard(
          title: _v(s.itemName),
          subtitle: _v(row.spesifikasi),
          chip: _buildHeaderBadges(row),
          extraContent: _buildBookingBanner(row),
          rows: [
            (label: 'Stok', value: _v(row.totalStok ?? s.finalStok)),
            if (row.hargaButtom != null)
              (label: 'Harga Bottom', value: _rp(row.hargaButtom)),
            (label: 'Modal', value: modalStr),
            (label: 'Pricelist', value: pricelistStr)
          ],
          onTap: () => onTap(row),
          highlightLastValue: false,
        );
      },
    );
  }
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Tidak ada data stok',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalElements,
    this.onPrev,
    this.onNext,
  });
  final int page;
  final int totalPages;
  final int totalElements;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Halaman ${page + 1} dari ${totalPages > 0 ? totalPages : 1} • Total $totalElements item',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade800),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}