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

/// State filter Penjualan disimpan agar saat pindah menu lalu balik, filter tetap.
class _SalesFilterState {
  _SalesFilterState._();
  static String search = '';
  static String searchColumn = 'ALL';
  static int page = 0;
  static int size = 50;
  static String sortBy = 'docDate';
  static String direction = 'desc';
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
    direction = 'desc';
    startDateMillis = null;
    endDateMillis = null;
    selectedEmpCodes = [];
    categories = [];
  }
}

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> with PresenceActionMixin {
  @override
  void initState() {
    super.initState();
    GlobalStateResetter.register(_SalesFilterState.reset);
  }

  @override
  Widget build(BuildContext context) {
    return const _SalesContent();
  }
}

class _SalesContent extends StatefulWidget {
  const _SalesContent();

  @override
  State<_SalesContent> createState() => _SalesContentState();
}

class _SalesContentState extends State<_SalesContent> with MigrationSyncMixin {
  bool _loading = true;
  List<Sales> _items = [];
  int _page = 0;
  int _size = 50;
  int _totalElements = 0;
  int _totalPages = 0;
  Object? _totalGrandSum;
  Object? _totalQty;
  String _search = '';
  String _searchColumn = 'ALL';
  String _sortBy = 'docDate';
  String _direction = 'desc';
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

  static String _v(Object? x) =>
      x?.toString().trim().isEmpty ?? true ? '—' : x.toString();

  List<String> get _availableEmpCodes {
    return _allEmpCodes.toList()..sort();
  }

  void _restoreFilterState() {
    _search = _SalesFilterState.search;
    _searchColumn = _SalesFilterState.searchColumn;
    _searchController.text = _search;
    _page = _SalesFilterState.page;
    _size = _SalesFilterState.size;
    _sortBy = _SalesFilterState.sortBy;
    _direction = _SalesFilterState.direction;
    _startDate = _SalesFilterState.startDateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(
            _SalesFilterState.startDateMillis!)
        : null;
    _endDate = _SalesFilterState.endDateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(_SalesFilterState.endDateMillis!)
        : null;
    _selectedEmpCodes = List<String>.from(_SalesFilterState.selectedEmpCodes);
    _selectedCategories = List<String>.from(_SalesFilterState.categories);
  }

  void _persistFilterState() {
    _SalesFilterState.search = _search;
    _SalesFilterState.searchColumn = _searchColumn;
    _SalesFilterState.page = _page;
    _SalesFilterState.size = _size;
    _SalesFilterState.sortBy = _sortBy;
    _SalesFilterState.direction = _direction;
    _SalesFilterState.startDateMillis = _startDate?.millisecondsSinceEpoch;
    _SalesFilterState.endDateMillis = _endDate?.millisecondsSinceEpoch;
    _SalesFilterState.selectedEmpCodes = List<String>.from(_selectedEmpCodes);
    _SalesFilterState.categories = List<String>.from(_selectedCategories);
  }

