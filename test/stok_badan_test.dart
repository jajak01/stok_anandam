import 'package:flutter_test/flutter_test.dart';
import 'package:stok_anandam/features/stock/stok_badan_models.dart';

void main() {
  group('StokBadan Detection & Models Test', () {
    test('StokBadanItem and StokBadanGroup model serialization', () {
      final itemJson = {
        'badan': 'SGI',
        'depCode': 'SGI-01',
        'depName': 'Divisi SGI',
        'itemCode': 'ITM-001',
        'itemName': 'Laptop Thinkpad',
        'stokQty': '15',
        'lineCount': '2',
      };

      final item = StokBadanItem.fromJson(itemJson);
      expect(item.badan, 'SGI');
      expect(item.depCode, 'SGI-01');
      expect(item.itemName, 'Laptop Thinkpad');
      expect(item.stokQty, 15);
      expect(item.lineCount, 2);

      final groupJson = {
        'badan': 'SGI',
        'totalItems': '1',
        'totalQty': '15',
        'items': [itemJson],
      };

      final group = StokBadanGroup.fromJson(groupJson);
      expect(group.badan, 'SGI');
      expect(group.totalItems, 1);
      expect(group.totalQty, 15);
      expect(group.items.length, 1);
      expect(group.items.first.itemCode, 'ITM-001');
    });

    test('StokBadanGroup from /api/stok snake_case response', () {
      final apiResponse = {
        'success': true,
        'data': [
          {
            'badan': 'ANC',
            'totalItems': 123,
            'totalQty': 4567,
            'items': [
              {
                'badan': 'ANC',
                'dep_code': 'D01',
                'dep_name': 'Departemen 1',
                'item_code': 'BRG001',
                'item_name': 'Nama Barang',
                'stok_qty': 100,
                'line_count': 5
              }
            ]
          }
        ]
      };

      final dataList = apiResponse['data'] as List;
      final groups = dataList
          .map((e) => StokBadanGroup.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(groups.length, 1);
      final ancGroup = groups.first;
      expect(ancGroup.badan, 'ANC');
      expect(ancGroup.totalItems, 123);
      expect(ancGroup.totalQty, 4567);
      expect(ancGroup.items.length, 1);
      expect(ancGroup.items.first.depCode, 'D01');
      expect(ancGroup.items.first.depName, 'Departemen 1');
      expect(ancGroup.items.first.itemCode, 'BRG001');
      expect(ancGroup.items.first.itemName, 'Nama Barang');
      expect(ancGroup.items.first.stokQty, 100);
      expect(ancGroup.items.first.lineCount, 5);
    });

    test('Badge Detection (par_name & sales.code)', () {
      final knownBadans = ['SGI', 'SSS', 'GBH', 'MGC', 'PDB', 'ANC'];

      String? detectBadanBadge(String? text) {
        if (text == null || text.trim().isEmpty) return null;
        final upper = text.toUpperCase().trim();
        for (final b in knownBadans) {
          if (upper == b) return b;
        }
        for (final b in knownBadans) {
          final regex = RegExp('(^|[^A-Z0-9])$b([^A-Z0-9]|\$)');
          if (regex.hasMatch(upper)) return b;
        }
        return null;
      }

      // a. purchases.par_name
      expect(detectBadanBadge('SGI-PT ANEKA USAHA'), 'SGI');
      expect(detectBadanBadge('MGC-DISTRIBUTOR'), 'MGC');
      expect(detectBadanBadge('GBH FARMASI'), 'GBH');
      expect(detectBadanBadge('SMK NEGERI 1 BANTUL'), null); // fallback to ANC

      // b. sales.code
      expect(detectBadanBadge('YGY-SGI'), 'SGI');
      expect(detectBadanBadge('XXX-MGC'), 'MGC');
      expect(detectBadanBadge('CUST-001'), null); // fallback to ANC
    });
  });
}
