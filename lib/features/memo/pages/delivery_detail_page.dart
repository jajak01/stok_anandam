import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stok_anandam/features/shared/widgets/camera_screen.dart';
import 'package:stok_anandam/core/widgets/action_slider.dart';
import 'package:stok_anandam/core/services/delivery_location_binder.dart';
import 'package:stok_anandam/data/models/memo.dart';
import 'package:stok_anandam/data/models/penjadwalan.dart';
import 'package:stok_anandam/features/memo/bloc/memo_bloc.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/features/shared/widgets/simple_barcode_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stok_anandam/core/env/app_env.dart';

class DeliveryDetailPage extends StatefulWidget {
  final String id;
  const DeliveryDetailPage({super.key, required this.id});

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  String? _scannedResi;
  bool _resiMatched = false;
  bool _isScanning = false;
  XFile? _packagePhoto;

  // ─────────────────────────────────────────────────────────────────
  //  Helper: apakah tipe pengiriman INSTANT?
  // ─────────────────────────────────────────────────────────────────
  bool _checkIsInstant(MemoDetail memo) {
    return (memo.ekspedisi ?? '').toLowerCase().contains('instan') ||
        (memo.tipeOngkir ?? '').toLowerCase().contains('instan') ||
        (memo.subEkspedisi ?? '').toLowerCase().contains('instan') ||
        (memo.opsiPengiriman ?? '').toLowerCase().contains('instan');
  }

