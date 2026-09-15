import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/features/memo/utils/memo_print_utils.dart';
import 'package:stok_anandam/data/models/memo.dart';

/// Dialog untuk memilih printer HP dan mengirim dokumen PDF ke server untuk dicetak.
class PrinterDialog extends StatefulWidget {
  final MemoDetail memo;

  const PrinterDialog({super.key, required this.memo});

  /// Menampilkan dialog print secara praktis.
  static Future<void> show(BuildContext context, MemoDetail memo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrinterDialog(memo: memo),
    );
  }

  @override
  State<PrinterDialog> createState() => _PrinterDialogState();
}

class _PrinterDialogState extends State<PrinterDialog> {
  final _api = getIt<ApiNewEndpoints>();

  bool _isLoadingPrinters = true;
  bool _isPrinting = false;
  String? _errorMessage;
  String? _successMessage;

  /// Daftar printer yang di-parse dari String response server
  List<String> _availablePrinters = [];
  String? _selectedPrinter;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _isLoadingPrinters = true;
      _errorMessage = null;
    });

    try {
      final raw = await _api.getAvailablePrinters();
      debugPrint('[PrinterDialog] Raw printer list: $raw');

      // Parse response — server returns lines prefixed with "- " (e.g. "- PrinterOnline")
      final List<String> printers;
      if (raw.contains('\n')) {
        printers = raw
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((e) => e.startsWith('- ')
                ? e.substring(2).trim()
                : e) // bersihkan prefix "- "
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (raw.contains(',')) {
        printers = raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (raw.isNotEmpty) {
        printers = [raw];
      } else {
        printers = [];
      }

      setState(() {
        _availablePrinters = printers;
        _isLoadingPrinters = false;
        if (printers.isNotEmpty) {
          _selectedPrinter = printers.first;
        }
      });
    } catch (e) {
      debugPrint('[PrinterDialog] Error loading printers: $e');
      setState(() {
        _isLoadingPrinters = false;
        _errorMessage =
            'Gagal memuat daftar printer: ${_extractErrorMessage(e)}';
      });
    }
  }

  Future<void> _printDocument() async {
    if (_isPrinting) return;

    setState(() {
      _isPrinting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Generate PDF bytes from memo using existing utility
      final pdfBytes = await MemoPrintUtils.generateMemoPrintBytes(widget.memo);
      debugPrint('[PrinterDialog] PDF generated: ${pdfBytes.length} bytes');

      // Send to server via /api/v1/printer/print
      await _api.printDocument(
        pdfBytes: pdfBytes,
        printerName: _selectedPrinter,
      );

      setState(() {
        _isPrinting = false;
        _successMessage =
            'Dokumen berhasil dikirim ke printer${_selectedPrinter != null ? ' "$_selectedPrinter"' : ''}.';
      });

      // Auto close after success
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('[PrinterDialog] Error printing: $e');
      setState(() {
        _isPrinting = false;
        _errorMessage = 'Gagal mencetak: ${_extractErrorMessage(e)}';
      });
    }
  }

  String _extractErrorMessage(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return error.message ?? 'Terjadi kesalahan koneksi';
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.print_rounded,
                color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Print Dokumen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ],
      ),
      content: _buildContent(theme),
      actions: [
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          child: Text(
            _successMessage != null ? 'Tutup' : 'Batal',
            style: TextStyle(
              color: _successMessage != null
                  ? Colors.grey
                  : theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_successMessage == null)
          ElevatedButton.icon(
            onPressed:
                (_isLoadingPrinters || _isPrinting) ? null : _printDocument,
            icon: _isPrinting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.print_rounded, size: 18),
            label: Text(_isPrinting ? 'Mencetak...' : 'Cetak'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    // Success state
    if (_successMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            _successMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info memo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.memo.nomorMemo ?? 'Memo #${widget.memo.id ?? '-'}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                (widget.memo.customerName ?? 'Umum').toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Printer selection
        const Text(
          'Pilih Printer',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),

        if (_isLoadingPrinters)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat daftar printer...',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          )
        else if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style:
                            TextStyle(color: Colors.red.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _loadPrinters,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          )
        else if (_availablePrinters.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tidak ada printer terdeteksi. Pastikan printer HP terhubung ke server.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedPrinter,
            isExpanded: true,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Icon(Icons.print_outlined),
            ),
            items: _availablePrinters.map((printer) {
              return DropdownMenuItem(
                value: printer,
                child: Text(printer,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedPrinter = value);
            },
          ),

        const SizedBox(height: 8),

        if (_availablePrinters.isNotEmpty)
          Text(
            '${_availablePrinters.length} printer tersedia',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
      ],
    );
  }
}
