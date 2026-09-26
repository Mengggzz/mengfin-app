/// Evaluator aritmatika untuk numpad kalkulator di layar input transaksi.
///
/// Kenapa ada: sebelumnya `_parseAmount()` di `transaction_input_screen.dart`
/// membuang SEMUA karakter non-angka, jadi pengguna yang mengetik "25 + 10"
/// menyimpan 2510 — bukan 35. Operan dan hasilnya jadi berbeda dari yang
/// dilihat pengguna. Di sini ekspresi benar-benar dihitung.
class AmountExpression {
  AmountExpression._();

  static const String kali = '×';
  static const String bagi = '÷';

  static bool isOperator(String s) =>
      s == '+' || s == '-' || s == kali || s == bagi;

  static final RegExp _token = RegExp(r'(\d+(?:\.\d+)?)|([+\-×÷])');
  static final RegExp _number = RegExp(r'\d+(?:\.\d+)?');

  /// Ekspresi diakhiri operator → masih menunggu angka berikutnya.
  static bool endsWithOperator(String expr) {
    final t = expr.trimRight();
    if (t.isEmpty) return false;
    return isOperator(t[t.length - 1]);
  }

  /// Buang operator yang menggantung di ujung ("25 + " → "25").
  /// Dipakai saat pengguna menekan operator lain sebelum angkanya masuk.
  static String stripTrailingOperator(String expr) {
    final t = expr.trimRight();
    if (t.isEmpty) return '';
    if (!isOperator(t[t.length - 1])) return t;
    return t.substring(0, t.length - 1).trimRight();
  }

  /// Isi input setelah menekan satu digit atau tombol "000".
  ///
  /// Digit selalu menempel apa adanya — kalkulator ini tidak mengubah
  /// ekspresi diam-diam; hitung dengan menekan "=".
  static String appendDigits(String expr, String digits) {
    // "000" tidak boleh menempel di belakang operator atau di depan nol.
    if (digits == '000') {
      if (expr.isEmpty || expr == '0' || endsWithOperator(expr)) {
        return expr.isEmpty ? '0' : expr;
      }
    }
    final dasar = expr == '0' ? '' : expr;
    return '$dasar$digits';
  }

  /// Ada operator sama sekali? (dipakai untuk membedakan "25000" dari "25 + 10")
  static bool hasOperator(String expr) =>
      _token.allMatches(expr).any((m) => m.group(1) == null);

  /// Angka terakhir yang diketik — dipakai saat ekspresi belum lengkap
  /// supaya layar tetap menampilkan sesuatu yang masuk akal.
  static double? lastNumber(String expr) {
    double? terakhir;
    for (final m in _number.allMatches(expr)) {
      terakhir = double.tryParse(m.group(0)!);
    }
    return terakhir;
  }

  /// Hitung ekspresi. Kembalikan null kalau ekspresi belum/tidak sah:
  /// berakhir operator, ada karakter asing, atau pembagian dengan nol.
  /// Prioritas mengikuti kalkulator biasa: × dan ÷ lebih dulu dari + dan -.
  static double? evaluate(String expr) {
    final s = expr.trim();
    if (s.isEmpty) return null;

    final tokens = <String>[];
    var pos = 0;
    for (final m in _token.allMatches(s)) {
      // Jarak antar token boleh spasi (numpad menulis "25 + 10"), tapi
      // karakter lain berarti ekspresi tidak sah.
      if (s.substring(pos, m.start).trim().isNotEmpty) return null;
      tokens.add(m.group(0)!);
      pos = m.end;
    }
    if (s.substring(pos).trim().isNotEmpty) return null;
    // Harus berpola angka (operator angka)* → jumlah token ganjil.
    if (tokens.isEmpty || tokens.length.isEven) return null;

    // Token pertama harus angka (ekspresi seperti "+" atau "× 5" tidak sah).
    final pertama = double.tryParse(tokens.first);
    if (pertama == null) return null;
    final angka = <double>[pertama];
    final ops = <String>[];
    for (var i = 1; i < tokens.length; i += 2) {
      final op = tokens[i];
      final n = double.tryParse(tokens[i + 1]);
      if (n == null) return null;
      if (op == kali || op == bagi) {
        if (op == bagi && n == 0) return null;
        final prev = angka.removeLast();
        angka.add(op == kali ? prev * n : prev / n);
      } else {
        ops.add(op);
        angka.add(n);
      }
    }

    var hasil = angka.first;
    for (var i = 0; i < ops.length; i++) {
      hasil = ops[i] == '+' ? hasil + angka[i + 1] : hasil - angka[i + 1];
    }
    if (!hasil.isFinite) return null;
    return hasil;
  }

  /// Jadikan hasil hitung sebagai isi input baru ("35", "12.5").
  static String formatNumber(double v) {
    if (!v.isFinite) return '0';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
