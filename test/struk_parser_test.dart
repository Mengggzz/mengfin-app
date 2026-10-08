import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/struk_parser.dart';

void main() {
  group('StrukParser Unit Tests', () {
    test('Struk minimarket dengan baris GRAND TOTAL Rp 57.500', () {
      const text = '''
INDOMARET POINT
JL. SUDIRMAN NO. 10
081234567890
15/09/2026 14:30
ROTI TAWAR 15.000
SUSU UHT 22.500
SNACK CHITATO 20.000
GRAND TOTAL Rp 57.500
TUNAI Rp 60.000
KEMBALI Rp 2.500
Terima kasih
''';
      final res = StrukParser.parse(text);
      expect(res['nominal'], 57500);
      expect(res['confidence'], 1.0);
      expect(res['kategori'], 'Belanja');
      expect(res['deskripsi'], contains('INDOMARET'));
      expect(res['tanggal'], '2026-09-15');
      expect(res['sumber'], 'lokal');
      expect(res['jenis'], 'pengeluaran');
    });

    test('Struk warung dengan tanggal 12-03-26 dan total tanpa grand', () {
      const text = '''
WARUNG MAKAN SEDAP
12-03-26
Nasi Goreng Spesial 25.000
Es Teh Manis 5.000
TOTAL: Rp 30.000
QRIS
''';
      final res = StrukParser.parse(text);
      expect(res['nominal'], 30000);
      expect(res['confidence'], 1.0);
      expect(res['kategori'], 'Makan & Minum');
      expect(res['deskripsi'], contains('WARUNG MAKAN'));
      expect(res['tanggal'], '2026-03-12');
      expect(res['metode_pembayaran'], 'qris');
    });

    test('Struk tanpa total jelas -> confidence rendah (< 0.6)', () {
      const text = '''
CATATAN BELANJA
Barang A
Barang B
Tanpa angka harga
''';
      final res = StrukParser.parse(text);
      expect(res['confidence'], lessThan(0.6));
      expect(res['nominal'], 0);
    });

    test('Angka besar Rp 1.500.000 terparse jadi 1500000', () {
      const text = '''
APOTEK SEHAT FARMA
TOTAL BAYAR: Rp 1.500.000
DEBIT BCA
''';
      final res = StrukParser.parse(text);
      expect(res['nominal'], 1500000);
      expect(res['confidence'], 1.0);
      expect(res['kategori'], 'Kesehatan');
      expect(res['metode_pembayaran'], 'debit');
    });

    test('Teks kosong atau tidak terbaca -> nominal 0, confidence 0.3, tidak crash', () {
      final res1 = StrukParser.parse('');
      expect(res1['nominal'], 0);
      expect(res1['confidence'], 0.3);

      final res2 = StrukParser.parse('   \n\n\t  ');
      expect(res2['nominal'], 0);
      expect(res2['confidence'], 0.3);
    });
  });
}
