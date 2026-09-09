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
import 'package:stok_anandam/core/network/file_download_service.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';
import 'package:stok_anandam/features/layout/dashboard_shell.dart';
import 'package:stok_anandam/features/shared/responsive_padding.dart';
import 'package:stok_anandam/features/shared/item_deck_card.dart';
import 'package:stok_anandam/features/shared/modern_filter.dart';
import 'package:stok_anandam/features/shared/detail_row_with_copy.dart';
import 'package:stok_anandam/features/shared/responsive_deck_grid.dart';
import 'package:stok_anandam/features/shared/migration_sync_mixin.dart';
import 'package:stok_anandam/features/shared/custom_pluto_grid.dart';
import 'package:stok_anandam/features/shared/grid_helpers.dart';
import 'package:stok_anandam/features/shared/responsive_table.dart';
import 'package:stok_anandam/features/presence/mixins/presence_action_mixin.dart';

/// State filter Pembelian disimpan agar saat pindah menu lalu balik, filter tetap.
class _PurchaseFilterState {
  _PurchaseFilterState._();
  static String search = '';
  static String searchColumn = 'ALL';
  static int page = 0;
  static int size = 50;
  static String sortBy = 'docDate';
  static String dir = 'desc';
  static int? startDateMillis;
  static int? endDateMillis;
  static List<String> selectedEmpCodes = [];
  static List<String> categories = [];

  static void reset() {
    search = '';
    searchColumn = 'ALL';
    page = 0;
    size = 50;
    sortBy = 'docDate';
    dir = 'desc';
    startDateMillis = null;
    endDateMillis = null;
    selectedEmpCodes = [];
    categories = [];
  }
}

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> with PresenceActionMixin {
  @override
  void initState() {
    super.initState();
    GlobalStateResetter.register(_PurchaseFilterState.reset);
  }

  @override
  Widget build(BuildContext context) {
    return const _PurchaseContent();
  }
}

class _PurchaseContent extends StatefulWidget {
  const _PurchaseContent();

  @override
  State<_PurchaseContent> createState() => _PurchaseContentState();
}

