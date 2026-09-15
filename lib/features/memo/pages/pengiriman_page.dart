import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:stok_anandam/features/shared/widgets/camera_screen.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/data/models/memo.dart';
import 'package:stok_anandam/data/models/penjadwalan.dart';
import 'package:stok_anandam/data/repositories/memo_repository.dart';
import 'package:stok_anandam/features/layout/dashboard_shell.dart';
import 'package:stok_anandam/features/memo/bloc/memo_bloc.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/core/auth/auth_service.dart';
import 'package:stok_anandam/features/memo/widgets/status_badge.dart';
import 'package:stok_anandam/features/memo/widgets/delivery_desktop_table_view.dart';
import 'package:stok_anandam/core/theme/app_spacing.dart';
import 'package:stok_anandam/features/memo/widgets/bulk_action_bar.dart';
import 'package:stok_anandam/features/memo/widgets/request_delivery_tab.dart';
import 'package:stok_anandam/features/memo/widgets/chrome_tab.dart';
import 'package:stok_anandam/features/memo/utils/memo_auth_utils.dart';
import 'package:stok_anandam/features/presence/mixins/presence_action_mixin.dart';

class PengirimanPage extends StatefulWidget {
  const PengirimanPage({super.key});

  @override
  State<PengirimanPage> createState() => _PengirimanPageState();
}

