import '../models/models.dart';
import '../widgets/saldo_illustrations.dart';

/// Filter pada tab Dompet di menu Saldo.
enum SaldoFilter {
  semua('Semua'),
  cashflow('Cashflow'),
  arsip('Arsip');

  final String label;
  const SaldoFilter(this.label);
}

/// Urutan daftar dompet di menu Saldo.
enum SaldoSort {
  nameAZ('Name A-Z'),
  nameZA('Name Z-A'),
  highest('Highest balance'),
  lowest('Lowest balance');

  final String label;
  const SaldoSort(this.label);
}

/// Saring lalu urutkan daftar dompet.
///
/// Dipisah dari layar supaya bisa diuji tanpa membangun UI.
/// - [SaldoFilter.cashflow] hanya menampilkan tipe cashflow.
/// - [SaldoFilter.arsip] menampilkan tipe selain cashflow (tabungan, kartu
///   kredit, aset) — akun belum punya penanda arsip sendiri.
/// - Urutan tidak pernah mengubah isi daftar, hanya posisinya.
List<Akun> filterDanUrutkanSaldo(
  List<Akun> wallets,
  SaldoFilter filter,
  SaldoSort sort,
) {
  Iterable<Akun> hasil = wallets;

  switch (filter) {
    case SaldoFilter.cashflow:
      hasil = hasil.where(
          (a) => SaldoIllustration.normalisasiJenis(a.jenis) == 'cashflow');
    case SaldoFilter.arsip:
      hasil = hasil.where(
          (a) => SaldoIllustration.normalisasiJenis(a.jenis) != 'cashflow');
    case SaldoFilter.semua:
      break;
  }

  final list = hasil.toList();
  switch (sort) {
    case SaldoSort.nameAZ:
      list.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
      break;
    case SaldoSort.nameZA:
      list.sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase()));
      break;
    case SaldoSort.highest:
      list.sort((a, b) => b.saldo.compareTo(a.saldo));
      break;
    case SaldoSort.lowest:
      list.sort((a, b) => a.saldo.compareTo(b.saldo));
      break;
  }
  return list;
}

/// Urutan daftar budget di tab Budget.
enum BudgetSort {
  persentase('Pemakaian tertinggi'),
  terpakai('Nominal terpakai'),
  batas('Batas terbesar'),
  nama('Nama kategori');

  final String label;
  const BudgetSort(this.label);
}

/// Saring lalu urutkan daftar anggaran.
///
/// [hanyaAktif] membuang anggaran yang pemakaiannya sudah lewat 100%.
List<Anggaran> filterDanUrutkanBudget(
  List<Anggaran> anggaran,
  bool hanyaAktif,
  BudgetSort sort,
) {
  Iterable<Anggaran> hasil = anggaran;
  if (hanyaAktif) {
    hasil = hasil.where((a) => a.persentase < 100);
  }

  final list = hasil.toList();
  switch (sort) {
    case BudgetSort.persentase:
      list.sort((a, b) => b.persentase.compareTo(a.persentase));
    case BudgetSort.terpakai:
      list.sort((a, b) => b.terpakai.compareTo(a.terpakai));
    case BudgetSort.batas:
      list.sort((a, b) => b.batas.compareTo(a.batas));
    case BudgetSort.nama:
      list.sort((a, b) => a.kategori.toLowerCase().compareTo(b.kategori.toLowerCase()));
  }
  return list;
}
