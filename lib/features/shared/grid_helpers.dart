import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:my_api_client/my_api_client.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';

class SalesGridHelper {
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'Tanggal',
        field: 'docDate',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'No Nota',
        field: 'docNo',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Kode',
        field: 'code',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Nama User',
        field: 'parName',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Dept',
        field: 'depCode',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Barang',
        field: 'itemName',
        type: PlutoColumnType.text(),
        width: 300,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Qty',
        field: 'qty',
        type: PlutoColumnType.number(),
        width: 80,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Harga',
        field: 'price',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Total',
        field: 'grandTotal',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Marketing',
        field: 'empCode',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
    ];
  }

  static List<PlutoRow> mapToRows(List<Sales> items) {
    return items.map((s) {
      return PlutoRow(
        cells: {
          'docDate': PlutoCell(value: _fmtDate(s.docDate)),
          'docNo': PlutoCell(value: s.docNo ?? '—'),
          'code': PlutoCell(value: s.code ?? '—'),
          'parName': PlutoCell(value: s.parName ?? '—'),
          'depCode': PlutoCell(value: s.depCode ?? '—'),
          'itemName': PlutoCell(value: s.itemName ?? '—'),
          'qty': PlutoCell(value: s.qty),
          'price': PlutoCell(value: _num(s.price)),
          'grandTotal': PlutoCell(value: _num(s.grandTotal)),
          'empCode': PlutoCell(value: s.empCode ?? '—'),
        },
      );
    }).toList();
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.tryParse(d.toString());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return d.toString();
  }

  static double _num(Object? x) {
    if (x == null) return 0;
    return double.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), '')) ??
        0;
  }
}

class PurchaseGridHelper {
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'Tanggal',
        field: 'docDate',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'No Nota',
        field: 'docNoP',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Distributor',
        field: 'parName',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Dept',
        field: 'depCode',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Barang',
        field: 'itemName',
        type: PlutoColumnType.text(),
        width: 300,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.left,
      ),
      PlutoColumn(
        title: 'Qty',
        field: 'qty',
        type: PlutoColumnType.number(),
        width: 80,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Harga',
        field: 'price',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Total',
        field: 'grandTotal',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
    ];
  }

  static List<PlutoRow> mapToRows(List<Purchase> items) {
    return items.map((p) {
      return PlutoRow(
        cells: {
          'docDate': PlutoCell(value: _fmtDate(p.docDate)),
          'docNoP': PlutoCell(value: p.docNoP ?? '—'),
          'parName': PlutoCell(value: p.parName ?? '—'),
          'depCode': PlutoCell(value: p.depCode ?? '—'),
          'itemName': PlutoCell(value: p.itemName ?? '—'),
          'qty': PlutoCell(value: p.qty),
          'price': PlutoCell(value: _num(p.price)),
          'grandTotal': PlutoCell(value: _num(p.grandTotal)),
        },
      );
    }).toList();
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.tryParse(d.toString());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return d.toString();
  }

  static double _num(Object? x) {
    if (x == null) return 0;
    return double.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), '')) ??
        0;
  }
}

/// Grid Piutang: satu baris = satu dokumen penjualan dgn status pembayaran.
class PiutangGridHelper {
  /// Kolom mengikuti halaman Penjualan + status bayar.
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(title: 'Tanggal', field: 'docDate', type: PlutoColumnType.text(), width: 120,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'No Nota', field: 'docNo', type: PlutoColumnType.text(), width: 150,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Kode', field: 'code', type: PlutoColumnType.text(), width: 110,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Nama User', field: 'parName', type: PlutoColumnType.text(), width: 180,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Dept', field: 'depCode', type: PlutoColumnType.text(), width: 90,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Barang', field: 'itemName', type: PlutoColumnType.text(), width: 280,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Qty', field: 'qty', type: PlutoColumnType.number(), width: 80,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Harga', field: 'price', type: PlutoColumnType.currency(symbol: '', decimalDigits: 0, locale: 'id_ID'), width: 140,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Total', field: 'grandTotal', type: PlutoColumnType.currency(symbol: '', decimalDigits: 0, locale: 'id_ID'), width: 150,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Terbayar', field: 'paidTotal', type: PlutoColumnType.currency(symbol: '', decimalDigits: 0, locale: 'id_ID'), width: 140,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Status', field: 'statusBayar', type: PlutoColumnType.text(), width: 110,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Marketing', field: 'empCode', type: PlutoColumnType.text(), width: 120,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
    ];
  }

  static List<PlutoRow> mapToRows(List<PiutangItem> items) {
    return items.map((s) {
      return PlutoRow(cells: {
        'docDate': PlutoCell(value: _fmtDate(s.docDate)),
        'docNo': PlutoCell(value: s.docNo ?? '—'),
        'code': PlutoCell(value: s.code ?? '—'),
        'parName': PlutoCell(value: s.parName ?? '—'),
        'depCode': PlutoCell(value: s.depCode ?? '—'),
        'itemName': PlutoCell(value: s.itemName ?? '—'),
        'qty': PlutoCell(value: s.qty),
        'price': PlutoCell(value: _num(s.price)),
        'grandTotal': PlutoCell(value: _num(s.grandTotal)),
        'paidTotal': PlutoCell(value: _num(s.paidTotal)),
        'statusBayar': PlutoCell(value: s.statusBayar ?? '—'),
        'empCode': PlutoCell(value: s.empCode ?? '—'),
      });
    }).toList();
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.tryParse(d.toString());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return d.toString();
  }

  static double _num(Object? x) {
    if (x == null) return 0;
    return double.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0;
  }
}

