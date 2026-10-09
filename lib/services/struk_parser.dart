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

    // 1. Items
    final items = _extractItems(lines);

    // 2. Deskripsi (Nama Toko)
    final storeResult = _extractNamaToko(lines);
    final deskripsi = storeResult.deskripsi;
    final bool garbledStore = storeResult.garbled;

    // 3. Tanggal
    final dateResult = _extractTanggalWithStatus(cleanText);
    final tanggal = dateResult.tanggal;
    final bool implausibleDate = dateResult.implausible;

    // 4. Metode Pembayaran
    final metode = _extractMetode(cleanText);

    // 5. Kategori
    final kategori = _guessKategori(cleanText);

    // 6. Nominal & Confidence
    final nominalResult = _extractNominal(
      lines,
      items: items,
      implausibleDate: implausibleDate,
      garbledStore: garbledStore,
    );
    final int nominal = nominalResult.nominal;
    final double confidence = nominalResult.confidence;

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

  static ({String deskripsi, bool garbled}) _extractNamaToko(List<String> lines) {
    final storeKeywords = RegExp(
      r'\b(pt|cv|toko|mart|shop|store|indomaret|alfamart|supermarket|minimarket|warung|cafe|kafe|resto|apotek)\b',
      caseSensitive: false,
    );

    // 1. Prioritaskan baris dengan keyword toko di 6 baris pertama
    for (int i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      if (_isValidStoreLine(line) && storeKeywords.hasMatch(line)) {
        return (deskripsi: line, garbled: false);
      }
    }

    // 2. Ambil baris pertama yang memenuhi kualifikasi huruf (>= 30% huruf)
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      if (_isValidStoreLine(line)) {
        return (deskripsi: line, garbled: false);
      }
    }

    return (deskripsi: 'Struk Pembelian', garbled: true);
  }

  static bool _isValidStoreLine(String line) {
    if (line.length <= 2) return false;
    if (_isMostlyNumbersOrDate(line)) return false;
    final letterCount = line.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    // Lewati baris yang < 30% huruf (bleed-through/noise)
    if (letterCount / line.length < 0.3) return false;
    // Abaikan jika baris kontak atau TRXID QR
    if (RegExp(r'\b(sms|wa|telp|teca|trxid)\b', caseSensitive: false).hasMatch(line)) return false;
    return true;
  }

  static ({String tanggal, bool implausible}) _extractTanggalWithStatus(String text) {
    final now = DateTime.now();
    final currentYear = now.year;
    final match = RegExp(r'(?<![A-Za-z0-9])(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})(?![A-Za-z0-9])').firstMatch(text);
    if (match != null) {
      int d = int.tryParse(match.group(1) ?? '') ?? 1;
      int m = int.tryParse(match.group(2) ?? '') ?? 1;
      int y = int.tryParse(match.group(3) ?? '') ?? currentYear;
      if (y < 100) y += 2000;
      if (m > 12 && d <= 12) {
        final temp = d;
        d = m;
        m = temp;
      }
      final bool validRange = (d >= 1 && d <= 31) && (m >= 1 && m <= 12);
      final bool validYear = (y >= currentYear - 1 && y <= currentYear);

      if (validRange && validYear) {
        final formatted = '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        return (tanggal: formatted, implausible: false);
      } else {
        return (tanggal: _todayDate(), implausible: true);
      }
    }
    return (tanggal: _todayDate(), implausible: false);
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

  static ({int nominal, double confidence}) _extractNominal(
    List<String> lines, {
    required List<Map<String, dynamic>> items,
    required bool implausibleDate,
    required bool garbledStore,
  }) {
    final totalKeywords = RegExp(
      r'\b(grand\s*total|total\s*bayar|jumlah\s*bayar|total\s*belanja|total|tagihan|net\s*total)\b',
      caseSensitive: false,
    );

    int foundNominal = 0;
    bool keywordFound = false;
    int totalKeywordLineIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (totalKeywords.hasMatch(line)) {
        keywordFound = true;
        totalKeywordLineIdx = i;
        final sameLineNums = _parseNumbersFromLine(line);
        if (sameLineNums.isNotEmpty) {
          foundNominal = sameLineNums.last;
          break;
        }
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

    double confidence = 0.85;

    if (!keywordFound || foundNominal <= 0) {
      // Fallback: periksa angka di dekat keyword total (±3 baris)
      if (totalKeywordLineIdx >= 0) {
        for (int offset = -3; offset <= 3; offset++) {
          final idx = totalKeywordLineIdx + offset;
          if (idx >= 0 && idx < lines.length && idx != totalKeywordLineIdx) {
            final nums = _parseNumbersFromLine(lines[idx]);
            if (nums.isNotEmpty && nums.last > foundNominal) {
              foundNominal = nums.last;
            }
          }
        }
      }

      // Jika masih belum ketemu, cari hanya dari baris ber-prefix Rp/RP
      if (foundNominal <= 0) {
        for (final line in lines) {
          if (RegExp(r'\brp\.?\s*\d', caseSensitive: false).hasMatch(line)) {
            final nums = _parseNumbersFromLine(line);
            for (final n in nums) {
              if (n > foundNominal) foundNominal = n;
            }
          }
        }
      }

      if (foundNominal > 0) {
        confidence = 0.5;
      } else {
        return (nominal: 0, confidence: 0.3);
      }
    }

    // ── Kalibrasi Confidence ───────────────────────────────────────────────
    final itemsTotal = items.fold<int>(0, (sum, it) => sum + ((it['harga'] as num?)?.toInt() ?? 0));

    if (items.isEmpty) {
      confidence -= 0.1;
    } else if (itemsTotal > 0) {
      if (foundNominal > 10 * itemsTotal || itemsTotal > (foundNominal * 1.5)) {
        confidence -= 0.3;
      } else if ((foundNominal - itemsTotal).abs() <= (foundNominal * 0.05)) {
        // Total sangat konsisten dengan sum items -> bonus confidence
        confidence += 0.15;
      }
    }

    if (implausibleDate) {
      confidence -= 0.1;
    }

    if (garbledStore) {
      confidence -= 0.1;
    }

    // Sanity nominal: nominal >= 100 juta (9 digit) atau > 1 miliar
    if (foundNominal >= 100000000) {
      confidence = confidence.clamp(0.0, 0.4);
    }

    confidence = confidence.clamp(0.3, 1.0);
    return (nominal: foundNominal, confidence: double.parse(confidence.toStringAsFixed(2)));
  }

  static List<int> _parseNumbersFromLine(String line) {
    final list = <int>[];

    // Abaikan nomor telepon / baris kontak (SMS, WA, Telp, HP)
    final isContactLine = RegExp(
      r'\b(sms|wa|whatsapp|telp|telepon|phone|call|hotline|cs|kontak)\b',
      caseSensitive: false,
    ).hasMatch(line);

    // Regex pola angka dengan word boundary lookaround
    final pattern = RegExp(
      r'(?<![A-Za-z0-9])(?:rp\.?\s*)?(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{4,9})(?![A-Za-z0-9])',
      caseSensitive: false,
    );

    final matches = pattern.allMatches(line);
    for (final m in matches) {
      String raw = m.group(1) ?? '';

      // Abaikan nomor telepon (diawali 08 atau di baris kontak)
      if (raw.startsWith('08') || (isContactLine && raw.length >= 7)) {
        continue;
      }

      // Cek prefix sebelum match
      final startIdx = m.start;
      if (startIdx >= 2) {
        final prefix = line.substring(0, startIdx).trimRight();
        if (prefix.endsWith('08') || prefix.endsWith('+62') || prefix.endsWith('62')) {
          continue;
        }
      }

      // Format koma / titik
      if (raw.contains('.') && raw.contains(',')) {
        final lastDot = raw.lastIndexOf('.');
        final lastComma = raw.lastIndexOf(',');
        if (lastComma > lastDot) {
          // 1.500.000,00 -> buang desimal
          raw = raw.substring(0, lastComma).replaceAll('.', '');
        } else {
          // 1,500,000.00 -> buang desimal
          raw = raw.substring(0, lastDot).replaceAll(',', '');
        }
      } else if (raw.contains(',')) {
        final parts = raw.split(',');
        if (parts.length > 1 && parts.last.length == 3) {
          // Koma ribuan: 27,000 atau 1,250,000
          raw = raw.replaceAll(',', '');
        } else if (parts.length > 1 && parts.last.length <= 2) {
          // Koma desimal: 27,50
          raw = parts.first.replaceAll(',', '');
        } else {
          raw = raw.replaceAll(',', '');
        }
      } else if (raw.contains('.')) {
        final parts = raw.split('.');
        if (parts.length > 1 && parts.last.length <= 2) {
          raw = parts.first.replaceAll('.', '');
        } else {
          raw = raw.replaceAll('.', '');
        }
      }

      final val = int.tryParse(raw);
      if (val != null && val > 0 && !raw.startsWith('08')) {
        list.add(val);
      }
    }
    return list;
  }

  static List<Map<String, dynamic>> _extractItems(List<String> lines) {
    final items = <Map<String, dynamic>>[];
    final contactPattern = RegExp(
      r'\b(sms|wa|whatsapp|telp|telepon|phone|call|hotline|cs|kontak)\b',
      caseSensitive: false,
    );

    final itemPattern = RegExp(
      r'^(?![0-9\s\.\-_/]+$)([A-Za-z0-9\s\.\-_/]+?)\s+(?:rp\.?\s*)?(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{4,8})$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (contactPattern.hasMatch(line)) continue;

      final match = itemPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)?.trim() ?? '';
        final rawPrice = match.group(2) ?? '';

        if (name.startsWith('08') || name.contains(RegExp(r'\b08\d{2}'))) continue;

        final nums = _parseNumbersFromLine(rawPrice);
        final price = nums.isNotEmpty ? nums.first : 0;

        final lowerName = name.toLowerCase();
        if (name.length > 2 &&
            price > 0 &&
            !lowerName.contains('total') &&
            !lowerName.contains('tunai') &&
            !lowerName.contains('kembali') &&
            !lowerName.contains('non tunai') &&
            !lowerName.contains('debit') &&
            !lowerName.contains('subtotal') &&
            !lowerName.contains('kembalian')) {
          items.add({'nama': name, 'harga': price});
        }
      }
    }
    return items;
  }
}
