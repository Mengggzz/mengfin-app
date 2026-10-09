import '../models/models.dart';
import '../constants/utils.dart';
import 'stemmer_id.dart';

/// Tebak kategori transaksi dari riwayat pengguna dan kamus kata kunci cerdas.
class KategoriOtomatis {
  KategoriOtomatis._();

  static const int _maksHari = 30;
  static const int _minKata = 3;

  /// Tebak kategori untuk [deskripsi].
  ///
  /// [riwayat] jika diberikan akan diprioritaskan dari yang paling baru.
  /// [gunakanKamus] jika true akan mencocokkan dengan kamus kata kunci otomatis.
  static String? tebak({
    required String deskripsi,
    List<Transaksi>? riwayat,
    bool gunakanKamus = false,
    bool isExpense = true,
  }) {
    final teks = deskripsi.trim().toLowerCase();
    if (teks.isEmpty) return null;

    // 1. Coba cocokkan dari riwayat transaksi terdahulu (maks 30 hari)
    if (riwayat != null && riwayat.isNotEmpty) {
      final kataKunci = _kataPenting(teks);
      if (kataKunci.isNotEmpty) {
        final batas = DateTime.now().subtract(const Duration(days: _maksHari));

        for (final tx in riwayat) {
          final tgl = DateTime.tryParse(tx.tanggal);
          if (tgl == null || tgl.isBefore(batas)) continue;

          final riwayatTeks = tx.deskripsi.trim().toLowerCase();
          if (riwayatTeks.isEmpty) continue;

          if (_cocok(teks, riwayatTeks, kataKunci)) {
            return tx.kategori;
          }
        }
      }
    }

    // 2. Jika gunakanKamus aktif, tebak berdasarkan kamus kata kunci bawaan
    if (gunakanKamus) {
      return tebakKamus(teks, isExpense: isExpense);
    }

    return null;
  }

  /// Tebak kategori dari kamus kata kunci Indonesia & istilah umum.
  /// Urutan cek pengeluaran: Makan & Minum -> Transportasi -> Tagihan ->
  /// Belanja -> Hiburan -> Kesehatan -> Pendidikan -> Kerja -> Sosial.
  static String? tebakKamus(String deskripsi, {bool isExpense = true}) {
    final teks = deskripsi.trim().toLowerCase();
    if (teks.isEmpty) return null;

    if (!isExpense) {
      // Pass 1: Multi-kata
      if (_matchesMultiKata(teks, _kGaji)) return 'Gaji';
      if (_matchesMultiKata(teks, _kBonus)) return 'Bonus';
      if (_matchesMultiKata(teks, _kInvestasi)) return 'Investasi';
      if (_matchesMultiKata(teks, _kTransfer)) return 'Transfer';

      // Pass 2: Kata tunggal & stem
      if (_matches(teks, _kGaji)) return 'Gaji';
      if (_matches(teks, _kBonus)) return 'Bonus';
      if (_matches(teks, _kInvestasi)) return 'Investasi';
      if (_matches(teks, _kTransfer)) return 'Transfer';
      return 'Lainnya';
    }

    // Pass 1: Multi-kata > kata tunggal (prioritas multi-kata untuk menghindari ambiguitas)
    if (_matchesMultiKata(teks, _kMakanMinum)) return 'Makan & Minum';
    if (_matchesMultiKata(teks, _kTransportasi)) return 'Transportasi';
    if (_matchesMultiKata(teks, _kTagihan)) return 'Tagihan';
    if (_matchesMultiKata(teks, _kBelanja)) return 'Belanja';
    if (_matchesMultiKata(teks, _kHiburan)) return 'Hiburan';
    if (_matchesMultiKata(teks, _kKesehatan)) return 'Kesehatan';
    if (_matchesMultiKata(teks, _kPendidikan)) return 'Pendidikan';
    if (_matchesMultiKata(teks, _kKerja)) return 'Kerja';
    if (_matchesMultiKata(teks, _kSosial)) return 'Sosial';

    // Pass 2: Kata tunggal & varian stem
    if (_matches(teks, _kMakanMinum)) return 'Makan & Minum';
    if (_matches(teks, _kTransportasi)) return 'Transportasi';
    if (_matches(teks, _kTagihan)) return 'Tagihan';
    if (_matches(teks, _kBelanja)) return 'Belanja';
    if (_matches(teks, _kHiburan)) return 'Hiburan';
    if (_matches(teks, _kKesehatan)) return 'Kesehatan';
    if (_matches(teks, _kPendidikan)) return 'Pendidikan';
    if (_matches(teks, _kKerja)) return 'Kerja';
    if (_matches(teks, _kSosial)) return 'Sosial';

    return null;
  }