class _PurchaseContentState extends State<_PurchaseContent>
    with MigrationSyncMixin {
  bool _loading = true;
  String? _error;
  List<Purchase> _items = [];
  int _page = 0;
  int _size = 50;
  int _totalElements = 0;
  int _totalPages = 0;
  Object? _totalGrandSum;
  Object? _totalQty;
  String _search = '';
  String _searchColumn = 'ALL';
  String _sortBy = 'docDate';
  String _dir = 'desc';
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _selectedEmpCodes = [];
  List<String> _selectedCategories = [];
  List<String> _allCategories = [];
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  static const _searchDebounceDuration = Duration(milliseconds: 450);

  // Store all employee codes that have ever appeared
  final Set<String> _allEmpCodes = {};

  List<String> get _availableEmpCodes {
    return _allEmpCodes.toList()..sort();
  }

  void _restoreFilterState() {
    _search = _PurchaseFilterState.search;
    _searchColumn = _PurchaseFilterState.searchColumn;
    _searchController.text = _search;
    _page = _PurchaseFilterState.page;
    _size = _PurchaseFilterState.size;
    _sortBy = _PurchaseFilterState.sortBy;
    _dir = _PurchaseFilterState.dir;
    _startDate = _PurchaseFilterState.startDateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(
            _PurchaseFilterState.startDateMillis!)
        : null;
    _endDate = _PurchaseFilterState.endDateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(
            _PurchaseFilterState.endDateMillis!)
        : null;
    _selectedEmpCodes =
        List<String>.from(_PurchaseFilterState.selectedEmpCodes);
    _selectedCategories = List<String>.from(_PurchaseFilterState.categories);
  }

  void _persistFilterState() {
    _PurchaseFilterState.search = _search;
    _PurchaseFilterState.searchColumn = _searchColumn;
    _PurchaseFilterState.page = _page;
    _PurchaseFilterState.size = _size;
    _PurchaseFilterState.sortBy = _sortBy;
    _PurchaseFilterState.dir = _dir;
    _PurchaseFilterState.startDateMillis = _startDate?.millisecondsSinceEpoch;
    _PurchaseFilterState.endDateMillis = _endDate?.millisecondsSinceEpoch;
    _PurchaseFilterState.selectedEmpCodes =
        List<String>.from(_selectedEmpCodes);
    _PurchaseFilterState.categories = List<String>.from(_selectedCategories);
  }

  @override
  void initState() {
    super.initState();
    _restoreFilterState();
    fetchLastSync();
    _loadAllEmpCodes();
    _loadAllCategories();
    _loadPurchases();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // TEKNISI: no debounce — hanya trigger saat Enter/Submit
    final isTeknisi =
        getIt<CurrentUserStore>().userRole?.toUpperCase() == 'TEKNISI';
    if (isTeknisi) return;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      setState(() {
        _search = _searchController.text;
        _page = 0;
        _persistFilterState();
      });
      _loadPurchases();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  static List<Purchase> _parseContent(Object? content) {
    if (content == null) return [];
    if (content is List) {
      return content
          .map((e) {
            if (e is Purchase) return e;
            if (e is Map) {
              return Purchase.fromJson(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<Purchase>()
          .toList();
    }
    return [];
  }

  static String _formatDateParam(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAllEmpCodes() async {
    try {
      final api = getIt<ApiNewEndpoints>();
      final codes = await api.getEmployeeCodes();
      if (mounted) {
        setState(() {
          _allEmpCodes.clear();
          _allEmpCodes.addAll(codes.map((e) => e.empCode));
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadAllCategories() async {
    try {
      final api = getIt<PurchaseControllerApi>();
      final response = await api.getCategories();
      if (isResponseSuccess(response.data?.status) &&
          response.data?.data != null) {
        setState(() {
          _allCategories =
              response.data!.data!.where((e) => e.trim().isNotEmpty).toList();
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadPurchases() async {
    final userRole = getIt<CurrentUserStore>().userRole?.toUpperCase();
    if (userRole == 'TEKNISI' && _search.trim().isEmpty) {
      setState(() {
        _items = [];
        _totalGrandSum = null;
        _totalQty = null;
        _totalElements = 0;
        _totalPages = 0;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = getIt<PurchaseControllerApi>();
      final startStr = _formatDateParam(_startDate);
      final endStr = _formatDateParam(_endDate);
      final response = await api.getPurchases(
        page: _page,
        size: _size,
        sortBy: _sortBy,
        dir: _dir,
        startDate: startStr.isEmpty ? null : startStr,
        endDate: endStr.isEmpty ? null : endStr,
        empCode: _selectedEmpCodes.isEmpty ? null : _selectedEmpCodes.join(','),
        search: _search.trim().isEmpty ? null : _search.trim(),
        searchColumn: _searchColumn == 'ALL' ? null : _searchColumn,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories,
      );
      final pageData = response.data?.data;
      if (isResponseSuccess(response.data?.status) && pageData != null) {
        var items = _parseContent(pageData.content);
        // TEKNISI: exact match filter on docNoP
        if (userRole == 'TEKNISI' && _search.trim().isNotEmpty) {
          final q = _search.trim().toUpperCase();
          items = items
              .where((p) => (p.docNoP?.toString() ?? '').toUpperCase() == q)
              .toList();
        }
        setState(() {
          _items = items;
          for (final item in items) {
            final code = _v(item.empCode);
            if (code.isNotEmpty && code != '—') _allEmpCodes.add(code);
          }
          _totalGrandSum = pageData.totalGrandSum;
          _totalQty = (pageData as dynamic).totalQty;
          _totalElements = (pageData.totalElements is int)
              ? pageData.totalElements as int
              : int.tryParse(pageData.totalElements?.toString() ?? '0') ?? 0;
          _totalPages = (pageData.totalPages is int)
              ? pageData.totalPages as int
              : int.tryParse(pageData.totalPages?.toString() ?? '0') ?? 0;
          _loading = false;
          _persistFilterState();
        });
      } else {
        setState(() {
          _error = response.data?.message?.toString() ?? 'Gagal memuat data.';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        final body = e.response!.data as Map<Object?, Object?>;
        final status = body['status'];
        final data = body['data'];
        final paging = body['paging'];
        if (isResponseSuccess(status) && data is List) {
          var items = _parseContent(data);
          // TEKNISI: exact match filter on docNoP
          if (userRole == 'TEKNISI' && _search.trim().isNotEmpty) {
            final q = _search.trim().toUpperCase();
            items = items
                .where((p) => (p.docNoP?.toString() ?? '').toUpperCase() == q)
                .toList();
          }
          int totalElements = 0;
          int totalPages = 1;
          Object? totalGrandSum = body['totalGrandSum'];
          if (paging is Map) {
            final p = Map<String, dynamic>.from(
                paging.map((k, v) => MapEntry(k?.toString() ?? '', v)));
            totalElements =
                int.tryParse(p['totalItem']?.toString() ?? '0') ?? 0;
            totalPages = int.tryParse(p['totalPage']?.toString() ?? '0') ?? 1;
            if (totalPages < 1) totalPages = 1;
          }
          if (mounted) {
            setState(() {
              _items = items;
              for (final item in items) {
                final code = _v(item.empCode);
                if (code.isNotEmpty && code != '—') _allEmpCodes.add(code);
              }
              _totalGrandSum = totalGrandSum;
              _totalQty = (body as dynamic)['totalQty'];
              _totalElements = totalElements;
              _totalPages = totalPages;
              _loading = false;
              _persistFilterState();
            });
          }
          return;
        }
      }
      setState(() {
        _error = 'Gagal memuat data. Periksa koneksi lalu coba lagi.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data. Periksa koneksi lalu coba lagi.';
        _loading = false;
      });
    }
  }

  static String _v(Object? x) =>
      x?.toString().trim().isEmpty ?? true ? '—' : x.toString();

  Future<void> _exportToExcel() async {
    setState(() {
      _loading = true;
    });
    try {
      final api = getIt<ApiNewEndpoints>();
      final startStr = _formatDateParam(_startDate);
      final endStr = _formatDateParam(_endDate);

      final bytes = await api.exportPurchases(
        startDate: startStr.isEmpty ? null : startStr,
        endDate: endStr.isEmpty ? null : endStr,
        empCode: _selectedEmpCodes.isEmpty ? null : _selectedEmpCodes.join(','),
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (bytes.isNotEmpty) {
        await FileDownloadService.downloadFile(
          bytes,
          "purchases_${_formatDateParam(DateTime.now())}.xlsx",
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        );
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Gagal export ke Excel.";
        _loading = false;
      });
    }
  }

  void _onSearchSubmitted() {
    _search = _searchController.text;
    setState(() {
      _page = 0;
      _persistFilterState();
    });
    _loadPurchases();
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
      _page = 0;
      _persistFilterState();
    });
    _loadPurchases();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;

    return DashboardShell(
      currentRoute: AppRoutes.pembelian,
      userName: getIt<CurrentUserStore>().displayName,
      userRole: getIt<CurrentUserStore>().userRole,
      headerActionLabel: 'Sync Migrasi',
      headerActionIcon: Icons.sync_rounded,
      onHeaderAction: () =>
          showSyncMigrationDialog(onCustomSuccess: _loadPurchases),
      lastSync: lastSyncFormatted,
      onScan: () => context.pushNamed(AppRoutes.scanner),
      showHeaderActionInAppBar: true,
      headerActions: const [],
      onRefresh: _loading ? null : _loadPurchases,
      onNavigate: (route) {
        if (route != AppRoutes.pembelian) context.go(route);
      },
      onLogout: () {
        getIt<TokenStorage>().clear();
        getIt<CurrentUserStore>().clear();
        context.go(AppRoutes.login);
      },
      child: Padding(
        padding: ResponsivePadding.all(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _FiltersSection(
                searchController: _searchController,
                searchColumn: _searchColumn,
                onSearchColumnChanged: (newCol) {
                  setState(() {
                    _searchColumn = newCol;
                    _page = 0;
                    _persistFilterState();
                  });
                  _loadPurchases();
                },
                searchFocus: _searchFocus,
                onSearchSubmitted: _onSearchSubmitted,
                sortBy: _sortBy,
                dir: _dir,
                size: _size,
                startDate: _startDate,
                endDate: _endDate,
                selectedEmpCodes: _selectedEmpCodes,
                availableEmpCodes: _availableEmpCodes,
                selectedCategories: _selectedCategories,
                availableCategories: _allCategories,
                onApply: (sortBy, dir, size, start, end, empCodes, categories) {
                  setState(() {
                    _sortBy = sortBy;
                    _dir = dir;
                    _size = size;
                    _startDate = start;
                    _endDate = end;
                    _selectedEmpCodes = empCodes;
                    _selectedCategories = categories;
                    _page = 0;
                    _persistFilterState();
                  });
                  _loadPurchases();
                },
                onDateRangeClear: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _page = 0;
                    _persistFilterState();
                  });
                  _loadPurchases();
                },
                onExport: _exportToExcel,
                isAdmin: (getIt<CurrentUserStore>().userRole?.toUpperCase() ==
                            'ADMIN' ||
                        getIt<CurrentUserStore>().userRole?.toUpperCase() ==
                            'MANAGER'),
                content: RefreshIndicator(
                  onRefresh: _loadPurchases,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_loading &&
                            _totalGrandSum != null &&
                            _items.isNotEmpty) ...[
                          _SummaryCard(
                            grandSum: _totalGrandSum,
                            totalQty: _totalQty,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_items.isEmpty)
                          _EmptySection(
                              onRetry: _loadPurchases,
                              isSearchEmpty: _search.trim().isEmpty)
                        else if (isMobile)
                          _PurchaseGroupedDeckView(items: _items)
                        else
                          CustomPlutoDataGrid<Purchase>(
                            data: _items,
                            totalPage: _totalPages,
                            currentPage: _page + 1,
                            totalElements: _totalElements,
                            onPageChanged: (newPage) {
                              setState(() {
                                _page = newPage - 1;
                                _persistFilterState();
                              });
                              _loadPurchases();
                            },
                            buildColumns: (ctx) =>
                                PurchaseGridHelper.getColumns(ctx),
                            buildRows: (data) =>
                                PurchaseGridHelper.mapToRows(data),
                          ),
                        if (!_loading && _items.isNotEmpty && isMobile) ...[
                          const SizedBox(height: 16),
                          _PaginationBar(
                            page: _page,
                            totalPages: _totalPages,
                            totalElements: _totalElements,
                            onPrev: _totalPages > 0 && _page > 0
                                ? () {
                                    setState(() {
                                      _page--;
                                      _persistFilterState();
                                    });
                                    _loadPurchases();
                                  }
                                : null,
                            onNext: _totalPages > 0 && _page < _totalPages - 1
                                ? () {
                                    setState(() {
                                      _page++;
                                      _persistFilterState();
                                    });
                                    _loadPurchases();
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
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.grandSum, required this.totalQty});
  final Object? grandSum;
  final Object? totalQty;

  static String _rp(Object? x) {
    if (x == null) return '—';
    final n = num.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), ''));
    if (n == null) return x.toString();

    // Format angka penuh dengan pemisah ribuan (titik)
    final String formatted = _formatNumber(n);
    return ' $formatted';
  }

  static String _formatNumber(num value) {
    // Handle angka desimal
    if (value % 1 != 0) {
      // Ada desimal, tampilkan dengan desimal
      final parts = value.toString().split('.');
      final integerPart = _addThousandSeparator(parts[0]);
      return '$integerPart,${parts[1]}';
    } else {
      // Angka bulat, tampilkan tanpa desimal
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_bag_rounded,
                color: Colors.green.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Pembelian',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  _rp(grandSum),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Qty',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  _rp(totalQty),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersSection extends StatefulWidget {
  const _FiltersSection({
    required this.searchController,
    required this.searchColumn,
    required this.onSearchColumnChanged,
    required this.searchFocus,
    required this.onSearchSubmitted,
    required this.sortBy,
    required this.dir,
    required this.size,
    required this.startDate,
    required this.endDate,
    required this.selectedEmpCodes,
    required this.availableEmpCodes,
    required this.selectedCategories,
    required this.availableCategories,
    required this.onApply,
    required this.onDateRangeClear,
    required this.onExport,
    required this.isAdmin,
    required this.content,
  });

  final TextEditingController searchController;
  final String searchColumn;
  final ValueChanged<String> onSearchColumnChanged;
  final FocusNode searchFocus;
  final VoidCallback onSearchSubmitted;
  final String sortBy;
  final String dir;
  final int size;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedEmpCodes;
  final List<String> availableEmpCodes;
  final List<String> selectedCategories;
  final List<String> availableCategories;
  final void Function(
    String sortBy,
    String dir,
    int size,
    DateTime? startDate,
    DateTime? endDate,
    List<String> selectedEmpCodes,
    List<String> categories,
  ) onApply;
  final VoidCallback onDateRangeClear;
  final VoidCallback onExport;
  final bool isAdmin;
  final Widget content;

  @override
  State<_FiltersSection> createState() => _FiltersSectionState();
}

class _FiltersSectionState extends State<_FiltersSection> {
  late String _sortBy;
  late String _dir;
  late int _size;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _selectedEmpCodes = [];
  List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _resetToCurrent();
  }

  void _resetToCurrent() {
    _sortBy = widget.sortBy;
    _dir = widget.dir;
    _size = widget.size;
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _selectedEmpCodes = List<String>.from(widget.selectedEmpCodes);
    _selectedCategories = List<String>.from(widget.selectedCategories);
  }

  @override
  void didUpdateWidget(_FiltersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortBy != widget.sortBy ||
        oldWidget.dir != widget.dir ||
        oldWidget.size != widget.size ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.selectedEmpCodes != widget.selectedEmpCodes ||
        oldWidget.selectedCategories != widget.selectedCategories) {
      _resetToCurrent();
    }
  }

  static String _fmt(DateTime? d) {
    if (d == null) return 'Pilih';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeFilterBadges = <Widget>[];

    if (widget.startDate != null || widget.endDate != null) {
      activeFilterBadges.add(
        FilterBadge(
          label: '${_fmt(widget.startDate)} - ${_fmt(widget.endDate)}',
          onRemove: widget.onDateRangeClear,
        ),
      );
    }

    if (widget.selectedEmpCodes.isNotEmpty) {
      activeFilterBadges.add(
        FilterBadge(
          label: 'Karyawan: ${widget.selectedEmpCodes.length} Terpilih',
          onRemove: () {
            widget.onApply(
              widget.sortBy,
              widget.dir,
              widget.size,
              widget.startDate,
              widget.endDate,
              [],
              widget.selectedCategories,
            );
          },
        ),
      );
    }

    if (widget.selectedCategories.isNotEmpty) {
      activeFilterBadges.add(
        FilterBadge(
          label: 'Kategori: ${widget.selectedCategories.length} Terpilih',
          onRemove: () {
            widget.onApply(
              widget.sortBy,
              widget.dir,
              widget.size,
              widget.startDate,
              widget.endDate,
              widget.selectedEmpCodes,
              [],
            );
          },
        ),
      );
    }

    return FixedSearchFilterLayout(
      searchBar: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.searchColumn,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Semua Kolom')),
                  DropdownMenuItem(value: 'barang', child: Text('Barang')),
                  DropdownMenuItem(
                      value: 'distributor', child: Text('Distributor')),
                  DropdownMenuItem(value: 'dept', child: Text('Dept')),
                  DropdownMenuItem(value: 'noNota', child: Text('No Nota')),
                  DropdownMenuItem(value: 'itemCode', child: Text('Code')),
                  DropdownMenuItem(value: 'tanggal', child: Text('Tanggal')),
                ],
                onChanged: (val) {
                  if (val != null) widget.onSearchColumnChanged(val);
                },
                style: theme.textTheme.bodyMedium,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ModernSearchBar(
              controller: widget.searchController,
              focusNode: widget.searchFocus,
              onSubmitted: widget.onSearchSubmitted,
              hintText:
                  'Cari di ${widget.searchColumn == 'ALL' ? 'Semua Kolom' : widget.searchColumn}...',
              onChanged: (_) {},
            ),
          ),
        ],
      ),
      filterTitle: 'Filter & Urutkan',
      activeFilterBadges:
          activeFilterBadges.isNotEmpty ? activeFilterBadges : null,
      filterContentBuilder: (close, refresh) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          // Rentang Tanggal
          FilterGroup(
            title: 'Rentang Tanggal',
            icon: Icons.date_range_rounded,
            children: [
              ModernDateChip(
                label: _fmt(_startDate),
                onTap: () async {
                  await _pickDate(context, true);
                  refresh();
                },
                selected: _startDate != null,
              ),
              const SizedBox(width: 8),
              Text('–', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              ModernDateChip(
                label: _fmt(_endDate),
                onTap: () async {
                  await _pickDate(context, false);
                  refresh();
                },
                selected: _endDate != null,
              ),
            ],
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const FilterLabel('Kode Karyawan'),
              MultiSelectSearchableDropdown<String>(
                values: _selectedEmpCodes,
                options: widget.availableEmpCodes,
                onChanged: (v) {
                  setState(() => _selectedEmpCodes = v);
                  refresh();
                },
                hintText: 'Semua Karyawan',
              ),
            ],
          ),

          const SizedBox(height: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const FilterLabel('Kategori (Dept)'),
              MultiSelectSearchableDropdown<String>(
                values: _selectedCategories,
                options: widget.availableCategories,
                onChanged: (v) {
                  setState(() => _selectedCategories = v);
                  refresh();
                },
                hintText: 'Semua Kategori',
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
                _dir,
                _size,
                _startDate,
                _endDate,
                _selectedEmpCodes,
                _selectedCategories,
              );
              close();
            },
            onReset: () {
              widget.onDateRangeClear();
              setState(() {
                _sortBy = 'docDate';
                _dir = 'desc';
                _size = 50;
                _startDate = null;
                _endDate = null;
                _selectedEmpCodes = [];
                _selectedCategories = [];
              });
              widget.onApply(
                _sortBy,
                _dir,
                _size,
                _startDate,
                _endDate,
                _selectedEmpCodes,
                _selectedCategories,
              );
              close();
            },
            additionalAction: widget.isAdmin
                ? OutlinedButton.icon(
                    onPressed: (_startDate != null && _endDate != null)
                        ? () {
                            close();
                            widget.onExport();
                          }
                        : null,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export ke Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF107C41),
                      side: BorderSide(
                        color: (_startDate != null && _endDate != null)
                            ? const Color(0xFF107C41)
                            : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
      child: widget.content,
    );
  }
}

class _PurchaseDesktopTableView extends StatelessWidget {
  const _PurchaseDesktopTableView({required this.items});
  final List<Purchase> items;

  static String _v(Object? x) =>
      x?.toString().trim().isEmpty ?? true ? '—' : x.toString();

  static String _rp(Object? x) {
    if (x == null) return '—';
    final n = num.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), ''));
    if (n == null) return x.toString();
    final reversed = n.toInt().toString().split('').reversed.join();
    final chunks = <String>[];
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      chunks.add(reversed.substring(i, end));
    }
    final formatted = chunks.join('.').split('').reversed.join();
    return ' $formatted';
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    final str = d.toString();
    if (str.isEmpty) return '—';
    try {
      final date = DateTime.tryParse(str);
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return str;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveDataTable(
      minColumnWidth: 180,
      columns: const [
        DataColumn(label: Text('Tanggal')),
        DataColumn(label: Text('No Nota')),
        DataColumn(label: Text('Code')),
        DataColumn(label: Text('Nama User')),
        DataColumn(label: Text('Barang')),
        DataColumn(label: Text('Qty')),
        DataColumn(label: Text('Harga')),
        DataColumn(label: Text('Total')),
      ],
      rows: items.map((p) {
        return DataRow(cells: [
          DataCell(Text(_fmtDate(p.docDate))),
          DataCell(Text(_v(p.docNoP))),
          DataCell(Text(_v(p.itemCode))),
          DataCell(Text(_v(p.parName))),
          DataCell(Text(_v(p.itemName))),
          DataCell(Text(_v(p.qty))),
          DataCell(Text(_rp(p.price))),
          DataCell(Text(_rp(p.grandTotal))),
        ]);
      }).toList(),
    );
  }
}

class _PurchaseGroupedDeckView extends StatelessWidget {
  const _PurchaseGroupedDeckView({required this.items});
  final List<Purchase> items;

  static String _v(Object? x) =>
      x?.toString().trim().isEmpty ?? true ? '—' : x.toString();

  static String _rp(Object? x) {
    if (x == null) return '—';
    final n = num.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), ''));
    if (n == null) return x.toString();
    final reversed = n.toInt().toString().split('').reversed.join();
    final chunks = <String>[];
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      chunks.add(reversed.substring(i, end));
    }
    final formatted = chunks.join('.').split('').reversed.join();
    return ' $formatted';
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    final str = d.toString();
    if (str.isEmpty) return '—';
    try {
      final date = DateTime.tryParse(str);
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return str;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Group items by docNoP
    final grouped = <String, List<Purchase>>{};
    for (final p in items) {
      final key = _v(p.docNoP);
      grouped.putIfAbsent(key, () => []).add(p);
    }

    final keys = grouped.keys.toList();

    return ResponsiveDeckGrid(
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final docNo = keys[i];
        final group = grouped[docNo]!;
        final first = group.first;

        // Calculate grand total for the group
        double groupTotal = 0;
        for (final p in group) {
          final gt = double.tryParse(p.grandTotal?.toString() ?? '0') ?? 0;
          groupTotal += gt;
        }

        return DataDeckCard(
          headerLeft: _fmtDate(first.docDate),
          headerRight: 'No. $docNo',
          title: _v(first.parName),
          rows: [
            (label: 'Total Pembelian', value: _rp(groupTotal)),
          ],
          onTap: () => _showDetailSheet(context, docNo, group),
        );
      },
    );
  }

  static void _showDetailSheet(
      BuildContext context, String docNo, List<Purchase> group) {
    final first = group.first;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detail Pembelian',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'No. Nota: $docNo',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.content_copy_rounded,
                                      size: 12),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: docNo));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Nomor Nota disalin'),
                                        duration: Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                            Text(
                              'Distributor: ${_v(first.parName)}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Grand Sum',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _rp(group.fold<double>(
                                0,
                                (prev, element) =>
                                    prev +
                                    (double.tryParse(
                                            element.grandTotal?.toString() ??
                                                '0') ??
                                        0))),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(builder: (context, constraints) {
                  final isMobileDetail = constraints.maxWidth < 600;
                  return ResponsiveDataTable(
                    minColumnWidth: isMobileDetail ? 180 : 180,
                    columns: [
                      if (!isMobileDetail) ...[
                        const DataColumn(label: Text('Tanggal')),
                        const DataColumn(label: Text('No Nota')),
                        const DataColumn(label: Text('Code')),
                        const DataColumn(label: Text('Nama Distributor')),
                      ],
                      const DataColumn(label: Text('Barang')),
                      const DataColumn(label: Text('Qty')),
                      const DataColumn(label: Text('Harga')),
                      const DataColumn(label: Text('Total')),
                    ],
                    rows: group.map((p) {
                      return DataRow(cells: [
                        if (!isMobileDetail) ...[
                          DataCell(Text(_fmtDate(p.docDate))),
                          DataCell(CopyableTextCell(text: _v(p.docNoP))),
                          DataCell(Text(_v(p.itemCode))),
                          DataCell(Text(_v(p.parName))),
                        ],
                        DataCell(CopyableTextCell(text: _v(p.itemName))),
                        DataCell(Text(_v(p.qty))),
                        DataCell(Text(_rp(p.price))),
                        DataCell(Text(_rp(p.grandTotal))),
                      ]);
                    }).toList(),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
  const _EmptySection({required this.onRetry, this.isSearchEmpty = false});
  final VoidCallback onRetry;
  final bool isSearchEmpty;

  @override
  Widget build(BuildContext context) {
    final isTeknisi =
        getIt<CurrentUserStore>().userRole?.toUpperCase() == 'TEKNISI';
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
          Icon(
            isSearchEmpty && isTeknisi
                ? Icons.search_rounded
                : Icons.shopping_bag_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isSearchEmpty && isTeknisi
                ? 'Silakan masukkan kata kunci pencarian di atas untuk mencari No Nota BL atau Serial Number (SN).'
                : 'Tidak ada data pembelian',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
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
                  foregroundColor: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
