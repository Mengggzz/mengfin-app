import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/csv_import_service.dart';

void main() {
  group('CsvImportService Unit Tests', () {
    test('Import CSV format BCA 2-kolom (Debit / Kredit)', () {
      const csvData = '''
Tanggal,Keterangan,Debit,Kredit
15/09/2026,TRSF E-BANKING CR DARI BUDI,0,"500.000"
16/09/2026,PEMBAYARAN QRIS KOPI KENANGAN,"35.000",0
17/09/2026,TARIK TUNAI ATM,"100.000",0
''';
      final rows = CsvImportService.parseCsvContent(csvData);
      expect(rows.length, 3);
      
      expect(rows[0]['tanggal'], '2026-09-15');
      expect(rows[0]['jenis'], 'pemasukan');
      expect(rows[0]['nominal'], 500000.0);
      expect(rows[0]['deskripsi'], contains('DARI BUDI'));

      expect(rows[1]['tanggal'], '2026-09-16');
      expect(rows[1]['jenis'], 'pengeluaran');
      expect(rows[1]['nominal'], 35000.0);

      expect(rows[2]['tanggal'], '2026-09-17');
      expect(rows[2]['jenis'], 'pengeluaran');
      expect(rows[2]['nominal'], 100000.0);
    });

    test('Import CSV format Mandiri 1-kolom nominal bertanda minus', () {
      const csvData = '''
Date,Description,Amount
10/08/2026,Gaji Bulanan PT Maju,5000000
11/08/2026,Beli Bensin Pertamina,-150000
''';
      final rows = CsvImportService.parseCsvContent(csvData);
      expect(rows.length, 2);

      expect(rows[0]['jenis'], 'pemasukan');
      expect(rows[0]['nominal'], 5000000.0);

      expect(rows[1]['jenis'], 'pengeluaran');
      expect(rows[1]['nominal'], 150000.0);
    });

    test('Handle CSV kosong / rusak gracefully', () {
      final rows1 = CsvImportService.parseCsvContent('');
      expect(rows1, isEmpty);

      final rows2 = CsvImportService.parseCsvContent('Header1,Header2\n');
      expect(rows2, isEmpty);
    });
  });
}
