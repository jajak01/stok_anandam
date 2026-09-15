import 'package:flutter/material.dart';
import 'package:stok_anandam/core/theme/app_spacing.dart';

/// [ProductListItemTile] — Widget list item produk dengan tata letak horizontal 3 bagian:
/// 1. Bagian Kiri (Expanded flex: 4): Nama Produk/Master & Spesifikasi.
/// 2. Bagian Tengah (Expanded flex: 3): Label Status Stok Badan Usaha & Tag PPN/Non-PPN.
/// 3. Bagian Kanan (Expanded flex: 3): Kuantitas Stok, Pricelist (strikethrough/muted), & Harga Bottom (aksen tebal).
class ProductListItemTile extends StatelessWidget {
  const ProductListItemTile({
    super.key,
    required this.productName,
    this.spesifikasi,
    this.stokBadanStatus,
    this.stokBadanWidget,
    this.isPpn,
    this.ppnTagWidget,
    this.stockQuantity,
    this.pricelist,
    this.hargaBottom,
    this.bookingBanner,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// Nama produk / master barang (Kiri - teks tebal)
  final String productName;

  /// Spesifikasi barang (Kiri - font lebih kecil, warna muted, ellipsis)
  final String? spesifikasi;

  /// Status/label stok badan usaha (Tengah - misal text status tunggal)
  final String? stokBadanStatus;

  /// Widget kustom untuk stok badan usaha (Tengah - misal badge multi-badan ANC, PDB, dll.)
  final Widget? stokBadanWidget;

  /// Penanda PPN: true untuk PPN, false untuk NON PPN, null jika tidak ditampilkan
  final bool? isPpn;

  /// Widget kustom untuk tag PPN/Non-PPN (Tengah)
  final Widget? ppnTagWidget;

  /// Jumlah stok barang (Kanan)
  final String? stockQuantity;

  /// Harga pricelist acuan (Kanan - dicoret / muted)
  final String? pricelist;

  /// Harga bottom / terendah (Kanan - warna aksen utama, tebal)
  final String? hargaBottom;

  /// Banner tambahan jika ada (misal total booking)
  final Widget? bookingBanner;

  /// Aksi saat tile ditekan
  final VoidCallback? onTap;

  /// Padding dalam tile
  final EdgeInsetsGeometry padding;

  /// Penjajaran vertikal baris utama (default: start)
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: crossAxisAlignment,
                children: [
                  // ==========================================
                  // 1. LEFT SECTION (Expanded flex: 4)
                  // ==========================================
                  Expanded(
                    flex: 4,
                    child: _buildLeftSection(context, theme),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // ==========================================
                  // 2. MIDDLE SECTION (Expanded flex: 3)
                  // ==========================================
                  Expanded(
                    flex: 3,
                    child: _buildMiddleSection(context, theme),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // ==========================================
                  // 3. RIGHT SECTION (Expanded flex: 3)
                  // ==========================================
                  Expanded(
                    flex: 3,
                    child: _buildRightSection(context, theme),
                  ),
                ],
              ),

              // Banner / konten ekstra opsional (misal: Total Booking)
              if (bookingBanner != null) ...[
                const SizedBox(height: AppSpacing.sm),
                bookingBanner!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Bagian Kiri: Nama Produk & Spesifikasi
  Widget _buildLeftSection(BuildContext context, ThemeData theme) {
    final hasSpec = spesifikasi != null &&
        spesifikasi!.trim().isNotEmpty &&
        spesifikasi != '—' &&
        spesifikasi != '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          productName,
          style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                height: 1.25,
              ) ??
              const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.25,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasSpec) ...[
          const SizedBox(height: 3),
          Text(
            spesifikasi!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.2,
                ) ??
                TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.2,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 2. Bagian Tengah: Label Stok Badan Usaha & Tag PPN / Non-PPN
  Widget _buildMiddleSection(BuildContext context, ThemeData theme) {
    final hasBadan = stokBadanWidget != null ||
        (stokBadanStatus != null && stokBadanStatus!.trim().isNotEmpty);
    final hasPpn = ppnTagWidget != null || isPpn != null;

    if (!hasBadan && !hasPpn) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stok Badan Usaha
        if (stokBadanWidget != null)
          stokBadanWidget!
        else if (stokBadanStatus != null &&
            stokBadanStatus!.trim().isNotEmpty)
          _buildDefaultBadanChip(stokBadanStatus!.trim()),

        if (hasBadan && hasPpn) const SizedBox(height: 4),

        // Tag PPN / Non-PPN
        if (ppnTagWidget != null)
          ppnTagWidget!
        else if (isPpn != null)
          _buildDefaultPpnChip(isPpn!),
      ],
    );
  }

  /// 3. Bagian Kanan: Stok, Pricelist (strikethrough/muted), Harga Bottom (aksen tebal)
  Widget _buildRightSection(BuildContext context, ThemeData theme) {
    final hasStock = stockQuantity != null &&
        stockQuantity!.trim().isNotEmpty &&
        stockQuantity != '—';
    final hasPricelist = pricelist != null &&
        pricelist!.trim().isNotEmpty &&
        pricelist != '—';
    final hasBottomPrice = hargaBottom != null &&
        hargaBottom!.trim().isNotEmpty &&
        hargaBottom != '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kuantitas Stok
        if (hasStock)
          Text(
            stockQuantity!.startsWith('Stok')
                ? stockQuantity!
                : 'Stok: $stockQuantity',
            style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ) ??
                const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),

        // Pricelist (dicoret / muted)
        if (hasPricelist) ...[
          const SizedBox(height: 2),
          Text(
            pricelist!,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              decoration: TextDecoration.lineThrough,
              decorationColor:
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ],

        // Harga Bottom (aksen tebal)
        if (hasBottomPrice) ...[
          const SizedBox(height: 2),
          Text(
            hargaBottom!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ],
      ],
    );
  }

  /// Chip bawaan untuk status badan usaha bila hanya teks yang diberikan
  Widget _buildDefaultBadanChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // blue 50
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFBFDBFE), // blue 200
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1D4ED8), // blue 700
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Chip bawaan untuk PPN / Non-PPN dengan container bersudut rounded
  Widget _buildDefaultPpnChip(bool ppn) {
    final Color bgColor = ppn ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final Color textColor = ppn ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    final Color borderColor = ppn ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        ppn ? 'PPN' : 'NON PPN',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
