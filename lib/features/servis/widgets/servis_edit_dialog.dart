import 'package:flutter/material.dart';
import 'package:stok_anandam/core/errors/app_errors.dart';
import 'package:stok_anandam/core/widgets/app_feedback.dart';
import '../models/pelanggan_servis.dart';
import '../models/transaksi_servis.dart';
import '../repositories/servis_repository.dart';
import '../utils/servis_mask_utils.dart';
import 'package:stok_anandam/injection.dart';

class ServisEditDialog extends StatefulWidget {
  final TransaksiServis transaksi;
  const ServisEditDialog({super.key, required this.transaksi});

  @override
  State<ServisEditDialog> createState() => _ServisEditDialogState();
}

class _ServisEditDialogState extends State<ServisEditDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ServisRepository _repository = getIt<ServisRepository>();

  bool _isLoadingPelanggan = true;
  bool _isLoading = false;

  List<PelangganServis> _pelangganList = [];
  PelangganServis? _selectedPelanggan;

  // --- FORM CONTROLLERS ---
  final _jenisBarangCtrl = TextEditingController();
  final _merekCtrl = TextEditingController();
  final _modelSeriCtrl = TextEditingController();
  final _kelengkapanCtrl = TextEditingController();
  final _kerusakanCtrl = TextEditingController();
  final _dpCtrl = TextEditingController();
  final _estimasiBiayaCtrl = TextEditingController();

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadPelanggan();
    _initForm();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  void _initForm() {
    final t = widget.transaksi;
    _jenisBarangCtrl.text = t.jenisBarang ?? '';
    _merekCtrl.text = t.merek ?? '';
    _modelSeriCtrl.text = t.modelSeri ?? '';
    _kelengkapanCtrl.text = t.kelengkapan ?? '';
    _kerusakanCtrl.text = t.kerusakan ?? '';
    _dpCtrl.text = t.dp?.toStringAsFixed(0) ?? '';
    _estimasiBiayaCtrl.text = t.estimasiBiaya?.toStringAsFixed(0) ?? '';

    // Set selected pelanggan if available
    if (t.pelanggan != null) {
      _selectedPelanggan = t.pelanggan;
    }
  }

  Future<void> _loadPelanggan() async {
    try {
      final parsedList = await _repository.getPelangganServis(size: 200);
      if (mounted) {
        setState(() {
          _pelangganList = parsedList.content;
        });
      }
    } catch (e) {
      debugPrint('Gagal load pelanggan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPelanggan = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final payload = <String, dynamic>{
        "jenisBarang": _jenisBarangCtrl.text.trim(),
        "merek": _merekCtrl.text.trim(),
        "modelSeri": _modelSeriCtrl.text.trim(),
        "kerusakan": _kerusakanCtrl.text.trim(),
        "kelengkapan": _kelengkapanCtrl.text.trim(),
        "dp": double.tryParse(_dpCtrl.text.trim()) ?? 0.0,
        "estimasiBiaya": double.tryParse(_estimasiBiayaCtrl.text.trim()) ?? 0.0,
      };

      // Only include pelangganId if changed
      if (_selectedPelanggan != null &&
          _selectedPelanggan!.id != widget.transaksi.pelangganId) {
        payload['pelangganId'] = _selectedPelanggan!.id;
      }

      await _repository.updateTransaksiServis(widget.transaksi.id!, payload);

      if (mounted) {
        AppFeedback.showSuccess(context, 'Servis berhasil diperbarui');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, AppErrors.userMessageFromException(e, fallback: 'Gagal memperbarui data servis.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _modernInputDecoration(
      ThemeData theme, String label, IconData icon,
      {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _jenisBarangCtrl.dispose();
    _merekCtrl.dispose();
    _modelSeriCtrl.dispose();
    _kelengkapanCtrl.dispose();
    _kerusakanCtrl.dispose();
    _dpCtrl.dispose();
    _estimasiBiayaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    double dialogMaxWidth;
    if (screenWidth > 900) {
      dialogMaxWidth = 600;
    } else if (screenWidth > 600) {
      dialogMaxWidth = 540;
    } else {
      dialogMaxWidth = screenWidth - 32;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: 800,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Servis',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'No. ${widget.transaksi.noServis ?? ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Tutup',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),

                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- PELANGGAN SECTION ---
                          Text('Data Pelanggan',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (_isLoadingPelanggan)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            Autocomplete<PelangganServis>(
                              displayStringForOption: (PelangganServis
                                      option) =>
                                  '${option.namaPelanggan} (${maskPhoneNumber(option.noTelepon)})',
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _pelangganList;
                                }
                                return _pelangganList
                                    .where((PelangganServis p) {
                                  final query =
                                      textEditingValue.text.toLowerCase();
                                  final nama =
                                      (p.namaPelanggan ?? "").toLowerCase();
                                  final telepon =
                                      (p.noTelepon ?? "").toLowerCase();
                                  return nama.contains(query) ||
                                      telepon.contains(query);
                                });
                              },
                              initialValue: TextEditingValue(
                                text: _selectedPelanggan != null
                                    ? '${_selectedPelanggan!.namaPelanggan} (${maskPhoneNumber(_selectedPelanggan!.noTelepon)})'
                                    : '',
                              ),
                              onSelected: (PelangganServis selection) {
                                setState(() {
                                  _selectedPelanggan = selection;
                                });
                                FocusScope.of(context).unfocus();
                              },
                              fieldViewBuilder: (context, textEditingController,
                                  focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: _modernInputDecoration(
                                    theme,
                                    'Ketik Nama atau WA Pelanggan...',
                                    Icons.search_rounded,
                                    suffixIcon: _selectedPelanggan != null
                                        ? IconButton(
                                            icon:
                                                const Icon(Icons.clear_rounded),
                                            onPressed: () {
                                              textEditingController.clear();
                                              setState(() {
                                                _selectedPelanggan = null;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (value) {
                                    if (_selectedPelanggan != null) {
                                      setState(() {
                                        _selectedPelanggan = null;
                                      });
                                    }
                                  },
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 6.0,
                                    borderRadius: BorderRadius.circular(12),
                                    clipBehavior: Clip.antiAlias,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxHeight: 250, maxWidth: 400),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          final PelangganServis option =
                                              options.elementAt(index);
                                          return ListTile(
                                            title: Text(
                                                option.namaPelanggan ??
                                                    "Tanpa Nama",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            subtitle:
                                                Text(maskPhoneNumber(option.noTelepon)),
                                            onTap: () {
                                              onSelected(option);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 24),

                          // --- DATA BARANG SECTION ---
                          Text('Data Barang',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          // Responsive layout
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 500;
                              return Column(
                                children: [
                                  if (isWide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _jenisBarangCtrl,
                                            decoration: _modernInputDecoration(
                                              theme,
                                              'Jenis (Misal: Laptop) *',
                                              Icons.devices_rounded,
                                            ),
                                            validator: (v) => v!.isEmpty
                                                ? 'Wajib diisi'
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _merekCtrl,
                                            decoration: _modernInputDecoration(
                                              theme,
                                              'Merek',
                                              Icons.branding_watermark_rounded,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!isWide) ...[
                                    TextFormField(
                                      controller: _jenisBarangCtrl,
                                      decoration: _modernInputDecoration(
                                          theme,
                                          'Jenis (Misal: Laptop) *',
                                          Icons.devices_rounded),
                                      validator: (v) =>
                                          v!.isEmpty ? 'Wajib diisi' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _merekCtrl,
                                      decoration: _modernInputDecoration(
                                          theme,
                                          'Merek',
                                          Icons.branding_watermark_rounded),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _modelSeriCtrl,
                                    decoration: _modernInputDecoration(theme,
                                        'Model / Seri *', Icons.memory_rounded),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _kerusakanCtrl,
                                    decoration: _modernInputDecoration(
                                        theme,
                                        'Keluhan / Kerusakan *',
                                        Icons.warning_amber_rounded),
                                    maxLines: 2,
                                    validator: (v) =>
                                        v!.isEmpty ? 'Wajib diisi' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _kelengkapanCtrl,
                                    decoration: _modernInputDecoration(
                                        theme,
                                        'Kelengkapan (Tas, Charger, dll)',
                                        Icons.backpack_rounded),
                                  ),
                                  const SizedBox(height: 12),
                                  if (isWide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _dpCtrl,
                                            decoration: _modernInputDecoration(
                                                theme,
                                                'DP',
                                                Icons.savings_rounded),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _estimasiBiayaCtrl,
                                            decoration: _modernInputDecoration(
                                                theme,
                                                'Estimasi Biaya',
                                                Icons.payments_rounded),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!isWide) ...[
                                    TextFormField(
                                      controller: _dpCtrl,
                                      decoration: _modernInputDecoration(
                                          theme, 'DP', Icons.savings_rounded),
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _estimasiBiayaCtrl,
                                      decoration: _modernInputDecoration(
                                          theme,
                                          'Estimasi Biaya',
                                          Icons.payments_rounded),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24)),
                    border: Border(
                        top: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                            _isLoading ? 'Menyimpan...' : 'Simpan Perubahan'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
