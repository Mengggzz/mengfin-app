import 'package:csv/csv.dart';
import 'kategori_otomatis.dart';

class CsvImportService {
  /// Parse isi CSV mutasi bank / e-wallet dan ekstrak menjadi data transaksi standar.
  static List<Map<String, dynamic>> parseCsvContent(String rawCsv) {
    final clean = rawCsv.trim();
    if (clean.isEmpty) return [];

    // Normalisasi baris baru
    final normalized = clean.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawRows = Csv().decode(normalized);

    if (rawRows.length < 2) return [];

    // Deteksi baris header
    final headerRow = rawRows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    int dateCol = -1;
    int descCol = -1;
    int amountCol = -1;
    int debitCol = -1;
    int creditCol = -1;

    for (int i = 0; i < headerRow.length; i++) {
      final h = headerRow[i];
      if (RegExp(r'\b(tgl|tanggal|date|waktu)\b').hasMatch(h)) {
        if (dateCol == -1) dateCol = i;
      } else if (RegExp(r'\b(keterangan|uraian|deskripsi|description|narasi|transaksi|memo)\b').hasMatch(h)) {
        if (descCol == -1) descCol = i;
      } else if (RegExp(r'\b(debit|debet|keluar|out)\b').hasMatch(h)) {
        debitCol = i;
      } else if (RegExp(r'\b(kredit|credit|masuk|in)\b').hasMatch(h)) {
        creditCol = i;
      } else if (RegExp(r'\b(nominal|jumlah|amount|total)\b').hasMatch(h)) {
        if (amountCol == -1) amountCol = i;
      }
    }

    // Fallbacks jika nama kolom tidak standar
    if (dateCol == -1) dateCol = 0;
    if (descCol == -1) descCol = headerRow.length > 1 ? 1 : 0;

    final results = <Map<String, dynamic>>[];

    for (int r = 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

      final dateStr = dateCol < row.length ? row[dateCol].toString().trim() : '';
      final descStr = descCol < row.length ? row[descCol].toString().trim() : 'Transaksi Mutasi';

      final tanggal = _formatTanggal(dateStr);

      double nominal = 0;
      String jenis = 'pengeluaran';

      if (debitCol != -1 || creditCol != -1) {
        final debitVal = debitCol != -1 && debitCol < row.length ? _parseAmount(row[debitCol].toString()) : 0.0;
        final creditVal = creditCol != -1 && creditCol < row.length ? _parseAmount(row[creditCol].toString()) : 0.0;

        if (creditVal > 0) {
          nominal = creditVal;
          jenis = 'pemasukan';
        } else if (debitVal > 0) {
          nominal = debitVal;
          jenis = 'pengeluaran';
        }
      } else if (amountCol != -1 && amountCol < row.length) {
        final rawVal = row[amountCol].toString().trim();
        final isNegative = rawVal.startsWith('-') || rawVal.contains('DB') || rawVal.toLowerCase().contains('dr');
        final isPositive = rawVal.contains('CR') || rawVal.toLowerCase().contains('cr');
        final parsed = _parseAmount(rawVal);

        nominal = parsed.abs();
        if (isPositive) {
          jenis = 'pemasukan';
        } else if (isNegative) {
          jenis = 'pengeluaran';
        } else {
          // Asumsi default dari deskripsi
          jenis = _guessJenisFromDesc(descStr);
        }
      }

      if (nominal > 0) {
        final kategori = KategoriOtomatis.tebakKamus(descStr);
        results.add({
          'tanggal': tanggal,
          'deskripsi': descStr.isNotEmpty ? descStr : 'Transaksi Mutasi',
          'nominal': nominal,
          'jenis': jenis,
          'kategori': kategori,
          'metode_pembayaran': 'transfer',
        });
      }
    }

    return results;
  }

  static double _parseAmount(String text) {
    if (text.isEmpty) return 0.0;
    var clean = text.replaceAll(RegExp(r'[^\d.,\-]'), '').trim();
    if (clean.isEmpty || clean == '-') return 0.0;

    // Deteksi pemisah ribuan vs desimal (e.g. 500.000,00 vs 500,000.00)
    if (clean.contains('.') && clean.contains(',')) {
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        // Format Indonesia: 500.000,00
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Format US: 500,000.00
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains('.')) {
      // 50.000 atau 50.5
      final parts = clean.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        clean = clean.replaceAll('.', '');
      }
    } else if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        clean = clean.replaceAll(',', '');
      } else {
        clean = clean.replaceAll(',', '.');
      }
    }

    return double.tryParse(clean) ?? 0.0;
  }

  static String _formatTanggal(String raw) {
    final match = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b').firstMatch(raw);
    if (match != null) {
      int d = int.tryParse(match.group(1) ?? '') ?? 1;
      int m = int.tryParse(match.group(2) ?? '') ?? 1;
      int y = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
      if (y < 100) y += 2000;
      if (m > 12 && d <= 12) {
        final temp = d;
        d = m;
        m = temp;
      }
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _guessJenisFromDesc(String desc) {
    final lower = desc.toLowerCase();
    if (RegExp(r'\b(gaji|gajian|terima|masuk|setor|transfer dari|topup|top up)\b').hasMatch(lower)) {
      return 'pemasukan';
    }
    return 'pengeluaran';
  }
}
