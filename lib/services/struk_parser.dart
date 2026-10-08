class StrukParser {
  static Map<String, dynamic> parse(String fullText) {
    final cleanText = fullText.trim();
    if (cleanText.isEmpty) {
      return {
        'jenis': 'pengeluaran',
        'nominal': 0,
        'kategori': 'Lainnya',
        'deskripsi': 'Struk Pembelian',
        'tanggal': _todayDate(),
        'metode_pembayaran': 'tunai',
        'items': <Map<String, dynamic>>[],
        'confidence': 0.3,
        'sumber': 'lokal',
      };
    }

    final lines = cleanText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return {
        'jenis': 'pengeluaran',
        'nominal': 0,
        'kategori': 'Lainnya',
        'deskripsi': 'Struk Pembelian',
        'tanggal': _todayDate(),
        'metode_pembayaran': 'tunai',
        'items': <Map<String, dynamic>>[],
        'confidence': 0.3,
        'sumber': 'lokal',
      };
    }

    // 1. Deskripsi (Nama Toko)
    String deskripsi = 'Struk Pembelian';
    for (int i = 0; i < lines.length && i < 3; i++) {
      final line = lines[i];
      if (!_isMostlyNumbersOrDate(line) && line.length > 2) {
        deskripsi = line;
        break;
      }
    }

    // 2. Tanggal
    String tanggal = _extractTanggal(cleanText) ?? _todayDate();

    // 3. Metode Pembayaran
    String metode = _extractMetode(cleanText);

    // 4. Kategori
    String kategori = _guessKategori(cleanText);

    // 5. Nominal & Confidence
    final nominalResult = _extractNominal(lines);
    final int nominal = nominalResult.nominal;
    final double confidence = nominalResult.confidence;

    // 6. Items
    final items = _extractItems(lines);

    return {
      'jenis': 'pengeluaran',
      'nominal': nominal,
      'kategori': kategori,
      'deskripsi': deskripsi,
      'tanggal': tanggal,
      'metode_pembayaran': metode,
      'items': items,
      'confidence': confidence,
      'sumber': 'lokal',
    };
  }

  static String _todayDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool _isMostlyNumbersOrDate(String line) {
    final digits = line.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= line.length * 0.6) return true;
    if (RegExp(r'\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}').hasMatch(line)) return true;
    return false;
  }

  static String? _extractTanggal(String text) {
    final match = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b').firstMatch(text);
    if (match != null) {
      int d = int.tryParse(match.group(1) ?? '') ?? 1;
      int m = int.tryParse(match.group(2) ?? '') ?? 1;
      int y = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
      if (y < 100) y += 2000;
      if (m > 12 && d <= 12) {
        // Swap month and day if month > 12 (e.g. MM/DD/YYYY)
        final temp = d;
        d = m;
        m = temp;
      }
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    }
    return null;
  }

  static String _extractMetode(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('qris') || lower.contains('qr code')) return 'qris';
    if (lower.contains('debit') || lower.contains('kartu debit')) return 'debit';
    if (lower.contains('kredit') || lower.contains('credit card') || lower.contains('cc')) return 'kredit';
    if (lower.contains('transfer') || lower.contains('gopay') || lower.contains('ovo') || lower.contains('dana') || lower.contains('shopeepay')) {
      return 'transfer';
    }
    return 'tunai';
  }

  static String _guessKategori(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'\b(indomaret|alfamart|supermarket|minimarket|mall|toko|shopee|tokopedia|hypermart|superindo)\b').hasMatch(lower)) {
      return 'Belanja';
    }
    if (RegExp(r'\b(warung|makan|resto|restoran|cafe|kafe|kopi|coffee|nasi|mie|bakso|ayam|roti|dapur|kitchen)\b').hasMatch(lower)) {
      return 'Makan & Minum';
    }
    if (RegExp(r'\b(apotek|farma|obat|dokter|klinik|hospital|rs|kesehatan|vitamin)\b').hasMatch(lower)) {
      return 'Kesehatan';
    }
    if (RegExp(r'\b(spbu|pertamina|shell|bensin|bbm|pertalite|pertamax|parkir|tol|ojol|gojek|grab|taxi|transport)\b').hasMatch(lower)) {
      return 'Transportasi';
    }
    if (RegExp(r'\b(pln|listrik|pdam|air|pulsa|kuota|telkom|wifi|indihome|tagihan)\b').hasMatch(lower)) {
      return 'Tagihan';
    }
    if (RegExp(r'\b(bioskop|cinema|xxi|game|steam|hiburan)\b').hasMatch(lower)) {
      return 'Hiburan';
    }
    return 'Lainnya';
  }

  static ({int nominal, double confidence}) _extractNominal(List<String> lines) {
    final totalKeywords = RegExp(
      r'\b(grand\s*total|total\s*bayar|jumlah\s*bayar|total\s*belanja|total|tagihan|net\s*total)\b',
      caseSensitive: false,
    );

    int foundNominal = 0;
    bool keywordFound = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (totalKeywords.hasMatch(line)) {
        keywordFound = true;
        // Check if current line itself has a number
        final sameLineNums = _parseNumbersFromLine(line);
        if (sameLineNums.isNotEmpty) {
          foundNominal = sameLineNums.last; // usually the amount on total line
          break;
        }
        // If not on same line, check next 1-2 lines (excluding payment/change lines)
        for (int offset = 1; offset <= 2; offset++) {
          final idx = i + offset;
          if (idx < lines.length) {
            final nextLine = lines[idx];
            final lower = nextLine.toLowerCase();
            if (lower.startsWith('tunai') || lower.startsWith('cash') || lower.startsWith('kembali') || lower.startsWith('change')) {
              continue;
            }
            final nums = _parseNumbersFromLine(nextLine);
            if (nums.isNotEmpty) {
              foundNominal = nums.last;
              break;
            }
          }
        }
        if (foundNominal > 0) break;
      }
    }

    if (keywordFound && foundNominal > 0) {
      return (nominal: foundNominal, confidence: 1.0);
    }

    // Fallback: pick the largest reasonable number in entire text
    final allNumbers = <int>[];
    for (final line in lines) {
      allNumbers.addAll(_parseNumbersFromLine(line));
    }

    if (allNumbers.isNotEmpty) {
      final maxVal = allNumbers.reduce((a, b) => a > b ? a : b);
      if (maxVal >= 100) {
        return (nominal: maxVal, confidence: 0.6);
      }
    }

    return (nominal: 0, confidence: 0.3);
  }

  static List<int> _parseNumbersFromLine(String line) {
    final list = <int>[];
    // Match patterns like Rp 57.500, 1.500.000, 25000, 35.000,00
    final matches = RegExp(r'(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d{4,9})', caseSensitive: false).allMatches(line);
    for (final m in matches) {
      String raw = m.group(1) ?? '';
      // Remove decimals if any (e.g. ,00)
      if (raw.contains(',')) {
        raw = raw.split(',').first;
      }
      raw = raw.replaceAll('.', '').trim();
      final val = int.tryParse(raw);
      if (val != null && val > 0) {
        list.add(val);
      }
    }
    return list;
  }

  static List<Map<String, dynamic>> _extractItems(List<String> lines) {
    final items = <Map<String, dynamic>>[];
    final itemPattern = RegExp(r'^([A-Za-z0-9\s\.\-_/]+?)\s+(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d{4,8})$', caseSensitive: false);

    for (final line in lines) {
      final match = itemPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)?.trim() ?? '';
        final priceStr = (match.group(2) ?? '').replaceAll('.', '');
        final price = int.tryParse(priceStr) ?? 0;
        if (name.length > 2 && price > 0 && !name.toLowerCase().contains('total') && !name.toLowerCase().contains('tunai') && !name.toLowerCase().contains('kembali')) {
          items.add({'nama': name, 'harga': price});
        }
      }
    }
    return items;
  }
}
