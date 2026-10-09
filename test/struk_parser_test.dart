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
      expect(res['confidence'], greaterThanOrEqualTo(0.7));
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

    test('Struk Indomaret asli user: koma ribuan 27,000, TRXID SEABANK diabaikan, telp diabaikan', () {
      const text = '''
INDOMARET JL MERDEKA
nimbA aite1D
SMS/WA 0811.1500.280 TELP
TECA2610071336490101
INDOMIE AYAM BAWANG 3,500
TEH PUCUK HARUM 4,000
TOTAL BELANJA : 27,000
NON TUNAI : 27,000
''';
      final res = StrukParser.parse(text);
      expect(res['nominal'], 27000);
      expect(res['deskripsi'], contains('INDOMARET'));
      expect(res['items'].any((i) => i['nama'].toString().contains('0811')), false);
      expect(res['items'].any((i) => i['harga'] == 1500280), false);
    });

    test('Teks OCR ngawur: total 9 digit dan tahun 2013 -> confidence rendah, tanggal fallback hari ini', () {
      const text = '''
nimbA aite1D
26/10/2013
TOTAL BAYAR Rp 261.007.133
''';
      final res = StrukParser.parse(text);
      expect(res['confidence'], lessThanOrEqualTo(0.4));
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      expect(res['tanggal'], '$y-$m-$d');
    });
  });
}
