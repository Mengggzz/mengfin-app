import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/app_events.dart';
import 'package:mengfin/services/update_service.dart';
import 'package:mengfin/widgets/update_dialog.dart';

void main() {
  test('AppEvents memberi tahu pendengar saat transaksi berubah', () {
    final bus = AppEvents.instance;
    var panggilan = 0;
    void listener() => panggilan++;

    bus.transaksi.addListener(listener);
    expect(panggilan, 0);

    bus.transaksiBerubah();
    expect(panggilan, 1, reason: 'layar harus diminta menyegarkan diri');

    bus.transaksiBerubah();
    expect(panggilan, 2);

    bus.transaksi.removeListener(listener);
    bus.transaksiBerubah();
    expect(panggilan, 2, reason: 'setelah dilepas tidak boleh dipanggil lagi');
  });

  test('Anggaran dan goals punya kanal sendiri (tidak saling memicu)', () {
    final bus = AppEvents.instance;
    var anggaran = 0, goals = 0, transaksi = 0;
    void la() => anggaran++;
    void lg() => goals++;
    void lt() => transaksi++;

    bus.anggaran.addListener(la);
    bus.goals.addListener(lg);
    bus.transaksi.addListener(lt);

    bus.anggaranBerubah();
    expect([anggaran, goals, transaksi], [1, 0, 0]);

    bus.goalsBerubah();
    expect([anggaran, goals, transaksi], [1, 1, 0]);

    bus.anggaran.removeListener(la);
    bus.goals.removeListener(lg);
    bus.transaksi.removeListener(lt);
  });

  test('perbandingan tag rilis: yang lebih baru terdeteksi', () {
    // Diuji lewat perilaku publik: tag lama vs baru pada endpoint GitHub,
    // jadi cukup pastikan pola tag CI vYYYYMMDD-HHMM urut secara leksikografis.
    const lama = 'v20260925-1115';
    const baru = 'v20260925-1118';
    expect(baru.compareTo(lama) > 0, isTrue);
    expect(UpdateService.apkUrlFor(baru),
        'https://github.com/Mengggzz/mengfin-app/releases/download/v20260925-1118/app-release.apk');
    expect(UpdateService.releasesPage,
        'https://github.com/Mengggzz/mengfin-app/releases');
  });
}