  bool _isWaitingDelivery(MemoDetail memo) {
    return memo.statusAkhir == MemoStatus.MENUNGGU_PENGIRIMAN ||
        memo.statusAkhir == MemoStatus.DIJADWALKAN ||
        memo.statusAkhir == MemoStatus.BUFFER_ZONE ||
        memo.statusAkhir == MemoStatus.MENUNGGU_EXPEDISI;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MemoBloc(getIt())..add(LoadMemoDetail(widget.id)),
      child: BlocConsumer<MemoBloc, MemoState>(
        listener: (context, state) {
          if (state is MemoOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: Colors.green),
            );
            // Refresh detail data immediately to update UI status
            context.read<MemoBloc>().add(LoadMemoDetail(widget.id));
            setState(() {
              _scannedResi = null;
              _resiMatched = false;
            });
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

          if (state is MemoDetailLoaded) {
            final memo = state.detail;
            final isInstant = _checkIsInstant(memo);
            final isWaiting = _isWaitingDelivery(memo);
            final isActiveDelivery = isWaiting ||
                memo.statusAkhir == MemoStatus.DALAM_PENGIRIMAN;

            return DeliveryLocationBinder(
              deliveryId: widget.id,
              menuCode: 'DELIVERY',
              active: memo.statusAkhir == MemoStatus.DALAM_PENGIRIMAN,
              child: Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text('Detail Pengantaran',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  actions: [
                    if (isWaiting)
                      IconButton(
                        icon:
                            const Icon(Icons.cancel_outlined, color: Colors.red),
                        tooltip: 'Lepas Tugas (Batal Ambil)',
                        onPressed: () => _confirmReleaseTask(context, memo),
                      ),
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Builder(builder: (context) {
                    final jadwal = memo.penjadwalanHistory.isNotEmpty
                        ? memo.penjadwalanHistory.last
                        : null;
                    return Column(
                      children: [
                        _buildStatusHeader(memo),
                        _buildCustomerCard(memo),
                        if (jadwal?.tipeTugas == 'DROP_OFF_EKSPEDISI')
                          _buildManifestCard(jadwal!),
                        _buildLogisticsCard(memo),
                        _buildLocationCard(memo),
                        _buildItemsCard(memo),
                        // Scan Resi: tampil saat aktif pengiriman
                        if (isActiveDelivery)
                          _buildResiScanCard(context, memo, isInstant),
                        // Foto paket: tampil setelah resi match ATAU status DALAM_PENGIRIMAN
                        if (isActiveDelivery &&
                            (_resiMatched ||
                                memo.statusAkhir ==
                                    MemoStatus.DALAM_PENGIRIMAN))
                          _buildPackagePhotoCard(context, memo, isInstant),
                      ],
                    );
                  }),
                ),
                bottomSheet: _buildStickyFooter(context, memo, isInstant),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: TextButton(
                onPressed: () =>
                    context.read<MemoBloc>().add(LoadMemoDetail(widget.id)),
                child: const Text('Gagal memuat. Ketuk untuk coba lagi.'),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  STATUS HEADER
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStatusHeader(MemoDetail memo) {
    final status = memo.statusAkhir;
    int currentStep = 0;
    if (_isWaitingDelivery(memo)) currentStep = 1;
    if (status == MemoStatus.DALAM_PENGIRIMAN) currentStep = 2;
    if (status == MemoStatus.DITERIMA_USER || status == MemoStatus.SELESAI) currentStep = 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
              2, Icons.local_shipping_rounded, currentStep >= 2, 'Jalan'),
          _buildStepDivider(currentStep >= 3),
          _buildStepIcon(
              3, Icons.check_circle_rounded, currentStep >= 3, 'Sampai'),
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
                        offset: const Offset(0, 4)),
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

  // ─────────────────────────────────────────────────────────────────
  //  CUSTOMER CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildCustomerCard(MemoDetail memo) {
    return _buildCard(
      icon: Icons.person_rounded,
      title: 'Informasi Pelanggan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (memo.customerName ?? 'Tanpa Nama').toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  memo.customerPhone ?? '-',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  if (memo.customerPhone != null) {
                    Clipboard.setData(ClipboardData(text: memo.customerPhone!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nomor HP disalin')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildWaButton(memo.customerPhone),
            ],
          ),
          if (memo.orderIdMarketplace != null &&
              memo.orderIdMarketplace!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order ID: ${memo.orderIdMarketplace}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    if (memo.orderIdMarketplace != null) {
                      Clipboard.setData(
                          ClipboardData(text: memo.orderIdMarketplace!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order ID disalin')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaButton(String? phone) {
    if (phone == null || phone.isEmpty) return const SizedBox();
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('0')) clean = '62${clean.substring(1)}';
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('https://wa.me/$clean')),
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
        child: const Icon(Icons.message_rounded, color: Colors.white, size: 14),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  MANIFEST CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildManifestCard(PenjadwalanResponse jadwal) {
    return _buildCard(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Informasi Manifest Ekspedisi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ID Manifest:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(jadwal.manifestId ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.purple,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Daftar Memo/Resi dalam Manifest:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: (jadwal.manifestResiList ?? [])
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 14, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(e,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 13)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  LOGISTICS CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLogisticsCard(MemoDetail memo) {
    final jadwal = memo.penjadwalanHistory.isNotEmpty
        ? memo.penjadwalanHistory.last
        : null;

    return _buildCard(
      icon: Icons.local_shipping_rounded,
      title: 'Logistik & Penjadwalan',
      child: Column(
        children: [
          _buildInfoRow('Marketing', memo.marketingName ?? '-'),
          const Divider(height: 24),
          _buildInfoRow('Tanggal Kirim',
              jadwal?.updatedAt ?? jadwal?.tanggalJadwal ?? '-'),
          const Divider(height: 24),
          _buildInfoRow('Estimasi (ETA)', jadwal?.estimasiWaktu ?? '-'),
          if (memo.resi != null && memo.resi!.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                    child: Text('Nomor Resi',
                        style: TextStyle(fontSize: 12, color: Colors.grey))),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(memo.resi!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Colors.indigo)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: memo.resi!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Resi disalin'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy_rounded,
                          size: 14, color: Colors.indigo),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (jadwal?.catatan != null && jadwal!.catatan!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catatan Penjadwalan:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey)),
                  const SizedBox(height: 4),
                  Text(jadwal.catatan!,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  LOCATION CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLocationCard(MemoDetail memo) {
    final jadwal = memo.penjadwalanHistory.isNotEmpty
        ? memo.penjadwalanHistory.last
        : null;
    final address =
        jadwal?.alamatLengkap ?? memo.deskripsi ?? 'Alamat tidak tersedia';
    final mapsUrl = jadwal?.alamatMaps;

    return _buildCard(
      icon: Icons.location_on_rounded,
      title: 'Alamat Pengiriman',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Kode Pos', jadwal?.kodePos ?? memo.kodePos ?? '-'),
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

  // ─────────────────────────────────────────────────────────────────
  //  ITEMS CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildItemsCard(MemoDetail memo) {
    return _buildCard(
      icon: Icons.inventory_2_rounded,
      title: 'Daftar Barang & Harga',
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: memo.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = memo.items[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(item.namaBarang ?? 'Item Tidak Dikenal',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3)),
                      ),
                      const SizedBox(width: 8),
                      Text('x${item.qty}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_formatCurrency(item.hargaSatuan)} / unit',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      Text(_formatCurrency(item.subtotal),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL PESANAN',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey)),
              Text(
                _formatCurrency(memo.totalHarga),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.indigo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  RESI SCAN CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildResiScanCard(
      BuildContext context, MemoDetail memo, bool isInstant) {
    final hasResi = memo.resi != null && memo.resi!.trim().isNotEmpty;
    final role = getIt<CurrentUserStore>().userRole?.toUpperCase() ?? '';
    final canScan = role == 'DELIVERY' ||
        role == 'GUDANG' ||
        role == 'SPV_GUDANG' ||
        role == 'ADMIN' ||
        role == 'MANAGER' ||
        role.startsWith('MARKETING');

    if (!canScan) return const SizedBox();

    // Jika status sudah DALAM_PENGIRIMAN, berarti resi sudah pernah diverifikasi
    final alreadyShipping = memo.statusAkhir == MemoStatus.DALAM_PENGIRIMAN;
    final isVerified = _resiMatched || alreadyShipping;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVerified ? Colors.green.shade300 : Colors.orange.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: isVerified
                  ? Colors.green.withValues(alpha: 0.08)
                  : Colors.orange.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isVerified
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isVerified
                      ? Icons.check_circle_rounded
                      : Icons.qr_code_scanner_rounded,
                  size: 18,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alreadyShipping
                      ? 'RESI TERVERIFIKASI — SEDANG DIKIRIM'
                      : 'SCAN RESI PAKET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isVerified ? Colors.green : Colors.orange.shade800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isInstant)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('INSTANT',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.purple)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Resi dari memo
          if (hasResi) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isVerified ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isVerified
                        ? Colors.green.shade200
                        : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 16,
                      color: isVerified ? Colors.green : Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          isVerified ? 'Resi: ' : 'Resi Memo: ',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  isVerified ? Colors.green : Colors.blueGrey,
                              fontWeight: FontWeight.w600),
                        ),
                        Expanded(
                          child: Text(memo.resi!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: isVerified
                                      ? Colors.green.shade700
                                      : Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: memo.resi!));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Resi disalin'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                    child: const Icon(Icons.copy_rounded,
                        size: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Memo belum punya nomor resi. Scan untuk menginput resi baru.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Hasil scan sesi ini
          if (_scannedResi != null) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _resiMatched ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _resiMatched
                        ? Colors.green.shade300
                        : Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    _resiMatched
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 18,
                    color: _resiMatched ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resiMatched ? 'Resi Cocok! ✓' : 'Resi Tidak Cocok',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _resiMatched ? Colors.green : Colors.red,
                          ),
                        ),
                        Text('Scan: $_scannedResi',
                            style: const TextStyle(
                                fontSize: 12, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Tombol Scan / Info Status
          if (alreadyShipping && !_resiMatched) ...[
            // Sudah DALAM_PENGIRIMAN — tampilkan info + tombol verifikasi ulang
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sedang dalam pengiriman. Resi sudah diverifikasi sebelumnya.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isScanning
                  ? null
                  : () => _doScanResi(context, memo, isInstant),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
              label: const Text('Verifikasi Ulang Resi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else if (!_resiMatched) ...[
            // Belum scan — tampilkan tombol scan utama
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning
                    ? null
                    : () => _doScanResi(context, memo, isInstant),
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: Text(_scannedResi == null ? 'Scan Resi' : 'Scan Ulang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildManualResiInput(context, memo, isInstant),
          ] else ...[
            // Resi matched sesi ini
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.teal.shade400]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isInstant
                          ? 'Resi cocok! Paket siap diselesaikan sekarang.'
                          : 'Resi cocok! Status berubah ke Sedang Dikirim.',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualResiInput(
      BuildContext context, MemoDetail memo, bool isInstant) {
    final controller = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Input resi manual...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            final input = controller.text.trim();
            if (input.isEmpty) return;
            _matchResi(context, memo, input, isInstant);
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.indigo,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child:
              const Text('Cek', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  PACKAGE PHOTO CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPackagePhotoCard(
      BuildContext context, MemoDetail memo, bool isInstant) {
    String? photoUrl;
    if (memo.buktiFotoUrl != null && memo.buktiFotoUrl!.isNotEmpty) {
      photoUrl = memo.buktiFotoUrl!.startsWith('http')
          ? memo.buktiFotoUrl
          : '$apiBaseUrl${memo.buktiFotoUrl!.startsWith('/') ? '' : '/'}${memo.buktiFotoUrl}';
    } else if (memo.buktiFoto != null && memo.buktiFoto!.isNotEmpty) {
      photoUrl = memo.buktiFoto!.startsWith('http')
          ? memo.buktiFoto
          : '$apiBaseUrl/uploads/${memo.buktiFoto}';
    }
    final bool hasBackendPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final bool hasLocalPhoto = _packagePhoto != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.indigo.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.indigo.withValues(alpha: 0.06),
              blurRadius: 15,
              offset: const Offset(0, 8)),
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
                  color: Colors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    size: 18, color: Colors.indigo),
              ),
              const SizedBox(width: 10),
              const Text(
                'FOTO PAKET (OPSIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.indigo,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ambil foto paket sebagai bukti keamanan. Foto ini bisa dilihat oleh semua pihak.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (!hasBackendPhoto && !hasLocalPhoto)
            GestureDetector(
              onTap: () => _takePackagePhoto(context),
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.indigo.withValues(alpha: 0.2), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: Colors.indigo, size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text('Ketuk untuk Foto Paket',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Opsional — untuk keamanan',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                GestureDetector(
                  onTap: () => _showFullScreenImage(context, photoUrl, _packagePhoto),
                  child: Stack(
                    children: [
                      // Tampilkan foto dari backend jika ada, jika tidak tampilkan dari local
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: hasBackendPhoto
                            ? Builder(builder: (context) {
                                final token = getIt<TokenStorage>().token;
                                return Image.network(
                                  photoUrl!,
                                  headers: {
                                    if (token != null && token.isNotEmpty)
                                      'Authorization': 'Bearer $token',
                                  },
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: double.infinity,
                                      height: 200,
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stack) {
                                    // Jika gagal load dari backend, fallback ke local
                                    if (hasLocalPhoto) {
                                      return Image.file(
                                        File(_packagePhoto!.path),
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return Container(
                                      width: double.infinity,
                                      height: 200,
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: Icon(Icons.broken_image,
                                            size: 48, color: Colors.grey),
                                      ),
                                    );
                                  },
                                );
                              })
                            : Image.file(
                                File(_packagePhoto!.path),
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.zoom_in,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Tap untuk perbesar',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      hasBackendPhoto
                          ? 'Foto bukti tersimpan di server'
                          : 'Foto bukti berhasil diambil',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  FULL SCREEN IMAGE VIEWER
  // ─────────────────────────────────────────────────────────────────
  void _showFullScreenImage(
      BuildContext context, String? photoUrl, XFile? localPhoto) {
    final token = getIt<TokenStorage>().token;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        headers: {
                          if (token != null && token.isNotEmpty)
                            'Authorization': 'Bearer $token',
                        },
                        fit: BoxFit.contain,
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                      )
                    : (localPhoto != null
                        ? Image.file(
                            File(localPhoto.path),
                            fit: BoxFit.contain,
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                          )
                        : const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white, size: 64))),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  STICKY FOOTER
  // ─────────────────────────────────────────────────────────────────
  Widget _buildStickyFooter(
      BuildContext context, MemoDetail memo, bool isInstant) {
    if (memo.statusAkhir == MemoStatus.DITERIMA_USER) return const SizedBox();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -5)),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isWaitingDelivery(memo)) ...[
              if (!_resiMatched) ...[
                // Belum scan / belum match — slider normal mulai jalan
                ActionSlider(
                  label: 'GESER UNTUK MULAI JALAN',
                  icon: Icons.local_shipping_rounded,
                  baseColor: Colors.indigo,
                  onComplete: () {
                    HapticFeedback.mediumImpact();
                    _handleAction(context, memo);
                  },
                ),
              ] else if (isInstant) ...[
                // INSTANT + resi match → selesaikan langsung
                _buildGradientButton(
                  label: 'SELESAIKAN INSTANT',
                  icon: Icons.bolt_rounded,
                  colors: const [Colors.purple, Color(0xFF7C3AED)],
                  shadowColor: Colors.purple,
                  onTap: () => _showInstantFinishModal(context, memo),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _confirmReleaseTask(context, memo),
                icon: const Icon(Icons.cancel_outlined,
                    size: 16, color: Colors.red),
                label: const Text(
                  'Lepas Tugas (Tidak Jadi Kirim)',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              // Reguler + resi match → sudah auto update via _matchResi
            ] else if (memo.statusAkhir == MemoStatus.DALAM_PENGIRIMAN) ...[
              _buildGradientButton(
                label: 'SELESAIKAN PENGIRIMAN',
                icon: Icons.check_circle_outline_rounded,
                colors: const [Colors.teal, Color(0xFF10B981)],
                shadowColor: Colors.teal,
                onTap: () => _handleAction(context, memo),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmReleaseTask(BuildContext context, MemoDetail memo) {
    final String nomor = memo.nomorMemo ?? memo.id ?? 'Memo';
    final memoBloc = context.read<MemoBloc>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lepas Tugas Pengiriman?'),
        content: Text(
            'Apakah Anda yakin ingin melepas tugas pengiriman $nomor?\n\nBarang ini akan dikembalikan ke antrean agar bisa diambil oleh kurir lain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (memo.id != null) {
                memoBloc.add(DeliveryReleaseByMemoIdEvent(memo.id!));
                Navigator.pop(context); // Kembali ke daftar pengiriman
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Lepas Tugas'),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: shadowColor.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  ACTIONS
  // ─────────────────────────────────────────────────────────────────
  Future<void> _handleAction(BuildContext context, MemoDetail memo) async {
    final bloc = context.read<MemoBloc>();
    if (_isWaitingDelivery(memo)) {
      bloc.add(UpdateMemoStatusEvent(memo.id!, MemoStatus.DALAM_PENGIRIMAN,
          'Mulai Pengiriman oleh Kurir'));
    } else if (memo.statusAkhir == MemoStatus.DALAM_PENGIRIMAN) {
      _showFinishDeliveryModal(context, memo, bloc);
    }
  }

  Future<void> _doScanResi(
      BuildContext context, MemoDetail memo, bool isInstant) async {
    setState(() => _isScanning = true);
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => const SimpleBarcodeScanner(title: 'Scan Resi Paket')),
    );
    setState(() => _isScanning = false);
    if (!context.mounted) return;
    if (scanned != null && scanned.trim().isNotEmpty) {
      _matchResi(context, memo, scanned.trim(), isInstant);
    }
  }

  void _matchResi(
      BuildContext context, MemoDetail memo, String scanned, bool isInstant) {
    final memoResi = memo.resi?.trim() ?? '';
    final matched =
        memoResi.isNotEmpty && memoResi.toLowerCase() == scanned.toLowerCase();

    setState(() {
      _scannedResi = scanned;
      _resiMatched = matched;
    });

    if (matched) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isInstant
                    ? 'Resi cocok! Paket langsung bisa diselesaikan.'
                    : 'Resi cocok! Status berubah ke Sedang Dikirim.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      // Reguler: otomatis ubah status ke DALAM_PENGIRIMAN
      if (!isInstant) {
        context.read<MemoBloc>().add(UpdateMemoStatusEvent(
              memo.id!,
              MemoStatus.DALAM_PENGIRIMAN,
              'Resi dicocokkan — Mulai Pengiriman',
            ));
      }
    } else {
      HapticFeedback.vibrate();
      final isNoResi = memoResi.isEmpty;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(isNoResi ? Icons.info_rounded : Icons.cancel_rounded,
                color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isNoResi
                    ? 'Resi "$scanned" disimpan ke memo ini.'
                    : 'Resi tidak cocok! Scan ulang atau cek nomor resi.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isNoResi ? Colors.blue : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      // Jika memo belum punya resi, simpan resi yang di-scan
      if (isNoResi) {
        context.read<MemoBloc>().add(UpdateMemoResiEvent(memo.id!, scanned));
      }
    }
  }

  Future<void> _takePackagePhoto(BuildContext context) async {
    final bloc = context.read<MemoBloc>();
    final photo = await _pickPhoto(context);
    if (photo != null) {
      // Upload foto ke backend sebagai audit log via repository langsung
      // (tanpa lewat Bloc event agar tidak trigger loading state yang mengganggu UI)
      try {
        final repo = bloc.repository;
        await repo.uploadEvidencePhoto(
          widget.id,
          filePath: photo.path,
          fileName: photo.name,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto bukti berhasil disimpan'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan foto: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      setState(() => _packagePhoto = photo);
    }
  }

  Future<XFile?> _pickPhoto(BuildContext context) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final picker = ImagePicker();
      return picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    } else {
      return Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  INSTANT FINISH MODAL
  // ─────────────────────────────────────────────────────────────────
  void _showInstantFinishModal(BuildContext outerContext, MemoDetail memo) {
    final bloc = outerContext.read<MemoBloc>();
    final namaPenerimaCtrl = TextEditingController();

    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          XFile? localPhoto = _packagePhoto;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
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
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const Icon(Icons.bolt_rounded,
                      size: 36, color: Colors.purple),
                  const SizedBox(height: 8),
                  const Text('Selesaikan Instant',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'Pengiriman INSTANT akan langsung diselesaikan setelah konfirmasi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  // Foto opsional
                  GestureDetector(
                    onTap: () async {
                      final photo = await _pickPhoto(context);
                      if (photo != null) {
                        setModalState(() => localPhoto = photo);
                        setState(() => _packagePhoto = photo);
                      }
                    },
                    child: localPhoto != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(File(localPhoto.path),
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.refresh_rounded,
                                      color: Colors.purple, size: 18),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.purple.withValues(alpha: 0.2),
                                  width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded,
                                    color: Colors.purple.shade300, size: 32),
                                const SizedBox(height: 8),
                                const Text('Ambil Foto (Opsional)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple)),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: namaPenerimaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Penerima (Opsional)',
                      hintText: 'Cth: Budi Santoso',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ActionSlider(
                    label: 'GESER UNTUK SELESAIKAN',
                    icon: Icons.bolt_rounded,
                    baseColor: Colors.purple,
                    onComplete: () {
                      HapticFeedback.heavyImpact();
                      final catatan =
                          'Pengiriman INSTANT selesai${namaPenerimaCtrl.text.trim().isNotEmpty ? " — Diterima: ${namaPenerimaCtrl.text.trim()}" : ""}';
                      if (localPhoto != null) {
                        bloc.add(FinishDeliveryProcessEvent(
                          id: memo.id!,
                          photo: localPhoto!,
                          catatan: catatan,
                          resi: _scannedResi,
                        ));
                      } else {
                        bloc.add(UpdateMemoStatusEvent(
                          memo.id!,
                          MemoStatus.DITERIMA_USER,
                          catatan,
                        ));
                      }
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  FINISH DELIVERY MODAL (status DALAM_PENGIRIMAN → DITERIMA_USER)
  // ─────────────────────────────────────────────────────────────────
  void _showFinishDeliveryModal(
      BuildContext outerContext, MemoDetail memo, MemoBloc bloc) {
    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        XFile? localPhoto;
        return StatefulBuilder(builder: (context, setModalState) {
          final isOnlineOrMarketingOnline = memo.memoType == 'ONLINE' ||
              getIt<CurrentUserStore>().userRole == 'MARKETING_ONLINE';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
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
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const Text('Konfirmasi Selesai',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final isExpedition = memo.penjadwalanHistory.isNotEmpty &&
                        memo.penjadwalanHistory.last.tipeTugas ==
                            'DROP_OFF_EKSPEDISI';
                    return Text(
                        isExpedition
                            ? 'WAJIB: Ambil foto bukti Drop-off Ekspedisi untuk laporan manifest.'
                            : 'Mohon ambil foto bukti sebagai syarat penyelesaian.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: isExpedition ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.w600));
                  }),
                  const SizedBox(height: 32),
                  if (localPhoto == null)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final photo = await _pickPhoto(context);
                            if (photo != null) {
                              setModalState(() => localPhoto = photo);
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
                                  width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.indigo, size: 32),
                                ),
                                const SizedBox(height: 16),
                                const Text('Ketuk untuk Ambil Foto',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo)),
                              ],
                            ),
                          ),
                        ),
                        if (isOnlineOrMarketingOnline) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                bloc.add(UpdateMemoStatusEvent(
                                  memo.id!,
                                  MemoStatus.DITERIMA_USER,
                                  'Pengiriman online diselesaikan tanpa foto',
                                ));
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Selesaikan Tanpa Foto'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Colors.teal, width: 2),
                                foregroundColor: Colors.teal,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ],
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
                                  image: FileImage(File(localPhoto!.path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
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
                                      color: Colors.indigo, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        ActionSlider(
                          label: 'GESER UNTUK SELESAIKAN',
                          icon: Icons.check_rounded,
                          baseColor: Colors.teal,
                          onComplete: () {
                            HapticFeedback.heavyImpact();
                            bloc.add(FinishDeliveryProcessEvent(
                              id: memo.id!,
                              photo: localPhoto!,
                              catatan: 'Pengiriman diselesaikan oleh Kurir',
                            ));
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  SHARED CARD WIDGET
  // ─────────────────────────────────────────────────────────────────
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
              offset: const Offset(0, 8)),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: Colors.indigo),
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey,
                  letterSpacing: 0.5,
                ),
              ),
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

  String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }
}