  /// Tebak tipe transaksi (Need, Want, Saving).
  static TransactionType? tebakTipe({
    required String deskripsi,
    required String kategori,
    List<Transaksi>? riwayat,
    bool isExpense = true,
  }) {
    if (!isExpense) {
      if (kategori.toLowerCase() == 'investasi') return TransactionType.saving;
      return null;
    }

    final teks = deskripsi.trim().toLowerCase();

    // 1. Cek override kata kunci spesifik
    if (kategori == 'Makan & Minum') {
      if (_matches(teks, _kMakanWant)) return TransactionType.want;
      return TransactionType.need;
    }

    if (kategori == 'Belanja') {
      if (_matches(teks, _kBelanjaNeed)) return TransactionType.need;
      return TransactionType.want;
    }

    if (kategori == 'Transportasi') {
      if (_matches(teks, _kTransportWant)) return TransactionType.want;
      return TransactionType.need;
    }

    // 2. Default per kategori
    switch (kategori) {
      case 'Tagihan':
      case 'Kesehatan':
      case 'Pendidikan':
      case 'Kerja':
      case 'Sosial':
        return TransactionType.need;
      case 'Hiburan':
        return TransactionType.want;
      default:
        return TransactionType.need;
    }
  }

  static bool _matchesMultiKata(String teks, List<String> keywords) {
    for (final kw in keywords) {
      if (kw.contains(' ') && (teks == kw || teks.contains(kw))) {
        return true;
      }
    }
    return false;
  }

  static bool _matches(String teks, List<String> keywords) {
    // 1. Cek langsung teks atau multi-kata substring
    for (final kw in keywords) {
      if (teks == kw || teks.contains(kw)) return true;
    }
    // 2. Tokenisasi per kata dan cek varian stem
    final words = teks.split(RegExp(r'\s+'));
    for (final w in words) {
      if (w.isEmpty) continue;
      final varian = StemmerId.varian(w);
      for (final v in varian) {
        for (final kw in keywords) {
          if (v == kw) return true;
        }
      }
    }
    return false;
  }

  static List<String> _kataPenting(String teks) {
    final kata = teks.split(RegExp(r'\s+'));
    final result = <String>{};
    for (final k in kata) {
      if (k.length >= _minKata && !_stopWords.contains(k)) {
        result.add(k);
        for (final v in StemmerId.varian(k)) {
          if (v.length >= _minKata && !_stopWords.contains(v)) {
            result.add(v);
          }
        }
      }
    }
    return result.toList();
  }