  @override
  void initState() {
    super.initState();
    _restoreFilterState();
    fetchLastSync();
    _loadAllEmpCodes(); // Load all employee codes first
    _loadAllCategories(); // Load all categories
    _loadSales();
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
      _loadSales();
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

  static List<Sales> _parseContent(Object? content) {
    if (content == null) return [];
    if (content is List) {
      return content
          .map((e) {
            if (e is Sales) return e;
            if (e is Map) return Sales.fromJson(Map<String, dynamic>.from(e));
            return null;
          })
          .whereType<Sales>()
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
      // Silently fail - we'll still collect codes from filtered results
    }
  }

  Future<void> _loadAllCategories() async {
    try {
      final api = getIt<SalesControllerApi>();
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

  Future<void> _loadSales() async {
    final userRole = getIt<CurrentUserStore>().userRole?.toUpperCase();
    if (userRole == 'TEKNISI' && _search.trim().isEmpty) {
      setState(() {
        _items = [];
        _totalGrandSum = null;
        _totalQty = null;
        _totalElements = 0;
        _totalPages = 0;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final api = getIt<SalesControllerApi>();
      final startStr = _formatDateParam(_startDate);
      final endStr = _formatDateParam(_endDate);
      final response = await api.getAllSales(
        page: _page,
        size: _size,
        sortBy: _sortBy,
        direction: _direction,
        startDate: startStr.isEmpty ? null : startStr,
        endDate: endStr.isEmpty ? null : endStr,
        empCode: _selectedEmpCodes.isEmpty ? null : _selectedEmpCodes.join(','),
        search: _search.trim().isEmpty ? null : _search.trim(),
        searchColumn: _searchColumn == 'ALL' ? null : _searchColumn,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories,
      );
      final pageData = response.data?.data;
      if (isResponseSuccess(response.data?.status) && pageData != null) {
        var parsedItems = _parseContent(pageData.content);
        // TEKNISI: exact match filter on docNo
        if (userRole == 'TEKNISI' && _search.trim().isNotEmpty) {
          final q = _search.trim().toUpperCase();
          parsedItems = parsedItems
              .where((s) => (s.docNo?.toString() ?? '').toUpperCase() == q)
              .toList();
        }
        setState(() {
          _items = parsedItems;
          for (final item in parsedItems) {
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
          var parsedItems = _parseContent(data);
          // TEKNISI: exact match filter on docNo
          if (userRole == 'TEKNISI' && _search.trim().isNotEmpty) {
            final q = _search.trim().toUpperCase();
            parsedItems = parsedItems
                .where((s) => (s.docNo?.toString() ?? '').toUpperCase() == q)
                .toList();
          }
          int totalElements = 0;
          int totalPages = 1;
          Object? totalGrandSum = body['totalGrandSum'];
          Object? totalQty = body['totalQty'];
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
              _items = parsedItems;
              for (final item in parsedItems) {
                final code = _v(item.empCode);
                if (code.isNotEmpty && code != '—') _allEmpCodes.add(code);
              }
              _totalGrandSum = totalGrandSum;
              _totalQty = totalQty;
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
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _exportToExcel() async {
    setState(() {
      _loading = true;
    });
    try {
      final api = getIt<ApiNewEndpoints>();
      final startStr = _formatDateParam(_startDate);
      final endStr = _formatDateParam(_endDate);

      final bytes = await api.exportSales(
        startDate: startStr.isEmpty ? null : startStr,
        endDate: endStr.isEmpty ? null : endStr,
        empCode: _selectedEmpCodes.isEmpty ? null : _selectedEmpCodes.join(','),
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (bytes.isNotEmpty) {
        await FileDownloadService.downloadFile(
          bytes,
          "sales_${_formatDateParam(DateTime.now())}.xlsx",
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        );
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
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
    _loadSales();
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
    _loadSales();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;

    return DashboardShell(
      currentRoute: AppRoutes.penjualan,
      userName: getIt<CurrentUserStore>().displayName,
      userRole: getIt<CurrentUserStore>().userRole,
      headerActionLabel: 'Sync Migrasi',
      headerActionIcon: Icons.sync_rounded,
      onHeaderAction: () =>
          showSyncMigrationDialog(onCustomSuccess: _loadSales),
      lastSync: lastSyncFormatted,
      onScan: () => context.pushNamed(AppRoutes.scanner),
      showHeaderActionInAppBar: true,
      headerActions: const [],
      onRefresh: _loading ? null : _loadSales,
      onNavigate: (route) {
        if (route != AppRoutes.penjualan) context.go(route);
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
                  _loadSales();
                },
                searchFocus: _searchFocus,
                onSearchSubmitted: _onSearchSubmitted,
                sortBy: _sortBy,
                direction: _direction,
                size: _size,
                startDate: _startDate,
                endDate: _endDate,
                selectedEmpCodes: _selectedEmpCodes,
                availableEmpCodes: _availableEmpCodes,
                selectedCategories: _selectedCategories,
                availableCategories: _allCategories,
                onApply: (sortBy, direction, size, start, end, empCodes,
                    categories) {
                  setState(() {
                    _sortBy = sortBy;
                    _direction = direction;
                    _size = size;
                    _startDate = start;
                    _endDate = end;
                    _selectedEmpCodes = empCodes;
                    _selectedCategories = categories;
                    _page = 0;
                    _persistFilterState();
                  });
                  _loadSales();
                },
                onDateRangeClear: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _page = 0;
                    _persistFilterState();
                  });
                  _loadSales();
                },
                onExport: _exportToExcel,
                isAdmin: (getIt<CurrentUserStore>().userRole?.toUpperCase() ==
                            'ADMIN' ||
                        getIt<CurrentUserStore>().userRole?.toUpperCase() ==
                            'MANAGER'),
                content: RefreshIndicator(
                  onRefresh: _loadSales,
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
                              onRetry: _loadSales,
                              isSearchEmpty: _search.trim().isEmpty)
                        else if (isMobile)
                          _SalesGroupedDeckView(items: _items)
                        else
                          CustomPlutoDataGrid<Sales>(
                            data: _items,
                            totalPage: _totalPages,
                            currentPage: _page + 1,
                            totalElements: _totalElements,
                            onPageChanged: (newPage) {
                              setState(() {
                                _page = newPage - 1;
                                _persistFilterState();
                              });
                              _loadSales();
                            },
                            buildColumns: (ctx) =>
                                SalesGridHelper.getColumns(ctx),
                            buildRows: (data) =>
                                SalesGridHelper.mapToRows(data),
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
                                    _loadSales();
                                  }
                                : null,
                            onNext: _totalPages > 0 && _page < _totalPages - 1
                                ? () {
                                    setState(() {
                                      _page++;
                                      _persistFilterState();
                                    });
                                    _loadSales();
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
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_cart_rounded,
                color: Colors.amber.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Penjualan',
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
    required this.direction,
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
  final String direction;
  final int size;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedEmpCodes;
  final List<String> availableEmpCodes;
  final List<String> selectedCategories;
  final List<String> availableCategories;
  final void Function(
    String sortBy,
    String direction,
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
  late String _direction;
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
    _direction = widget.direction;
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
        oldWidget.direction != widget.direction ||
        oldWidget.size != widget.size ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.selectedEmpCodes != widget.selectedEmpCodes ||
        oldWidget.selectedCategories != widget.selectedCategories) {
      _resetToCurrent();
    }
  }

  static const _sortOptions = [
    ('docDate', 'Tanggal Dokumen'),
    ('docNo', 'No. Dokumen'),
    ('code', 'Kode'),
    ('parName', 'Nama Partner'),
    ('itemName', 'Nama Barang'),
    ('qty', 'Qty'),
    ('price', 'Harga'),
    ('grandTotal', 'Grand Total'),
    ('empCode', 'Kode Karyawan'),
  ];

  static String _fmt(DateTime? d) {
    if (d == null) return 'Pilih';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
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
              widget.direction,
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
              widget.direction,
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
                  DropdownMenuItem(value: 'code', child: Text('Kode')),
                  DropdownMenuItem(value: 'noNota', child: Text('No Nota')),
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
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                      if (_endDate != null && _endDate!.isBefore(picked)) {
                        _endDate = picked;
                      }
                    });
                    refresh();
                  }
                },
                selected: _startDate != null,
              ),
              const SizedBox(width: 8),
              Text('–', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              ModernDateChip(
                label: _fmt(_endDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _endDate = picked;
                      if (_startDate != null && _startDate!.isAfter(picked)) {
                        _startDate = picked;
                      }
                    });
                    refresh();
                  }
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
                _direction,
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
                _direction = 'desc';
                _size = 50;
                _startDate = null;
                _endDate = null;
                _selectedEmpCodes = [];
                _selectedCategories = [];
              });
              widget.onApply(
                _sortBy,
                _direction,
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

class _SalesGroupedDeckView extends StatelessWidget {
  const _SalesGroupedDeckView({required this.items});
  final List<Sales> items;

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

    // Group items by docNo
    final grouped = <String, List<Sales>>{};
    for (final s in items) {
      final key = _v(s.docNo);
      grouped.putIfAbsent(key, () => []).add(s);
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
        for (final s in group) {
          final gt = double.tryParse(s.grandTotal?.toString() ?? '0') ?? 0;
          groupTotal += gt;
        }

        return DataDeckCard(
          headerLeft: _fmtDate(first.docDate),
          headerRight: 'No. $docNo',
          title: _v(first.parName),
          rows: [
            (label: 'Total Transaksi', value: _rp(groupTotal)),
            (label: 'Marketing Code', value: _v(first.empCode)),
          ],
          onTap: () => _showDetailSheet(context, docNo, group),
        );
      },
    );
  }

  static void _showDetailSheet(
      BuildContext context, String docNo, List<Sales> group) {
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
                              'Detail Penjualan',
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
                                    maxLines: 2,
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
                              'Partner: ${_v(first.parName)}',
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
                        const DataColumn(label: Text('Nama User')),
                      ],
                      const DataColumn(label: Text('Barang')),
                      const DataColumn(label: Text('Qty')),
                      const DataColumn(label: Text('Harga')),
                      const DataColumn(label: Text('Total')),
                      const DataColumn(label: Text('Marketing')),
                    ],
                    rows: group.map((s) {
                      return DataRow(cells: [
                        if (!isMobileDetail) ...[
                          DataCell(Text(_fmtDate(s.docDate))),
                          DataCell(CopyableTextCell(text: _v(s.docNo))),
                          DataCell(Text(_v(s.parName))),
                        ],
                        DataCell(CopyableTextCell(text: _v(s.itemName))),
                        DataCell(Text(_v(s.qty))),
                        DataCell(Text(_rp(s.price))),
                        DataCell(Text(_rp(s.grandTotal))),
                        DataCell(Text(_v(s.empCode))),
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
                : Icons.shopping_cart_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isSearchEmpty && isTeknisi
                ? 'Silakan masukkan kata kunci pencarian di atas untuk mencari No Nota JL atau Serial Number (SN).'
                : 'Tidak ada data penjualan',
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
