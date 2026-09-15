import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/auth/global_state_resetter.dart';
import 'package:stok_anandam/core/network/file_download_service.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/features/layout/dashboard_shell.dart';
import 'package:stok_anandam/features/shared/custom_pluto_grid.dart';
import 'package:stok_anandam/features/shared/detail_row_with_copy.dart';
import 'package:stok_anandam/features/shared/grid_helpers.dart';
import 'package:stok_anandam/features/shared/item_deck_card.dart';
import 'package:stok_anandam/features/shared/modern_filter.dart';
import 'package:stok_anandam/features/shared/responsive_deck_grid.dart';
import 'package:stok_anandam/features/shared/responsive_padding.dart';
import 'package:stok_anandam/features/shared/responsive_table.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';

/// State filter Piutang agar bertahan saat pindah menu.
class _PiutangFilterState {
  _PiutangFilterState._();
  static String tab = 'UNPAID';
  static int page = 0;
  static int size = 50;
  static String search = '';
  static String searchColumn = 'ALL';
  static DateTime? startDate;
  static DateTime? endDate;
  static List<String> empCodes = [];
  static List<String> categories = [];

  static void reset() {
    tab = 'UNPAID';
    page = 0;
    size = 50;
    search = '';
    searchColumn = 'ALL';
    startDate = null;
    endDate = null;
    empCodes = [];
    categories = [];
  }
}

class PiutangPage extends StatefulWidget {
  const PiutangPage({super.key});

  @override
  State<PiutangPage> createState() => _PiutangPageState();
}

class _PiutangPageState extends State<PiutangPage> {
  @override
  void initState() {
    super.initState();
    GlobalStateResetter.register(_PiutangFilterState.reset);
  }

  @override
  Widget build(BuildContext context) => const _PiutangContent();
}

class _PiutangContent extends StatefulWidget {
  const _PiutangContent();

  @override
  State<_PiutangContent> createState() => _PiutangContentState();
}

class _PiutangContentState extends State<_PiutangContent> {
  bool _loading = true;
  String? _error;
  List<PiutangItem> _items = [];
  String _tab = _PiutangFilterState.tab;
  int _page = _PiutangFilterState.page;
  int _size = _PiutangFilterState.size;
  int _totalPages = 0;
  int _totalElements = 0;
  Object? _totalGrandSum;

  String _search = _PiutangFilterState.search;
  String _searchColumn = _PiutangFilterState.searchColumn;
  DateTime? _startDate = _PiutangFilterState.startDate;
  DateTime? _endDate = _PiutangFilterState.endDate;
  List<String> _empCodes = List.of(_PiutangFilterState.empCodes);
  List<String> _categories = List.of(_PiutangFilterState.categories);

  List<String> _availableEmpCodes = [];
  List<String> _availableCategories = [];
  final _searchController =
      TextEditingController(text: _PiutangFilterState.search);
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  static const _searchDebounceDuration = Duration(milliseconds: 450);

