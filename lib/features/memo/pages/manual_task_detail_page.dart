import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stok_anandam/features/shared/widgets/camera_screen.dart';
import 'package:stok_anandam/core/widgets/action_slider.dart';
import 'package:stok_anandam/core/services/delivery_location_binder.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/data/models/penjadwalan.dart';
import 'package:stok_anandam/features/memo/bloc/memo_bloc.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';
import 'package:stok_anandam/data/repositories/memo_repository.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:url_launcher/url_launcher.dart';

class ManualTaskDetailPage extends StatefulWidget {
  final String id;
  const ManualTaskDetailPage({super.key, required this.id});

  @override
  State<ManualTaskDetailPage> createState() => _ManualTaskDetailPageState();
}

class _ManualTaskDetailPageState extends State<ManualTaskDetailPage> {
  final _namaPenerimaController = TextEditingController();
  final _catatanOperasionalController = TextEditingController();

  @override
  void dispose() {
    _namaPenerimaController.dispose();
    _catatanOperasionalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          MemoBloc(getIt())..add(LoadManualTaskDetail(widget.id)),
      child: BlocConsumer<MemoBloc, MemoState>(
        listener: (context, state) {
          if (state is MemoOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: Colors.green),
            );
            context.read<MemoBloc>().add(LoadManualTaskDetail(widget.id));
          } else if (state is MemoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is MemoLoading || state is MemoInitial) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          if (state is ManualTaskDetailLoaded) {
            final task = state.task;
            return DeliveryLocationBinder(
              deliveryId: widget.id,
              menuCode: 'MANUAL_TASK',
              active: task.statusJadwal == 'DALAM_PENGIRIMAN',
              child: Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text('Detail Manual Request',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    children: [
                      _buildStatusHeader(task),
                      _buildCustomerCard(task),
                      if (task.statusJadwal == 'SELESAI' &&
                          task.fotoBukti != null)
                        _buildProofCard(task),
                      _buildLogisticsCard(task, context),
                      _buildLocationCard(task),
                    ],
                  ),
                ),
                bottomSheet: _buildStickyFooter(context, task),
              ),
            );
          }

          final String errorMsg = (state is MemoError)
              ? state.error
              : 'Terjadi kesalahan saat memuat data.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Detail Manual Request',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(errorMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context
                        .read<MemoBloc>()
                        .add(LoadManualTaskDetail(widget.id)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(PenjadwalanResponse task) {
    final isJadwal = task.statusJadwal == 'DIJADWALKAN';
    final isJalan = task.statusJadwal == 'DALAM_PENGIRIMAN';
    final isSelesai = task.statusJadwal == 'SELESAI';

    // 1: Siap, 2: Dijadwalkan, 3: Jalan, 4: Sampai
    int currentStep = 1;
    if (isSelesai) {
      currentStep = 4;
    } else if (isJalan) {
      currentStep = 3;
    } else if (isJadwal) {
      currentStep = 2;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIcon(
              1, Icons.inventory_2_rounded, currentStep >= 1, 'Siap'),
          _buildStepDivider(currentStep >= 2),
          _buildStepIcon(
              2, Icons.event_available_rounded, currentStep >= 2, 'Jadwal'),
          _buildStepDivider(currentStep >= 3),
          _buildStepIcon(
              3, Icons.local_shipping_rounded, currentStep >= 3, 'Jalan'),
          _buildStepDivider(currentStep >= 4),
          _buildStepIcon(
              4, Icons.check_circle_rounded, currentStep >= 4, 'Sampai'),
        ],
      ),
    );
  }

  Widget _buildProofCard(PenjadwalanResponse task) {
    return _buildCard(
      icon: Icons.image_rounded,
      title: 'Bukti Pengiriman',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Penerima: ${task.namaPenerima ?? "-"}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          if (task.catatanOperasional != null &&
              task.catatanOperasional!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Catatan: ${task.catatanOperasional}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Builder(builder: (context) {
              final token = getIt<TokenStorage>().token;
              final baseUrl = getIt<ApiNewEndpoints>().baseUrl;
              final photoUrl = task.fotoBukti != null && task.fotoBukti!.isNotEmpty
                  ? (task.fotoBukti!.startsWith('http')
                      ? task.fotoBukti!
                      : (task.fotoBukti!.startsWith('/')
                          ? '$baseUrl${task.fotoBukti}'
                          : '$baseUrl/uploads/${task.fotoBukti}'))
                  : '';
              return Image.network(
                photoUrl,
                headers: {
                  if (token != null && token.isNotEmpty)
                    'Authorization': 'Bearer $token',
                },
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.grey.shade200,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Gagal memuat gambar',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIcon(int step, IconData icon, bool isActive, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? Colors.indigo : Colors.grey.shade100,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.indigo.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Icon(icon,
              color: isActive ? Colors.white : Colors.grey.shade400, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
            color: isActive ? Colors.indigo : Colors.grey.shade400,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 20),
        decoration: BoxDecoration(
          color: isActive ? Colors.indigo : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(PenjadwalanResponse task) {
    return _buildCard(
      icon: Icons.person_rounded,
      title: 'Informasi Pelanggan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.manualCustomerName ?? task.nomorMemo ?? 'Tanpa Nama',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  task.manualNoHp ?? '-',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  if (task.manualNoHp != null) {
                    Clipboard.setData(ClipboardData(text: task.manualNoHp!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nomor HP disalin')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildCommunicationTools(task.manualNoHp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationTools(String? phone) {
    if (phone == null || phone.isEmpty) return const SizedBox();
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }
    return Row(
      children: [
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('https://wa.me/$cleanPhone')),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF25D366).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.message_rounded,
                color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLogisticsCard(
      PenjadwalanResponse task, BuildContext outerContext) {
    return _buildCard(
      icon: Icons.local_shipping_rounded,
      title: 'Logistik & Penjadwalan',
      child: Column(
        children: [
          _buildInfoRow('Marketing', task.marketingName ?? '-'),
          const Divider(height: 24),
          _buildInfoRow(
              'Tanggal Jadwal', task.tanggalJadwal ?? 'Belum dijadwalkan'),
          const Divider(height: 24),
          _buildInfoRow(
              'Estimasi Waktu', task.estimasiWaktu ?? 'Belum ditentukan'),
          const Divider(height: 24),
          _buildInfoRow('Driver / Kurir', task.personelName ?? 'Belum ada'),
          if (task.catatan != null && task.catatan!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catatan Pengiriman / Pengambilan:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo)),
                  const SizedBox(height: 8),
                  Text(task.catatan!,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87)),
                ],
              ),
            ),
          ],
          if (task.statusJadwal != 'SELESAI') ...[
            const SizedBox(height: 16),
            if (['ADMIN', 'MANAGER', 'GUDANG', 'SPV_GUDANG']
                .contains(getIt<CurrentUserStore>().userRole))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAssignmentModal(outerContext, task),
                  icon: const Icon(Icons.assignment_ind_rounded),
                  label: Text(task.personelId == null
                      ? 'Jadwalkan Delivery'
                      : 'Ubah Jadwal/Delivery'),
                ),
              ),
          ]
        ],
      ),
    );
  }

  void _showAssignmentModal(
      BuildContext outerContext, PenjadwalanResponse task) {
    final bloc = outerContext.read<MemoBloc>();
    final repository = getIt<MemoRepository>();

    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    repository.getUsersByRole('DELIVERY').then((drivers) {
      if (!mounted) return;
      Navigator.pop(outerContext); // dismiss loader

      int? selectedDriverId = task.personelId;
      DateTime selectedDate = DateTime.now();
      String? selectedTime = task.estimasiWaktu;


      // parse existing date if available
      if (task.tanggalJadwal != null && task.tanggalJadwal!.isNotEmpty) {
        try {
          final parts = task.tanggalJadwal!.split('-');
          if (parts.length == 3) {
            selectedDate = DateTime(
                int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } catch (_) {}
      }

      showDialog(
        context: outerContext,
        builder: (ctx) => AlertDialog(
          title: const Text('Penugasan Driver'),
          content: StatefulBuilder(
            builder: (ctx, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Driver / Kurir:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedDriverId,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        fillColor: null,
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
                    const Text('Tanggal & Waktu Rencana:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 7)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
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
                                      size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                      "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}",
                                      style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime != null
                                    ? TimeOfDay(
                                        hour: int.parse(
                                            selectedTime!.split(':')[0]),
                                        minute: int.parse(
                                            selectedTime!.split(':')[1]))
                                    : TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedTime =
                                      "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                });
                              }
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
                                  const Icon(Icons.access_time,
                                      size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(selectedTime ?? "Waktu",
                                      style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (selectedDriverId == null) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(
                          content: Text("Pilih driver terlebih dahulu")));
                  return;
                }
                if (selectedTime == null) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(
                          content:
                              Text("Pilih estimasi waktu terlebih dahulu")));
                  return;
                }
                final dateStr =
                    "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}";
                bloc.add(AssignManualTaskEvent(widget.id, {
                  'personelId': selectedDriverId,
                  'tanggalJadwal': dateStr,
                  'estimasiWaktu': selectedTime,
                }));
                Navigator.pop(ctx);
              },
              child: const Text('Simpan Tugas'),
            ),
          ],
        ),
      );
    }).catchError((e) {
      if (mounted) {
        Navigator.pop(outerContext);
        ScaffoldMessenger.of(outerContext)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    });
  }

  Widget _buildLocationCard(PenjadwalanResponse task) {
    final address = task.alamatLengkap ?? 'Alamat tidak tersedia';
    final mapsUrl = task.alamatMaps;

    return _buildCard(
      icon: Icons.location_on_rounded,
      title: 'Alamat Pengiriman',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Kode Pos', task.kodePos ?? '-'),
          const SizedBox(height: 12),
          Text(address,
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: Colors.black87)),
          if (mapsUrl != null && mapsUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(mapsUrl),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Buka Google Maps'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context, PenjadwalanResponse task) {
    if (task.statusJadwal == 'SELESAI' ||
        task.statusJadwal == 'MENUNGGU_KONFIRMASI') {
      return const SizedBox();
    }

    final String? role = getIt<CurrentUserStore>().userRole;
    if (role != 'DELIVERY' && role != 'TEKNISI') {
      return const SizedBox();
    }

    final bool canStart = task.statusJadwal == 'DIJADWALKAN';
    final bool canFinish = task.statusJadwal == 'DALAM_PENGIRIMAN';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: canStart
                    ? [Colors.indigo, Colors.blue]
                    : [Colors.teal, const Color(0xFF10B981)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: (canStart ? Colors.indigo : Colors.teal)
                      .withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              if (canStart) {
                _handleStartTask(context, task.id.toString());
              } else if (canFinish) {
                _showFinishDeliveryModal(
                    context, task, context.read<MemoBloc>());
              }
            },
            icon: Icon(
                canStart
                    ? Icons.play_arrow_rounded
                    : Icons.check_circle_outline_rounded,
                size: 20),
            label: Text(canStart ? 'SIAP JALAN' : 'SAMPAI',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  void _handleStartTask(BuildContext context, String id) async {
    final bloc = context.read<MemoBloc>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await getIt<ApiNewEndpoints>().startManualTask(id);
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loader
        bloc.add(LoadManualTaskDetail(id)); // Refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tugas berhasil dimulai!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal memulai tugas: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFinishDeliveryModal(
      BuildContext outerContext, PenjadwalanResponse task, MemoBloc bloc) {
    XFile? localPhoto;

    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2))),
                    const Text('Konfirmasi Sampai',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    const Text('Mohon ambil foto bukti penyelesaian (Sampai).',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 32),
                    if (localPhoto == null)
                      GestureDetector(
                        onTap: () async {
                          if (Platform.isWindows ||
                              Platform.isLinux ||
                              Platform.isMacOS) {
                            final ImagePicker picker = ImagePicker();
                            final XFile? photo = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                            );
                            if (photo != null) {
                              setModalState(() => localPhoto = photo);
                            }
                          } else {
                            final XFile? photo = await Navigator.push<XFile>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CameraScreen()),
                            );
                            if (photo != null) {
                              setModalState(() => localPhoto = photo);
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.indigo.withValues(alpha: 0.1),
                                  width: 2)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.indigo.withValues(alpha: 0.1),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.indigo, size: 32)),
                              const SizedBox(height: 16),
                              const Text('Ketuk untuk Ambil Foto',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo)),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    image: DecorationImage(
                                        image:
                                            FileImage(File(localPhoto!.path)),
                                        fit: BoxFit.cover)),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () =>
                                      setModalState(() => localPhoto = null),
                                  child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.refresh_rounded,
                                          color: Colors.indigo, size: 20)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _namaPenerimaController,
                            decoration: InputDecoration(
                              labelText: 'Nama Penerima (Wajib)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _catatanOperasionalController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Catatan Operasional (Opsional)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.note),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ActionSlider(
                            label: 'GESER JIKA SUDAH SAMPAI',
                            icon: Icons.check_rounded,
                            baseColor: Colors.teal,
                            onComplete: () {
                              if (_namaPenerimaController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Nama penerima wajib diisi!'),
                                      backgroundColor: Colors.red),
                                );
                                return;
                              }
                              HapticFeedback.heavyImpact();
                              bloc.add(FinishManualTaskProcessEvent(
                                id: task.id.toString(),
                                photo: localPhoto!,
                                namaPenerima:
                                    _namaPenerimaController.text.trim(),
                                catatanOperasional:
                                    _catatanOperasionalController.text.trim(),
                              ));
                              Navigator.pop(context); // Close modal
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(
      {required IconData icon, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: Colors.indigo)),
              const SizedBox(width: 10),
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