class HutangGridHelper {
  /// Kolom mengikuti halaman Pembelian + status bayar.
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(title: 'Tanggal', field: 'docDate', type: PlutoColumnType.text(), width: 120,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'No Nota', field: 'docNoP', type: PlutoColumnType.text(), width: 160,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Distributor', field: 'parName', type: PlutoColumnType.text(), width: 200,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Dept', field: 'depCode', type: PlutoColumnType.text(), width: 90,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Barang', field: 'itemName', type: PlutoColumnType.text(), width: 280,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Qty', field: 'qty', type: PlutoColumnType.number(), width: 80,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Harga', field: 'price', type: PlutoColumnType.currency(symbol: '', decimalDigits: 0, locale: 'id_ID'), width: 140,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Total', field: 'grandTotal', type: PlutoColumnType.currency(symbol: '', decimalDigits: 0, locale: 'id_ID'), width: 150,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Terbayar', field: 'paidTotal', type: PlutoColumnType.currency(symbol: '', decimalDigits: 0, locale: 'id_ID'), width: 140,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'Status', field: 'statusBayar', type: PlutoColumnType.text(), width: 110,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
      PlutoColumn(title: 'Marketing', field: 'empCode', type: PlutoColumnType.text(), width: 120,
          enableEditingMode: false, enableColumnDrag: false, textAlign: PlutoColumnTextAlign.left),
    ];
  }

  static List<PlutoRow> mapToRows(List<HutangItem> items) {
    return items.map((s) {
      return PlutoRow(cells: {
        'docDate': PlutoCell(value: _fmtDate(s.docDate)),
        'docNoP': PlutoCell(value: s.docNoP ?? '—'),
        'parName': PlutoCell(value: s.parName ?? '—'),
        'depCode': PlutoCell(value: s.depCode ?? '—'),
        'itemName': PlutoCell(value: s.itemName ?? '—'),
        'qty': PlutoCell(value: s.qty),
        'price': PlutoCell(value: _num(s.price)),
        'grandTotal': PlutoCell(value: _num(s.grandTotal)),
        'paidTotal': PlutoCell(value: _num(s.paidTotal)),
        'statusBayar': PlutoCell(value: s.statusBayar ?? '—'),
        'empCode': PlutoCell(value: s.empCode ?? '—'),
      });
    }).toList();
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.tryParse(d.toString());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return d.toString();
  }

  static double _num(Object? x) {
    if (x == null) return 0;
    return double.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0;
  }
}

