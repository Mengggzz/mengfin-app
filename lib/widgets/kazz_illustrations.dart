import 'package:flutter/material.dart';

/// Ilustrasi kecil untuk menu Kazz, digambar dengan CustomPaint supaya
/// tidak perlu file gambar dan tetap tajam di semua ukuran layar.
///
/// Semua painter menggambar di dalam [size] yang diberikan dan memakai
/// koordinat relatif (0..1) sehingga aman untuk ukuran berapa pun.
class KazzIllustration extends StatelessWidget {
  /// 'cashflow' | 'tabungan' | 'kredit' | 'aset'
  final String jenis;
  final double size;

  const KazzIllustration({super.key, required this.jenis, this.size = 40});

  /// Ilustrasi sesuai tipe akun. Tipe tak dikenal memakai ilustrasi cashflow.
  static KazzIllustration forJenis(String? jenis, {double size = 40}) =>
      KazzIllustration(jenis: normalisasiJenis(jenis), size: size);

  /// Samakan penamaan tipe akun: nilai lama (bank/cash/ewallet) dianggap
  /// cashflow, sisanya dipetakan ke tipe yang dikenal.
  static String normalisasiJenis(String? jenis) {
    switch ((jenis ?? '').trim().toLowerCase()) {
      case 'tabungan':
      case 'saving':
      case 'savings':
        return 'tabungan';
      case 'kredit':
      case 'credit':
      case 'kartu_kredit':
        return 'kredit';
      case 'aset':
      case 'asset':
      case 'gold':
        return 'aset';
      default:
        return 'cashflow';
    }
  }

  @override
  Widget build(BuildContext context) {
    final painter = switch (jenis) {
      'tabungan' => _TabunganPainter(),
      'kredit' => _KartuKreditPainter(),
      'aset' => _AsetPainter(),
      _ => _CashflowPainter(),
    };
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter),
    );
  }
}

/// Ikon dompet oranye berisi uang hijau (Kazz Cashflow).
class _CashflowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final green = Paint()..color = const Color(0xFF34C759);
    final greenDark = Paint()..color = const Color(0xFF1F9E43);
    final orange = Paint()..color = const Color(0xFFFF9F0A);
    final orangeDark = Paint()..color = const Color(0xFFD97706);

    // Tiga lembar uang hijau menyembul di atas dompet.
    void bill(double dx, double dy, double rot) {
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(rot);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.40, height: h * 0.26),
        Radius.circular(h * 0.05),
      );
      canvas.drawRRect(r, green);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w * 0.22, height: h * 0.12),
          Radius.circular(h * 0.03),
        ),
        greenDark,
      );
      canvas.restore();
    }

    bill(w * 0.36, h * 0.30, -0.35);
    bill(w * 0.64, h * 0.28, 0.35);
    bill(w * 0.50, h * 0.24, 0);

    // Badan dompet oranye.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.42, w * 0.80, h * 0.46),
      Radius.circular(h * 0.13),
    );
    canvas.drawRRect(body, orange);

    // Tutup dompet sedikit lebih gelap supaya ada kedalaman.
    final flap = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.42, w * 0.80, h * 0.12),
      Radius.circular(h * 0.06),
    );
    canvas.drawRRect(flap, orangeDark);

    // Kancing dompet.
    canvas.drawCircle(Offset(w * 0.74, h * 0.66), h * 0.075, orangeDark);
    canvas.drawCircle(Offset(w * 0.74, h * 0.66), h * 0.035,
        Paint()..color = const Color(0xFFFFD60A));
  }

  @override
  bool shouldRepaint(covariant _CashflowPainter oldDelegate) => false;
}

/// Gedung bank putih-hijau (Kazz Tabungan).
class _TabunganPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final putih = Paint()..color = const Color(0xFFE8F5E9);
    final hijau = Paint()..color = const Color(0xFF34C759);
    final hijauTua = Paint()..color = const Color(0xFF1F9E43);

    // Atap segitiga (pedimen).
    final atap = Path()
      ..moveTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.92, h * 0.34)
      ..lineTo(w * 0.08, h * 0.34)
      ..close();
    canvas.drawPath(atap, hijau);

    // Balok di bawah atap.
    canvas.drawRect(
        Rect.fromLTWH(w * 0.06, h * 0.34, w * 0.88, h * 0.07), putih);

    // Empat tiang.
    for (var i = 0; i < 4; i++) {
      final x = w * (0.16 + i * 0.20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * 0.41, w * 0.12, h * 0.34),
          Radius.circular(w * 0.02),
        ),
        putih,
      );
    }

    // Alas / tangga.
    canvas.drawRect(Rect.fromLTWH(w * 0.06, h * 0.75, w * 0.88, h * 0.09), hijauTua);
    canvas.drawRect(Rect.fromLTWH(w * 0.02, h * 0.84, w * 0.96, h * 0.07), putih);

    // Puncak kecil di atas pedimen.
    canvas.drawCircle(Offset(w * 0.50, h * 0.12), h * 0.045, hijauTua);
  }

  @override
  bool shouldRepaint(covariant _TabunganPainter oldDelegate) => false;
}

