import 'package:flutter_test/flutter_test.dart';

import 'package:mengfin/models/models.dart';
import 'package:mengfin/services/saldo_filter.dart';
import 'package:mengfin/widgets/saldo_illustrations.dart';

Akun buatAkun(String nama, double saldo, String jenis) => Akun(
      id: nama,
      nama: nama,
      jenis: jenis,
      saldo: saldo,
      warna: '#2563EB',
      ikon: jenis,
    );

void main() {
  // 'bank' adalah jenis lama (sebelum Saldo tipe diperkenalkan) dan sengaja
  // dimasukkan supaya pemetaannya ikut terjaga.
  final daftar = [
    buatAkun('Dompet Utama', -6164, 'cashflow'),
    buatAkun('Bank Jago', 250000, 'bank'),
    buatAkun('Tabungan Liburan', 1500000, 'tabungan'),
    buatAkun('Kartu Kredit BCA', -750000, 'kredit'),
    buatAkun('Emas Antam', 3000000, 'aset'),
  ];

  test('filter Semua menampilkan seluruh dompet', () {
    final hasil = filterDanUrutkanSaldo(daftar, SaldoFilter.semua, SaldoSort.nameAZ);
    expect(hasil.length, daftar.length);
  });

  test('filter Cashflow hanya tipe cashflow (jenis lama ikut terhitung)', () {
    final hasil =
        filterDanUrutkanSaldo(daftar, SaldoFilter.cashflow, SaldoSort.nameAZ);
    expect(hasil.map((a) => a.nama), ['Bank Jago', 'Dompet Utama'],
        reason: 'jenis lama "bank" diperlakukan sebagai cashflow');
    expect(hasil.every((a) =>
        SaldoIllustration.normalisasiJenis(a.jenis) == 'cashflow'), isTrue);
  });

  test('filter Arsip menampilkan tipe selain cashflow', () {
    final hasil =
        filterDanUrutkanSaldo(daftar, SaldoFilter.arsip, SaldoSort.nameAZ);
    expect(hasil.map((a) => a.nama),
        ['Emas Antam', 'Kartu Kredit BCA', 'Tabungan Liburan']);
    expect(hasil.any((a) => a.nama == 'Dompet Utama'), isFalse);
    expect(hasil.any((a) => a.nama == 'Bank Jago'), isFalse);
  });

  test('urutan nama naik dan turun', () {
    final az = filterDanUrutkanSaldo(daftar, SaldoFilter.semua, SaldoSort.nameAZ)
        .map((a) => a.nama)
        .toList();
    final za = filterDanUrutkanSaldo(daftar, SaldoFilter.semua, SaldoSort.nameZA)
        .map((a) => a.nama)
        .toList();

    expect(az.first, 'Bank Jago');
    expect(az.last, 'Tabungan Liburan');
    expect(za, az.reversed.toList(),
        reason: 'Name Z-A harus kebalikan persis dari Name A-Z');
  });

  test('urutan saldo: terbesar dan terkecil (termasuk negatif)', () {
    final tinggi =
        filterDanUrutkanSaldo(daftar, SaldoFilter.semua, SaldoSort.highest);
    expect(tinggi.first.nama, 'Emas Antam');
    expect(tinggi.first.saldo, 3000000);

    final rendah =
        filterDanUrutkanSaldo(daftar, SaldoFilter.semua, SaldoSort.lowest);
    expect(rendah.first.nama, 'Kartu Kredit BCA',
        reason: 'saldo paling negatif harus di urutan pertama');
    expect(rendah.first.saldo, -750000);
    expect(rendah.last.nama, 'Emas Antam');
  });

  test('filter dan urutan bisa digabung', () {
    final hasil =
        filterDanUrutkanSaldo(daftar, SaldoFilter.arsip, SaldoSort.highest);
    expect(hasil.first.nama, 'Emas Antam');
    expect(hasil.length, 3, reason: 'hanya tipe non-cashflow yang masuk Arsip');
    expect(hasil.map((a) => a.nama).toList(),
        ['Emas Antam', 'Tabungan Liburan', 'Kartu Kredit BCA'],
        reason: 'urutan saldo terbesar dulu, termasuk yang minus di akhir');
  });

  test('daftar kosong tidak error', () {
    final hasil = filterDanUrutkanSaldo([], SaldoFilter.semua, SaldoSort.highest);
    expect(hasil, isEmpty);
  });

  test('label enum sama dengan yang tampil di UI', () {
    expect(SaldoFilter.values.map((e) => e.label).toList(),
        ['Semua', 'Cashflow', 'Arsip']);
    expect(SaldoSort.values.map((e) => e.label).toList(),
        ['Name A-Z', 'Name Z-A', 'Highest balance', 'Lowest balance']);
  });

  test('jenis akun lama dipetakan ke tipe yang benar', () {
    // Nilai lama (bank/cash/ewallet) tidak boleh bikin kartu tanpa ilustrasi.
    expect(SaldoIllustration.normalisasiJenis('bank'), 'cashflow');
    expect(SaldoIllustration.normalisasiJenis('cash'), 'cashflow');
    expect(SaldoIllustration.normalisasiJenis('ewallet'), 'cashflow');
    expect(SaldoIllustration.normalisasiJenis('tabungan'), 'tabungan');
    expect(SaldoIllustration.normalisasiJenis('saving'), 'tabungan');
    expect(SaldoIllustration.normalisasiJenis('kredit'), 'kredit');
    expect(SaldoIllustration.normalisasiJenis('aset'), 'aset');
    expect(SaldoIllustration.normalisasiJenis(null), 'cashflow');
    expect(SaldoIllustration.normalisasiJenis(''), 'cashflow');
  });

  // ── Budget: filter + urutan ─────────────────────────────────────────────
  Anggaran buatAnggaran(String kategori, double batas, double terpakai,
          [double persentase = 0]) =>
      Anggaran(
        id: kategori,
        kategori: kategori,
        batas: batas,
        periode: '2026-09',
        terpakai: terpakai,
        persentase: persentase,
      );

  test('budget: urutan label enum sesuai UI', () {
    expect(BudgetSort.values.map((e) => e.label).toList(),
        ['Pemakaian tertinggi', 'Nominal terpakai', 'Batas terbesar', 'Nama kategori']);
  });

  test('budget: urutan pemakaian tertinggi', () {
    final list = [
      buatAnggaran('Makan', 1000000, 200000, 20),
      buatAnggaran('Transport', 500000, 450000, 90),
      buatAnggaran('Belanja', 2000000, 500000, 25),
    ];
    final hasil = filterDanUrutkanBudget(list, false, BudgetSort.persentase);
    expect(hasil.map((a) => a.kategori).toList(),
        ['Transport', 'Belanja', 'Makan']);
  });

  test('budget: urutan nominal terpakai dan batas terbesar', () {
    final list = [
      buatAnggaran('Makan', 1000000, 200000, 20),
      buatAnggaran('Transport', 500000, 450000, 90),
      buatAnggaran('Belanja', 2000000, 500000, 25),
    ];
    expect(
        filterDanUrutkanBudget(list, false, BudgetSort.terpakai)
            .map((a) => a.kategori)
            .toList(),
        ['Belanja', 'Transport', 'Makan']);
    expect(
        filterDanUrutkanBudget(list, false, BudgetSort.batas)
            .map((a) => a.kategori)
            .toList(),
        ['Belanja', 'Makan', 'Transport']);
  });

  test('budget: urutan nama kategori A-Z', () {
    final list = [
      buatAnggaran('Transport', 500000, 0),
      buatAnggaran('belanja', 500000, 0),
      buatAnggaran('Makan', 500000, 0),
    ];
    expect(
        filterDanUrutkanBudget(list, false, BudgetSort.nama)
            .map((a) => a.kategori)
            .toList(),
        ['belanja', 'Makan', 'Transport'],
        reason: 'perbandingan tidak boleh peka huruf besar/kecil');
  });

  test('budget: filter aktif membuang yang sudah lewat 100%', () {
    final list = [
      buatAnggaran('Makan', 1000000, 200000, 20),
      buatAnggaran('Transport', 500000, 600000, 120),
      buatAnggaran('Jajan', 300000, 300000, 100),
    ];
    final semua = filterDanUrutkanBudget(list, false, BudgetSort.persentase);
    final aktif = filterDanUrutkanBudget(list, true, BudgetSort.persentase);

    expect(semua.length, 3);
    expect(aktif.map((a) => a.kategori).toList(), ['Makan'],
        reason: 'persentase 100 dan 120 sudah tidak aktif');
  });

  test('budget: daftar kosong tidak error', () {
    expect(filterDanUrutkanBudget([], true, BudgetSort.batas), isEmpty);
  });
}
