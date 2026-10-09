/**
 * Kamus Kategori Otomatis & Stemmer Bahasa Indonesia (Backend)
 * Selaras 100% dengan lib/services/kategori_otomatis.dart & stemmer_id.dart
 */

class StemmerId {
  static varian(kata) {
    if (!kata || typeof kata !== 'string') return [];
    kata = kata.toLowerCase().trim();
    if (kata.length < 4) return [kata];
    const hasil = new Set([kata]);
    for (const v of this._lepasAkhiran(kata)) {
      hasil.add(v);
      for (const v2 of this._lepasAwalan(v)) {
        hasil.add(v2);
      }
    }
    for (const v of this._lepasAwalan(kata)) {
      hasil.add(v);
    }
    return Array.from(hasil).filter(s => s.length >= 3);
  }

  static _lepasAkhiran(k) {
    const akhiran = ['nya', 'kan', 'lah', 'kah', 'pun', 'ku', 'mu', 'an', 'i'];
    for (const a of akhiran) {
      if (k.endsWith(a) && k.length - a.length >= 3) {
        return [k.slice(0, k.length - a.length)];
      }
    }
    return [];
  }

  static _lepasAwalan(k) {
    const awalan = {
      'meny': 's', 'menge': '', 'meng': '', 'men': 't', 'mem': 'p', 'me': '',
      'peny': 's', 'peng': '', 'pen': 't', 'pem': 'p', 'pe': '',
      'ber': '', 'ter': '', 'per': '', 'di': '', 'ke': '', 'se': '',
    };
    for (const [prefix, substitute] of Object.entries(awalan)) {
      if (k.startsWith(prefix) && k.length - prefix.length >= 3) {
        const sisa = k.slice(prefix.length);
        const kandidat = [sisa];
        if (substitute) kandidat.push(substitute + sisa);
        return kandidat;
      }
    }
    return [];
  }
}

// ── Kata Kunci Komprehensif ──────────────────────────────────────────────────

