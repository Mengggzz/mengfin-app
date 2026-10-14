import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/models/models.dart';
import 'package:mengfin/services/api_service.dart';

void main() {
  group('Task 2 Round 7: Null-safe fromJson pada 4 model', () {
    test('Transaksi.fromJson menangani nominal null tanpa melempar exception', () {
      final json = {
        'id': 'tx_null_nom',
        'tanggal': '2026-10-12',
        'jenis': 'pengeluaran',
        'nominal': null,
        'kategori': 'Makan',
        'deskripsi': null,
        'metode_pembayaran': null,
      };

      final tx = Transaksi.fromJson(json);
      expect(tx.id, 'tx_null_nom');
      expect(tx.nominal, 0.0);
      expect(tx.deskripsi, '');
      expect(tx.metodePembayaran, 'tunai');
    });

    test('Anggaran.fromJson menangani batas & field numerik null tanpa exception', () {
      final json = {
        'id': 'ang_null_batas',
        'kategori': 'Makan',
        'batas': null,
        'periode': '2026-10',
        'terpakai': null,
        'persentase': null,
      };

      final ang = Anggaran.fromJson(json);
      expect(ang.id, 'ang_null_batas');
      expect(ang.batas, 0.0);
      expect(ang.terpakai, 0.0);
      expect(ang.persentase, 0.0);
    });

    test('Goal.fromJson menangani target, terkumpul, nabung_per_bulan null tanpa exception', () {
      final json = {
        'id': 'goal_null_target',
        'nama': 'Liburan',
        'target': null,
        'terkumpul': null,
        'prioritas': null,
        'nabung_per_bulan': null,
        'catatan': null,
      };

      final goal = Goal.fromJson(json);
      expect(goal.id, 'goal_null_target');
      expect(goal.target, 0.0);
      expect(goal.terkumpul, 0.0);
      expect(goal.prioritas, 'sedang');
      expect(goal.nabungPerBulan, 0.0);
      expect(goal.catatan, '');
    });

    test('HealthScore.fromJson menangani score null tanpa exception', () {
      final json = {
        'score': null,
        'status': null,
        'warna': null,
        'pesan': null,
      };

      final hs = HealthScore.fromJson(json);
      expect(hs.score, 0);
      expect(hs.status, isNotEmpty);
      expect(hs.warna, isNotEmpty);
      expect(hs.pesan, isNotNull);
    });
  });

  group('Task 2 Round 7: Pemetaan list server menoleransi dokumen rusak (skip + log)', () {
    test('parseTransaksiList melewati dokumen rusak/bukan map dan tetap mengambil dokumen valid', () {
      final rawList = [
        // 1. Dokumen valid
        {
          'id': 'tx_valid_1',
          'tanggal': '2026-10-12',
          'jenis': 'pengeluaran',
          'nominal': 50000,
          'kategori': 'Makan',
        },
        // 2. Dokumen rusak: bukan map (string corrupt / null di array)
        null,
        'bukan-json-map',
        // 3. Dokumen valid kedua
        {
          'id': 'tx_valid_2',
          'tanggal': '2026-10-12',
          'jenis': 'pemasukan',
          'nominal': 100000,
          'kategori': 'Gaji',
        },
      ];

      final list = ApiService.parseTransaksiList(rawList);
      expect(list.length, 2);
      expect(list[0].id, 'tx_valid_1');
      expect(list[1].id, 'tx_valid_2');
    });

    test('parseAnggaranList melewati item rusak', () {
      final rawList = [
        {
          'id': 'ang_1',
          'kategori': 'Makan',
          'batas': 500000,
          'periode': '2026-10',
        },
        'corrupt_entry',
        {
          'id': 'ang_2',
          'kategori': 'Transport',
          'batas': 300000,
          'periode': '2026-10',
        },
      ];

      final list = ApiService.parseAnggaranList(rawList);
      expect(list.length, 2);
      expect(list[0].id, 'ang_1');
      expect(list[1].id, 'ang_2');
    });

    test('parseGoalList melewati item rusak', () {
      final rawList = [
        {
          'id': 'goal_1',
          'nama': 'Dana Darurat',
          'target': 10000000,
        },
        null,
        {
          'id': 'goal_2',
          'nama': 'Laptop',
          'target': 15000000,
        },
      ];

      final list = ApiService.parseGoalList(rawList);
      expect(list.length, 2);
      expect(list[0].id, 'goal_1');
      expect(list[1].id, 'goal_2');
    });

    test('parseAkunList melewati item rusak', () {
      final rawList = [
        {
          'id': 'akun_1',
          'nama': 'BCA',
          'jenis': 'bank',
          'saldo': 1000000,
        },
        12345,
        {
          'id': 'akun_2',
          'nama': 'Tunai',
          'jenis': 'kas',
          'saldo': 250000,
        },
      ];

      final list = ApiService.parseAkunList(rawList);
      expect(list.length, 2);
      expect(list[0].id, 'akun_1');
      expect(list[1].id, 'akun_2');
    });
  });
}
