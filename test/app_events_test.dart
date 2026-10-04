import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/app_events.dart';
import 'package:mengfin/services/update_service.dart';

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

  test('perbandingan tag rilis memakai urutan versi, bukan teks', () {
    const tagAwal = 'v20260924-2021';

    // Tag yang lebih baru (tanggal & jam lebih besar) harus terdeteksi.
    expect(UpdateService.tagLebihBaru('v20260925-0559', tagAwal), isTrue);
    expect(UpdateService.tagLebihBaru('v20260925-0001', tagAwal), isTrue);

    // Tag lama / sama tidak dianggap update.
    expect(UpdateService.tagLebihBaru(tagAwal, tagAwal), isFalse);
    expect(UpdateService.tagLebihBaru('v20260923-2359', tagAwal), isFalse);
    expect(UpdateService.tagLebihBaru('v20260932-9999', tagAwal), isTrue,
        reason: 'perbandingan numerik, bukan teks');

    // Tag yang tidak mengikuti pola tidak pernah dianggap lebih baru.
    expect(UpdateService.tagLebihBaru('nightly', tagAwal), isFalse);
    expect(UpdateService.tagLebihBaru('', tagAwal), isFalse);

    // Build lokal (tag kosong) → tag apa pun dianggap update.
    expect(UpdateService.tagLebihBaru(tagAwal, ''), isTrue);
  });

  test('URL rilis mengikuti pola asset workflow CI', () {
    const tag = 'v20260925-0559';
    expect(UpdateService.apkUrlFor(tag),
        'https://github.com/Mengggzz/mengfin-app/releases/download/v20260925-0559/app-release.apk');
    expect(UpdateService.releasesPage,
        'https://github.com/Mengggzz/mengfin-app/releases');
  });

  test('ReleaseInfo membangun URL APK dari respons GitHub', () {
    final r = ReleaseInfo.fromGithub({
      'tag_name': 'v20260925-0559',
      'name': 'MengFin v20260925-0559',
      'body': 'catatan rilis',
      'html_url': 'https://github.com/Mengggzz/mengfin-app/releases/tag/v20260925-0559',
      'published_at': '2026-09-25T06:05:18Z',
      'assets': [
        {'name': 'checksums.txt', 'browser_download_url': 'https://x/checksums.txt'},
        {'name': 'app-release.apk', 'browser_download_url': 'https://x/app-release.apk'},
      ],
    });

    expect(r.apkUrl, 'https://x/app-release.apk',
        reason: 'harus memilih asset .apk, bukan file lain');
    expect(r.tag, 'v20260925-0559');
    expect(r.readableVersion, '25 Sep 2026 · 05:59',
        reason: 'label versi yang dibaca user');
  });
}
