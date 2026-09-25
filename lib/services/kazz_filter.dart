import '../models/models.dart';
import '../widgets/kazz_illustrations.dart';

/// Filter pada tab Dompet di menu Kazz.
enum KazzFilter {
  semua('Semua'),
  cashflow('Cashflow'),
  arsip('Arsip');

  final String label;
  const KazzFilter(this.label);
}

/// Urutan daftar dompet di menu Kazz.
enum KazzSort {
  nameAZ('Name A-Z'),
  nameZA('Name Z-A'),
  highest('Highest balance'),
  lowest('Lowest balance');

  final String label;
  const KazzSort(this.label);
}

/// Saring lalu urutkan daftar dompet.
///
/// Dipisah dari layar supaya bisa diuji tanpa membangun UI.
/// - [KazzFilter.cashflow] hanya menampilkan tipe cashflow.
/// - [KazzFilter.arsip] menampilkan tipe selain cashflow (tabungan, kartu
///   kredit, aset) — akun belum punya penanda arsip sendiri.
/// - Urutan tidak pernah mengubah isi daftar, hanya posisinya.
List<Akun> filterDanUrutkanKazz(
  List<Akun> wallets,
  KazzFilter filter,
  KazzSort sort,
) {
  Iterable<Akun> hasil = wallets;

  switch (filter) {
    case KazzFilter.cashflow:
      hasil = hasil.where(
          (a) => KazzIllustration.normalisasiJenis(a.jenis) == 'cashflow');
    case KazzFilter.arsip:
      hasil = hasil.where(
          (a) => KazzIllustration.normalisasiJenis(a.jenis) != 'cashflow');
    case KazzFilter.semua:
      break;
  }

  final list = hasil.toList();
  switch (sort) {
    case KazzSort.nameAZ:
      list.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    case KazzSort.nameZA:
      list.sort((a, b) => b.nama.toLowerCase().compareTo(a.nama.toLowerCase()));
    case KazzSort.highest:
      list.sort((a, b) => b.saldo.compareTo(a.saldo));
    case KazzSort.lowest:
      list.sort((a, b) => a.saldo.compareTo(b.saldo));
  }
  return list;
}
