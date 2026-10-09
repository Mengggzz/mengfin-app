import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/models/models.dart';
import 'package:mengfin/services/dompet_view.dart';

/// Saldo di beranda harus ikut dompet yang dipilih pengguna.
/// Sebelumnya beranda selalu memakai `saldoTotal` dari server, jadi pilihan
/// "Saldo Utama" dan "dompet yang tampil" di layar pengaturan tidak
/// berpengaruh apa pun.
Akun akun(dynamic id, String nama, double saldo) =>
    Akun(id: id, nama: nama, jenis: 'bank', saldo: saldo, warna: '#2563EB', ikon: 'bank');

void main() {
  test('tanpa akun (offline/gagal): saldo server dipakai apa adanya', () {
    final hasil = DompetView.saldoTampil(
      akun: const [],
      dompetUtama: 'x',
      dompetTampil: const ['x'],
      saldoServer: 1234,
    );
    expect(hasil, 1234);
  });

  test('dompet tampil: jumlah saldo akun terpilih saja', () {
    final hasil = DompetView.saldoTampil(
      akun: [akun(1, 'BCA', 100), akun(2, 'Mandiri', 50), akun(3, 'OVO', 7)],
      dompetUtama: null,
      dompetTampil: const ['1', '3'],
      saldoServer: 9999,
    );
    expect(hasil, 107);
  });

  test('tanpa dompet tampil: pakai dompet utama', () {
    final hasil = DompetView.saldoTampil(
      akun: [akun(1, 'BCA', 100), akun(2, 'Mandiri', 50)],
      dompetUtama: '2',
      dompetTampil: const [],
      saldoServer: 9999,
    );
    expect(hasil, 50);
  });

  test('tanpa dompet utama & tanpa dompet tampil: jumlahkan semua akun (Semua Dompet)', () {
    final hasil = DompetView.saldoTampil(
      akun: [akun(1, 'BCA', 100), akun(2, 'Mandiri', 50)],
      dompetUtama: null,
      dompetTampil: const [],
      saldoServer: 9999,
    );
    expect(hasil, 150);
  });

  test('id int dibandingkan sebagai teks (id lokal vs ObjectId server)', () {
    final hasil = DompetView.saldoTampil(
      akun: [akun(6841, 'BCA', 100), akun('6841abc', 'Mandiri', 55)],
      dompetUtama: null,
      dompetTampil: const ['6841abc'],
      saldoServer: 0,
    );
    expect(hasil, 55);
  });

  test('id terpilih tidak ada di daftar akun: jatuh ke saldo server', () {
    final hasil = DompetView.saldoTampil(
      akun: [akun(1, 'BCA', 100)],
      dompetUtama: 'sudah-dihapus',
      dompetTampil: const ['sudah-dihapus'],
      saldoServer: 777,
    );
    expect(hasil, 777);
  });

  test('saldo negatif ikut dihitung (dompet minus)', () {
    final hasil = DompetView.saldoTampil(
      akun: [akun(1, 'BCA', 100), akun(2, 'Kartu Kredit', -40)],
      dompetUtama: null,
      dompetTampil: const ['1', '2'],
      saldoServer: 0,
    );
    expect(hasil, 60);
  });

  test('dompetAwal: utama kalau ada, kalau tidak akun pertama', () {
    final daftar = [akun(1, 'BCA', 100), akun(2, 'Mandiri', 50)];
    expect(DompetView.dompetAwal(daftar, '2')?.nama, 'Mandiri');
    expect(DompetView.dompetAwal(daftar, null)?.nama, 'BCA');
    expect(DompetView.dompetAwal(daftar, 'hilang')?.nama, 'BCA');
    expect(DompetView.dompetAwal(const [], null), isNull);
  });
}
