import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/auth/global_state_resetter.dart';
import 'package:stok_anandam/core/network/file_download_service.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/features/layout/dashboard_shell.dart';
import 'package:stok_anandam/features/shared/custom_pluto_grid.dart';
import 'package:stok_anandam/features/shared/grid_helpers.dart';
import 'package:stok_anandam/features/shared/item_deck_card.dart';
import 'package:stok_anandam/features/shared/responsive_padding.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';

/// State filter Hutang agar bertahan saat pindah menu.
class _HutangFilterState {
  _HutangFilterState._();
  static String tab = 'UNPAID';
  static int page = 0;
  static String search = '';
  static String searchColumn = 'ALL';
  static DateTime? startDate;
  static DateTime? endDate;
  static List<String> empCodes = [];
  static List<String> categories = [];

  static void reset() {
    tab = 'UNPAID';
    page = 0;
    search = '';
    searchColumn = 'ALL';
    startDate = null;
    endDate = null;
    empCodes = [];
    categories = [];
  }
}

class HutangPage extends StatefulWidget {
  const HutangPage({super.key});

  @override
  State<HutangPage> createState() => _HutangPageState();
}

class _HutangPageState extends State<HutangPage> {
  @override
  void initState() {
    super.initState();
    GlobalStateResetter.register(_HutangFilterState.reset);
  }

  @override
  Widget build(BuildContext context) => const _HutangContent();
}

class _HutangContent extends StatefulWidget {
  const _HutangContent();

  @override
  State<_HutangContent> createState() => _HutangContentState();
}

class _HutangContentState extends State<_HutangContent> {
  bool _loading = true;
  String? _error;
  List<HutangItem> _items = [];
  String _tab = _HutangFilterState.tab;
  int _page = _HutangFilterState.page;
  static const int _size = 50;
  int _totalPages = 0;
  int _totalElements = 0;
  Object? _totalGrandSum;

  String _search = _HutangFilterState.search;
  String _searchColumn = _HutangFilterState.searchColumn;
  DateTime? _startDate = _HutangFilterState.startDate;
  DateTime? _endDate = _HutangFilterState.endDate;
  List<String> _empCodes = List.of(_HutangFilterState.empCodes);
  List<String> _categories = List.of(_HutangFilterState.categories);

  List<String> _availableEmpCodes = [];
  List<String> _availableCategories = [];
  final _searchController = TextEditingController(text: _HutangFilterState.search);

