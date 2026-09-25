import 'package:flutter_test/flutter_test.dart';

import 'package:mengfin/models/models.dart';
import 'package:mengfin/services/kazz_filter.dart';
import 'package:mengfin/widgets/kazz_illustrations.dart';

Akun buatAkun(String nama, double saldo, String jenis) => Akun(
      id: nama,
      nama: nama,
      jenis: jenis,
      saldo: saldo,
      warna: '#2563EB',
      ikon: jenis,
    );

void main() {
  // 'bank' adalah jenis lama (sebelum Kazz tipe diperkenalkan) dan sengaja
  // dimasukkan supaya pemetaannya ikut terjaga.
  final daftar = [
    buatAkun('Dompet Utama', -6164, 'cashflow'),
    buatAkun('Bank Jago', 250000, 'bank'),
    buatAkun('Tabungan Liburan', 1500000, 'tabungan'),
    buatAkun('Kartu Kredit BCA', -750000, 'kredit'),
    buatAkun('Emas Antam', 3000000, 'aset'),
  ];

  test('filter Semua menampilkan seluruh dompet', () {
    final hasil = filterDanUrutkanKazz(daftar, KazzFilter.semua, KazzSort.nameAZ);
    expect(hasil.length, daftar.length);
  });

  test('filter Cashflow hanya tipe cashflow (jenis lama ikut terhitung)', () {
    final hasil =
        filterDanUrutkanKazz(daftar, KazzFilter.cashflow, KazzSort.nameAZ);
    expect(hasil.map((a) => a.nama), ['Bank Jago', 'Dompet Utama'],
        reason: 'jenis lama "bank" diperlakukan sebagai cashflow');
    expect(hasil.every((a) =>
        KazzIllustration.normalisasiJenis(a.jenis) == 'cashflow'), isTrue);
  });

  test('filter Arsip menampilkan tipe selain cashflow', () {
    final hasil =
        filterDanUrutkanKazz(daftar, KazzFilter.arsip, KazzSort.nameAZ);
    expect(hasil.map((a) => a.nama),
        ['Emas Antam', 'Kartu Kredit BCA', 'Tabungan Liburan']);
    expect(hasil.any((a) => a.nama == 'Dompet Utama'), isFalse);
    expect(hasil.any((a) => a.nama == 'Bank Jago'), isFalse);
  });

  test('urutan nama naik dan turun', () {
    final az = filterDanUrutkanKazz(daftar, KazzFilter.semua, KazzSort.nameAZ)
        .map((a) => a.nama)
        .toList();
    final za = filterDanUrutkanKazz(daftar, KazzFilter.semua, KazzSort.nameZA)
        .map((a) => a.nama)
        .toList();

    expect(az.first, 'Bank Jago');
    expect(az.last, 'Tabungan Liburan');
    expect(za, az.reversed.toList(),
        reason: 'Name Z-A harus kebalikan persis dari Name A-Z');
  });

  test('urutan saldo: terbesar dan terkecil (termasuk negatif)', () {
    final tinggi =
        filterDanUrutkanKazz(daftar, KazzFilter.semua, KazzSort.highest);
    expect(tinggi.first.nama, 'Emas Antam');
    expect(tinggi.first.saldo, 3000000);

    final rendah =
        filterDanUrutkanKazz(daftar, KazzFilter.semua, KazzSort.lowest);
    expect(rendah.first.nama, 'Kartu Kredit BCA',
        reason: 'saldo paling negatif harus di urutan pertama');
    expect(rendah.first.saldo, -750000);
    expect(rendah.last.nama, 'Emas Antam');
  });

  test('filter dan urutan bisa digabung', () {
    final hasil =
        filterDanUrutkanKazz(daftar, KazzFilter.arsip, KazzSort.highest);
    expect(hasil.first.nama, 'Emas Antam');
    expect(hasil.length, 3, reason: 'hanya tipe non-cashflow yang masuk Arsip');
    expect(hasil.map((a) => a.nama).toList(),
        ['Emas Antam', 'Tabungan Liburan', 'Kartu Kredit BCA'],
        reason: 'urutan saldo terbesar dulu, termasuk yang minus di akhir');
  });

  test('daftar kosong tidak error', () {
    final hasil = filterDanUrutkanKazz([], KazzFilter.semua, KazzSort.highest);
    expect(hasil, isEmpty);
  });

  test('label enum sama dengan yang tampil di UI', () {
    expect(KazzFilter.values.map((e) => e.label).toList(),
        ['Semua', 'Cashflow', 'Arsip']);
    expect(KazzSort.values.map((e) => e.label).toList(),
        ['Name A-Z', 'Name Z-A', 'Highest balance', 'Lowest balance']);
  });

  test('jenis akun lama dipetakan ke tipe yang benar', () {
    // Nilai lama (bank/cash/ewallet) tidak boleh bikin kartu tanpa ilustrasi.
    expect(KazzIllustration.normalisasiJenis('bank'), 'cashflow');
    expect(KazzIllustration.normalisasiJenis('cash'), 'cashflow');
    expect(KazzIllustration.normalisasiJenis('ewallet'), 'cashflow');
    expect(KazzIllustration.normalisasiJenis('tabungan'), 'tabungan');
    expect(KazzIllustration.normalisasiJenis('saving'), 'tabungan');
    expect(KazzIllustration.normalisasiJenis('kredit'), 'kredit');
    expect(KazzIllustration.normalisasiJenis('aset'), 'aset');
    expect(KazzIllustration.normalisasiJenis(null), 'cashflow');
    expect(KazzIllustration.normalisasiJenis(''), 'cashflow');
  });
}
