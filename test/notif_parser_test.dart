import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/notif_parser.dart';

/// Uji parser notifikasi dengan teks notifikasi yang realistis.
/// Bagian ini murni, jadi bisa diuji tanpa HP Android.
void main() {
  NotifTransaksi? parse(String teks, {Set<String> kataKunci = const {}}) =>
      NotifParser.parse(
        title: teks.split('|').first,
        content: teks.contains('|') ? teks.split('|')[1] : '',
        packageName: 'com.contoh.app',
        kataKunci: kataKunci,
      );

  group('nominal', () {
    test('format Indonesia dengan titik ribuan', () {
      expect(NotifParser.parseNominal('Pembayaran Rp25.000 berhasil'), 25000);
      expect(NotifParser.parseNominal('Rp1.250.000'), 1250000);
    });

    test('tanpa pemisah dan dengan awalan IDR', () {
      expect(NotifParser.parseNominal('IDR 75000'), 75000);
      expect(NotifParser.parseNominal('bayar 15000'), 15000);
    });

    test('koma sebagai desimal', () {
      expect(NotifParser.parseNominal('Rp25,5'), 25.5);
    });

    test('singkatan rb/jt', () {
      expect(NotifParser.parseNominal('bayar 25rb'), 25000);
      expect(NotifParser.parseNominal('bayar 1,5jt'), 1500000);
      expect(NotifParser.parseNominal('bayar 2 juta'), 2000000);
    });

    test('nominal menang atas angka tahun di tanggal', () {
      expect(
        NotifParser.parseNominal('Transaksi 27/09/2026 sebesar Rp25.000'),
        25000,
      );
    });

    test('pilih angka setelah kata penanda, bukan saldo', () {
      expect(
        NotifParser.parseNominal('Saldo Rp500.000, total transaksi Rp25.000'),
        25000,
      );
    });

    test('tanpa angka → null', () {
      expect(NotifParser.parseNominal('Pembayaran berhasil'), isNull);
      expect(NotifParser.parseNominal(''), isNull);
    });
  });

  group('penyaring notifikasi', () {
    test('notifikasi pembayaran ditangkap', () {
      final hasil = parse('Pembayaran Berhasil|Rp25.000 ke Toko Kopi');
      expect(hasil, isNotNull);
      expect(hasil!.nominal, 25000);
      expect(hasil.jenis, 'pengeluaran');
    });

    test('promo dengan nominal ditolak kalau mode ketat', () {
      // Ini inti kenapa ada kataWajibBayar: promo diskon sering memuat angka.
      final hasil = parse('Promo Spesial|Diskon hingga Rp50.000 hari ini');
      expect(hasil, isNull);
    });

    test('promo tetap ditolak walau kata kunci cocok', () {
      final hasil = parse('Promo Spesial|Diskon Rp50.000 untuk semua transaksi');
      expect(hasil, isNull);
    });

    test('kata kunci pengguna menyaring', () {
      final hasil = parse(
        'Pembayaran Berhasil|Rp25.000',
        kataKunci: {'tidakadadisinikata'},
      );
      expect(hasil, isNull);
    });

    test('chat biasa tanpa nominal tidak ditangkap', () {
      expect(parse('Budi|Halo apa kabar'), isNull);
      expect(parse('Budi|Kita bayar nanti ya'), isNull);
    });
  });

  group('jenis transaksi', () {
    test('pembayaran/debit/pembelian → pengeluaran', () {
      expect(parse('Pembayaran|Rp25.000 berhasil')!.jenis, 'pengeluaran');
      expect(parse('Kartu Debit|Transaksi Rp100.000')!.jenis, 'pengeluaran');
    });

    test('transfer masuk/gaji → pemasukan', () {
      expect(parse('Transfer Masuk|Rp1.500.000 diterima')!.jenis, 'pemasukan');
      expect(parse('Gaji|Payroll Rp8.000.000 masuk')!.jenis, 'pemasukan');
    });
  });

  group('kategori', () {
    test('selalu salah satu label di kategoriList, tidak pernah kosong', () {
      final contoh = [
        'Pembayaran|Rp25.000 GoFood',
        'Pembayaran|Rp50.000 Grab',
        'Pembayaran|Rp100.000 Tokopedia',
        'Pembayaran|Rp200.000 PLN',
        'Transfer Masuk|Rp1.000.000 diterima',
        'Pembayaran|Rp30.000 entah apa',
      ];
      for (final c in contoh) {
        final hasil = parse(c);
        expect(hasil, isNotNull, reason: c);
        expect(hasil!.kategori.trim(), isNotEmpty, reason: c);
      }
    });

    test('kata khas menuntun kategori', () {
      expect(parse('Pembayaran|Rp25.000 GoFood')!.kategori, 'Makan & Minum');
      expect(parse('Pembayaran|Rp50.000 Grab')!.kategori, 'Transportasi');
      expect(parse('Pembayaran|Rp200.000 PLN')!.kategori, 'Tagihan');
      expect(parse('Transfer Masuk|Rp1.000.000')!.kategori, 'Transfer');
    });
  });

  group('deskripsi', () {
    test('judul dan isi digabung, isi panjang dipotong', () {
      final hasil = parse('Pembayaran|Rp25.000 ke Toko Kopi Senja');
      expect(hasil!.deskripsi, contains('Pembayaran'));
      expect(hasil.deskripsi, contains('Toko Kopi'));

      final panjang = parse(
          'Pembayaran|Rp25.000 ${'x' * 100}');
      expect(panjang!.deskripsi.length, lessThan(120));
    });

    test('isi yang mengulang judul tidak digandakan', () {
      final hasil = parse('Pembayaran|Pembayaran Rp25.000');
      expect(hasil!.deskripsi, 'Pembayaran Rp25.000');
    });
  });
}