  bool get _isAdminOrManager {
    final role = getIt<CurrentUserStore>().userRole?.toUpperCase();
    return role == 'ADMIN' || role == 'MANAGER';
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final api = getIt<ApiNewEndpoints>();
      final codes = await api.getHutangEmployeeCodes();
      final cats = await api.getHutangCategories();
      if (!mounted) return;
      setState(() {
        _availableEmpCodes = codes.map((c) => c.empCode).toList()..sort();
        _availableCategories = cats;
      });
    } catch (e) {
      debugPrint('load hutang options failed: $e');
    }
  }

  void _persistFilterState() {
    _HutangFilterState.tab = _tab;
    _HutangFilterState.page = _page;
    _HutangFilterState.search = _search;
    _HutangFilterState.searchColumn = _searchColumn;
    _HutangFilterState.startDate = _startDate;
    _HutangFilterState.endDate = _endDate;
    _HutangFilterState.empCodes = List.of(_empCodes);
    _HutangFilterState.categories = List.of(_categories);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = getIt<ApiNewEndpoints>();
      final result = await api.getHutang(
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
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat hutang (${e.response?.statusCode ?? 'network'})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reload() async {
    _page = 0;
    await _load();
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
      final bytes = await getIt<ApiNewEndpoints>().exportHutang(
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
        'hutang_${_tab.toLowerCase()}_${DateTime.now().toIso8601String().split('T').first}.xlsx',
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
            content: Text('Export gagal: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _page = 0;
      });
      _persistFilterState();
      _load();
    }
  }

  Future<void> _pickEmpCodes() async {
    if (_availableEmpCodes.isEmpty) return;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _MultiSelectDialog<String>(
        title: 'Kode Karyawan',
        options: _availableEmpCodes,
        selected: _empCodes,
      ),
    );
    if (selected != null) {
      setState(() {
        _empCodes = selected;
        _page = 0;
      });
      _persistFilterState();
      _load();
    }
  }

  Future<void> _pickCategories() async {
    if (_availableCategories.isEmpty) return;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _MultiSelectDialog<String>(
        title: 'Kategori (Dept)',
        options: _availableCategories,
        selected: _categories,
      ),
    );
    if (selected != null) {
      setState(() {
        _categories = selected;
        _page = 0;
      });
      _persistFilterState();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;
    final activeFilters = <String>[];
    if (_startDate != null || _endDate != null) activeFilters.add('Tanggal');
    if (_empCodes.isNotEmpty) activeFilters.add('Karyawan');
    if (_categories.isNotEmpty) activeFilters.add('Kategori');
    if (_search.trim().isNotEmpty) activeFilters.add('Pencarian');

    return DashboardShell(
      currentRoute: AppRoutes.hutang,
      userName: getIt<CurrentUserStore>().displayName,
      userRole: getIt<CurrentUserStore>().userRole,
      headerActionLabel: _isAdminOrManager ? 'Export Excel' : 'Refresh',
      headerActionIcon: _isAdminOrManager
          ? Icons.file_download_rounded
          : Icons.refresh_rounded,
      onHeaderAction: _isAdminOrManager ? _export : _reload,
      onScan: () => context.pushNamed(AppRoutes.scanner),
      onRefresh: _loading ? null : _reload,
      onNavigate: (route) {
        if (route != AppRoutes.hutang) context.go(route);
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
                  child: Text(
                    'Hutang',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SegmentedButton<String>(
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
              ],
            ),
            const SizedBox(height: 12),
            // ── Filter bar ────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterAction(
                  icon: Icons.date_range_rounded,
                  label: (_startDate != null && _endDate != null)
                      ? '${_fmt(_startDate)} s/d ${_fmt(_endDate)}'
                      : 'Tanggal',
                  active: _startDate != null || _endDate != null,
                  onTap: _pickDateRange,
                ),
                _buildFilterAction(
                  icon: Icons.badge_rounded,
                  label: _empCodes.isEmpty
                      ? 'Kode Karyawan'
                      : '${_empCodes.length} karyawan',
                  active: _empCodes.isNotEmpty,
                  onTap: _pickEmpCodes,
                ),
                _buildFilterAction(
                  icon: Icons.category_rounded,
                  label: _categories.isEmpty
                      ? 'Kategori'
                      : '${_categories.length} kategori',
                  active: _categories.isNotEmpty,
                  onTap: _pickCategories,
                ),
                if (isMobile)
                  SizedBox(
                    width: double.infinity,
                    child: _buildSearchField(theme),
                  )
                else
                  SizedBox(
                    width: 260,
                    child: _buildSearchField(theme),
                  ),
                if (activeFilters.isNotEmpty)
                  IconButton(
                    tooltip: 'Reset filter',
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _empCodes = [];
                        _categories = [];
                        _search = '';
                        _searchController.clear();
                        _page = 0;
                      });
                      _persistFilterState();
                      _load();
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded),
                  ),
              ],
            ),
            if (!isMobile && activeFilters.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final f in activeFilters)
                    Chip(
                      label: Text(f),
                      visualDensity: VisualDensity.compact,
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {},
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_loading && _totalGrandSum != null && _items.isNotEmpty) ...[
                        _buildSummaryCard(),
                        const SizedBox(height: 12),
                      ],
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
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
                        _HutangDeckView(items: _items)
                      else
                        CustomPlutoDataGrid<HutangItem>(
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
                              HutangGridHelper.getColumns(ctx),
                          buildRows: (data) =>
                              HutangGridHelper.mapToRows(data),
                        ),
                      if (!_loading && _items.isNotEmpty) ...[
                        const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAction({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: active
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      onPressed: onTap,
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Cari no nota / distributor / barang / dept...',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onSubmitted: (v) {
        setState(() {
          _search = v.trim();
          _page = 0;
        });
        _persistFilterState();
        _load();
      },
    );
  }

  Widget _buildSummaryCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _tab == 'UNPAID'
                ? 'Total Hutang Belum Dibayar'
                : 'Total Sudah Dibayar',
            style: theme.textTheme.titleSmall,
          ),
          Text(
            _formatCurrency(_totalGrandSum),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _formatCurrency(Object? v) {
    if (v == null) return 'Rp0';
    final n = double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.-]'), ''));
    if (n == null) return v.toString();
    final s = n.abs().toStringAsFixed(0);
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final digit = s[s.length - 1 - i];
      b.write(digit);
      if (i % 3 == 2 && i != s.length - 1) b.write('.');
    }
    final digits = b.toString().split('').reversed.join();
    return 'Rp$digits';
  }
}

/// Cards mobile hutang — satu card = satu baris pembelian.
class _HutangDeckView extends StatelessWidget {
  const _HutangDeckView({required this.items});
  final List<HutangItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = items[i];
        final isPaid =
            (it.statusBayar ?? '').toUpperCase() == 'PAID' ||
            (it.statusBayar ?? '').toUpperCase() == 'LUNAS';
        return DataDeckCard(
          title: it.docNoP ?? '—',
          subtitle: it.parName ?? '—',
          chip: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isPaid ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              it.statusBayar ?? '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green.shade700 : Colors.orange.shade800,
              ),
            ),
          ),
          rows: [
            (label: 'Marketing', value: it.empCode ?? '—'),
            (label: 'Barang', value: it.itemName ?? '—'),
            (label: 'Qty', value: it.qty?.toString() ?? '—'),
            (label: 'Tanggal', value: _fmtDate(it.docDate)),
            (label: 'Total', value: _currency(it.grandTotal)),
            (
              label: 'Terbayar',
              value: it.paidTotal == null ? '—' : _currency(it.paidTotal),
            ),
          ],
        );
      },
    );
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    final dt = DateTime.tryParse(d.toString());
    if (dt == null) return d.toString();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _currency(Object? v) {
    if (v == null) return 'Rp0';
    final n = double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.-]'), ''));
    if (n == null) return v.toString();
    return 'Rp${n.abs().toStringAsFixed(0)}';
  }
}

class _MultiSelectDialog<T> extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<T> options;
  final List<T> selected;

  @override
  State<_MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

class _MultiSelectDialogState<T> extends State<_MultiSelectDialog<T>> {
  late final Set<T> _selected = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final opt in widget.options)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('$opt'),
                value: _selected.contains(opt),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(opt);
                    } else {
                      _selected.remove(opt);
                    }
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: const Text('Terapkan'),
        ),
      ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total $totalElements transaksi',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filled(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Text('${page + 1}/${totalPages > 0 ? totalPages : 1}'),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(emptyLabel, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