  static bool _cocok(String a, String b, List<String> kataKunci) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    final kataB = _kataPenting(b).toSet();
    for (final k in kataKunci) {
      if (kataB.contains(k)) return true;
    }
    return false;
  }

  static const Set<String> _stopWords = {
    'dan', 'atau', 'untuk', 'dari', 'ke', 'di', 'yang', 'ini', 'itu',
    'saya', 'kamu', 'dia', 'ada', 'tidak', 'juga', 'sudah', 'belum',
    'beli', 'belanja', 'bayar', 'tebus',
  };

  // ── Kamus Kata Kunci Komprehensif ──────────────────────────────────────────

  // PENGELUARAN: Makan & Minum
  static const List<String> _kMakanMinum = [
    'makan', 'makanan', 'kuliner', 'sarapan', 'makan siang', 'makan malam', 'brunch',
    'nasi goreng', 'nasi padang', 'nasi uduk', 'nasi kuning', 'nasi liwet', 'nasi pecel',
    'nasi campur', 'nasi box', 'nasi bungkus', 'nasi bakar',
    'ayam goreng', 'ayam bakar', 'ayam geprek', 'ayam penyet', 'ayam pop', 'ayam kecap',
    'lele', 'nila', 'gurame', 'bandeng', 'tongkol', 'tuna', 'salmon', 'cumi', 'udang', 'kepiting',
    'rajungan', 'kerang', 'soto', 'soto ayam', 'soto betawi', 'soto mie', 'rawon', 'gudeg',
    'rendang', 'opor', 'sayur asem', 'lodeh', 'capcay', 'fuyunghai',
    'kwetiau', 'bihun', 'misoa', 'ramen', 'udon',
    'sushi', 'sashimi', 'dimsum', 'dumpling', 'gyoza',
    'kebab', 'shawarma', 'burger', 'pizza', 'pasta', 'spaghetti', 'carbonara', 'bolognese',
    'steak', 'hotdog', 'sandwich', 'kentang goreng',
    'sop buntut', 'sop iga', 'bakmoy', 'timlo', 'saksang', 'empal', 'dendeng', 'abon', 'tongseng',
    'mie', 'mie ayam', 'bakmie', 'bakmi', 'mie goreng', 'mie rebus', 'indomie', 'sedaap',
    'sarimi', 'supermie', 'lemonilo', 'bakso', 'bakso urat', 'bakso malang',
    'sate', 'sate ayam', 'sate kambing', 'sate padang', 'sate taichan', 'sate lilit',
    'jajan', 'jajanan', 'cemilan', 'camilan', 'snack',
    'kue', 'roti', 'bolu', 'brownies', 'donat', 'kue cubit', 'kue lumpur', 'bika ambon',
    'kue lapis', 'lapis', 'putu', 'klepon', 'onde-onde', 'getuk', 'cenil', 'nagasari',
    'serabi', 'pukis', 'pancong', 'bandros', 'martabak', 'terang bulan',
    'cilok', 'cilor', 'cireng', 'cimol', 'batagor', 'siomay', 'somay', 'pempek', 'mpek-mpek',
    'seblak', 'gorengan', 'bala-bala', 'combro', 'misro', 'pisang goreng', 'pisang molen',
    'tahu goreng', 'tempe goreng', 'tahu isi', 'bakwan', 'perkedel', 'kroket', 'lumpia',
    'risoles', 'pastel', 'lemper', 'arem-arem', 'tahu bulat', 'telur gulung', 'sempol',
    'pentol', 'cilung', 'cakwe', 'odading', 'roti goreng',
    'es krim', 'ice cream', 'puding', 'agar-agar',
    'buah', 'apel', 'jeruk', 'pisang', 'mangga', 'anggur', 'semangka', 'melon', 'pepaya', 'nanas',
    'alpukat', 'durian', 'rambutan', 'kelengkeng', 'salak', 'duku', 'manggis', 'sirsak',
    'belimbing', 'kedondong', 'strawberry', 'stroberi', 'blueberry', 'kiwi', 'pir', 'leci',
    'rujak', 'asinan', 'manisan', 'sop buah', 'es buah', 'es teler', 'es campur', 'salad buah',
    'petis', 'lalapan',
    'minum', 'minuman', 'kopi', 'coffee', 'espresso', 'latte', 'cappuccino', 'americano',
    'kopi tubruk', 'kopi susu', 'vietnam drip', 'cold brew',
    'teh', 'es teh', 'teh manis', 'teh botol', 'teh pucuk', 'thai tea', 'matcha', 'green tea',
    'boba', 'bubble tea', 'jus', 'juice', 'smoothie', 'milkshake', 'soda',
    'susu', 'susu kedelai', 'susu jahe', 'yogurt', 'yakult',
    'air mineral', 'air minum', 'aqua', 'le minerale', 'ades', 'pristine',
    'wedang jahe', 'wedang ronde', 'wedang uwuh', 'bir pletok', 'bajigur', 'bandrek',
    'sekoteng', 'stmj', 'sarabba', 'es jeruk', 'es kelapa', 'es dawet', 'es cendol', 'dawet',
    'cendol', 'cincau', 'es cincau', 'kolak', 'es kolak',
    'restoran', 'resto', 'rumah makan', 'warung', 'warkop', 'warteg', 'kafe', 'cafe',
    'kopitiam', 'kantin', 'depot', 'angkringan', 'kaki lima', 'food court', 'pujasera',
    'starbucks', 'kopi kenangan', 'kenangan', 'janji jiwa', 'fore coffee', 'fore', 'tomoro',
    'point coffee', 'mixue', 'chatime', 'kokumi', 'kopi jago', 'kopi jujur',
    'kfc', 'mcd', 'mcdonald', 'hokben', 'hoka hoka bento', 'pizza hut', 'domino', 'burger king',
    'richeese', 'solaria', 'dcrepes', 'jco', 'breadtalk', 'holland bakery', 'kartikasari',
    'gofood', 'grabfood', 'shopeefood',
    'lunch', 'dinner', 'katering', 'catering', 'prasmanan', 'rice box', 'tumpeng',
    'botol', 'rebus'
  ];

  // PENGELUARAN: Transportasi
  static const List<String> _kTransportasi = [
    'bensin', 'pertalite', 'pertamax', 'pertamax turbo', 'solar', 'dexlite', 'spbu',
    'pertamina', 'shell', 'vivo',
    'gojek', 'grab', 'gocar', 'goride', 'grabbike', 'grabcar', 'maxim', 'indrive', 'ojol', 'ojek',
    'ojek online', 'ojek pangkalan', 'opang',
    'bus', 'busway', 'transjakarta', 'angkot', 'mikrolet', 'kopaja', 'metromini',
    'kereta', 'krl', 'commuter line', 'mrt', 'lrt', 'whoosh', 'kereta cepat',
    'taksi', 'taxi', 'blue bird', 'bluebird', 'damri', 'travel', 'shuttle', 'cipaganti', 'xtrans',
    'becak', 'delman', 'kapal', 'ferry', 'speedboat',
    'tiket pesawat', 'tiket kereta', 'tiket bus', 'airlines', 'garuda', 'lion air',
    'citilink', 'batik air', 'sriwijaya', 'airasia', 'super air jet', 'pelita air',
    'parkir', 'tol', 'e-toll', 'etoll', 'tapcash', 'e-money',
    'servis', 'service', 'bengkel', 'oli', 'ganti oli', 'tune up', 'spooring', 'balancing',
    'tambal ban', 'ban', 'aki', 'sparepart', 'onderdil', 'suku cadang',
    'cuci motor', 'cuci mobil', 'steam motor', 'coating', 'salon mobil', 'detailing',
    'stnk', 'perpanjang stnk', 'pajak kendaraan', 'bpkb', 'sim', 'perpanjang sim', 'kir',
    'mudik', 'balik kampung', 'pulang kampung', 'traveloka', 'tiket.com'
  ];

  // PENGELUARAN: Tagihan
  static const List<String> _kTagihan = [
    'listrik', 'pln', 'token listrik',
    'pdam', 'tagihan air', 'pam jaya', 'aetra',
    'wifi', 'indihome', 'biznet', 'first media', 'myrepublic', 'cbn', 'oxygen', 'megavision',
    'internet', 'langganan internet',
    'pulsa', 'paket data', 'kuota', 'voucher data', 'telkomsel', 'simpati', 'kartu halo',
    'indosat', 'im3', 'tri', 'xl', 'axis', 'smartfren', 'byu',
    'netflix', 'disney', 'viu', 'iqiyi', 'wetv', 'prime video', 'youtube premium', 'spotify',
    'apple music', 'joox', 'icloud', 'google one', 'canva', 'capcut', 'zoom', 'microsoft 365',
    'bpjs', 'bpjs kesehatan', 'bpjs ketenagakerjaan', 'asuransi', 'premi', 'iuran',
    'iuran warga', 'iuran rt', 'retribusi', 'kebersihan', 'keamanan',
    'sewa', 'kontrakan', 'kontrak rumah', 'kos', 'kost', 'apartemen', 'kpr', 'ipl',
    'cicilan', 'kredit', 'paylater', 'pay later', 'kartu kredit', 'pinjol', 'pinjaman online',
    'kredivo', 'akulaku', 'spaylater', 'shopee paylater', 'adira', 'fif', 'wom finance', 'baf',
    'home credit', 'indodana', 'tunai', 'rupiah cepat'
  ];

  // PENGELUARAN: Belanja
  static const List<String> _kBelanja = [
    'shopee', 'tokopedia', 'tiktok shop', 'lazada', 'blibli', 'bukalapak', 'zalora', 'orami',
    'jd.id', 'ruparupa', 'ikea', 'informa', 'ace hardware', 'mr diy', 'miniso', 'daiso', 'kkv',
    'ohsome', 'gramedia',
    'indomaret', 'alfamart', 'alfamidi', 'lawson', 'circle k', 'superindo', 'hypermart',
    'lotte mart', 'farmers market', 'guardian', 'watsons', 'century',
    'belanja', 'mall', 'pasar', 'supermarket', 'minimarket', 'toko', 'online shop', 'olshop',
    'baju', 'kaos', 'kemeja', 'celana', 'jeans', 'rok', 'dress', 'gamis', 'hijab', 'kerudung',
    'jilbab', 'sepatu', 'sneakers', 'sandal', 'tas', 'dompet', 'jaket', 'hoodie', 'sweater',
    'blazer', 'jas', 'pakaian', 'fashion', 'outfit', 'dasi', 'ikat pinggang', 'gesper',
    'topi', 'jam tangan', 'aksesoris', 'perhiasan', 'emas', 'gelang', 'kalung', 'cincin', 'anting',
    'skincare', 'skintific', 'somethinc', 'wardah', 'emina', 'makeup', 'kosmetik', 'lipstik',
    'bedak', 'parfum', 'minyak wangi',
    'sabun', 'sabun mandi', 'shampo', 'sampo', 'conditioner', 'pasta gigi', 'odol',
    'sikat gigi', 'deodoran', 'deodorant', 'pembalut', 'pantyliner',
    'deterjen', 'sabun cuci', 'pewangi pakaian', 'molto', 'downy', 'soklin', 'rinso',
    'sunlight', 'mama lemon', 'tisu', 'tissue', 'pembersih lantai', 'wipol', 'bayclin',
    'sapu', 'pel', 'ember', 'keset', 'kain pel', 'sikat',
    'lampu', 'bohlam', 'baterai', 'batre', 'kabel', 'charger', 'cas', 'colokan', 'stop kontak',
    'terminal listrik', 'lampu led',
    'popok', 'pampers', 'mamy poko', 'susu bayi', 'susu formula', 'bebelac', 'sgm', 'morinaga',
    'lactogen', 'dot', 'empeng', 'stroller', 'mainan anak', 'lego',
    'hp', 'handphone', 'smartphone', 'iphone', 'samsung', 'xiaomi', 'oppo', 'vivo', 'realme',
    'infinix', 'poco', 'laptop', 'asus', 'lenovo', 'acer', 'komputer', 'pc', 'monitor', 'keyboard',
    'mouse', 'printer', 'earphone', 'headset', 'tws', 'airpods', 'speaker', 'powerbank',
    'kabel data', 'adaptor', 'tv', 'kulkas', 'freezer', 'mesin cuci', 'kipas angin', 'ac',
    'rice cooker', 'magic com', 'blender', 'dispenser', 'setrika', 'vacuum cleaner',
    'microwave', 'oven', 'air fryer', 'hair dryer', 'catokan', 'kompor', 'gas', 'tabung gas',
    'helm', 'jaket motor', 'jas hujan', 'mantel', 'payung',
    'bunga', 'tanaman', 'pot', 'pupuk', 'tanah', 'bibit',
    'kado ultah', 'bingkisan'
  ];

  // PENGELUARAN: Hiburan
  static const List<String> _kHiburan = [
    'nonton', 'bioskop', 'xxi', 'cgv', 'cinepolis', 'platinum cineplex', 'tiket nonton',
    'popcorn', 'film',
    'game', 'topup game', 'top up game', 'diamond', 'mlbb', 'mobile legends', 'free fire',
    'pubg', 'pubgm', 'genshin', 'genshin impact', 'honkai', 'valorant', 'steam', 'playstation',
    'ps4', 'ps5', 'xbox', 'nintendo', 'switch', 'voucher game', 'unipin', 'codashop', 'lapakgaming',
    'joki',
    'karaoke', 'nav karaoke', 'inul vizta', 'billiard', 'biliar', 'bowling', 'timezone',
    'arcade', 'playground', 'kidzoona',
    'liburan', 'holiday', 'traveling', 'travelling', 'jalan-jalan', 'piknik',
    'hotel', 'penginapan', 'villa', 'homestay', 'guest house', 'resort', 'staycation',
    'glamping', 'camping', 'kemah',
    'tiket wisata', 'tiket masuk', 'dufan', 'ancol', 'waterpark', 'waterboom', 'jungleland',
    'trans studio', 'konser', 'tiket konser', 'festival', 'event', 'pameran', 'expo',
    'museum', 'kebun binatang', 'ragunan', 'taman safari', 'sea world', 'jakarta aquarium',
    'pantai', 'curug', 'air terjun', 'gunung', 'mendaki', 'hiking', 'diving', 'snorkeling',
    'memancing', 'mancing', 'futsal', 'badminton', 'bulutangkis', 'tenis', 'golf', 'renang',
    'kolam renang', 'gym', 'fitness', 'yoga', 'zumba', 'pilates', 'muay thai', 'bela diri',
    'klub malam', 'dugem', 'bar', 'pub', 'lounge'
  ];

  // PENGELUARAN: Kesehatan
  static const List<String> _kKesehatan = [
    'obat', 'apotek', 'k24', 'kimia farma', 'halodoc', 'alodokter', 'klikdokter', 'sehatq',
    'dokter', 'dokter gigi', 'dokter umum', 'dokter spesialis', 'puskesmas', 'klinik',
    'rumah sakit', 'rsud', 'rsup', 'ugd', 'igd', 'rawat jalan', 'rawat inap', 'opname',
    'laboratorium', 'lab', 'tes darah', 'cek darah', 'cek gula', 'cek kolesterol',
    'rontgen', 'usg', 'ct scan', 'mri', 'swab', 'pcr', 'antigen', 'vaksin', 'vaksinasi', 'imunisasi',
    'vitamin', 'suplemen', 'madu', 'herbal', 'jamu', 'habbatussauda',
    'masker', 'masker medis', 'hand sanitizer', 'antiseptik', 'plester', 'hansaplast',
    'minyak kayu putih', 'minyak telon', 'minyak angin', 'freshcare', 'tolak angin',
    'antangin', 'panadol', 'paracetamol', 'bodrex', 'procold', 'komix', 'adem sari', 'larutan',
    'oralit', 'betadine',
    'kacamata', 'optik', 'softlens', 'behel', 'kawat gigi', 'scaling', 'tambal gigi',
    'cabut gigi', 'bleaching gigi',
    'pijat', 'massage', 'refleksi', 'spa', 'salon', 'potong rambut', 'cukur', 'barbershop',
    'facial', 'creambath', 'hair spa', 'meni pedi', 'manicure', 'pedicure', 'lulur',
    'terapi', 'fisioterapi', 'akupuntur', 'bekam'
  ];

  // PENGELUARAN: Pendidikan
  static const List<String> _kPendidikan = [
    'spp', 'ukt', 'uang sekolah', 'uang kuliah', 'uang semester', 'daftar ulang',
    'uang gedung', 'uang pangkal', 'biaya sks',
    'buku', 'buku tulis', 'buku paket', 'novel', 'komik', 'majalah', 'kitab', 'ensiklopedia',
    'atk', 'alat tulis', 'pulpen', 'pensil', 'stabilo', 'penggaris', 'penghapus', 'tip ex',
    'kertas', 'kertas hvs', 'binder', 'map', 'amplop',
    'fotocopy', 'fotokopi', 'print', 'ngeprint', 'cetak', 'jilid', 'laminating', 'scan dokumen',
    'kursus', 'les', 'les privat', 'bimbel', 'bimbingan belajar', 'ruangguru', 'zenius',
    'pahamify', 'quipper', 'colearn', 'kursus bahasa', 'kursus inggris', 'toefl', 'ielts',
    'toeic', 'duolingo',
    'pelatihan', 'training', 'seminar', 'webinar', 'workshop', 'bootcamp', 'udemy', 'coursera',
    'skill academy', 'dicoding', 'purwadhika', 'hacktiv8', 'revou', 'dibimbing',
    'sekolah', 'kuliah', 'kampus', 'universitas', 'politeknik', 'institut',
    'wisuda', 'toga', 'skripsi', 'tesis', 'disertasi', 'sidang', 'yudisium'
  ];

  // PENGELUARAN: Kerja
  static const List<String> _kKerja = [
    'domain', 'hosting', 'server', 'vps', 'sewa server', 'niagahoster', 'idcloudhost',
    'jagoanhosting', 'domainesia', 'qwords',
    'iklan', 'ads', 'fb ads', 'ig ads', 'google ads', 'tiktok ads', 'meta ads', 'endorse',
    'promosi', 'marketing', 'buzzer',
    'modal', 'modal usaha', 'stok', 'stok barang', 'kulakan', 'supplier', 'bahan baku',
    'kemasan', 'packaging', 'dus', 'kardus', 'lakban', 'bubble wrap', 'plastik packing',
    'paper bag', 'stiker label', 'nota',
    'gaji karyawan', 'gaji pegawai', 'gaji staff', 'thr karyawan', 'bonus karyawan',
    'pajak', 'pph', 'ppn', 'pph 21', 'pajak usaha', 'konsultan pajak', 'notaris', 'nib',
    'legalitas', 'perizinan usaha', 'cv', 'pt', 'akta',
    'meeting', 'kantor', 'office', 'bisnis', 'reimburse', 'klaim', 'dinas', 'perjalanan dinas',
    'seragam', 'atribut kantor', 'sewa kantor', 'sewa ruko', 'sewa kios'
  ];

  // PENGELUARAN: Sosial
  static const List<String> _kSosial = [
    'sedekah', 'infaq', 'infak', 'zakat', 'zakat fitrah', 'zakat mal', 'wakaf', 'donasi',
    'sumbangan', 'derma', 'charity', 'kitabisa', 'benihbaik', 'wecare',
    'kondangan', 'amplop', 'hajatan', 'pernikahan', 'nikahan', 'sunatan', 'khitanan',
    'aqiqah', 'tahlilan', 'yasinan', 'pengajian', 'qurban', 'kurban', 'idul adha', 'idul fitri',
    'kado', 'hadiah', 'hampers', 'parcel', 'buket', 'bunga papan', 'papan bunga',
    'uang saku', 'nafkah', 'kirim orang tua', 'orang tua', 'keluarga', 'anak',
    'jajan anak', 'susu anak', 'biaya anak'
  ];

  // PEMASUKAN: Gaji
  static const List<String> _kGaji = [
    'gaji', 'gajian', 'salary', 'upah', 'payroll', 'honor', 'honorarium', 'thr', 'tunjangan',
    'tunjangan kinerja', 'tukin', 'gaji ke-13', 'lembur', 'overtime', 'uang lembur'
  ];

  // PEMASUKAN: Bonus
  static const List<String> _kBonus = [
    'bonus', 'insentif', 'komisi', 'tips', 'angpao', 'ampau', 'cashback', 'giveaway', 'sawer',
    'saweria', 'reward', 'hadiah uang', 'bonus tahunan', 'bonus proyek'
  ];

  // PEMASUKAN: Investasi
  static const List<String> _kInvestasi = [
    'dividen', 'deviden', 'saham', 'reksadana', 'crypto', 'kripto', 'bitcoin', 'btc', 'ethereum',
    'eth', 'bunga', 'bunga bank', 'bunga deposito', 'deposito', 'cuan', 'profit', 'trading',
    'forex', 'yield', 'staking', 'royalti', 'royalty', 'capital gain', 'obligasi', 'sukuk', 'sbn',
    'ori', 'emas', 'logam mulia', 'antam', 'tabungan emas'
  ];

  // PEMASUKAN: Transfer
  static const List<String> _kTransfer = [
    'transfer masuk', 'kiriman', 'kiriman uang', 'tf masuk', 'terima transfer',
    'pengembalian', 'refund', 'pengembalian dana',
    'penjualan', 'jualan', 'omset', 'omzet', 'dagang', 'laku', 'fee', 'jasa', 'project fee',
    'freelance', 'upwork', 'fiverr', 'sribulancer', 'projects.co.id'
  ];

  // Tipe Overrides (Need vs Want)
  static const List<String> _kMakanWant = [
    'starbucks', 'kopi kenangan', 'kenangan', 'janji jiwa', 'fore coffee', 'fore', 'tomoro',
    'point coffee', 'mixue', 'chatime', 'xing fu tang', 'kokumi', 'kopi jago', 'boba',
    'bubble tea', 'nongkrong', 'kongkow', 'cafe', 'kafe', 'kopitiam', 'coffee shop',
    'pizza hut', 'sushi', 'sashimi', 'steak', 'all you can eat', 'ayce', 'fine dining'
  ];

  static const List<String> _kBelanjaNeed = [
    'sabun', 'sabun mandi', 'shampo', 'sampo', 'conditioner', 'pasta gigi', 'odol',
    'sikat gigi', 'deodoran', 'deodorant', 'pembalut', 'pantyliner',
    'deterjen', 'sabun cuci', 'pewangi pakaian', 'tisu', 'tissue',
    'popok', 'pampers', 'mamy poko', 'susu bayi', 'susu formula', 'dot',
    'beras', 'minyak goreng', 'gula', 'garam', 'telur', 'mie instan'
  ];

  static const List<String> _kTransportWant = [
    'liburan', 'holiday', 'traveling', 'piknik', 'wisata', 'dufan', 'ancol'
  ];
}