class _PengirimanPageState extends State<PengirimanPage>
    with PresenceActionMixin {
  String? _selectedCity;
  String _searchQuery = '';
  // Tab State
  late final List<ChromeTabGroup<String>> _tabGroups;
  late ChromeTabGroup<String> _activeGroup;
  String? _selectedChildStatus; // null means 'Semua' for the active group

  final _searchController = TextEditingController();
  final _verticalScrollController = ScrollController();

  // Bulk Selection
  bool _isSelectionMode = false;
  final Set<String> _selectedMemoIds = {};

  late MemoBloc _memoBloc;

  int _currentPage = 1;
  int _pageSize = 100;
  String? _selectedMemoType;
  final List<String> _memoTypes = [
    'BIASA',
    'ONLINE',
    'DISTRIBUSI',
    'PROJECT',
    'PENDING',
  ];
  // Expedition filter
  String? _selectedEkspedisi;
  // Date range filter
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _memoBloc = MemoBloc(getIt());
    _initTabGroups();
    final role = getIt<CurrentUserStore>().userRole;
    if (role == 'DELIVERY' ||
        role == 'GUDANG' ||
        role == 'SPV_GUDANG' ||
        role == 'ADMIN' ||
        role == 'MANAGER' ||
        role == 'TEKNISI' ||
        role == 'SPV_TEKNISI' ||
        (role != null && role.startsWith('MARKETING'))) {
      _selectedChildStatus = 'PERLU';
    }

    _memoBloc.add(LoadDeliveryTasks(
      tipe: (role == 'TEKNISI' || role == 'SPV_TEKNISI')
          ? 'TEKNISI'
          : 'PENGIRIMAN',
      status: _getMappedStatus(_selectedChildStatus),
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _memoBloc.close();
    super.dispose();
  }

  void _toggleSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (_isSelectionMode && initialId != null) {
        _selectedMemoIds.add(initialId);
      } else if (!_isSelectionMode) {
        _selectedMemoIds.clear();
      }
    });
  }

  void _handleBulkComplete(BuildContext context) {
    if (_selectedMemoIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Selesaikan Memo'),
        content: Text(
            'Apakah Anda yakin ingin menyelesaikan ${_selectedMemoIds.length} memo terpilih?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              _memoBloc.add(BulkCompleteMemoEvent(_selectedMemoIds.toList()));
              Navigator.pop(ctx);
              setState(() {
                _isSelectionMode = false;
                _selectedMemoIds.clear();
              });
            },
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );
  }

  void _showBulkUpdateStatusDialog(BuildContext context) {
    final keteranganController = TextEditingController();
    MemoStatus? targetStatus;

    final state = _memoBloc.state;
    if (state is! MemoLoaded) return;

    final selectedMemos =
        state.memos.where((m) => _selectedMemoIds.contains(m.id)).toList();

    // Calculate possible next statuses based on selected items
    final Set<MemoStatus> possibleStatuses = {};
    for (var m in selectedMemos) {
      if (m.statusAkhir != null) {
        possibleStatuses.addAll(m.statusAkhir!.nextPossibleStatuses);
      }
    }

    final List<MemoStatus> displayStatuses = possibleStatuses.isEmpty
        ? MemoStatus.values
            .where((s) => ![MemoStatus.DELETED, MemoStatus.DRAFT].contains(s))
            .toList()
        : possibleStatuses.toList();

    // Sort for consistency
    displayStatuses.sort((a, b) => a.index.compareTo(b.index));

    final TextEditingController jlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Ubah Status Massal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Akan mengubah ${_selectedMemoIds.length} pengiriman.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                DropdownButtonFormField<MemoStatus>(
                  decoration: const InputDecoration(
                    labelText: 'Pilih Status Baru',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: displayStatuses
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setLocalState(() => targetStatus = v),
                ),
                if (targetStatus == MemoStatus.MENUNGGU_NOTA) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: jlController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor JL / Invoice (Opsional)',
                      hintText: 'JL-XXX-XXXXXXX',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: keteranganController,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  if (targetStatus != null) {
                    final jl = jlController.text.trim();
                    if (targetStatus == MemoStatus.MENUNGGU_NOTA &&
                        jl.isNotEmpty) {
                      if (!jl.toUpperCase().startsWith("JL-")) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "Format JL tidak valid (harus diawali 'JL-')")));
                        return;
                      }
                    }

                    _memoBloc.add(BulkUpdateMemoStatusEvent(
                      _selectedMemoIds.toList(),
                      targetStatus!,
                      keteranganController.text,
                      nomorJl: targetStatus == MemoStatus.MENUNGGU_NOTA &&
                              jl.isNotEmpty
                          ? jl
                          : null,
                    ));
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Ubah Status'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleBulkPrint(BuildContext context) {
    final state = _memoBloc.state;
    if (state is MemoLoaded) {
      final selectedMemos =
          state.memos.where((m) => _selectedMemoIds.contains(m.id)).toList();
      if (selectedMemos.isNotEmpty) {
        _memoBloc.add(BulkPrintMemoEvent(selectedMemos));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menyiapkan Manifest...')),
        );
      }
    }
  }

  void _handleBulkStartDelivery(BuildContext context) {
    final state = _memoBloc.state;
    if (state is MemoLoaded) {
      final selectedMemos =
          state.memos.where((m) => _selectedMemoIds.contains(m.id)).toList();
      final List<int> penjadwalanIds = selectedMemos
          .map((m) {
            // Find the most recent DELIVERY task that is valid for starting
            final deliveryTasks = m.penjadwalanHistory
                .where((h) =>
                    h.tipeTugas == 'DELIVERY' &&
                    (h.statusJadwal == 'DIJADWALKAN' ||
                        h.statusJadwal == 'MENUNGGU_KONFIRMASI'))
                .toList();
            return deliveryTasks.lastOrNull?.id;
          })
          .whereType<int>()
          .toList();

      if (penjadwalanIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak ada jadwal aktif pada memo yang dipilih'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      _memoBloc.add(BulkMulaiDeliveryEvent(penjadwalanIds));
    }
  }

  Future<void> _handleBulkFinishDelivery(BuildContext context) async {
    final state = _memoBloc.state;
    if (state is MemoLoaded) {
      final selectedMemos =
          state.memos.where((m) => _selectedMemoIds.contains(m.id)).toList();
      final List<int> penjadwalanIds = selectedMemos
          .map((m) {
            // Find the most recent DELIVERY task that is currently in transit
            final deliveryTasks = m.penjadwalanHistory
                .where((h) =>
                    h.tipeTugas == 'DELIVERY' &&
                    h.statusJadwal == 'DALAM_PENGIRIMAN')
                .toList();
            return deliveryTasks.lastOrNull?.id;
          })
          .whereType<int>()
          .toList();

      if (penjadwalanIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak ada jadwal aktif pada memo yang dipilih'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      XFile? photo;
      final TextEditingController nameController = TextEditingController();
      final TextEditingController notesController = TextEditingController();

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: const Text('Selesaikan Kirim Massal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Akan menyelesaikan ${penjadwalanIds.length} pengiriman.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await Navigator.push<XFile>(
                        context,
                        MaterialPageRoute(builder: (_) => const CameraScreen()),
                      );
                      if (picked != null) {
                        setModalState(() => photo = picked);
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: photo == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Ambil Foto Bukti (Wajib)',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(photo!.path),
                                  fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Penerima (Wajib)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  if (photo == null || nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Foto dan Nama Penerima wajib diisi'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  _memoBloc.add(BulkSelesaikanDeliveryEvent(
                    penjadwalanIds: penjadwalanIds,
                    photo: photo!,
                    namaPenerima: nameController.text.trim(),
                    catatan: notesController.text.trim(),
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showBulkAssignmentDialog(BuildContext context) {
    final repository = getIt<MemoRepository>();
    final memoBloc = _memoBloc;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    repository.getAllUsers().then((allUsers) {
      if (!context.mounted) return;
      Navigator.pop(context); // Remove loading

      final drivers =
          allUsers.where((u) => u.role.toUpperCase() == 'DELIVERY').toList();
      final teknisi =
          allUsers.where((u) => u.role.toUpperCase() == 'TEKNISI').toList();
      final marketings = allUsers
          .where((u) => u.role.toUpperCase().contains('MARKETING'))
          .toList();

      int? selectedDriverId;
      int? selectedTeknisiId;
      int? selectedMarketingId;
      DateTime selectedDate = DateTime.now();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Penugasan Personel Massal'),
          content: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Menugaskan ${_selectedMemoIds.length} pengiriman.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  const Text('Driver / Pengiriman:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDriverId,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      hintText: 'Pilih Driver',
                      prefixIcon: const Icon(Icons.local_shipping, size: 20),
                    ),
                    items: drivers
                        .map((u) => DropdownMenuItem<int>(
                            value: u.id, child: Text(u.nama)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedDriverId = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Teknisi (Opsional):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedTeknisiId,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      hintText: 'Pilih Teknisi',
                      prefixIcon: const Icon(Icons.build, size: 20),
                    ),
                    items: teknisi
                        .map((u) => DropdownMenuItem<int>(
                            value: u.id, child: Text(u.nama)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedTeknisiId = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Atau Marketing Pengirim:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedMarketingId,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      hintText: 'Pilih Marketing',
                      prefixIcon: const Icon(Icons.person, size: 20),
                    ),
                    items: marketings
                        .map((u) => DropdownMenuItem<int>(
                            value: u.id, child: Text(u.nama)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedMarketingId = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tanggal Rencana:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 12),
                          Text(
                              "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}",
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (selectedDriverId == null && selectedMarketingId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text("Pilih driver atau marketing terlebih dahulu")));
                  return;
                }
                memoBloc.add(BulkConfirmDeliveryRouteEvent(
                  _selectedMemoIds.toList(),
                  {
                    'driverId': selectedDriverId,
                    'teknisiId': selectedTeknisiId,
                    'marketingId': selectedMarketingId,
                    'tanggalJadwal':
                        "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}",
                  },
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Konfirmasi & Simpan'),
            ),
          ],
        ),
      );
    }).catchError((e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal mengambil data: $e")));
      }
    });
  }

  void _showBatchDropOffDialog(BuildContext context) {
    if (_selectedMemoIds.isEmpty) return;
    final repository = getIt<MemoRepository>();
    final memoBloc = _memoBloc;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    repository.getAllUsers().then((allUsers) {
      if (!context.mounted) return;
      Navigator.pop(context); // Remove loading

      final drivers =
          allUsers.where((u) => u.role.toUpperCase() == 'DELIVERY').toList();
      final marketings = allUsers
          .where((u) => u.role.toUpperCase().contains('MARKETING'))
          .toList();

      int? selectedDriverId;
      int? selectedMarketingId;
      DateTime selectedDate = DateTime.now();
      final expeditionController = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Buat Penugasan Drop-off Ekspedisi massal'),
          content: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Menugaskan ${_selectedMemoIds.length} pengiriman.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  const Text('Pilih Driver / Kurir Gudang:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDriverId,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      hintText: 'Pilih Driver',
                      prefixIcon: const Icon(Icons.local_shipping, size: 20),
                    ),
                    items: drivers
                        .map((u) => DropdownMenuItem<int>(
                            value: u.id, child: Text(u.nama)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      selectedDriverId = v;
                      if (v != null) selectedMarketingId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Atau Marketing Pengirim:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedMarketingId,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      hintText: 'Pilih Marketing',
                      prefixIcon: const Icon(Icons.person, size: 20),
                    ),
                    items: marketings
                        .map((u) => DropdownMenuItem<int>(
                            value: u.id, child: Text(u.nama)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      selectedMarketingId = v;
                      if (v != null) selectedDriverId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nama Ekspedisi (JNE, J&T, Wahana, dll):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: expeditionController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Contoh: JNE / J&T',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.local_post_office, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tanggal Drop-off:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 12),
                          Text(
                              "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}",
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (selectedDriverId == null && selectedMarketingId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text("Pilih driver atau marketing terlebih dahulu")));
                  return;
                }
                if (expeditionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Isi nama ekspedisi terlebih dahulu")));
                  return;
                }
                memoBloc.add(CreateBatchDropOffEvent(
                  memoIds: _selectedMemoIds.toList(),
                  personelId: selectedDriverId ?? selectedMarketingId!,
                  tanggalRencana: selectedDate,
                  expeditionName: expeditionController.text,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Buat Tugas Drop-off'),
            ),
          ],
        ),
      );
    }).catchError((e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal mengambil data: $e")));
      }
    });
  }

  bool _isMemoInCity(MemoDetail memo, String targetCity) {
    final cityUpper = targetCity.trim().toUpperCase();

    // Helper to check if a value matches the target city
    bool matches(String? val) {
      if (val == null || val.isEmpty) return false;
      final u = val.toUpperCase();
      // Direct match or partial match
      if (u.contains(cityUpper) || cityUpper.contains(u)) return true;
      // Special case: "KOTA YOGYAKARTA" matches "YOGYAKARTA" or "KOTA"
      if (cityUpper == 'KOTA YOGYAKARTA') {
        if (u == 'YOGYAKARTA' ||
            u == 'KOTA' ||
            u == 'JOGJA' ||
            u == 'JOGJAKARTA') {
          return true;
        }
      }
      return false;
    }

    // 1. Priority Check: Scheduling History (Data from the specific delivery task)
    if (memo.penjadwalanHistory.isNotEmpty) {
      final lastSchedule = memo.penjadwalanHistory.last;
      if (matches(lastSchedule.kabupatenKota)) return true;
      if (matches(lastSchedule.kecamatan)) return true;

      // If the schedule explicitly specifies a DIFFERENT city (not empty/DIY),
      // we should be careful about falling back to postal code.
      final histKab = (lastSchedule.kabupatenKota ?? '').toUpperCase();
      if (histKab.isNotEmpty && histKab != 'DIY' && histKab != 'YOGYAKARTA') {
        // It has a specific city in history, but it didn't match targetCity.
        // We'll still check top-level memo properties just in case.
      }
    }

    // 2. Secondary Check: Top-level Memo properties (Address parsing results)
    if (matches(memo.kabupatenKota)) return true;
    if (matches(memo.kecamatan)) return true;

    // 3. Fallback: Check Postal Code (Using prefixes for DIY)
    if (memo.kodePos != null && memo.kodePos!.isNotEmpty) {
      final kp = memo.kodePos!;

      if (cityUpper == 'SLEMAN' &&
          (kp.startsWith('555') || kp.startsWith('5528'))) {
        return true;
      }
      if (cityUpper == 'KOTA YOGYAKARTA' &&
          (kp.startsWith('551') || kp.startsWith('552')) &&
          !kp.startsWith('5528')) {
        return true;
      }
      if (cityUpper == 'KULON PROGO' && kp.startsWith('556')) return true;
      if (cityUpper == 'BANTUL' && kp.startsWith('557')) return true;
      if (cityUpper == 'GUNUNG KIDUL' &&
          (kp.startsWith('558') || kp.startsWith('559'))) {
        return true;
      }
    }

    // 4. Last Resort: Search in Description/Full Address
    final searchArea =
        "${memo.deskripsi} ${memo.kabupatenKota} ${memo.kecamatan}"
            .toUpperCase();
    if (searchArea.contains(cityUpper)) return true;

    // Extra check for "KOTA" in description if target is Kota Yogyakarta
    if (cityUpper == 'KOTA YOGYAKARTA' && searchArea.contains('KOTA')) {
      return true;
    }

    return false;
  }

  final List<String> _cities = [
    'SLEMAN',
    'BANTUL',
    'KOTA YOGYAKARTA',
    'KULON PROGO',
    'GUNUNG KIDUL',
  ];

  void _initTabGroups() {
    final role = getIt<CurrentUserStore>().userRole;
    if (role == 'TEKNISI' || role == 'SPV_TEKNISI') {
      _tabGroups = [
        ChromeTabGroup(
          id: 'MEMO',
          label: 'Memo Service',
          children: ['PERLU', 'SEDANG', 'SELESAI'],
        ),
      ];
    } else {
      _tabGroups = [
        ChromeTabGroup(
          id: 'MEMO',
          label: 'Pengiriman Memo',
          children: ['PERLU', 'SEDANG', 'SELESAI'],
        ),
        if (role != 'DELIVERY')
          ChromeTabGroup(
            id: 'REQUEST',
            label: 'Request Delivery',
            children: ['PERLU', 'SEDANG', 'SELESAI'],
          ),
      ];
    }
    _activeGroup = _tabGroups.first;
  }

  String _getMappedStatus(String? status) {
    final role = getIt<CurrentUserStore>().userRole;
    if (role == 'TEKNISI' || role == 'SPV_TEKNISI') {
      switch (status) {
        case 'PERLU':
          return 'DIJADWALKAN';
        case 'SEDANG':
          return 'DALAM_PENGIRIMAN';
        case 'SELESAI':
          return 'SELESAI';
        default:
          return 'SEMUA';
      }
    }

    switch (status) {
      case 'PERLU':
        return 'MENUNGGU_KONFIRMASI';
      case 'SEDANG':
        return 'DALAM_PENGIRIMAN';
      case 'SELESAI':
        return 'SELESAI';
      default:
        return 'SEMUA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStore = getIt<CurrentUserStore>();
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    final isDelivery = userStore.userRole == 'DELIVERY';

    return BlocProvider.value(
      value: _memoBloc,
      child: BlocListener<MemoBloc, MemoState>(
        listener: (context, state) {
          if (state is MemoOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() {
              _isSelectionMode = false;
              _selectedMemoIds.clear();

              if (state.targetStatus != null) {
                // Smart navigation for PengirimanPage
                final target = state.targetStatus!;
                if (target == MemoStatus.DALAM_PENGIRIMAN) {
                  _selectedChildStatus = 'SEDANG';
                } else if (target == MemoStatus.SELESAI ||
                    target == MemoStatus.DITERIMA_USER) {
                  _selectedChildStatus = 'SELESAI';
                } else {
                  _selectedChildStatus = 'PERLU';
                }
              }
            });
            _memoBloc.add(LoadDeliveryTasks(
              tipe: (userStore.userRole == 'TEKNISI' ||
                      userStore.userRole == 'SPV_TEKNISI')
                  ? 'TEKNISI'
                  : 'PENGIRIMAN',
              status: _getMappedStatus(_selectedChildStatus),
            ));
          } else if (state is MemoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Builder(
          builder: (context) => Stack(
            children: [
              DashboardShell(
                currentRoute: AppRoutes.pengiriman,
                title: (userStore.userRole == 'DELIVERY' ||
                        (userStore.userRole != null &&
                            userStore.userRole!.startsWith('MARKETING')))
                    ? 'Menu Pengantaran'
                    : 'Menu Pengiriman',
                userName: userStore.displayName,
                userRole: userStore.userRole,
                onNavigate: (route) => context.go(route),
                onScan: isMobile
                    ? null
                    : () async {
                        final scannedCode = await context.pushNamed<String>(
                          AppRoutes.scanner,
                          extra: true,
                        );
                        if (scannedCode != null && context.mounted) {
                          setState(() {
                            _searchController.text = scannedCode;
                            _searchQuery = scannedCode.toLowerCase();
                            _currentPage = 1;
                          });
                        }
                      },
                headerActions: !isMobile
                    ? [
                        ...(userStore.userRole == 'DELIVERY'
                            ? [
                                HeaderAction(
                                  label: 'Scan QR Ambil Tugas',
                                  icon: Icons.qr_code_scanner_rounded,
                                  onPressed: () {
                                    context
                                        .pushNamed(AppRoutes.deliveryScanner);
                                  },
                                ),
                              ]
                            : []),
                        HeaderAction(
                          label: 'Scan QR Pengiriman',
                          icon: Icons.search,
                          onPressed: () async {
                            final scannedCode = await context.pushNamed<String>(
                              AppRoutes.scanner,
                              extra: true,
                            );
                            if (scannedCode != null && context.mounted) {
                              setState(() {
                                _searchController.text = scannedCode;
                                _searchQuery = scannedCode.toLowerCase();
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ]
                    : [],
                onLogout: () async {
                  await getIt<AuthService>().logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (isMobile && isDelivery) ? 12 : 20,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildGroupingTabs(theme, isMobile, context),
                      if (!isDelivery || !isMobile) ...[
                        const SizedBox(height: 12),
                        _buildSearchField(isMobile),
                        const SizedBox(height: AppSpacing.md),
                        _buildFilterBar(isMobile, theme),
                        const SizedBox(height: AppSpacing.md),
                      ] else
                        const SizedBox(height: 12),
                      Expanded(
                        child: isDelivery
                            ? BlocBuilder<MemoBloc, MemoState>(
                                builder: (context, state) {
                                  return _buildContent(
                                      context, state, theme, isMobile,
                                      onlyMemo: true);
                                },
                              )
                            : IndexedStack(
                                index: _activeGroup.id == 'MEMO' ? 0 : 1,
                                children: [
                                  BlocBuilder<MemoBloc, MemoState>(
                                    builder: (context, state) {
                                      return _buildContent(
                                          context, state, theme, isMobile,
                                          onlyMemo: true);
                                    },
                                  ),
                                  RequestDeliveryTab(
                                    showHeader: false,
                                    selectedChildStatus: _selectedChildStatus,
                                  ),
                                ],
                              ),
                      ),
                      if (isMobile && isDelivery)
                        _buildDeliveryBottomNav(context),
                    ],
                  ),
                ),
              ),
              if (_selectedMemoIds.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: Center(
                    child: BulkActionBar(
                      count: _selectedMemoIds.length,
                      userRole: userStore.userRole,
                      onClear: () => setState(() {
                        _isSelectionMode = false;
                        _selectedMemoIds.clear();
                      }),
                      onPrint: () => _handleBulkPrint(context),
                      onChangeStatus: () =>
                          _showBulkUpdateStatusDialog(context),
                      onAssignment: () => _showBulkAssignmentDialog(context),
                      onDropOff: () => _showBatchDropOffDialog(context),
                      onBulkStart: () => _handleBulkStartDelivery(context),
                      onBulkFinish: () => _handleBulkFinishDelivery(context),
                      onComplete: () => _handleBulkComplete(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Pengantaran
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.local_shipping_rounded,
                  label: 'Pengantaran',
                  isActive: true,
                  onTap: () {},
                ),
              ),
              // Center: Scanner FAB (agak popup)
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  await context.pushNamed(AppRoutes.deliveryScanner);
                  if (mounted) {
                    setState(() {
                      _selectedChildStatus = 'PERLU';
                    });
                    _memoBloc.add(LoadDeliveryTasks(
                      tipe: 'PENGIRIMAN',
                      status: _getMappedStatus('PERLU'),
                    ));
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 28),
                ),
              ),
              const SizedBox(width: 16),
              // Right: Profile
              Expanded(
                child: _bottomNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  isActive: false,
                  onTap: () => context.pushNamed(AppRoutes.profile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? const Color(0xFF10B981) : Colors.grey.shade500,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color:
                    isActive ? const Color(0xFF10B981) : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isMobile) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari No. Memo, Pelanggan, atau Order ID...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: theme.colorScheme.primary, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide(
                        color: theme.colorScheme.primary, width: 1.5),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _currentPage = 1;
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (v) => setState(() {
                  _searchQuery = v.toLowerCase();
                  _currentPage = 1;
                }),
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _toggleSelectionMode,
                icon: Icon(
                  _isSelectionMode
                      ? Icons.close
                      : Icons.playlist_add_check_rounded,
                  color:
                      _isSelectionMode ? Colors.red : theme.colorScheme.primary,
                ),
                tooltip: _isSelectionMode ? 'Batal Pilih' : 'Pilih Banyak',
              ),
            ),
          ],
          if (isMobile) ...[
            const SizedBox(width: 12),
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () async {
                  final scannedCode = await context.pushNamed<String>(
                    AppRoutes.scanner,
                    extra: true,
                  );
                  if (scannedCode != null && context.mounted) {
                    setState(() {
                      _searchController.text = scannedCode;
                      _searchQuery = scannedCode.toLowerCase();
                      _currentPage = 1;
                    });
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupingTabs(
      ThemeData theme, bool isMobile, BuildContext context) {
    final isDelivery = getIt<CurrentUserStore>().userRole == 'DELIVERY';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Parent Groups (Memo, Request) — hidden for DELIVERY
        if (!isDelivery)
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tabGroups.map((group) {
                  final bool isActive = _activeGroup.id == group.id;
                  return ChromeTab(
                    label: group.label,
                    isActive: isActive,
                    onTap: () {
                      setState(() {
                        _activeGroup = group;
                        _currentPage = 1;
                      });
                      if (_activeGroup.id == 'MEMO') {
                        context.read<MemoBloc>().add(LoadDeliveryTasks(
                              tipe: 'PENGIRIMAN',
                              status: _getMappedStatus(_selectedChildStatus),
                            ));
                      }
                    },
                    isParent: true,
                  );
                }).toList(),
              ),
            ),
          ),

        // Row 2: Child Statuses (Perlu, Sedang, Selesai)
        Container(
          width: double.infinity,
          height: 44,
          margin: const EdgeInsets.only(top: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChromeTab(
                  label: 'Semua',
                  isActive: _selectedChildStatus == null,
                  onTap: () {
                    setState(() {
                      _selectedChildStatus = null;
                      _currentPage = 1;
                    });
                    if (_activeGroup.id == 'MEMO') {
                      context.read<MemoBloc>().add(LoadDeliveryTasks(
                            tipe: 'PENGIRIMAN',
                            status: _getMappedStatus(null),
                          ));
                    }
                  },
                  isParent: false,
                ),
                ..._activeGroup.children.map((status) {
                  final bool isActive = _selectedChildStatus == status;
                  String label = status;
                  if (status == 'PERLU') label = 'Perlu Dikirim';
                  if (status == 'SEDANG') label = 'Sedang Dikirim';
                  if (status == 'SELESAI') label = 'Selesai Dikirim';

                  return ChromeTab(
                    label: label,
                    isActive: isActive,
                    onTap: () {
                      setState(() {
                        _selectedChildStatus = status;
                        _currentPage = 1;
                      });
                      if (_activeGroup.id == 'MEMO') {
                        context.read<MemoBloc>().add(LoadDeliveryTasks(
                              tipe: 'PENGIRIMAN',
                              status: _getMappedStatus(status),
                            ));
                      }
                    },
                    isParent: false,
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(bool isMobile, ThemeData theme) {
    final showCityFilter = getIt<CurrentUserStore>().userRole == 'GUDANG' ||
        getIt<CurrentUserStore>().userRole == 'SPV_GUDANG' ||
        getIt<CurrentUserStore>().userRole == 'ADMIN' ||
        getIt<CurrentUserStore>().userRole == 'MANAGER';

    final memoTypeDropdown = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedMemoType,
          hint: const Text('Semua Tipe', style: TextStyle(fontSize: 12)),
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          onChanged: (value) {
            setState(() {
              _selectedMemoType = value;
              _currentPage = 1;
            });
          },
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Semua Tipe'),
            ),
            ..._memoTypes.map((type) => DropdownMenuItem<String?>(
                  value: type,
                  child: Text(type),
                )),
          ],
        ),
      ),
    );

    final pageSizeDropdown = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _pageSize,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _pageSize = value;
                _currentPage = 1;
              });
            }
          },
          items: [50, 100, 200]
              .map((size) => DropdownMenuItem<int>(
                    value: size,
                    child: Text('$size / hal'),
                  ))
              .toList(),
        ),
      ),
    );

    final expeditionDropdown = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedEkspedisi,
          hint: const Text('Ekspedisi', style: TextStyle(fontSize: 12)),
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          onChanged: (value) {
            setState(() {
              _selectedEkspedisi = value;
              _currentPage = 1;
            });
          },
          items: const [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Semua Ekspedisi'),
            ),
            DropdownMenuItem<String?>(
              value: 'ANDI',
              child: Text('ANDI'),
            ),
            DropdownMenuItem<String?>(
              value: 'REGULER',
              child: Text('REGULER'),
            ),
            DropdownMenuItem<String?>(
              value: 'INSTANT',
              child: Text('INSTANT'),
            ),
          ],
        ),
      ),
    );

    final dateFilterButton = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: (_startDate != null || _endDate != null)
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (_startDate != null || _endDate != null)
              ? theme.colorScheme.primary
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDialog<DateTimeRange>(
            context: context,
            builder: (context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 360,
                    maxHeight: 520,
                  ),
                  child: DateRangePickerDialog(
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                  ),
                ),
              );
            },
          );
          if (picked != null) {
            setState(() {
              _startDate = picked.start;
              _endDate = picked.end;
              _currentPage = 1;
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 16,
              color: (_startDate != null || _endDate != null)
                  ? theme.colorScheme.primary
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              _startDate != null && _endDate != null
                  ? '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}'
                  : 'Filter Tanggal',
              style: TextStyle(
                fontSize: 11,
                color: (_startDate != null || _endDate != null)
                    ? theme.colorScheme.primary
                    : Colors.grey.shade600,
                fontWeight: (_startDate != null || _endDate != null)
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (_startDate != null || _endDate != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _currentPage = 1;
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (showCityFilter) ...[
              _buildDesktopCityFilter(),
              const SizedBox(width: 8),
            ],
            memoTypeDropdown,
            const SizedBox(width: 8),
            expeditionDropdown,
            const SizedBox(width: 8),
            dateFilterButton,
            const SizedBox(width: 8),
            pageSizeDropdown,
          ],
        ),
      );
    }

    return Row(
      children: [
        if (showCityFilter) ...[
          _buildDesktopCityFilter(),
          const SizedBox(width: 12),
        ],
        memoTypeDropdown,
        const SizedBox(width: 12),
        expeditionDropdown,
        const SizedBox(width: 12),
        dateFilterButton,
        const SizedBox(width: 12),
        pageSizeDropdown,
        const Spacer(),
      ],
    );
  }

  Widget _buildDesktopCityFilter() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildCityChipSlim('Semua Kota', null),
          ..._cities.map((city) => _buildCityChipSlim(city, city)),
        ],
      ),
    );
  }

  Widget _buildCityChipSlim(String label, String? value) {
    final isSelected = _selectedCity == value;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () => setState(() {
          _selectedCity = value;
          _currentPage = 1;
        }),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
          backgroundColor:
              isSelected ? theme.colorScheme.primary : Colors.transparent,
          foregroundColor: isSelected ? Colors.white : Colors.grey.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildCityChip(String label, String? value) {
    final isSelected = _selectedCity == value;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            )),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCity = value;
            _currentPage = 1;
          });
        },
        selectedColor: theme.colorScheme.primary,
        checkmarkColor: theme.colorScheme.onPrimary,
        backgroundColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, MemoState state, ThemeData theme, bool isMobile,
      {bool onlyMemo = false}) {
    final userStore = getIt<CurrentUserStore>();
    if (state is MemoLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is MemoError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error, style: const TextStyle(color: Colors.red)),
            TextButton(
              onPressed: () => context.read<MemoBloc>().add(LoadMemos()),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state is MemoLoaded) {
      final List<MemoDetail> allItems = [];

      if (state.tasks != null) {
        for (final task in state.tasks!) {
          if (task.memoId == null) {
            // It's a manual task (Request Delivery), convert to pseudo-memo
            if (!onlyMemo) allItems.add(_mapTaskToMemo(task));
          } else {
            // Jika user adalah Marketing yg di-assign sbg driver, memo aslinya mungkin tidak
            // di-return oleh getListMemo (karena getListMemo hny mengembalikan memo buatannya sendiri).
            // Jadi kita harus buat dummy memo dari task.
            if (!state.memos.any((m) => m.id == task.memoId)) {
              allItems.add(_mapTaskToMemo(task));
            }
          }
        }
      }

      // Add ALL actual memos fetched from backend. The frontend filter block below
      // accurately places them into Perlu / Sedang / Selesai tabs based on their true statuses.
      for (final memo in state.memos) {
        if (!allItems.any((m) => m.id == memo.id)) {
          allItems.add(memo);
        }
      }

      var filtered = allItems.where((m) {
        // 1. Status Filter based on Selected Tab (0=Semua, 1=Perlu, 2=Sedang, 3=Selesai, 4=Parsial)
        final s = m.statusAkhir;
        final targetStatus = _getMappedStatus(_selectedChildStatus);

        if (targetStatus != 'SEMUA') {
          if (targetStatus == 'MENUNGGU_KONFIRMASI') {
            // "Perlu Dikirim" Tab: Includes waiting for assignment, buffer zone, or assigned but not yet started
            if (s != MemoStatus.MENUNGGU_PENGIRIMAN &&
                s != MemoStatus.BUFFER_ZONE &&
                s != MemoStatus.MENUNGGU_EXPEDISI) {
              return false;
            }
          } else if (targetStatus == 'DALAM_PENGIRIMAN') {
            // "Sedang Dikirim" Tab: Only actually in-transit memos
            if (s != MemoStatus.DALAM_PENGIRIMAN) return false;
          } else if (targetStatus == 'SELESAI') {
            final role = getIt<CurrentUserStore>().userRole;
            if (role == 'DELIVERY' ||
                (role != null && role.startsWith('MARKETING'))) {
              if (s != MemoStatus.DITERIMA_USER &&
                  s != MemoStatus.TERKIRIM_SEBAGIAN) {
                return false;
              }
            } else {
              if (s != MemoStatus.DITERIMA_USER &&
                  s != MemoStatus.SELESAI &&
                  s != MemoStatus.TERKIRIM_SEBAGIAN) {
                return false;
              }
            }
          }
        }

        // 2. Search Filter
        final matchesSearch =
            m.nomorMemo?.toLowerCase().contains(_searchQuery) == true ||
                m.customerName?.toLowerCase().contains(_searchQuery) == true ||
                m.deskripsi?.toLowerCase().contains(_searchQuery) == true ||
                m.resi?.toLowerCase().contains(_searchQuery) == true ||
                m.orderIdMarketplace?.toLowerCase().contains(_searchQuery) ==
                    true;

        if (!matchesSearch) return false;

        // 3. City Filter
        if (_selectedCity != null) {
          if (!_isMemoInCity(m, _selectedCity!)) return false;
        }

        // 4. Memo Type Filter
        if (_selectedMemoType != null) {
          if (m.memoType?.toUpperCase() != _selectedMemoType?.toUpperCase()) {
            return false;
          }
        }

        // 5. Expedition Filter
        if (_selectedEkspedisi != null && _selectedEkspedisi!.isNotEmpty) {
          if (m.ekspedisi == null || m.ekspedisi!.isEmpty) {
            return false;
          }
          final eks = m.ekspedisi!.toUpperCase();
          if (_selectedEkspedisi == 'ANDI') {
            if (!eks.contains('ANDI')) return false;
          } else if (_selectedEkspedisi == 'REGULER') {
            if (!eks.contains('REGULER') && !eks.contains('REGULAR')) {
              return false;
            }
          } else if (_selectedEkspedisi == 'INSTANT') {
            if (!eks.contains('INSTAN')) return false;
          }
        }

        // 6. Date Range Filter
        if (_startDate != null || _endDate != null) {
          // Try to get date from memo's penjadwalanHistory or tanggalMemo
          DateTime? memoDate;
          if (m.tanggalMemo != null) {
            memoDate = DateTime(
                m.tanggalMemo!.year, m.tanggalMemo!.month, m.tanggalMemo!.day);
          } else if (m.penjadwalanHistory.isNotEmpty) {
            final lastSchedule = m.penjadwalanHistory.last;
            if (lastSchedule.tanggalJadwal != null &&
                lastSchedule.tanggalJadwal!.isNotEmpty) {
              // Parse date string in format DD-MM-YYYY or YYYY-MM-DD
              final dateStr = lastSchedule.tanggalJadwal!;
              try {
                if (dateStr.contains('-')) {
                  final parts = dateStr.split('-');
                  if (parts.length == 3) {
                    // Try DD-MM-YYYY first (Indonesian format)
                    int? day, month, year;
                    day = int.tryParse(parts[0]);
                    month = int.tryParse(parts[1]);
                    year = int.tryParse(parts[2]);
                    if (day != null && month != null && year != null) {
                      memoDate = DateTime(year, month, day);
                    }
                  }
                }
              } catch (_) {}
            }
          }

          if (memoDate == null) {
            return false; // No date available, can't match
          }

          if (_startDate != null) {
            final start =
                DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            if (memoDate.isBefore(start)) return false;
          }
          if (_endDate != null) {
            final end =
                DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
            if (memoDate.isAfter(end)) return false;
          }
        }

        return true;
      }).toList();

      if (filtered.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Tidak ada pengiriman ditemukan',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        );
      }

      final totalFilteredItems = filtered.length;
      final totalPages = (totalFilteredItems / _pageSize).ceil();

      if (_currentPage > totalPages && totalPages > 0) {
        _currentPage = totalPages;
      }
      if (_currentPage < 1) {
        _currentPage = 1;
      }

      final startIndex = (_currentPage - 1) * _pageSize;
      final endIndex = startIndex + _pageSize;
      final paginatedList = filtered.sublist(
        startIndex,
        endIndex > totalFilteredItems ? totalFilteredItems : endIndex,
      );

      final paginationControls =
          _buildPaginationControls(totalPages, totalFilteredItems, theme);

      if (!isMobile) {
        return Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  child: DeliveryDesktopTableView(
                    memos: paginatedList,
                    selectedIds: _selectedMemoIds,
                    isSelectionMode: _isSelectionMode,
                    onSelectAll: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedMemoIds
                              .addAll(paginatedList.map((m) => m.id!));
                        } else {
                          _selectedMemoIds
                              .removeAll(paginatedList.map((m) => m.id!));
                        }
                      });
                    },
                    onTap: (memo) async {
                      if (_isSelectionMode || _selectedMemoIds.isNotEmpty) {
                        setState(() {
                          if (_selectedMemoIds.contains(memo.id)) {
                            _selectedMemoIds.remove(memo.id);
                          } else {
                            _selectedMemoIds.add(memo.id!);
                          }
                        });
                      } else {
                        if (memo.id!.startsWith('task-')) {
                          final taskId = memo.id!.replaceFirst('task-', '');
                          MemoAuthUtils.guardManualTaskAccess(
                            context,
                            role: userStore.userRole,
                            statusJadwal: memo.statusAkhir?.name,
                            onGranted: () => context.pushNamed(
                                AppRoutes.manualTaskDetail,
                                pathParameters: {'id': taskId}),
                          );
                        } else {
                          MemoAuthUtils.guardAccess(
                            context,
                            role: userStore.userRole,
                            status: memo.statusAkhir,
                            onGranted: () => context.pushNamed(
                                AppRoutes.deliveryDetail,
                                pathParameters: {'id': memo.id!}),
                          );
                        }
                        if (context.mounted) {
                          context.read<MemoBloc>().add(LoadDeliveryTasks(
                                tipe: 'PENGIRIMAN',
                                status: _getMappedStatus(_selectedChildStatus),
                              ));
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            paginationControls,
            const SizedBox(height: 16),
          ],
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<MemoBloc>().add(LoadDeliveryTasks(
                tipe: 'PENGIRIMAN',
                status: _getMappedStatus(_selectedChildStatus),
              ));
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: paginatedList.length + (totalPages > 1 ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == paginatedList.length) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: paginationControls,
              );
            }
            final memo = paginatedList[index];
            return _buildMemoCard(memo, theme);
          },
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildPaginationControls(
      int totalPages, int totalItems, ThemeData theme) {
    if (totalPages <= 1) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final String infoTextStr = isMobile
            ? '${(_currentPage - 1) * _pageSize + 1}-${(_currentPage * _pageSize) > totalItems ? totalItems : (_currentPage * _pageSize)} / $totalItems'
            : 'Menampilkan ${(_currentPage - 1) * _pageSize + 1} - ${(_currentPage * _pageSize) > totalItems ? totalItems : (_currentPage * _pageSize)} dari $totalItems data';

        return Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(vertical: 6, horizontal: isMobile ? 8 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                infoTextStr,
                style:
                    TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: isMobile
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                    padding:
                        isMobile ? EdgeInsets.zero : const EdgeInsets.all(8),
                    constraints: isMobile
                        ? const BoxConstraints(minWidth: 32, minHeight: 32)
                        : null,
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    tooltip: 'Halaman Sebelumnya',
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  Text(
                    '$_currentPage / $totalPages',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 8),
                  IconButton(
                    visualDensity: isMobile
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                    padding:
                        isMobile ? EdgeInsets.zero : const EdgeInsets.all(8),
                    constraints: isMobile
                        ? const BoxConstraints(minWidth: 32, minHeight: 32)
                        : null,
                    onPressed: _currentPage < totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    tooltip: 'Halaman Berikutnya',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemoCard(MemoDetail memo, ThemeData theme) {
    final userStore = getIt<CurrentUserStore>();
    final bool isSelected = _selectedMemoIds.contains(memo.id);
    final status = memo.statusAkhir ?? MemoStatus.MENUNGGU_PENGIRIMAN;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          if (_isSelectionMode || _selectedMemoIds.isNotEmpty) {
            setState(() {
              if (isSelected) {
                _selectedMemoIds.remove(memo.id);
              } else {
                _selectedMemoIds.add(memo.id!);
              }
            });
          } else {
            MemoAuthUtils.guardAccess(
              context,
              role: userStore.userRole,
              status: memo.statusAkhir,
              onGranted: () => context.pushNamed(AppRoutes.deliveryDetail,
                  pathParameters: {'id': memo.id!}),
            );
            if (context.mounted) {
              context.read<MemoBloc>().add(LoadDeliveryTasks(
                    tipe: 'PENGIRIMAN',
                    status: _getMappedStatus(_selectedChildStatus),
                  ));
            }
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelectionMode(memo.id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memo.customerName ?? 'No Name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#MEMO-${memo.nomorMemo ?? memo.id?.substring(0, 8)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: theme.colorScheme.primary),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(thickness: 1, color: Color(0xFFF1F5F9)),
              ),
              // Order ID Marketplace
              if (memo.orderIdMarketplace != null &&
                  memo.orderIdMarketplace!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Order: ${memo.orderIdMarketplace}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              // Middle Section: Area / Logistics info
              Row(
                children: [
                  Icon(Icons.map_outlined,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _getDeliveryArea(memo),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_pin_circle_outlined,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _getDriverName(memo),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Bottom Section: Status & Type Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(status: status),
                  if (memo.opsiPengiriman != null) _buildOpsiBadge(memo, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDeliveryArea(MemoDetail memo) {
    final logisticsTasks = memo.penjadwalanHistory
        .where((j) =>
            j.tipeTugas == 'PENGIRIMAN' ||
            j.tipeTugas == 'PENGAMBILAN' ||
            j.tipeTugas == 'DROP_OFF_EKSPEDISI')
        .toList();

    if (logisticsTasks.isNotEmpty) {
      final last = logisticsTasks.last;
      final kabKota = last.kabupatenKota ?? '';
      final kecamatan = last.kecamatan ?? '';
      if (kabKota.isNotEmpty && kecamatan.isNotEmpty) {
        return "$kabKota, $kecamatan".toUpperCase();
      }
      if (last.alamatLengkap != null && last.alamatLengkap!.isNotEmpty) {
        return last.alamatLengkap!.toUpperCase();
      }
    }
    final kab = memo.kabupatenKota ?? '';
    final kec = memo.kecamatan ?? '';
    if (kab.isNotEmpty) return "$kab, $kec".toUpperCase();

    final address = memo.deskripsi ?? '';
    if (address.length > 50) return address.substring(0, 50);
    return address.isEmpty ? 'Wilayah / Area' : address;
  }

  String _getDriverName(MemoDetail memo) {
    final logisticsTasks = memo.penjadwalanHistory
        .where((j) =>
            j.tipeTugas == 'PENGIRIMAN' ||
            j.tipeTugas == 'PENGAMBILAN' ||
            j.tipeTugas == 'DROP_OFF_EKSPEDISI')
        .toList();

    if (logisticsTasks.isNotEmpty) {
      final last = logisticsTasks.last;
      if (last.personelName != null && last.personelName!.isNotEmpty) {
        return last.personelName!;
      }
      // Tambahkan pengecekan marketingName di jadwal (untuk kasus ditugaskan ke marketing lain)
      if (last.marketingName != null && last.marketingName!.isNotEmpty) {
        return last.marketingName!;
      }
    }
    if (memo.isMarketingDelivery &&
        memo.marketingName != null &&
        memo.marketingName!.isNotEmpty) {
      return memo.marketingName!;
    }
    if (memo.ekspedisi != null && memo.ekspedisi!.isNotEmpty) {
      return memo.ekspedisi!;
    }
    return 'Pengirim Belum Ditentukan';
  }

  String _toTitleCase(String str) {
    if (str.isEmpty) return str;
    return str.toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Widget _buildOpsiBadge(MemoDetail memo, ThemeData theme) {
    final String opsi = memo.opsiPengiriman ?? '';
    final bool isDelivery = opsi.toUpperCase().contains('DELIVERY') ||
        opsi.toUpperCase().contains('KIRIM') ||
        opsi.toUpperCase().contains('DIKIRIM');

    if (!isDelivery) {
      return _createOpsiBadge(
          'AMBIL DI TOKO', Colors.deepOrange, Icons.store_rounded);
    }

    final isMarketingDelivery = memo.isMarketingDelivery;
    final String label =
        isMarketingDelivery ? 'DIKIRIM (MARKETING)' : 'DIKIRIM (DELIVERY)';
    final Color color = isMarketingDelivery ? Colors.purple : Colors.blue;

    return _createOpsiBadge(label, color, Icons.local_shipping_rounded);
  }

  Widget _createOpsiBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  MemoDetail _mapTaskToMemo(PenjadwalanResponse task) {
    // Map PenjadwalanResponse to MemoDetail so we can reuse existing UI components
    return MemoDetail(
      id: task.memoId ?? 'task-${task.id}',
      nomorMemo: task.nomorMemo ?? 'DIRECT-${task.id}',
      customerName: task.namaPenerima ??
          task.manualCustomerName ??
          task.nomorMemo ??
          'Direct Request',
      customerPhone: task.manualNoHp,
      deskripsi: task.catatan,
      memoType: task.memoId == null ? 'DIRECT' : 'REGULAR',
      marketingName: task.marketingName,
      statusAkhir: _mapJadwalStatusToMemoStatus(task.statusJadwal ?? ''),
      kabupatenKota: task.kabupatenKota,
      kecamatan: task.kecamatan,
      desaKelurahan: task.desaKelurahan,
      penjadwalanHistory: [
        PenjadwalanResponse(
          id: task.id,
          memoId: task.memoId,
          nomorMemo: task.nomorMemo,
          tipeTugas: task.tipeTugas,
          statusJadwal: task.statusJadwal,
          alamatLengkap: task.alamatLengkap,
          alamatMaps: task.alamatMaps,
          idKodepos: task.idKodepos,
          estimasiWaktu: task.estimasiWaktu,
          catatan: task.catatan,
          tanggalJadwal: task.tanggalJadwal,
          personelId: task.personelId,
          kodePos: task.kodePos,
          kecamatan: task.kecamatan,
          desaKelurahan: task.desaKelurahan,
          kabupatenKota: task.kabupatenKota,
          isUrgen: task.isUrgen,
          manualCustomerName: task.manualCustomerName,
          manualNoHp: task.manualNoHp,
          marketingName: task.marketingName,
        )
      ],
      items: const [],
    );
  }

  MemoStatus _mapJadwalStatusToMemoStatus(String status) {
    if (status.isEmpty) return MemoStatus.MENUNGGU_PENGIRIMAN;

    switch (status.toUpperCase()) {
      case 'MENUNGGU_KONFIRMASI':
      case 'DIJADWALKAN':
        return MemoStatus.MENUNGGU_PENGIRIMAN;
      case 'DALAM_PENGIRIMAN':
        return MemoStatus.DALAM_PENGIRIMAN;
      case 'SELESAI':
        return MemoStatus.DITERIMA_USER;
      default:
        return MemoStatus.MENUNGGU_PENGIRIMAN;
    }
  }
}

class _InfoTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _InfoTag(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