  bool get _isAdminOrManager {
    final role = getIt<CurrentUserStore>().userRole?.toUpperCase();
    return role == 'ADMIN' || role == 'MANAGER';
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _load();
    _searchController.addListener(_onSearchChanged);
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
      _load();
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

  Future<void> _loadOptions() async {
    try {
      final api = getIt<ApiNewEndpoints>();
      final codes = await api.getPiutangEmployeeCodes();
      final cats = await api.getPiutangCategories();
      if (!mounted) return;
      setState(() {
        _availableEmpCodes = codes.map((c) => c.empCode).toList()..sort();
        _availableCategories = cats;
      });
    } catch (e) {
      debugPrint('load piutang options failed: $e');
    }
  }

  void _persistFilterState() {
    _PiutangFilterState.tab = _tab;
    _PiutangFilterState.page = _page;
    _PiutangFilterState.size = _size;
    _PiutangFilterState.search = _search;
    _PiutangFilterState.searchColumn = _searchColumn;
    _PiutangFilterState.startDate = _startDate;
    _PiutangFilterState.endDate = _endDate;
    _PiutangFilterState.empCodes = List.of(_empCodes);
    _PiutangFilterState.categories = List.of(_categories);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = getIt<ApiNewEndpoints>();
      final result = await api.getPiutang(
        tab: _tab,
        page: _page,
        size: _size,
        startDate: _startDate,
        endDate: _endDate,
        empCodes: _empCodes,
        categories: _categories,
        search: _search,
        searchColumn: _searchColumn,
      );
      if (!mounted) return;
      setState(() {
        _items = result.content;
        _totalPages = result.totalPages;
        _totalElements = result.totalElements;
        _totalGrandSum = result.totalGrandSum;
        _loading = false;
        _persistFilterState();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Gagal memuat piutang (${e.response?.statusCode ?? 'network'})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _setTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _page = 0;
    });
    _persistFilterState();
    _load();
  }

  Future<void> _export() async {
    if (!_isAdminOrManager) return;
    try {
      final bytes = await getIt<ApiNewEndpoints>().exportPiutang(
        tab: _tab,
        startDate: _startDate,
        endDate: _endDate,
        empCodes: _empCodes,
        categories: _categories,
        search: _search,
        searchColumn: _searchColumn,
      );
      await FileDownloadService.downloadFile(
        bytes,
        'piutang_${_tab.toLowerCase()}_${DateTime.now().toIso8601String().split('T').first}.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Export Excel berhasil diunduh'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export gagal: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _onSearchSubmitted() {
    _search = _searchController.text;
    setState(() {
      _page = 0;
      _persistFilterState();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;

    return DashboardShell(
      currentRoute: AppRoutes.piutang,
      userName: getIt<CurrentUserStore>().displayName,
      userRole: getIt<CurrentUserStore>().userRole,
      headerActionLabel: _isAdminOrManager ? 'Export Excel' : 'Refresh',
      headerActionIcon: _isAdminOrManager
          ? Icons.file_download_rounded
          : Icons.refresh_rounded,
      onHeaderAction: _isAdminOrManager ? _export : _load,
      showHeaderActionInAppBar: true,
      onScan: () => context.pushNamed(AppRoutes.scanner),
      onRefresh: _loading ? null : _load,
      onNavigate: (route) {
        if (route != AppRoutes.piutang) context.go(route);
      },
      onLogout: () async {
        getIt<TokenStorage>().clear();
        getIt<CurrentUserStore>().clear();
        if (context.mounted) context.go(AppRoutes.login);
      },
      child: Padding(
        padding: ResponsivePadding.all(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'UNPAID',
                        label: Text('UNPAID'),
                        icon: Icon(Icons.pending_actions_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 'PAID',
                        label: Text('PAID'),
                        icon: Icon(Icons.task_alt_rounded, size: 16),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => _setTab(s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _PiutangFiltersSection(
                searchController: _searchController,
                searchColumn: _searchColumn,
                onSearchColumnChanged: (newCol) {
                  setState(() {
                    _searchColumn = newCol;
                    _page = 0;
                    _persistFilterState();
                  });
                  _load();
                },
                searchFocus: _searchFocus,
                onSearchSubmitted: _onSearchSubmitted,
                size: _size,
                startDate: _startDate,
                endDate: _endDate,
                selectedEmpCodes: _empCodes,
                availableEmpCodes: _availableEmpCodes,
                selectedCategories: _categories,
                availableCategories: _availableCategories,
                onApply: (size, start, end, empCodes, categories) {
                  setState(() {
                    _size = size;
                    _startDate = start;
                    _endDate = end;
                    _empCodes = empCodes;
                    _categories = categories;
                    _page = 0;
                    _persistFilterState();
                  });
                  _load();
                },
                onDateRangeClear: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _page = 0;
                    _persistFilterState();
                  });
                  _load();
                },
                onExport: _export,
                isAdmin: _isAdminOrManager,
                content: RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_loading &&
                            _totalGrandSum != null &&
                            _items.isNotEmpty) ...[
                          _PiutangSummaryCard(
                            grandSum: _totalGrandSum,
                            tab: _tab,
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
                        else if (_error != null)
                          _ErrorSection(message: _error!, onRetry: _load)
                        else if (_items.isEmpty)
                          _EmptySection(
                            emptyLabel: _tab == 'UNPAID'
                                ? 'Tidak ada transaksi belum dibayar'
                                : 'Tidak ada transaksi sudah dibayar',
                          )
                        else if (isMobile)
                          _PiutangGroupedDeckView(items: _items)
                        else
                          CustomPlutoDataGrid<PiutangItem>(
                            data: _items,
                            totalPage: _totalPages,
                            currentPage: _page + 1,
                            totalElements: _totalElements,
                            onPageChanged: (newPage) {
                              setState(() {
                                _page = newPage - 1;
                                _persistFilterState();
                              });
                              _load();
                            },
                            buildColumns: (ctx) =>
                                PiutangGridHelper.getColumns(ctx),
                            buildRows: (data) =>
                                PiutangGridHelper.mapToRows(data),
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
                                    _load();
                                  }
                                : null,
                            onNext: _totalPages > 0 && _page < _totalPages - 1
                                ? () {
                                    setState(() {
                                      _page++;
                                      _persistFilterState();
                                    });
                                    _load();
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

class _PiutangSummaryCard extends StatelessWidget {
  const _PiutangSummaryCard({required this.grandSum, required this.tab});
  final Object? grandSum;
  final String tab;

  static String _rp(Object? x) {
    if (x == null) return '—';
    final n = num.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), ''));
    if (n == null) return x.toString();
    return ' ${_addThousandSeparator(n.toInt().abs().toString())}';
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
              color: tab == 'UNPAID' ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tab == 'UNPAID'
                  ? Icons.pending_actions_rounded
                  : Icons.task_alt_rounded,
              color: tab == 'UNPAID'
                  ? Colors.orange.shade700
                  : Colors.green.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab == 'UNPAID'
                      ? 'Total Piutang Belum Dibayar'
                      : 'Total Piutang Sudah Dibayar',
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
        ],
      ),
    );
  }
}

class _PiutangFiltersSection extends StatefulWidget {
  const _PiutangFiltersSection({
    required this.searchController,
    required this.searchColumn,
    required this.onSearchColumnChanged,
    required this.searchFocus,
    required this.onSearchSubmitted,
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
  final int size;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedEmpCodes;
  final List<String> availableEmpCodes;
  final List<String> selectedCategories;
  final List<String> availableCategories;
  final void Function(
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
  State<_PiutangFiltersSection> createState() => _PiutangFiltersSectionState();
}

class _PiutangFiltersSectionState extends State<_PiutangFiltersSection> {
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
    _size = widget.size;
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _selectedEmpCodes = List<String>.from(widget.selectedEmpCodes);
    _selectedCategories = List<String>.from(widget.selectedCategories);
  }

  @override
  void didUpdateWidget(_PiutangFiltersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size ||
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
                  DropdownMenuItem(value: 'noNota', child: Text('No Nota')),
                  DropdownMenuItem(value: 'barang', child: Text('Barang')),
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'dept', child: Text('Dept')),
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
                _size = 50;
                _startDate = null;
                _endDate = null;
                _selectedEmpCodes = [];
                _selectedCategories = [];
              });
              widget.onApply(
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
                    onPressed: () {
                      close();
                      widget.onExport();
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export ke Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF107C41),
                      side: const BorderSide(color: Color(0xFF107C41)),
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

class _PiutangGroupedDeckView extends StatelessWidget {
  const _PiutangGroupedDeckView({required this.items});
  final List<PiutangItem> items;

  static String _v(Object? x) =>
      x?.toString().trim().isEmpty ?? true ? '—' : x.toString();

  static String _rp(Object? x) {
    if (x == null) return '—';
    final n = num.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), ''));
    if (n == null) return x.toString();
    final reversed = n.toInt().abs().toString().split('').reversed.join();
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

    final grouped = <String, List<PiutangItem>>{};
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

        double groupTotal = 0;
        for (final s in group) {
          final gt = double.tryParse(s.grandTotal?.toString() ?? '0') ?? 0;
          groupTotal += gt;
        }

        final isPaid =
            (first.statusBayar ?? '').toUpperCase() == 'PAID' ||
            (first.statusBayar ?? '').toUpperCase() == 'LUNAS';

        return DataDeckCard(
          headerLeft: _fmtDate(first.docDate),
          headerRight: 'No. $docNo',
          title: _v(first.parName),
          chip: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isPaid ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              first.statusBayar ?? '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green.shade700 : Colors.orange.shade800,
              ),
            ),
          ),
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
      BuildContext context, String docNo, List<PiutangItem> group) {
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
                              'Detail Piutang',
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
                      const DataColumn(label: Text('Total')),
                      const DataColumn(label: Text('Terbayar')),
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
                        DataCell(Text(_rp(s.grandTotal))),
                        DataCell(Text(_rp(s.paidTotal))),
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.emptyLabel});
  final String emptyLabel;

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
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}