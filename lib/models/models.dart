class Akun {
  final dynamic id;
  final String nama;
  final String jenis;
  final double saldo;
  final String warna;
  final String ikon;

  Akun({required this.id, required this.nama, required this.jenis,
        required this.saldo, required this.warna, required this.ikon});

  factory Akun.fromJson(Map<String, dynamic> j) => Akun(
    id: j['id'] ?? j['_id'], nama: j['nama'], jenis: j['jenis'],
    saldo: (j['saldo'] as num).toDouble(),
    warna: j['warna'] ?? '#2563EB', ikon: j['ikon'] ?? 'bank',
  );
}

class Transaksi {
  final dynamic id;
  final String? localId;
  final String tanggal;
  final String jenis;
  final double nominal;
  final String kategori;
  final String deskripsi;
  final String metodePembayaran;
  final dynamic akunId;
  final String? akunNama;
  final bool synced;

  Transaksi({required this.id, this.localId, required this.tanggal,
             required this.jenis, required this.nominal, required this.kategori,
             required this.deskripsi, required this.metodePembayaran,
             this.akunId, this.akunNama, this.synced = true});

  factory Transaksi.fromJson(Map<String, dynamic> j) => Transaksi(
    id: j['id'] ?? j['_id'], tanggal: j['tanggal'], jenis: j['jenis'],
    nominal: (j['nominal'] as num).toDouble(),
    kategori: j['kategori'], deskripsi: j['deskripsi'] ?? '',
    metodePembayaran: j['metode_pembayaran'] ?? 'tunai',
    akunId: j['akun_id'], akunNama: j['akun_nama'],
    synced: true,
  );

  Map<String, dynamic> toJson() => {
    'tanggal': tanggal, 'jenis': jenis, 'nominal': nominal,
    'kategori': kategori, 'deskripsi': deskripsi,
    'metode_pembayaran': metodePembayaran,
    if (akunId != null) 'akun_id': akunId,
  };
}

class Anggaran {
  final dynamic id;
  final String? localId;
  final String kategori;
  final double batas;
  final String periode;
  final double terpakai;
  final double persentase;
  final bool synced;

  Anggaran({required this.id, this.localId, required this.kategori,
            required this.batas, required this.periode, required this.terpakai,
            required this.persentase, this.synced = true});

  factory Anggaran.fromJson(Map<String, dynamic> j) => Anggaran(
    id: j['id'] ?? j['_id'], kategori: j['kategori'],
    batas: (j['batas'] as num).toDouble(),
    periode: j['periode'],
    terpakai: (j['terpakai'] as num? ?? 0).toDouble(),
    persentase: (j['persentase'] as num? ?? 0).toDouble(),
    synced: true,
  );
}

class Goal {
  final dynamic id;
  final String? localId;
  final String nama;
  final double target;
  final double terkumpul;
  final String? deadline;
  final String prioritas;
  final double nabungPerBulan;
  final String catatan;
  final bool synced;

  Goal({required this.id, this.localId, required this.nama, required this.target,
        required this.terkumpul, this.deadline, required this.prioritas,
        required this.nabungPerBulan, required this.catatan, this.synced = true});

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'] ?? j['_id'], nama: j['nama'],
    target: (j['target'] as num).toDouble(),
    terkumpul: (j['terkumpul'] as num? ?? 0).toDouble(),
    deadline: j['deadline'],
    prioritas: j['prioritas'] ?? 'sedang',
    nabungPerBulan: (j['nabung_per_bulan'] as num? ?? 0).toDouble(),
    catatan: j['catatan'] ?? '',
    synced: true,
  );

  double get persen => target > 0 ? (terkumpul / target * 100).clamp(0, 100) : 0;
  bool get tercapai => terkumpul >= target;
}

class HealthScore {
  final int score;
  final String status;
  final String warna;
  final String pesan;

  HealthScore({required this.score, required this.status,
               required this.warna, required this.pesan});

  factory HealthScore.fromJson(Map<String, dynamic> j) => HealthScore(
    score: (j['score'] as num).toInt(), status: j['status'],
    warna: j['warna'], pesan: j['pesan'],
  );
}

class DashboardData {
  final double saldoTotal;
  final double pemasukanBulanIni;
  final double pengeluaranBulanIni;
  final String bulanIni;
  final HealthScore health;
  final double rataHarian;
  final double mingguIniPengeluaran;
  final int kenaikanPersen;
  final String kategoriTerbesar;
  final String mingguPeriode;
  final double prediksiSaldoAkhir;
  final int sisaHari;
  final String prediksiStatus;

  DashboardData({
    required this.saldoTotal, required this.pemasukanBulanIni,
    required this.pengeluaranBulanIni, required this.bulanIni,
    required this.health, required this.rataHarian,
    required this.mingguIniPengeluaran, required this.kenaikanPersen,
    required this.kategoriTerbesar, required this.mingguPeriode,
    required this.prediksiSaldoAkhir, required this.sisaHari,
    required this.prediksiStatus,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
    saldoTotal: (j['saldoTotal'] as num).toDouble(),
    pemasukanBulanIni: (j['bulanIni']?['pemasukan'] as num? ?? 0).toDouble(),
    pengeluaranBulanIni: (j['bulanIni']?['pengeluaran'] as num? ?? 0).toDouble(),
    bulanIni: j['bulanIni']?['bulan'] ?? '',
    health: HealthScore.fromJson(j['health']),
    rataHarian: (j['mingguIni']?['rataHarian'] as num? ?? 0).toDouble(),
    mingguIniPengeluaran: (j['mingguIni']?['pengeluaran'] as num? ?? 0).toDouble(),
    kenaikanPersen: (j['mingguIni']?['kenaikanDariBulanLalu'] as num? ?? 0).toInt(),
    kategoriTerbesar: j['mingguIni']?['kategoriTerbesar'] ?? '-',
    mingguPeriode: j['mingguIni']?['periode'] ?? '',
    prediksiSaldoAkhir: (j['prediksi']?['prediksiSaldoAkhir'] as num? ?? 0).toDouble(),
    sisaHari: (j['prediksi']?['sisaHari'] as num? ?? 0).toInt(),
    prediksiStatus: j['prediksi']?['status'] ?? 'aman',
  );
}
