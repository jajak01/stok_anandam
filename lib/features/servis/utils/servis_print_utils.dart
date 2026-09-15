import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:stok_anandam/features/servis/models/transaksi_servis.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/features/servis/repositories/servis_repository.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';

class ServisPrintUtils {
  /// Cetak Nota Servis (Tanda Terima / Nota Lunas) - existing
  static Future<void> printNotaServis(TransaksiServis servis) async {
    final isLunas = servis.statusTerkini == 'SUDAH_DIAMBIL';

    final pdf = pw.Document();
    final fontNormal = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    final DateFormat dateFormatter = DateFormat('dd MMM yyyy');

    // Format: A5 Landscape
    final formatA5Landscape = PdfPageFormat.a5.landscape;

    String formatRp(num? value) {
      if (value == null) return "Rp 0";
      return "Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}";
    }

    pw.MemoryImage? pngLogo;
    try {
      final ByteData data =
          await rootBundle.load('assets/images/Movva by Anandam.png');
      pngLogo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      pngLogo = null;
    }

    const PdfColor primaryColor = PdfColors.teal900;

    String tglTerimaFormatted = '-';
    if (servis.tglTerima != null) {
      try {
        tglTerimaFormatted =
            dateFormatter.format(DateTime.parse(servis.tglTerima!));
      } catch (_) {}
    }

    // Helper: Highlighted field
    pw.Widget buildHighlightedRow(
        String label, String? value, pw.Font fontNormal, pw.Font fontBold) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFFF3E0),
          border: pw.Border.all(
              color: const PdfColor.fromInt(0xFFFF9800), width: 0.4),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 55,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 7,
                      color: const PdfColor.fromInt(0xFFE65100))),
            ),
            pw.Text(': ',
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 7,
                    color: const PdfColor.fromInt(0xFFE65100))),
            pw.Expanded(
              child: pw.Text(
                  value != null && value.isNotEmpty ? value.toUpperCase() : '-',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 7,
                      color: const PdfColor.fromInt(0xFFBF360C))),
            ),
          ],
        ),
      );
    }

    // Helper: Row data (label : value)
    pw.Widget dataRow(
        String label, String? value, pw.Font fontNormal, pw.Font fontBold) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: fontNormal, fontSize: 7, color: PdfColors.grey800)),
          ),
          pw.Text(': ',
              style: pw.TextStyle(
                  font: fontNormal, fontSize: 7, color: PdfColors.grey800)),
          pw.Expanded(
            child: pw.Text(
                value != null && value.isNotEmpty ? value.toUpperCase() : '-',
                style: pw.TextStyle(font: fontBold, fontSize: 7)),
          ),
        ],
      );
    }

    // Helper: Biaya row (label kiri, angka kanan)
    pw.Widget biayaRow(String label, String value, pw.Font fontNormal,
        pw.Font fontBold, bool isTotal) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        decoration: isTotal
            ? const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey400, width: 0.4),
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.4),
                ),
              )
            : null,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: isTotal ? fontBold : fontNormal,
                    fontSize: isTotal ? 7.5 : 7,
                    color: isTotal ? primaryColor : PdfColors.grey900)),
            pw.Text(value,
                style: pw.TextStyle(
                    font: isTotal ? fontBold : fontNormal,
                    fontSize: isTotal ? 7.5 : 7,
                    color: isTotal ? PdfColors.red900 : PdfColors.grey900)),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: formatA5Landscape,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: 0.5 * PdfPageFormat.cm,
          vertical: 0.3 * PdfPageFormat.cm,
        ),
        build: (pw.Context context) {
          final total = servis.biayaFinal ?? servis.estimasiBiaya ?? 0;
          final dp = servis.dp ?? 0;
          // Jika statusBayar LUNAS atau sudah SUDAH_DIAMBIL, sisa = 0
          final isStatusLunas = servis.statusBayar?.toUpperCase() == 'LUNAS' ||
              servis.statusTerkini == 'SUDAH_DIAMBIL';
          final sisa = isStatusLunas ? 0.0 : (total - dp);

          return [
            // ── HEADER ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (pngLogo != null)
                  pw.Container(
                    width: 28,
                    margin: const pw.EdgeInsets.only(right: 6),
                    child: pw.Image(pngLogo),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ANANDAM INDONESIA',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 11,
                              color: primaryColor,
                              letterSpacing: 1)),
                      pw.SizedBox(height: 1),
                      pw.Text('Toko Komputer, Laptop & Service Terpercaya',
                          style: pw.TextStyle(
                              font: fontNormal,
                              fontSize: 7,
                              color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Text(isLunas ? 'NOTA LUNAS' : 'TANDA TERIMA SERVIS',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 11,
                        color: primaryColor,
                        letterSpacing: 0.6)),
              ],
            ),
            pw.SizedBox(height: 1.5),
            pw.Divider(thickness: 0.8, color: primaryColor),
            pw.SizedBox(height: 2.5),

            // ── INFO PELANGGAN ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          'Jl. Affandi No. 17, Soropadan, Condongcatur, Depok, Sleman',
                          style: pw.TextStyle(
                              font: fontNormal,
                              fontSize: 7,
                              color: PdfColors.grey800)),
                      pw.Text('Telp. 0274-523539 | WA 085950544597',
                          style: pw.TextStyle(
                              font: fontNormal,
                              fontSize: 7,
                              color: PdfColors.grey800)),
                      pw.Text('Buka 08.00-21.00',
                          style: pw.TextStyle(
                              font: fontNormal,
                              fontSize: 7,
                              color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: primaryColor, width: 0.3),
                      color: PdfColors.grey50,
                    ),
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _infoRow('No. Servis', servis.noServis ?? '-',
                            fontNormal, fontBold),
                        pw.SizedBox(height: 0.5),
                        _infoRow('Tanggal', tglTerimaFormatted, fontNormal,
                            fontBold),
                        pw.SizedBox(height: 0.5),
                        _infoRow('Nama', servis.namaPelanggan ?? '-',
                            fontNormal, fontBold),
                        pw.SizedBox(height: 0.5),
                        _infoRow('Telepon', servis.noTelepon ?? '-', fontNormal,
                            fontBold),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),

            // ── SATU KOTAK BESAR: KIRI DATA BARANG | KANAN RINCIAN BIAYA ──
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: const pw.BoxDecoration(color: primaryColor),
              child: pw.Text(
                  isLunas ? 'DATA BARANG & NOTA LUNAS' : 'DATA BARANG SERVIS',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8,
                      color: PdfColors.white,
                      letterSpacing: 0.6)),
            ),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: primaryColor, width: 0.4),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ── KOLOM KIRI: Data Barang ──
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          dataRow('Nama Barang', servis.jenisBarang, fontNormal,
                              fontBold),
                          pw.SizedBox(height: 1),
                          dataRow('Merek', servis.merek, fontNormal, fontBold),
                          pw.SizedBox(height: 1),
                          dataRow(
                              'SN Lama',
                              servis.modelSeriLama?.isNotEmpty == true
                                  ? servis.modelSeriLama
                                  : servis.modelSeri,
                              fontNormal,
                              fontBold),
                          pw.SizedBox(height: 1),
                          dataRow(
                              'SN Baru',
                              servis.modelSeriBaru?.isNotEmpty == true
                                  ? servis.modelSeriBaru
                                  : '-',
                              fontNormal,
                              fontBold),
                          pw.SizedBox(height: 1),
                          dataRow('Kelengkapan', servis.kelengkapan, fontNormal,
                              fontBold),
                          pw.SizedBox(height: 2),
                          buildHighlightedRow('Kerusakan', servis.kerusakan,
                              fontNormal, fontBold),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 0.4,
                      color: PdfColors.grey300,
                    ),
                    pw.SizedBox(width: 10),

                    // ── KOLOM KANAN: Rincian Biaya (jika invoice) / Info (jika not) ──
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Keterangan Lain di kanan
                          dataRow('Keterangan Lain', servis.ketTindakan ?? '-',
                              fontNormal, fontBold),
                          pw.SizedBox(height: 2),
                          ...isLunas
                              ? [
                                  biayaRow('DP / Uang Muka', formatRp(dp),
                                      fontNormal, fontBold, false),
                                  pw.SizedBox(height: 0.5),
                                  biayaRow(
                                      'Estimasi Biaya',
                                      formatRp(servis.estimasiBiaya),
                                      fontNormal,
                                      fontBold,
                                      false),
                                  pw.SizedBox(height: 0.5),
                                  biayaRow(
                                      'Biaya Final / Total',
                                      formatRp(total == 0
                                          ? servis.estimasiBiaya
                                          : total),
                                      fontNormal,
                                      fontBold,
                                      false),
                                  pw.SizedBox(height: 1),
                                  biayaRow(
                                      isStatusLunas
                                          ? 'LUNAS / TERBAYAR'
                                          : 'SISA / KEKURANGAN',
                                      isStatusLunas ? 'LUNAS' : formatRp(sisa),
                                      fontNormal,
                                      fontBold,
                                      true),
                                  pw.SizedBox(height: 1),
                                  biayaRow(
                                      'Status Bayar',
                                      isStatusLunas
                                          ? 'LUNAS'
                                          : (servis.statusBayar
                                                  ?.replaceAll('_', ' ') ??
                                              '-'),
                                      fontNormal,
                                      fontBold,
                                      false),
                                ]
                              : [
                                  dataRow('DP / Uang Muka', formatRp(servis.dp),
                                      fontNormal, fontBold),
                                  pw.SizedBox(height: 1),
                                  dataRow(
                                      'Estimasi Biaya',
                                      servis.estimasiBiaya != null
                                          ? formatRp(servis.estimasiBiaya)
                                          : '.........................',
                                      fontNormal,
                                      fontBold),
                                ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 3),

            // ── QR CODES & SIGNATURES ──
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.3),
              ),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // QR1 - Scan Update & Ambil
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: servis.id ?? '-',
                        width: 50,
                        height: 50,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Scan Update & Ambil',
                          style: pw.TextStyle(
                              font: fontNormal,
                              fontSize: 6,
                              color: PdfColors.grey700)),
                    ],
                  ),
                  // QR2 - Scan Cek Status (Tracking)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data:
                            'https://anandam.id/track/servis/${servis.trackingToken ?? servis.id}',
                        width: 50,
                        height: 50,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Scan Cek Status (Tracking)',
                          style: pw.TextStyle(
                              font: fontNormal,
                              fontSize: 6,
                              color: PdfColors.grey700)),
                    ],
                  ),
                  // Penerima (Tanda Tangan)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Penerima',
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 8, color: PdfColors.grey800)),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                                color: PdfColors.grey600, width: 0.5),
                          ),
                        ),
                        child: pw.Text(
                            servis.namaPenerima?.toUpperCase() ??
                                '........................',
                            style: pw.TextStyle(font: fontBold, fontSize: 7)),
                      ),
                    ],
                  ),
                  // Pemilik (Tanda Tangan)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Pemilik',
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 8, color: PdfColors.grey800)),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                                color: PdfColors.grey600, width: 0.5),
                          ),
                        ),
                        child: pw.Text(
                            servis.namaPelanggan?.toUpperCase() ??
                                '........................',
                            style: pw.TextStyle(font: fontBold, fontSize: 7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Divider(thickness: 0.4, color: PdfColors.grey400),
            pw.SizedBox(height: 1),

            // ── FOOTER ──
            if (isLunas) ...[
              pw.Text(
                  '* Terima kasih telah menggunakan jasa servis Anandam.ID.',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7)),
              pw.Text(
                  '* Barang yang sudah diambil tidak dapat dikembalikan. Garansi servis berlaku sesuai ketentuan.',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7)),
              pw.Text(
                  '* Dicetak ${servis.namaPenerima?.toUpperCase() ?? 'ADMIN'} [${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} WIB]',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7)),
            ] else ...[
              pw.Text(
                  '* Tanda Terima Servis ini silahkan dibawa saat pengambilan Barang Servis',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7)),
              pw.Text(
                  '* Dicetak ${servis.namaPenerima?.toUpperCase() ?? 'ADMIN'} [${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} WIB]',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7)),
            ],
            pw.SizedBox(height: 2.5),

            // ── SYARAT & KETENTUAN ──
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF5F5F5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('SYARAT & KETENTUAN',
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8,
                          color: primaryColor,
                          letterSpacing: 0.4)),
                  pw.SizedBox(height: 1),
                  pw.Text(
                      '1. Unit masuk servis apabila melalui pembongkaran dipastikan unit tidak bisa kembali 100% seperti sebelumnya dan mungkin resiko mati total tidak ditanggung Anandam.ID',
                      style: pw.TextStyle(
                          font: fontItalic, fontSize: 7, lineSpacing: 1)),
                  pw.Text(
                      '2. Unit masuk Klaim Garansi Pembelian artinya disetujui kehilangan data pada unit.',
                      style: pw.TextStyle(
                          font: fontItalic, fontSize: 7, lineSpacing: 1)),
                  pw.Text(
                      '3. Periksa kondisi & kelengkapan unit saat pengambilan! Keluhan setelah meninggalkan Anandam.ID tidak dapat dilayani.',
                      style: pw.TextStyle(
                          font: fontItalic, fontSize: 7, lineSpacing: 1)),
                  pw.Text(
                      '4. Jika barang tidak diambil >1 bulan setelah konfirmasi pengambilan, bukan tanggung jawab kami.',
                      style: pw.TextStyle(
                          font: fontItalic, fontSize: 7, lineSpacing: 1)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final String docType = isLunas ? 'Nota_Lunas' : 'Tanda_Terima_Servis';
    final String fileName =
        '${docType}_${servis.noServis ?? servis.id ?? 'Doc'}.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName,
      format: formatA5Landscape,
    );
  }

  /// Cetak Nota Pengantar Klaim - generate PDF lokal dengan layout seperti print servis biasa.
  /// Tanpa rincian pembayaran, dengan info distributor + user, highlight detail kerusakan.
  static Future<void> printNotaPengantarKlaim(String transaksiId) async {
    try {
      final repo = getIt<ServisRepository>();
      final transaksi = await repo.getTransaksiById(transaksiId);
      final klaim = await repo.getKlaimByTransaksiId(transaksiId);
      final userStore = getIt<CurrentUserStore>();

      final pdf = pw.Document();
      final fontNormal = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      final fontItalic = await PdfGoogleFonts.robotoItalic();

      final DateFormat dateFormatter = DateFormat('dd MMM yyyy');
      final formatA5Landscape = PdfPageFormat.a5.landscape;

      pw.MemoryImage? pngLogo;
      try {
        final ByteData data =
            await rootBundle.load('assets/images/Movva by Anandam.png');
        pngLogo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (e) {
        pngLogo = null;
      }

      const PdfColor primaryColor = PdfColors.teal900;

      String tglTerimaFormatted = '-';
      if (transaksi.tglTerima != null) {
        try {
          tglTerimaFormatted =
              dateFormatter.format(DateTime.parse(transaksi.tglTerima!));
        } catch (_) {}
      }

      // Helper: Highlighted field (oranye)
      pw.Widget buildHighlightedRow(
          String label, String? value, pw.Font fontNormal, pw.Font fontBold) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFF3E0),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFFF9800), width: 0.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 60,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 7.5,
                        color: const PdfColor.fromInt(0xFFE65100))),
              ),
              pw.Text(': ',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 7.5,
                      color: const PdfColor.fromInt(0xFFE65100))),
              pw.Expanded(
                child: pw.Text(
                    value != null && value.isNotEmpty
                        ? value.toUpperCase()
                        : '-',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 7.5,
                        color: const PdfColor.fromInt(0xFFBF360C))),
              ),
            ],
          ),
        );
      }

      // Helper: Row data (label : value)
      pw.Widget dataRow(
          String label, String? value, pw.Font fontNormal, pw.Font fontBold) {
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 60,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      font: fontNormal, fontSize: 7, color: PdfColors.grey800)),
            ),
            pw.Text(': ',
                style: pw.TextStyle(
                    font: fontNormal, fontSize: 7, color: PdfColors.grey800)),
            pw.Expanded(
              child: pw.Text(
                  value != null && value.isNotEmpty ? value.toUpperCase() : '-',
                  style: pw.TextStyle(font: fontBold, fontSize: 7)),
            ),
          ],
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: formatA5Landscape,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 0.5 * PdfPageFormat.cm,
            vertical: 0.3 * PdfPageFormat.cm,
          ),
          build: (pw.Context context) {
            return [
              // ── HEADER ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (pngLogo != null)
                    pw.Container(
                      width: 28,
                      margin: const pw.EdgeInsets.only(right: 6),
                      child: pw.Image(pngLogo),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ANANDAM INDONESIA',
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                color: primaryColor,
                                letterSpacing: 1)),
                        pw.SizedBox(height: 1),
                        pw.Text('Toko Komputer, Laptop & Service Terpercaya',
                            style: pw.TextStyle(
                                font: fontNormal,
                                fontSize: 7,
                                color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Text('NOTA PENGANTAR KLAIM',
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 11,
                          color: const PdfColor.fromInt(0xFFBF360C),
                          letterSpacing: 0.6)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Divider(thickness: 0.8, color: primaryColor),
              pw.SizedBox(height: 2.5),

              // ── INFO TOKO & NOMOR SERVIS ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            'Jl. Affandi No. 17, Soropadan, Condongcatur, Depok, Sleman',
                            style: pw.TextStyle(
                                font: fontNormal,
                                fontSize: 7,
                                color: PdfColors.grey800)),
                        pw.Text('Telp. 0274-523539 | WA 085950544597',
                            style: pw.TextStyle(
                                font: fontNormal,
                                fontSize: 7,
                                color: PdfColors.grey800)),
                        pw.Text('Buka 08.00-21.00',
                            style: pw.TextStyle(
                                font: fontNormal,
                                fontSize: 7,
                                color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: primaryColor, width: 0.3),
                        color: PdfColors.grey50,
                      ),
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('No. Servis', transaksi.noServis ?? '-',
                              fontNormal, fontBold),
                          pw.SizedBox(height: 0.5),
                          _infoRow('Tanggal', tglTerimaFormatted, fontNormal,
                              fontBold),
                          pw.SizedBox(height: 0.5),
                          _infoRow('Nama', transaksi.namaPelanggan ?? '-',
                              fontNormal, fontBold),
                          pw.SizedBox(height: 0.5),
                          _infoRow('Telepon', transaksi.noTelepon ?? '-',
                              fontNormal, fontBold),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),

              // ── HEADER DATA BARANG ──
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const pw.BoxDecoration(color: primaryColor),
                child: pw.Text('DATA BARANG KLAIM GARANSI',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: PdfColors.white,
                        letterSpacing: 0.6)),
              ),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 0.4),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      dataRow('Nama Barang', transaksi.jenisBarang, fontNormal,
                          fontBold),
                      pw.SizedBox(height: 1),
                      dataRow('Merek', transaksi.merek, fontNormal, fontBold),
                      pw.SizedBox(height: 1),
                      dataRow(
                          'SN / Model',
                          transaksi.modelSeriLama?.isNotEmpty == true
                              ? transaksi.modelSeriLama
                              : transaksi.modelSeri,
                          fontNormal,
                          fontBold),
                      pw.SizedBox(height: 1),
                      dataRow('Kelengkapan', transaksi.kelengkapan, fontNormal,
                          fontBold),
                      pw.SizedBox(height: 2),
                      // ── HIGHLIGHT KERUSAKAN ──
                      buildHighlightedRow('Kerusakan', transaksi.kerusakan,
                          fontNormal, fontBold),
                      pw.SizedBox(height: 2),
                      dataRow('Keterangan', transaksi.ketTindakan ?? '-',
                          fontNormal, fontBold),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 3),

              // ── HEADER INFO DISTRIBUTOR ──
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFBF360C),
                ),
                child: pw.Text('INFORMASI DISTRIBUTOR',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: PdfColors.white,
                        letterSpacing: 0.6)),
              ),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: const PdfColor.fromInt(0xFFBF360C), width: 0.4),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      dataRow('Nama Distributor', klaim?.namaDistributor ?? '-',
                          fontNormal, fontBold),
                      pw.SizedBox(height: 1),
                      dataRow(
                          'Alamat Distributor',
                          klaim?.alamatDistributor ?? '-',
                          fontNormal,
                          fontBold),
                      pw.SizedBox(height: 1),
                      dataRow('Resi Pengiriman', klaim?.resiPengiriman ?? '-',
                          fontNormal, fontBold),
                      pw.SizedBox(height: 1),
                      dataRow(
                          'Tgl Kirim',
                          klaim?.tanggalKirim != null
                              ? dateFormatter
                                  .format(DateTime.parse(klaim!.tanggalKirim!))
                              : '-',
                          fontNormal,
                          fontBold),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 3),

              // ── TANDA TANGAN ──
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.3),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Pengirim (Toko)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Pengirim',
                            style: pw.TextStyle(
                                font: fontBold, fontSize: 8, color: PdfColors.grey800)),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(
                                  color: PdfColors.grey600, width: 0.5),
                            ),
                          ),
                          child: pw.Text(
                              transaksi.namaPenerima?.toUpperCase() ??
                                  '........................',
                              style: pw.TextStyle(font: fontBold, fontSize: 7)),
                        ),
                      ],
                    ),
                    // Penerima Distributor
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Penerima (Distributor)',
                            style: pw.TextStyle(
                                font: fontBold, fontSize: 8, color: PdfColors.grey800)),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(
                                  color: PdfColors.grey600, width: 0.5),
                            ),
                          ),
                          child: pw.Text('........................',
                              style: pw.TextStyle(font: fontBold, fontSize: 7)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.4, color: PdfColors.grey400),
              pw.SizedBox(height: 1),

              // ── FOOTER ──
              pw.Text(
                  '* Nota ini sebagai bukti pengiriman barang klaim garansi ke distributor.',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7)),
              pw.Text(
                  '* Dicetak oleh: ${userStore.displayName.toUpperCase()} [${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} WIB]',
                  style: pw.TextStyle(font: fontItalic, fontSize: 7)),
              pw.SizedBox(height: 2.5),

              // ── SYARAT & KETENTUAN KLAIM ──
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5F5F5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('SYARAT & KETENTUAN KLAIM',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 8,
                            color: primaryColor,
                            letterSpacing: 0.4)),
                    pw.SizedBox(height: 1),
                    pw.Text(
                        '1. Unit masuk Klaim Garansi Pembelian artinya disetujui kehilangan data pada unit.',
                        style: pw.TextStyle(
                            font: fontItalic, fontSize: 7, lineSpacing: 1)),
                    pw.Text(
                        '2. Klaim diproses sesuai kebijakan distributor/principal.',
                        style: pw.TextStyle(
                            font: fontItalic, fontSize: 7, lineSpacing: 1)),
                    pw.Text(
                        '3. Estimasi waktu proses klaim tergantung distributor.',
                        style: pw.TextStyle(
                            font: fontItalic, fontSize: 7, lineSpacing: 1)),
                    pw.Text(
                        '4. Barang yang sudah diklaim tidak dapat ditarik kembali sebelum proses selesai.',
                        style: pw.TextStyle(
                            font: fontItalic, fontSize: 7, lineSpacing: 1)),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final String fileName =
          'Nota_Pengantar_Klaim_${transaksi.noServis ?? transaksi.id ?? 'Doc'}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: fileName,
        format: formatA5Landscape,
      );
    } catch (e) {
      debugPrint('[ServisPrintUtils] Error printNotaPengantarKlaim: $e');
      rethrow;
    }
  }

  // ── HELPERS ──
  static pw.Widget _infoRow(
      String label, String? value, pw.Font fontNormal, pw.Font fontBold) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 40,
          child: pw.Text(label,
              style: pw.TextStyle(
                  font: fontNormal, fontSize: 7, color: PdfColors.grey800)),
        ),
        pw.Text(': ',
            style: pw.TextStyle(
                font: fontNormal, fontSize: 7, color: PdfColors.grey800)),
        pw.Expanded(
          child: pw.Text(value ?? '-',
              style: pw.TextStyle(font: fontBold, fontSize: 7)),
        ),
      ],
    );
  }
}