const _kMakanMinum = [
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

const _kTransportasi = [
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

const _kTagihan = [
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

const _kBelanja = [
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

const _kHiburan = [
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

const _kKesehatan = [
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

const _kPendidikan = [
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

const _kKerja = [
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

const _kSosial = [
  'sedekah', 'infaq', 'infak', 'zakat', 'zakat fitrah', 'zakat mal', 'wakaf', 'donasi',
  'sumbangan', 'derma', 'charity', 'kitabisa', 'benihbaik', 'wecare',
  'kondangan', 'amplop', 'hajatan', 'pernikahan', 'nikahan', 'sunatan', 'khitanan',
  'aqiqah', 'tahlilan', 'yasinan', 'pengajian', 'qurban', 'kurban', 'idul adha', 'idul fitri',
  'kado', 'hadiah', 'hampers', 'parcel', 'buket', 'bunga papan', 'papan bunga',
  'uang saku', 'nafkah', 'kirim orang tua', 'orang tua', 'keluarga', 'anak',
  'jajan anak', 'susu anak', 'biaya anak'
];

const _kGaji = [
  'gaji', 'gajian', 'salary', 'upah', 'payroll', 'honor', 'honorarium', 'thr', 'tunjangan',
  'tunjangan kinerja', 'tukin', 'gaji ke-13', 'lembur', 'overtime', 'uang lembur'
];

const _kBonus = [
  'bonus', 'insentif', 'komisi', 'tips', 'angpao', 'ampau', 'cashback', 'giveaway', 'sawer',
  'saweria', 'reward', 'hadiah uang', 'bonus tahunan', 'bonus proyek'
];

const _kInvestasi = [
  'dividen', 'deviden', 'saham', 'reksadana', 'crypto', 'kripto', 'bitcoin', 'btc', 'ethereum',
  'eth', 'bunga', 'bunga bank', 'bunga deposito', 'deposito', 'cuan', 'profit', 'trading',
  'forex', 'yield', 'staking', 'royalti', 'royalty', 'capital gain', 'obligasi', 'sukuk', 'sbn',
  'ori', 'emas', 'logam mulia', 'antam', 'tabungan emas'
];

const _kTransfer = [
  'transfer masuk', 'kiriman', 'kiriman uang', 'tf masuk', 'terima transfer',
  'pengembalian', 'refund', 'pengembalian dana',
  'penjualan', 'jualan', 'omset', 'omzet', 'dagang', 'laku', 'fee', 'jasa', 'project fee',
  'freelance', 'upwork', 'fiverr', 'sribulancer', 'projects.co.id'
];

// Tipe Overrides (Need vs Want)
const _kMakanWant = [
  'starbucks', 'kopi kenangan', 'kenangan', 'janji jiwa', 'fore coffee', 'fore', 'tomoro',
  'point coffee', 'mixue', 'chatime', 'xing fu tang', 'kokumi', 'kopi jago', 'boba',
  'bubble tea', 'nongkrong', 'kongkow', 'cafe', 'kafe', 'kopitiam', 'coffee shop',
  'pizza hut', 'sushi', 'sashimi', 'steak', 'all you can eat', 'ayce', 'fine dining'
];

const _kBelanjaNeed = [
  'sabun', 'sabun mandi', 'shampo', 'sampo', 'conditioner', 'pasta gigi', 'odol',
  'sikat gigi', 'deodoran', 'deodorant', 'pembalut', 'pantyliner',
  'deterjen', 'sabun cuci', 'pewangi pakaian', 'tisu', 'tissue',
  'popok', 'pampers', 'mamy poko', 'susu bayi', 'susu formula', 'dot',
  'beras', 'minyak goreng', 'gula', 'garam', 'telur', 'mie instan'
];

const _kTransportWant = [
  'liburan', 'holiday', 'traveling', 'piknik', 'wisata', 'dufan', 'ancol'
];

function matchesMultiKata(teks, keywords) {
  if (!teks || typeof teks !== 'string') return false;
  const t = teks.toLowerCase().trim();
  for (const kw of keywords) {
    if (kw.includes(' ') && (t === kw || t.includes(kw))) {
      return true;
    }
  }
  return false;
}

function matches(teks, keywords) {
  if (!teks || typeof teks !== 'string') return false;
  const t = teks.toLowerCase().trim();
  for (const kw of keywords) {
    if (t === kw || t.includes(kw)) return true;
  }
  const words = t.split(/\s+/);
  for (const w of words) {
    if (!w) continue;
    const varian = StemmerId.varian(w);
    for (const v of varian) {
      for (const kw of keywords) {
        if (v === kw) return true;
      }
    }
  }
  return false;
}

function tebakKamus(deskripsi, isExpense = true) {
  if (!deskripsi) return null;
  const t = deskripsi.toLowerCase().trim();

  if (!isExpense) {
    // Pass 1: Multi-kata
    if (matchesMultiKata(t, _kGaji)) return 'Gaji';
    if (matchesMultiKata(t, _kBonus)) return 'Bonus';
    if (matchesMultiKata(t, _kInvestasi)) return 'Investasi';
    if (matchesMultiKata(t, _kTransfer)) return 'Transfer';

    // Pass 2: Kata tunggal & stem
    if (matches(t, _kGaji)) return 'Gaji';
    if (matches(t, _kBonus)) return 'Bonus';
    if (matches(t, _kInvestasi)) return 'Investasi';
    if (matches(t, _kTransfer)) return 'Transfer';
    return 'Lainnya';
  }

  // Pass 1: Multi-kata > kata tunggal (prioritas multi-kata untuk menghindari ambiguitas)
  if (matchesMultiKata(t, _kMakanMinum)) return 'Makan & Minum';
  if (matchesMultiKata(t, _kTransportasi)) return 'Transportasi';
  if (matchesMultiKata(t, _kTagihan)) return 'Tagihan';
  if (matchesMultiKata(t, _kBelanja)) return 'Belanja';
  if (matchesMultiKata(t, _kHiburan)) return 'Hiburan';
  if (matchesMultiKata(t, _kKesehatan)) return 'Kesehatan';
  if (matchesMultiKata(t, _kPendidikan)) return 'Pendidikan';
  if (matchesMultiKata(t, _kKerja)) return 'Kerja';
  if (matchesMultiKata(t, _kSosial)) return 'Sosial';

  // Pass 2: Kata tunggal & varian stem
  if (matches(t, _kMakanMinum)) return 'Makan & Minum';
  if (matches(t, _kTransportasi)) return 'Transportasi';
  if (matches(t, _kTagihan)) return 'Tagihan';
  if (matches(t, _kBelanja)) return 'Belanja';
  if (matches(t, _kHiburan)) return 'Hiburan';
  if (matches(t, _kKesehatan)) return 'Kesehatan';
  if (matches(t, _kPendidikan)) return 'Pendidikan';
  if (matches(t, _kKerja)) return 'Kerja';
  if (matches(t, _kSosial)) return 'Sosial';

  return 'Lainnya';
}

function tebakTipe(deskripsi, kategori, isExpense = true) {
  if (!isExpense) {
    if (String(kategori).toLowerCase() === 'investasi') return 'saving';
    return null;
  }

  const t = (deskripsi || '').toLowerCase().trim();

  // Keyword override
  if (kategori === 'Makan & Minum') {
    if (matches(t, _kMakanWant)) return 'want';
    return 'need';
  }
  if (kategori === 'Belanja') {
    if (matches(t, _kBelanjaNeed)) return 'need';
    return 'want';
  }
  if (kategori === 'Transportasi') {
    if (matches(t, _kTransportWant)) return 'want';
    return 'need';
  }

  // Default per kategori
  switch (kategori) {
    case 'Tagihan':
    case 'Kesehatan':
    case 'Pendidikan':
    case 'Kerja':
    case 'Sosial':
      return 'need';
    case 'Hiburan':
      return 'want';
    default:
      return 'need';
  }
}

module.exports = {
  StemmerId,
  tebakKamus,
  tebakTipe,
  matches,
  keywords: {
    MakanMinum: _kMakanMinum,
    Transportasi: _kTransportasi,
    Tagihan: _kTagihan,
    Belanja: _kBelanja,
    Hiburan: _kHiburan,
    Kesehatan: _kKesehatan,
    Pendidikan: _kPendidikan,
    Kerja: _kKerja,
    Sosial: _kSosial,
    Gaji: _kGaji,
    Bonus: _kBonus,
    Investasi: _kInvestasi,
    Transfer: _kTransfer,
  }
};
