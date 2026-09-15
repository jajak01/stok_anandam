import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/pelanggan_servis.dart';
import '../../repositories/servis_repository.dart';
import '../../widgets/pelanggan_form_dialog.dart';
import '../../utils/servis_mask_utils.dart';
import 'riwayat_servis_view.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/core/errors/app_errors.dart';
import 'package:stok_anandam/core/widgets/app_feedback.dart';

class ServisPelangganView extends StatefulWidget {
  const ServisPelangganView({super.key});

  @override
  State<ServisPelangganView> createState() => _ServisPelangganViewState();
}

class _ServisPelangganViewState extends State<ServisPelangganView> {
  final ServisRepository _repository = getIt<ServisRepository>();
  final _searchCtrl = TextEditingController();
  List<PelangganServis> _pelanggan = [];
  bool _isLoading = true;
  String? _errorMessage;
  // Pagination state
  int _currentPage = 0;
  final int _size = 50;
  int _totalElements = 0;
  int _totalPages = 0;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _fetchPelanggan();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchCtrl.text.trim();
        _currentPage = 0;
      });
      _fetchPelanggan();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPelanggan({bool resetPage = false}) async {
    if (resetPage) {
      setState(() {
        _currentPage = 0;
      });
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repository.getPelangganServis(
        page: _currentPage,
        size: _size,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) {
        setState(() {
          _pelanggan = data.content;
          _totalElements = data.totalElements;
          _totalPages = data.totalPages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrors.userMessageFromException(
            e,
            fallback: 'Gagal memuat daftar pelanggan. Coba lagi.',
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openForm({PelangganServis? pelanggan}) async {
    final refresh = await showDialog<bool>(
      context: context,
      builder: (_) => PelangganFormDialog(pelanggan: pelanggan),
    );
    if (refresh == true) {
      await _fetchPelanggan();
    }
  }

  Future<void> _deletePelanggan(PelangganServis pelanggan) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pelanggan?'),
        content: Text(
          'Data "${pelanggan.namaPelanggan ?? '-'}" akan dihapus dari daftar pelanggan servis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || pelanggan.id == null) return;
    try {
      await _repository.deletePelangganServis(pelanggan.id!);
      if (mounted) {
        AppFeedback.showSuccess(context, 'Pelanggan berhasil dihapus');
        await _fetchPelanggan();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, AppErrors.userMessageFromException(
          e,
          fallback: 'Gagal menghapus pelanggan. Coba lagi.',
        ));
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      AppFeedback.showSuccess(context, '$label disalin');
    }
  }

  Future<void> _openWhatsApp(PelangganServis pelanggan) async {
    final wa = pelanggan.noWhatsapp?.trim();
    if (wa == null || wa.isEmpty) {
      AppFeedback.showError(context, 'Nomor WhatsApp tidak tersedia');
      return;
    }

    final cleanNumber = wa.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.isEmpty) return;

    final uri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppFeedback.showError(context, 'Tidak dapat membuka WhatsApp: $uri');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _pelanggan.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _pelanggan.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _fetchPelanggan(resetPage: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _PelangganToolbar(
          total: _totalElements,
          filtered: _pelanggan.length,
          searchCtrl: _searchCtrl,
          onRefresh: () => _fetchPelanggan(resetPage: true),
          onAdd: () => _openForm(),
        ),
        if (_isLoading && _pelanggan.isNotEmpty)
          const LinearProgressIndicator(),
        Expanded(
          child: _pelanggan.isEmpty
              ? _EmptyPelangganState(hasData: _totalElements > 0)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 920) {
                      return _buildDesktopList(_pelanggan);
                    }
                    return _buildMobileList(_pelanggan);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopList(List<PelangganServis> items) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = items[index];
              return _PelangganRowCard(
                pelanggan: p,
                onRiwayat: () => RiwayatServisDialog.show(
                  context,
                  pelangganId: p.id ?? '',
                  namaPelanggan: p.namaPelanggan,
                ),
                onEdit: () => _openForm(pelanggan: p),
                onDelete: () => _deletePelanggan(p),
                onWhatsApp: () => _openWhatsApp(p),
                onCopyNama: () =>
                    _copyToClipboard('Nama', p.namaPelanggan ?? ''),
                onCopyWhatsApp: () =>
                    _copyToClipboard('WhatsApp', maskPhoneNumber(p.noWhatsapp)),
                onCopyAlamat: () => _copyToClipboard('Alamat', p.alamat ?? ''),
              );
            },
          ),
          _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<PelangganServis> items) {
    return RefreshIndicator(
      onRefresh: _fetchPelanggan,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final p = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PelangganMobileCard(
                      pelanggan: p,
                      onRiwayat: () => RiwayatServisDialog.show(
                        context,
                        pelangganId: p.id ?? '',
                        namaPelanggan: p.namaPelanggan,
                      ),
                      onEdit: () => _openForm(pelanggan: p),
                      onDelete: () => _deletePelanggan(p),
                      onWhatsApp: () => _openWhatsApp(p),
                      onCopyNama: () =>
                          _copyToClipboard('Nama', p.namaPelanggan ?? ''),
                      onCopyWhatsApp: () =>
                          _copyToClipboard('WhatsApp', maskPhoneNumber(p.noWhatsapp)),
                      onCopyAlamat: () =>
                          _copyToClipboard('Alamat', p.alamat ?? ''),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildPaginationBar(),
          ),
        ],
      ),
    );
  }

  /// Menampilkan pagination bar di bawah daftar item (sebagai bagian dari scroll)
  Widget _buildPaginationBar() {
    return _PaginationBar(
      page: _currentPage,
      totalPages: _totalPages,
      totalElements: _totalElements,
      onPrev: (_totalPages > 0 && _currentPage > 0)
          ? () {
              setState(() {
                _currentPage--;
              });
              _fetchPelanggan();
            }
          : null,
      onNext: (_totalPages > 0 && _currentPage < _totalPages - 1)
          ? () {
              setState(() {
                _currentPage++;
              });
              _fetchPelanggan();
            }
          : null,
    );
  }

  static String fmtDate(String? d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.tryParse(d);
      if (dt == null) return d;
      return DateFormat('dd/MM/yy').format(dt);
    } catch (_) {
      return d;
    }
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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Halaman ${page + 1} dari ${totalPages > 0 ? totalPages : 1} • Total $totalElements pelanggan',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PelangganToolbar extends StatelessWidget {
  final int total;
  final int filtered;
  final TextEditingController searchCtrl;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _PelangganToolbar({
    required this.total,
    required this.filtered,
    required this.searchCtrl,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 20,
            16,
            isCompact ? 16 : 20,
            14,
          ),
          child: Column(
            children: [
              // Baris judul + tombol aksi
              Row(
                children: [
                  Expanded(
                      child: _ToolbarTitle(total: total, filtered: filtered)),
                  IconButton.outlined(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: isCompact
                      ? 'Cari pelanggan'
                      : 'Cari nama, nomor, WhatsApp, atau alamat',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: searchCtrl.clear,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Bersihkan pencarian',
                        ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolbarTitle extends StatelessWidget {
  final int total;
  final int filtered;

  const _ToolbarTitle({required this.total, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pelanggan Servis',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          '$filtered dari $total pelanggan ditampilkan',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PelangganRowCard extends StatelessWidget {
  final PelangganServis pelanggan;
  final VoidCallback onRiwayat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopyNama;
  final VoidCallback onCopyWhatsApp;
  final VoidCallback onCopyAlamat;

  const _PelangganRowCard({
    required this.pelanggan,
    required this.onRiwayat,
    required this.onEdit,
    required this.onDelete,
    required this.onWhatsApp,
    required this.onCopyNama,
    required this.onCopyWhatsApp,
    required this.onCopyAlamat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            _AvatarBadge(pelanggan: pelanggan),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: _MainIdentity(
                pelanggan: pelanggan,
                onCopyNama: onCopyNama,
              ),
            ),
            Expanded(
              child: _InlineInfo(
                icon: Icons.phone_outlined,
                label: 'Telepon',
                value: maskPhoneNumber(pelanggan.noTelepon),
              ),
            ),
            Expanded(
              child: _CopyableInfo(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                value: maskPhoneNumber(pelanggan.noWhatsapp),
                onCopy: onCopyWhatsApp,
              ),
            ),
            Expanded(
              flex: 2,
              child: _CopyableInfo(
                icon: Icons.location_on_outlined,
                label: 'Alamat',
                value: pelanggan.alamat,
                maxLines: 2,
                onCopy: onCopyAlamat,
              ),
            ),
            Expanded(
              child: _InlineInfo(
                icon: Icons.event_outlined,
                label: 'Terdaftar',
                value: _ServisPelangganViewState.fmtDate(pelanggan.createdAt),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Aksi pelanggan',
              onSelected: (value) {
                if (value == 'riwayat') onRiwayat();
                if (value == 'whatsapp') onWhatsApp();
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'riwayat',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.history_rounded),
                    title: Text('Riwayat Servis'),
                  ),
                ),
                PopupMenuItem(
                  value: 'whatsapp',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.chat_rounded),
                    title: Text('WhatsApp'),
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_rounded),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PelangganMobileCard extends StatelessWidget {
  final PelangganServis pelanggan;
  final VoidCallback onRiwayat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopyNama;
  final VoidCallback onCopyWhatsApp;
  final VoidCallback onCopyAlamat;

  const _PelangganMobileCard({
    required this.pelanggan,
    required this.onRiwayat,
    required this.onEdit,
    required this.onDelete,
    required this.onWhatsApp,
    required this.onCopyNama,
    required this.onCopyWhatsApp,
    required this.onCopyAlamat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarBadge(pelanggan: pelanggan),
                const SizedBox(width: 12),
                Expanded(
                  child: _MainIdentity(
                    pelanggan: pelanggan,
                    onCopyNama: onCopyNama,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Aksi pelanggan',
                  onSelected: (value) {
                    if (value == 'riwayat') onRiwayat();
                    if (value == 'whatsapp') onWhatsApp();
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'riwayat',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.history_rounded),
                        title: Text('Riwayat Servis'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'whatsapp',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.chat_rounded),
                        title: Text('WhatsApp'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_rounded),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Hapus'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _InlineInfo(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: maskPhoneNumber(pelanggan.noTelepon),
                    ),
                    const SizedBox(height: 10),
                    _CopyableInfo(
                      icon: Icons.chat_bubble_outline,
                      label: 'WhatsApp',
                      value: maskPhoneNumber(pelanggan.noWhatsapp),
                      onCopy: onCopyWhatsApp,
                    ),
                    const SizedBox(height: 10),
                    _InlineInfo(
                      icon: Icons.event_outlined,
                      label: 'Terdaftar',
                      value: _ServisPelangganViewState.fmtDate(
                        pelanggan.createdAt,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _CopyableInfo(
              icon: Icons.location_on_outlined,
              label: 'Alamat',
              value: pelanggan.alamat,
              maxLines: 3,
              onCopy: onCopyAlamat,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  final PelangganServis pelanggan;

  const _AvatarBadge({required this.pelanggan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = pelanggan.namaPelanggan ?? '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MainIdentity extends StatelessWidget {
  final PelangganServis pelanggan;
  final VoidCallback? onCopyNama;

  const _MainIdentity({
    required this.pelanggan,
    this.onCopyNama,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onCopyNama,
          child: Text(
            pelanggan.namaPelanggan ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            pelanggan.kategori ?? 'User',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InlineInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value?.isNotEmpty == true ? value! : '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CopyableInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final int maxLines;
  final VoidCallback onCopy;

  const _CopyableInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onCopy,
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value?.isNotEmpty == true ? value! : '-',
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPelangganState extends StatelessWidget {
  final bool hasData;

  const _EmptyPelangganState({required this.hasData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasData ? Icons.search_off_rounded : Icons.group_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            hasData ? 'Pelanggan tidak ditemukan' : 'Belum ada data pelanggan',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
