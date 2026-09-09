import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/data/models/delivery_scan_response.dart';
import 'package:stok_anandam/data/models/memo.dart';
import 'package:stok_anandam/features/memo/bloc/memo_bloc.dart';
import 'package:stok_anandam/injection.dart';

class DeliveryScannerPage extends StatefulWidget {
  const DeliveryScannerPage({super.key});

  @override
  State<DeliveryScannerPage> createState() => _DeliveryScannerPageState();
}

class _DeliveryScannerPageState extends State<DeliveryScannerPage>
    with WidgetsBindingObserver {
  MobileScannerController? controller;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _pausedForNavigation = false;

  final FocusNode _focusNode = FocusNode();
  final FocusNode _manualInputFocusNode = FocusNode();
  String _scanBuffer = '';
  DateTime _lastKeyPress = DateTime.now();
  DateTime _lastScanTime = DateTime.now().subtract(const Duration(seconds: 2));
  static const Duration _debounceDuration = Duration(milliseconds: 1500);

  DeliveryScanResponse? _scanResult;
  bool _hasScanned = false;
  MemoDetail? _memoDetail;
  bool _loadingDetail = false;
  bool _detailError = false;
  late MemoBloc _memoBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _memoBloc = MemoBloc(getIt());
    controller = MobileScannerController(
      formats: const [BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.normal,
      autoStart: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Kembali dari background: mulai ulang scanner (camera dilepas OS saat pause).
      if (!_pausedForNavigation) {
        controller?.start();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Background: lepas kamera agar tidak konflik dengan mode kamera lain.
      controller?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    _focusNode.dispose();
    _memoBloc.close();
    super.dispose();
  }

  void _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      if (now.difference(_lastKeyPress).inMilliseconds > 1000) _scanBuffer = '';
      _lastKeyPress = now;
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_scanBuffer.isNotEmpty) {
          dev.log('[DeliveryScanner] Hardware Scan: $_scanBuffer', name: 'DeliveryScanner');
          _processQrCode(_scanBuffer.trim());
          _scanBuffer = '';
        }
      } else {
        final char = event.character;
        if (char != null) _scanBuffer += char;
      }
    }
  }

  void _handleCapture(BarcodeCapture capture) async {
    if (_isProcessing || _hasScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastScanTime) < _debounceDuration) return;
    _lastScanTime = now;
    await _processQrCode(code.trim());
  }

  Future<void> _processQrCode(String code) async {
    if (_isProcessing || _hasScanned) return;
    setState(() => _isProcessing = true);
    dev.log('[DeliveryScanner] Processing: $code', name: 'DeliveryScanner');
    _memoBloc.add(DeliveryScanEvent(code));
  }

  void _resetScan() {
    setState(() {
      _hasScanned = false;
      _scanResult = null;
      _memoDetail = null;
      _loadingDetail = false;
      _detailError = false;
      _isProcessing = false;
    });
    _focusNode.requestFocus();
  }

  void _loadMemoDetail(String memoId) {
    if (memoId.isEmpty) {
      setState(() => _loadingDetail = false);
      return;
    }
    setState(() {
      _loadingDetail = true;
      _detailError = false;
    });
    _memoBloc.add(LoadMemoDetail(memoId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _memoBloc,
      child: BlocListener<MemoBloc, MemoState>(
        listener: (context, state) {
          if (state is DeliveryScanSuccess) {
            setState(() {
              _scanResult = state.result;
              _hasScanned = true;
              _isProcessing = false;
              _memoDetail = null;
              _detailError = false;
            });
            // Muat detail Memo lengkap setelah scan berhasil
            _loadMemoDetail(state.result.memoId);
          } else if (state is MemoDetailLoaded) {
            setState(() {
              _memoDetail = state.detail;
              _loadingDetail = false;
              _detailError = false;
            });
          } else if (state is MemoError) {
            if (_hasScanned) {
              // Error saat memuat detail Memo — tetap tampilkan info hasil scan
              setState(() {
                _loadingDetail = false;
                _detailError = true;
              });
            } else {
              setState(() => _isProcessing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
              );
            }
          } else if (state is MemoOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
            _resetScan();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Scan QR Pengiriman', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              if (_hasScanned)
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _resetScan, tooltip: 'Scan Lagi'),
              if (!_hasScanned)
                IconButton(
                  icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                  onPressed: () {
                    controller?.toggleTorch();
                    setState(() => _isFlashOn = !_isFlashOn);
                  },
                ),
            ],
          ),
          body: _hasScanned && _scanResult != null ? _buildResultCard() : _buildScanner(),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleHardwareKey,
      child: _buildScanOverlay(),
    );
  }

  Widget _buildScanOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null)
          MobileScanner(
            controller: controller!,
            onDetect: _handleCapture,
            fit: BoxFit.cover,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Kamera tidak dapat diakses atau izin belum diberikan',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => controller?.start(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Mulai Ulang Kamera'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 3.5),
                        left: BorderSide(color: Colors.white, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 3.5),
                        right: BorderSide(color: Colors.white, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 3.5),
                        left: BorderSide(color: Colors.white, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 3.5),
                        right: BorderSide(color: Colors.white, width: 3.5),
                      ),
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isProcessing)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(), SizedBox(height: 16), Text('Memproses scan...'),
                ]),
              ),
            ),
          ),
        Positioned(
          bottom: 60,
          left: 24,
          right: 24,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Arahkan scan ke QR Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final result = _scanResult!;
    final bloc = _memoBloc;
    final memo = _memoDetail;
    final isNarrow = MediaQuery.sizeOf(context).width < 400;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 16 : 24,
          16,
          isNarrow ? 16 : 24,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSuccessHeader(result, isNarrow),
            const SizedBox(height: 16),
            _buildDeliverySection(result),
            const SizedBox(height: 16),
            _buildMemoSection(memo, isNarrow),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Pause scanner dulu agar kamera tidak konflik saat pindah layar.
                  _pausedForNavigation = true;
                  await controller?.stop();
                  if (!mounted) return;
                  await context.pushNamed(
                    AppRoutes.deliveryDetail,
                    pathParameters: {'id': result.memoId},
                  );
                  if (mounted) {
                    _resetScan();
                    // Kembali dari detail: hidupkan scanner lagi.
                    _pausedForNavigation = false;
                    await controller?.start();
                  }
                },
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Buka Detail & Mulai Kirim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Lainnya'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Lepas Tugas?'),
                      content: Text(
                          'Anda yakin ingin melepas tugas pengiriman ${result.nomorMemo}?\n\nBarang ini tidak akan lagi terikat dengan Anda.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            bloc.add(DeliveryReleaseEvent(result.penjadwalanId));
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Ya, Lepas Tugas'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: const Text('Lepas Tugas (Tidak Jadi Kirim)',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader(DeliveryScanResponse result, bool isNarrow) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isNarrow ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        const Icon(Icons.check_circle_outline, size: 48, color: Colors.white),
        const SizedBox(height: 12),
        Text('Scan Berhasil!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: isNarrow ? 20 : 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Anda ditugaskan untuk mengirim',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12)),
          child: Text(result.nomorMemo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _buildDeliverySection(DeliveryScanResponse result) {
    return _buildSectionCard(
      title: 'Detail Pengiriman',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildInfoRow(Icons.person, 'Penerima', result.namaPenerima ?? '-'),
        if (result.noHpPenerima != null && result.noHpPenerima!.isNotEmpty)
          _buildInfoRow(Icons.phone, 'No. HP', result.noHpPenerima!),
        if (result.alamatLengkap != null && result.alamatLengkap!.isNotEmpty)
          _buildInfoRow(Icons.location_on, 'Alamat', result.alamatLengkap!),
        if (result.alamatMaps != null && result.alamatMaps!.isNotEmpty)
          _buildInfoRow(Icons.map, 'Link Maps', result.alamatMaps!),
      ]),
    );
  }


  Widget _buildMemoSection(MemoDetail? memo, bool isNarrow) {
    if (_loadingDetail) {
      return _buildSectionCard(
        title: 'Detail Memo',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Memuat detail Memo...'),
          ]),
        ),
      );
    }

    if (memo == null) {
      return _buildSectionCard(
        title: 'Detail Memo',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _detailError
                    ? 'Gagal memuat detail Memo. Anda tetap bisa melanjutkan tugas.'
                    : 'Detail Memo tidak tersedia.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ),
      );
    }

    final items = memo.items;
    return _buildSectionCard(
      title: 'Detail Memo',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildInfoRow(Icons.person_outline, 'Pelanggan',
            memo.customerName?.isNotEmpty == true ? memo.customerName! : '-'),
        if (memo.customerPhone?.isNotEmpty == true)
          _buildInfoRow(Icons.phone_outlined, 'Telp Pelanggan',
              memo.customerPhone!),
        if (memo.marketingName?.isNotEmpty == true)
          _buildInfoRow(Icons.badge_outlined, 'Marketing', memo.marketingName!),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (memo.statusAkhir != null) _statusBadge(memo.statusAkhir!.label),
          if (memo.memoType?.isNotEmpty == true) _statusBadge(memo.memoType!),
        ]),
        const Divider(height: 24),
        Text('Barang (${items.length} item)',
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Tidak ada item.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          )
        else
          ...items.map((item) => _buildItemTile(item, isNarrow)),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Harga',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(_formatRupiah(memo.totalHarga),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF059669))),
          ],
        ),
      ]),
    );
  }

  Widget _buildItemTile(MemoItem item, bool isNarrow) {
    final hasShippedInfo = item.qtyShipped > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.namaBarang ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.qty}${hasShippedInfo ? '  •  Terkirim: ${item.qtyShipped}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatRupiah(item.subtotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              if (item.hargaSatuan > 0)
                Text('@${_formatRupiah(item.hargaSatuan)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF059669))),
    );
  }


  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  String _formatRupiah(num value) {
    final rounded = value.round();
    final s = rounded.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final remaining = s.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write('.');
    }
    return 'Rp ${rounded < 0 ? '-' : ''}${buf.toString()}';
  }


  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
} 