/// Dua kartu bertumpuk, biru + kuning (Kartu Kredit).
class _KartuKreditPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;

    // Kartu belakang (kuning).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.30, w * 0.80, h * 0.50),
        Radius.circular(h * 0.10),
      ),
      Paint()..color = const Color(0xFFFFD60A),
    );

    // Kartu depan (biru).
    final depan = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.18, w * 0.80, h * 0.50),
      Radius.circular(h * 0.10),
    );
    canvas.drawRRect(depan, Paint()..color = const Color(0xFF0A84FF));
    canvas.drawRRect(
      depan,
      Paint()
        ..color = const Color(0xFF5AC8FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.035,
    );

    // Chip kartu.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.30, w * 0.20, h * 0.14),
        Radius.circular(h * 0.04),
      ),
      Paint()..color = const Color(0xFFB9E4FF),
    );

    // Garis strip.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.52, w * 0.46, h * 0.07),
        Radius.circular(h * 0.035),
      ),
      Paint()..color = const Color(0x99FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _KartuKreditPainter oldDelegate) => false;
}

/// Tumpukan koin emas dengan panah naik (Kazz Aset).
class _AsetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final emas = Paint()..color = const Color(0xFFFFD60A);
    final emasTua = Paint()..color = const Color(0xFFD4A017);
    final hijau = const Color(0xFF34C759);

    // Tumpukan koin di kiri bawah. Bagian bawah rata dengan ilustrasi lain
    // (y = 0.90) supaya sejajar saat dipasang berjajar.
    const kiri = 0.02, lebar = 0.50;
    const tinggiKoin = 0.16, langkah = 0.135, jumlahKoin = 4;

    for (var i = 0; i < jumlahKoin; i++) {
      final top = h * (0.90 - tinggiKoin - i * langkah);
      final x = w * kiri;
      final wKoin = w * lebar;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, wKoin, h * tinggiKoin),
          Radius.circular(h * 0.075),
        ),
        emas,
      );
      // Sisi atas koin lebih gelap supaya tumpukan terbaca.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, wKoin, h * 0.05),
          Radius.circular(h * 0.025),
        ),
        emasTua,
      );

      // Gerigi tepi kanan koin (ciri khas koin, bukan cakram biasa).
      final tepi = Paint()
        ..color = emasTua.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.012;
      for (var g = 1; g <= 2; g++) {
        final gx = x + wKoin - g * w * 0.03;
        canvas.drawLine(
            Offset(gx, top + h * 0.055), Offset(gx, top + h * tinggiKoin), tepi);
      }
    }

    // Muka koin paling atas: cincin dalam. Dipakai menggantikan tanda "$"
    // karena pada ukuran kartu (±40px) huruf sekecil itu tidak terbaca dan
    // hanya terlihat seperti noda.
    final topKoin = h * (0.90 - tinggiKoin - (jumlahKoin - 1) * langkah);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * (kiri + lebar / 2), topKoin + h * 0.09),
        width: w * 0.17,
        height: h * 0.085,
      ),
      Paint()
        ..color = emasTua.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.018,
    );

    // Panah naik keluar dari koin paling atas, lalu membelok ke kanan.
    // Pangkalnya menyentuh koin supaya terbaca satu kesatuan.
    final panah = Paint()
      ..color = hijau
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.062
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Batang tegak tepat di sumbu tumpukan koin supaya bobotnya seimbang.
    final pangkal = Offset(w * 0.27, topKoin + h * 0.02);
    final siku = Offset(w * 0.27, h * 0.15);
    final ujung = Offset(w * 0.78, h * 0.15);
    canvas.drawPath(
      Path()
        ..moveTo(pangkal.dx, pangkal.dy)
        ..lineTo(siku.dx, siku.dy)
        ..lineTo(ujung.dx, ujung.dy),
      panah,
    );

    // Mata panah menunjuk ke kanan, tepat di ujung garis.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.86, ujung.dy)
        ..lineTo(ujung.dx, ujung.dy - h * 0.12)
        ..lineTo(ujung.dx, ujung.dy + h * 0.12)
        ..close(),
      Paint()..color = hijau,
    );
  }

  @override
  bool shouldRepaint(covariant _AsetPainter oldDelegate) => false;
}