class ItemSnGridHelper {
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'Doc ID',
        field: 'docId',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Tanggal',
        field: 'tanggal',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'User',
        field: 'user',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Item Name',
        field: 'itemName',
        type: PlutoColumnType.text(),
        width: 350,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'SN',
        field: 'sn',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
    ];
  }

  static List<PlutoRow> mapToRows(List<ItemSerialNumberResponse> items) {
    return items.map((t) {
      return PlutoRow(
        cells: {
          'docId': PlutoCell(value: t.docId ?? '—'),
          'tanggal': PlutoCell(value: _fmtDate(t.tanggal)),
          'user': PlutoCell(value: t.user ?? '—'),
          'itemName': PlutoCell(value: t.itemName ?? '—'),
          'sn': PlutoCell(value: t.sn ?? '—'),
        },
      );
    }).toList();
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class OldSalesGridHelper {
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'Tanggal',
        field: 'docDate',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'No Nota',
        field: 'docNo',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Kode',
        field: 'code',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Dept',
        field: 'dept_code',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Nama User',
        field: 'parName',
        type: PlutoColumnType.text(),
        width: 200,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Barang',
        field: 'itemName',
        type: PlutoColumnType.text(),
        width: 300,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Qty',
        field: 'qty',
        type: PlutoColumnType.number(),
        width: 80,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Harga',
        field: 'price',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Total',
        field: 'grandTotal',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Marketing',
        field: 'empCode',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
    ];
  }

  static List<PlutoRow> mapToRows(List<dynamic> items) {
    return items.map((s) {
      final m = s as Map<String, dynamic>;
      return PlutoRow(
        cells: {
          'docDate': PlutoCell(value: _fmtDate(m['docDate'])),
          'docNo': PlutoCell(value: m['docNo']?.toString() ?? '—'),
          'code': PlutoCell(value: m['code']?.toString() ?? '—'),
          'dept_code': PlutoCell(
              value: m['depCode']?.toString() ??
                  m['dep_code']?.toString() ??
                  '—'),
          'parName': PlutoCell(value: m['parName']?.toString() ?? '—'),
          'itemName': PlutoCell(value: m['itemName']?.toString() ?? '—'),
          'qty': PlutoCell(value: m['qty']),
          'price': PlutoCell(value: _num(m['price'])),
          'grandTotal': PlutoCell(value: _num(m['grandTotal'])),
          'empCode': PlutoCell(value: m['empCode']?.toString() ?? '—'),
        },
      );
    }).toList();
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.tryParse(d.toString());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return d.toString();
  }

  static double _num(Object? x) {
    if (x == null) return 0;
    return double.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), '')) ??
        0;
  }
}

class OldPurchaseGridHelper {
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'Tanggal',
        field: 'docDate',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'No Nota',
        field: 'docNoP',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Dept',
        field: 'dept_code',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Partner',
        field: 'parName',
        type: PlutoColumnType.text(),
        width: 200,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Barang',
        field: 'itemName',
        type: PlutoColumnType.text(),
        width: 300,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Qty',
        field: 'qty',
        type: PlutoColumnType.number(),
        width: 80,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Harga',
        field: 'price',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
      PlutoColumn(
        title: 'Total',
        field: 'grandTotal',
        type: PlutoColumnType.currency(
            symbol: '', decimalDigits: 0, locale: 'id_ID'),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
        textAlign: PlutoColumnTextAlign.right,
      ),
    ];
  }

  static List<PlutoRow> mapToRows(List<dynamic> items) {
    return items.map((s) {
      final m = s as Map<String, dynamic>;
      return PlutoRow(
        cells: {
          'docDate': PlutoCell(value: _fmtDate(m['docDate'])),
          'docNoP': PlutoCell(value: m['docNoP']?.toString() ?? '—'),
          'dept_code': PlutoCell(
              value: m['depCode']?.toString() ??
                  m['dep_code']?.toString() ??
                  '—'),
          'parName': PlutoCell(value: m['parName']?.toString() ?? '—'),
          'itemName': PlutoCell(value: m['itemName']?.toString() ?? '—'),
          'qty': PlutoCell(value: m['qty']),
          'price': PlutoCell(value: _num(m['price'])),
          'grandTotal': PlutoCell(value: _num(m['grandTotal'])),
        },
      );
    }).toList();
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.tryParse(d.toString());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return d.toString();
  }

  static double _num(Object? x) {
    if (x == null) return 0;
    return double.tryParse(x.toString().replaceAll(RegExp(r'[^\d.-]'), '')) ??
        0;
  }
}

class OldItemSnGridHelper {
  static List<PlutoColumn> getColumns(BuildContext context) {
    return [
      PlutoColumn(
        title: 'Tanggal',
        field: 'tanggal',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Doc ID',
        field: 'docId',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'User',
        field: 'user_name',
        type: PlutoColumnType.text(),
        width: 150,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Item',
        field: 'itemName',
        type: PlutoColumnType.text(),
        width: 350,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'SN',
        field: 'sn',
        type: PlutoColumnType.text(),
        width: 180,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
      PlutoColumn(
        title: 'Tipe',
        field: 'type',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        enableColumnDrag: false,
      ),
    ];
  }

  static List<PlutoRow> mapToRows(List<dynamic> items) {
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return PlutoRow(
        cells: {
          'tanggal': PlutoCell(value: _fmtDate(m['tanggal'])),
          'docId': PlutoCell(value: m['docId']?.toString() ?? '—'),
          'user_name': PlutoCell(value: m['userName']?.toString() ?? '—'),
          'itemName': PlutoCell(value: m['itemName']?.toString() ?? '—'),
          'sn': PlutoCell(value: m['sn']?.toString() ?? '—'),
          'type': PlutoCell(value: m['type']?.toString() ?? '—'),
        },
      );
    }).toList();
  }

  static String _fmtDate(Object? d) {
    if (d == null) return '—';
    try {
      final date = DateTime.tryParse(d.toString());
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (_) {}
    return d.toString();
  }
}
