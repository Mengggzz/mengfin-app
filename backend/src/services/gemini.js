const { GoogleGenerativeAI } = require('@google/generative-ai');
const { getMengFinAISystemPrompt } = require('../config/mengfin_ai_system_prompt');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');
const CANDIDATE_MODELS = [
  process.env.GEMINI_MODEL,
  'gemini-1.5-flash',
  'gemini-2.0-flash',
  'gemini-1.5-pro',
].filter(Boolean);

// Daftar kategori tunggal — dipakai oleh parse teks, scan struk, dan narasi
// supaya hasil AI selalu konsisten dengan kategori di aplikasi Flutter
// (lihat lib/constants/utils.dart → kategoriList).
const KATEGORI = [
  'Makan & Minum', 'Transportasi', 'Belanja', 'Hiburan', 'Kesehatan',
  'Pendidikan', 'Tagihan', 'Pajak & Asuransi', 'Sosial', 'Keluarga',
  'Pakaian', 'Perawatan', 'Olahraga', 'Pemeliharaan', 'Rumah Tangga',
  'Kendaraan', 'Kerja', 'Gaji', 'Bonus', 'Investasi', 'Transfer', 'Lainnya',
];
const KATEGORI_LIST = KATEGORI.map(k => `"${k}"`).join(', ');
const METODE = ['tunai', 'transfer', 'qris', 'debit', 'kredit'];

/// Timeout wrapper agar panggilan LLM tidak menggantung
function withTimeout(promise, ms = 6000) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('AI Request Timeout')), ms))
  ]);
}

/// Retry helper — Gemini sering balas 503 (high demand) secara transien.
async function withRetry(fn, attempts = 2) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await withTimeout(fn(), 5000);
    } catch (err) {
      lastErr = err;
      const status = err?.status || err?.response?.status;
      if (status !== 503 && status !== 429 && !err.message?.includes('Timeout')) throw err;
      await new Promise(r => setTimeout(r, 600 * (i + 1)));
    }
  }
  throw lastErr;
}

/// Helper pemanggilan Gemini dengan multi-model fallback
async function generateWithFallbackModels(promptOrContent) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY tidak dikonfigurasi');
  }
  let lastErr;
  for (const modelName of CANDIDATE_MODELS) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const res = await withRetry(() => model.generateContent(promptOrContent), 2);
      return res.response.text();
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

/// Ambil JSON dari respons model — tahan terhadap pagar markdown / teks nyasar.
function extractJson(text) {
  let clean = (text || '').trim();
  clean = clean.replace(/```json\s*/gi, '').replace(/```\s*/g, '').trim();
  try {
    return JSON.parse(clean);
  } catch (_) {
    // Fallback: ambil blok {...} atau [...] pertama
    const objMatch = clean.match(/\{[\s\S]*\}/);
    const arrMatch = clean.match(/\[[\s\S]*\]/);
    let candidates = [];
    if (objMatch && arrMatch) {
      if (clean.indexOf('{') < clean.indexOf('[')) {
        candidates = [objMatch[0], arrMatch[0]];
      } else {
        candidates = [arrMatch[0], objMatch[0]];
      }
    } else if (objMatch) {
      candidates = [objMatch[0]];
    } else if (arrMatch) {
      candidates = [arrMatch[0]];
    }
    for (const c of candidates) {
      try {
        return JSON.parse(c);
      } catch (_) {}
    }
    throw new Error('Tidak ada JSON pada respons model');
  }
}

/// Rapikan nilai kategori dari model agar selalu salah satu nilai valid.
function normalizeKategori(raw) {
  if (!raw) return 'Lainnya';
  const s = String(raw).trim();
  const exact = KATEGORI.find(k => k.toLowerCase() === s.toLowerCase());
  if (exact) return exact;
  const partial = KATEGORI.find(k =>
    k.toLowerCase().includes(s.toLowerCase()) || s.toLowerCase().includes(k.toLowerCase()));
  return partial || 'Lainnya';
}

function normalizeMetode(raw) {
  if (!raw) return 'tunai';
  const s = String(raw).trim().toLowerCase();
  return METODE.find(m => s.includes(m)) || 'tunai';
}

// Parse transaksi dari teks natural language
async function parseTransaksiDariTeks(teks) {
  const prompt = `Kamu adalah sistem pencatat keuangan. Parse teks berikut menjadi JSON transaksi.

Teks: "${teks}"

Kembalikan JSON dengan format persis ini (tanpa markdown, tanpa penjelasan):
{
  "jenis": "pengeluaran" atau "pemasukan",
  "nominal": angka dalam rupiah (hilangkan "rb" = x1000, "jt" = x1000000, "ribu" = x1000, "juta" = x1000000),
  "kategori": salah satu dari [${KATEGORI_LIST}],
  "deskripsi": deskripsi singkat (nama objek/item yang dibeli, mis. "Kopi"),
  "metode_pembayaran": salah satu dari [${METODE.map(m => `"${m}"`).join(', ')}],
  "tanggal": "${new Date().toISOString().split('T')[0]}"
}

PENTING:
- Jika teks BUKAN pencatatan transaksi atau tidak ada nominal nyata (>0), kembalikan: {"error": "bukan_transaksi"}
- Kategori HARUS persis salah satu nilai di atas. Untuk makanan/minuman pakai "Makan & Minum".

Contoh:
- "beli kopi 5 ribu" → jenis:pengeluaran, nominal:5000, kategori:"Makan & Minum", deskripsi:"Kopi", metode:tunai
- "beli mie ayam 25rb pakai tunai" → jenis:pengeluaran, nominal:25000, kategori:"Makan & Minum", deskripsi:"Mie Ayam", metode:tunai
- "gajian 5 juta" → jenis:pemasukan, nominal:5000000, kategori:"Gaji", deskripsi:"Gaji Bulanan", metode:transfer`;

  try {
    const textRes = await generateWithFallbackModels(prompt);
    const parsed = extractJson(textRes);
    if (parsed.error || !parsed.nominal || Number(parsed.nominal) <= 0) {
      return null;
    }
    parsed.kategori = normalizeKategori(parsed.kategori);
    parsed.metode_pembayaran = normalizeMetode(parsed.metode_pembayaran);
    parsed.nominal = Number(parsed.nominal) || 0;
    parsed.deskripsi = (parsed.deskripsi || '').trim();
    if (!parsed.deskripsi) return null;
    return parsed;
  } catch (err) {
    return null;
  }
}

// AI Financial Advisor - jawab pertanyaan keuangan
async function tanyaAIAdvisor(pertanyaan, konteksKeuangan) {
  const systemPrompt = getMengFinAISystemPrompt(konteksKeuangan);
  const userPrompt = `Pertanyaan/perintah pengguna: "${pertanyaan}"`;

  try {
    return await generateWithFallbackModels(systemPrompt + '\n\n' + userPrompt);
  } catch (err) {
    // Fallback cerdas berbasis data keuangan aktual
    return generateFallbackAdvisorResponse(pertanyaan, konteksKeuangan);
  }
}

function generateFallbackAdvisorResponse(pertanyaan, konteksKeuangan) {
  const {
    bulanIni = '',
    pemasukan = 0,
    pengeluaran = 0,
    saldoBersih = 0,
    saldoTotal = 0,
    rataHarian = 0,
    pengeluaranHariIni = 0,
    budgetHarian = 100000,
    topKategoriPengeluaran = [],
    anggaranList = [],
    riwayatTransaksi = [],
    sisaHariBulan = 0,
    hariIni = 1
  } = konteksKeuangan || {};

  const p = (pertanyaan || '').toLowerCase().trim();
  const fmt = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');

  const clean = p.replace(/[!.,?~]+/g, '').trim();
  const greetings = [
    'halo', 'hai', 'hi', 'hey', 'hei', 'tes', 'test', 'ping', 'p',
    'pagi', 'selamat pagi', 'siang', 'selamat siang', 'sore', 'selamat sore',
    'malam', 'selamat malam', 'assalamualaikum', 'halo mengfin', 'hai mengfin'
  ];

  // Sapaan murni
  if (greetings.includes(clean)) {
    return `👋 Halo! Saya **MengFin AI**, asisten keuangan personal Anda.\n\nSistem AI siap membantu:\n• Tanya kondisi keuangan atau saldo (*"berapa saldo saya?"*)\n• Cek pengeluaran kategori (*"berapa pengeluaran makan?"*)\n• Minta tips penghematan (*"tips hemat"*\)\n• Catat transaksi instan (contoh: *"beli kopi 25rb"* atau *"gajian 5jt"*)\n\nAda yang bisa saya bantu hari ini? 😊`;
  }

  // Tanya kategori spesifik
  const katKamus = {
    'Makan & Minum': /\b(makan|minum|kopi|coffee|cafe|kafe|restoran|resto|warung|mie|nasi|ayam|bakso|jajan|snack)\b/i,
    'Transportasi': /\b(bensin|bbm|pertalite|pertamax|solar|parkir|tol|ojol|gojek|grab|maxim|angkot|bus|kereta|transportasi)\b/i,
    'Belanja': /\b(belanja|supermarket|minimarket|indomaret|alfamart|shopee|tokopedia|mall)\b/i,
    'Tagihan': /\b(listrik|pln|pdam|air|pulsa|kuota|paket data|wifi|tagihan|bpjs)\b/i,
    'Kesehatan': /\b(obat|apotek|dokter|klinik|rs|rumah sakit|vitamin|kesehatan)\b/i,
    'Hiburan': /\b(nonton|bioskop|cinema|game|steam|netflix|spotify|hiburan)\b/i,
    'Pakaian': /\b(baju|celana|sepatu|tas|kaos|jaket|pakaian)\b/i,
    'Pendidikan': /\b(buku|kursus|kuliah|sekolah|spp|les|pendidikan)\b/i,
  };

  for (const [katNama, katRegex] of Object.entries(katKamus)) {
    if (katRegex.test(p)) {
      const katItem = topKategoriPengeluaran.find(k => k.kategori.toLowerCase() === katNama.toLowerCase());
      const total = katItem ? katItem.total : 0;
      const anggaran = (anggaranList || []).find(a => a.kategori.toLowerCase() === katNama.toLowerCase());

      let res = `📁 **Pengeluaran Kategori: ${katNama} (${bulanIni}):**\n\n• Total Pengeluaran: **${fmt(total)}**\n`;
      if (anggaran && anggaran.batas > 0) {
        res += `• Batas Anggaran: ${fmt(anggaran.batas)} (${anggaran.persentase}%)\n`;
        res += total > anggaran.batas ? '• Status: ⚠️ Melebihi budget!\n' : '• Status: Aman ✅\n';
      }
      return res;
    }
  }

  // Hari ini
  if (p.includes('hari ini') || p.includes('today')) {
    return `📅 **Status Hari Ini:**\n\n• Pengeluaran Hari Ini: **${fmt(pengeluaranHariIni)}**\n• Target Budget Harian: **${fmt(budgetHarian)}**\n• Sisa Budget Hari Ini: **${fmt(Math.max(0, budgetHarian - pengeluaranHariIni))}** (${pengeluaranHariIni > budgetHarian ? '⚠️ Melebihi target' : '✅ Aman'})`;
  }

  // Tanya riwayat / daftar transaksi terakhir
  if (p.includes('riwayat transaksi') || p.includes('daftar transaksi') || p.includes('transaksi terakhir') || p.includes('mutasi') || p.includes('beli apa saja')) {
    if (riwayatTransaksi.length === 0) {
      return `📝 **Riwayat Transaksi:**\n\nBelum ada transaksi tercatat di akun Anda. Mulai catat dengan mengetik misalnya *"beli kopi 20rb"*!`;
    }
    let res = `📝 **${riwayatTransaksi.length} Transaksi Terakhir:**\n\n`;
    riwayatTransaksi.forEach((t, i) => {
      const sign = t.jenis === 'pemasukan' ? '(+) ' : '(-) ';
      res += `${i + 1}. **${t.deskripsi || t.kategori}** — ${sign}${fmt(t.nominal)}\n   📅 ${t.tanggal} • 📁 ${t.kategori}\n`;
    });
    return res;
  }

  // Tanya sisa saldo / dompet
  if (p.includes('saldo') || p.includes('dompet') || p.includes('uangku') || p.includes('sisa uang') || p.includes('rekening') || p.includes('tabungan')) {
    return `💰 **Informasi Saldo:**\n\n• Total Saldo Dompet: **${fmt(saldoTotal)}**\n• Pemasukan Bulan Ini: **${fmt(pemasukan)}**\n• Pengeluaran Bulan Ini: **${fmt(pengeluaran)}**\n• Arus Kas Bersih: **${saldoBersih >= 0 ? '+' : ''}${fmt(saldoBersih)}** (${saldoBersih >= 0 ? 'Surplus ✅' : 'Defisit ⚠️'})`;
  }

  // Tanya status budget / anggaran
  if (p.includes('budget') || p.includes('anggaran') || p.includes('batas')) {
    if (anggaranList.length === 0) {
      return `🎯 **Status Budget:**\n\n• Budget Harian: **${fmt(budgetHarian)}**\n• Pengeluaran Hari Ini: **${fmt(pengeluaranHariIni)}**\n• Sisa Budget Hari Ini: **${fmt(Math.max(0, budgetHarian - pengeluaranHariIni))}**\n\n*Tips: Buat batas anggaran kategori di menu Saldo/Budget untuk kontrol pengeluaran otomatis!*`;
    }
    let res = `🎯 **Status Anggaran Kategori (${bulanIni}):**\n\n`;
    anggaranList.forEach((a, i) => {
      const statusIcon = a.terpakai > a.batas ? '⚠️' : '✅';
      res += `${i + 1}. ${statusIcon} **${a.kategori}**: ${fmt(a.terpakai)} / ${fmt(a.batas)} (${a.persentase}%)\n`;
    });
    return res;
  }

  // Tips hemat
  if (p.includes('tips') || p.includes('hemat') || p.includes('kurangi') || p.includes('berhemat') || p.includes('strategi')) {
    let tips = `💡 **Tips Hemat Terarah (${bulanIni}):**\n\n`;
    if (topKategoriPengeluaran.length > 0) {
      tips += `1. **Fokus pada Pos ${topKategoriPengeluaran[0].kategori}**: Pengeluaran pos ini mencapai **${fmt(topKategoriPengeluaran[0].total)}**. Tetapkan batas mingguan ketat.\n`;
    } else {
      tips += `1. **Catat Pengeluaran Rutin**: Awasi setiap transaksi harian agar pos pengeluaran tidak bocor halus.\n`;
    }
    if (pengeluaranHariIni > budgetHarian) {
      tips += `2. **Jaga Budget Harian**: Hari ini pengeluaran (${fmt(pengeluaranHariIni)}) melebihi target (${fmt(budgetHarian)}). Tahan belanja non-primer sampai esok hari.\n`;
    } else {
      tips += `2. **Pertahankan Budget Harian**: Sisa budget hari ini masih aman (${fmt(Math.max(0, budgetHarian - pengeluaranHariIni))}).\n`;
    }
    tips += `3. **Alokasikan Tabungan di Awal**: Sisihkan minimal 10-20% segera saat pemasukan masuk ke akun tabungan atau goals.\n`;
    tips += `4. **Evaluasi Rutin**: Rata-rata pengeluaran Anda saat ini **${fmt(rataHarian)}/hari**.`;
    return tips;
  }

  // Dana darurat & investasi
  if (p.includes('dana darurat') || p.includes('darurat')) {
    return `🛡️ **Panduan Dana Darurat:**\n\n• **Ideal**: 3–6x pengeluaran bulananmu.\n• **Tempat Simpan**: Rekening terpisah atau Reksadana Pasar Uang (likuid & aman).\n• **Tujuan**: Mengatasi keadaan genting tanpa mengganggu investasi jangka panjang.`;
  }

  if (p.includes('investasi') || p.includes('saham') || p.includes('reksadana')) {
    return `📈 **Panduan Investasi:**\n\n1. Lunasi utang konsumtif & siapkan dana darurat terlebih dahulu.\n2. Untuk jangka pendek (<1 th): Deposito / RPU.\n3. Untuk jangka panjang (>3 th): Saham Indeks, Reksadana Campuran/Saham, Emas Fisik.\n4. Diversifikasikan aset Anda.`;
  }

  if (p.includes('terima kasih') || p.includes('makasih') || p.includes('thanks') || p === 'ok' || p === 'siap') {
    return `Sama-sama! Senang bisa membantu mengelola keuanganmu. Jika ada yang ingin ditanyakan lagi, silakan kabari ya! 😊`;
  }

  // Analisis keuangan default / pertanyaan umum
  let out = `📊 **Analisis Keuangan (${bulanIni || 'Bulan Ini'}):**\n\n`;
  out += `• **Saldo Dompet**: ${fmt(saldoTotal)}\n`;
  out += `• **Total Pemasukan**: ${fmt(pemasukan)}\n`;
  out += `• **Total Pengeluaran**: ${fmt(pengeluaran)}\n`;
  out += `• **Arus Kas (Net)**: ${saldoBersih >= 0 ? '✅ Surplus ' : '⚠️ Defisit '}${fmt(saldoBersih)}\n\n`;

  out += `📈 **Top Pengeluaran:**\n`;
  if (topKategoriPengeluaran.length > 0) {
    topKategoriPengeluaran.slice(0, 3).forEach((k, idx) => {
      const pct = pengeluaran > 0 ? Math.round((k.total / pengeluaran) * 100) : 0;
      out += `  ${idx + 1}. **${k.kategori}**: ${fmt(k.total)} (${pct}%)\n`;
    });
  } else {
    out += `  (Belum ada data pengeluaran tercatat di periode ini)\n`;
  }

  out += `\n🎯 **Status Harian & Saran:**\n`;
  out += `• Rata-rata pengeluaran: **${fmt(rataHarian)}/hari** (sisa ${sisaHariBulan} hari di bulan ini)\n`;
  if (saldoBersih < 0) {
    out += `• ⚠️ Arus kas saat ini sedang defisit. Disarankan membatasi pengeluaran pos sekunder untuk menstabilkan saldo.\n`;
  } else if (pemasukan > 0) {
    const saveRate = Math.round((saldoBersih / pemasukan) * 100);
    out += `• ✅ Tingkat tabungan Anda mencapai **${saveRate}%**. Kondisi keuangan dalam batas sehat!\n`;
  } else {
    out += `• Catat transaksi harian secara konsisten untuk melihat proyeksi kesehatan finansial yang lebih akurat.\n`;
  }

  return out;
}

// Scan nota/struk dari base64 image
async function scanNota(imageBase64, mimeType = 'image/jpeg') {
  const hariIni = new Date().toISOString().split('T')[0];

  const prompt = `Kamu adalah OCR struk belanja Indonesia yang sangat teliti.
Baca gambar struk/nota/bon ini dan ekstrak data transaksinya.

Aturan penting:
1. "nominal" = GRAND TOTAL yang harus dibayar (baris Total / Grand Total / Jumlah Bayar),
   BUKAN subtotal dan BUKAN angka acak. Kalau ada diskon/pajak, pakai total akhir setelahnya.
2. Nominal dalam rupiah tanpa titik/koma. Contoh "Rp 57.500" → 57500.
3. "tanggal" diambil dari struk. Format struk Indonesia biasanya DD/MM/YYYY atau DD-MM-YY.
   Konversi ke YYYY-MM-DD. Kalau tidak terbaca, pakai "${hariIni}".
4. "deskripsi" = nama toko/merchant (mis. "Indomaret", "Warung Bu Siti").
5. "kategori" HARUS salah satu dari [${KATEGORI_LIST}].
   - minimarket/supermarket/kelontong → "Belanja"
   - restoran/warung/kafe/makanan → "Makan & Minum"
   - apotek/klinik → "Kesehatan"
   - bensin/spbu/parkir/tol → "Transportasi"
6. "items" = daftar barang yang terbaca: nama barang + harga satuan. Kalau tidak terbaca, array kosong.

Balas HANYA JSON valid (tanpa markdown):
{
  "jenis": "pengeluaran",
  "nominal": 57500,
  "kategori": "Belanja",
  "deskripsi": "Indomaret",
  "metode_pembayaran": "tunai" | "debit" | "qris" | "kredit" | "transfer",
  "tanggal": "${hariIni}",
  "items": [{"nama": "Indomie Goreng", "harga": 3500}],
  "confidence": 0.0 sampai 1.0
}`;

  let textRes = null;
  try {
    textRes = await generateWithFallbackModels([
      prompt,
      { inlineData: { data: imageBase64, mimeType } },
    ]);
    const parsed = extractJson(textRes);
    parsed.jenis = parsed.jenis === 'pemasukan' ? 'pemasukan' : 'pengeluaran';
    parsed.kategori = normalizeKategori(parsed.kategori);
    parsed.metode_pembayaran = normalizeMetode(parsed.metode_pembayaran);
    parsed.nominal = Number(parsed.nominal) || 0;
    parsed.items = Array.isArray(parsed.items) ? parsed.items : [];
    parsed.confidence = typeof parsed.confidence === 'number' ? parsed.confidence : null;
    return parsed;
  } catch (err) {
    console.error('Gemini scan error:', err.message || err);
    if (textRes) {
      console.error('Gemini scan raw output:', String(textRes).slice(0, 2000));
    }
    return null;
  }
}

// Scan bukti transfer / riwayat mutasi bank dari base64 image
async function scanMutasi(imageBase64, mimeType = 'image/jpeg') {
  const hariIni = new Date().toISOString().split('T')[0];

  const prompt = `Gambar ini adalah screenshot bukti transfer / riwayat mutasi bank / e-wallet di Indonesia.
Ekstrak SEMUA transaksi yang terlihat di gambar sebagai array JSON transaksi.
Abaikan saldo sisa, jam, nama aplikasi, atau elemen antarmuka UI lainnya.

Aturan parsing:
1. "tanggal": YYYY-MM-DD (jika tahun 2 digit atau tanpa tahun, gunakan ${hariIni.split('-')[0]}). Jika tidak ada tanggal, gunakan "${hariIni}".
2. "nominal": angka bulat positif tanpa titik/koma (misal 50.000 → 50000).
3. "jenis": "pengeluaran" (debet, uang keluar, transfer keluar, QRIS keluar, bayar) atau "pemasukan" (kredit, transfer masuk, top up diterima).
4. "deskripsi": nama penerima/pengirim, merchant, atau berita transfer (mis. "Transfer ke Budi", "Pembayaran QRIS Kopi Kenangan").
5. "kategori": salah satu dari [${KATEGORI_LIST}].
6. "metode_pembayaran": "transfer", "qris", "debit", "kredit", atau "tunai".

Kembalikan HANYA JSON berformat persis ini (tanpa markdown, tanpa teks lain):
{
  "transaksi": [
    {
      "tanggal": "${hariIni}",
      "deskripsi": "Transfer ke Rekening",
      "nominal": 100000,
      "jenis": "pengeluaran",
      "kategori": "Transfer",
      "metode_pembayaran": "transfer"
    }
  ]
}`;

  let textRes = null;
  try {
    textRes = await generateWithFallbackModels([
      prompt,
      { inlineData: { data: imageBase64, mimeType } },
    ]);
    const parsed = extractJson(textRes);
    const list = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.transaksi) ? parsed.transaksi : []);
    const sanitized = list.map(t => ({
      tanggal: t.tanggal || hariIni,
      deskripsi: (t.deskripsi || 'Transaksi Mutasi').trim(),
      nominal: Math.max(0, Number(t.nominal) || 0),
      jenis: t.jenis === 'pemasukan' ? 'pemasukan' : 'pengeluaran',
      kategori: normalizeKategori(t.kategori),
      metode_pembayaran: normalizeMetode(t.metode_pembayaran || 'transfer'),
    })).filter(t => t.nominal > 0);

    if (sanitized.length === 0 && textRes) {
      console.error('Gemini scan mutasi 0 hasil. Raw output:', String(textRes).slice(0, 2000));
    }

    return sanitized;
  } catch (err) {
    console.error('Gemini scan mutasi error:', err.message || err);
    if (textRes) {
      console.error('Gemini scan mutasi raw output:', String(textRes).slice(0, 2000));
    }
    return null;
  }
}

// Generate insight otomatis berdasarkan data keuangan
async function generateInsight(dataKeuangan) {
  const prompt = `Berdasarkan data keuangan berikut, buat 3 insight singkat dan actionable dalam Bahasa Indonesia.

Data: ${JSON.stringify(dataKeuangan)}

Format response (JSON array, tanpa markdown):
[
  {"ikon": "💡", "pesan": "insight 1"},
  {"ikon": "⚠️", "pesan": "insight 2"},
  {"ikon": "🎯", "pesan": "insight 3"}
]`;

  try {
    const textRes = await generateWithFallbackModels(prompt);
    return extractJson(textRes);
  } catch (err) {
    return [
      { ikon: '💡', pesan: 'Pantau pengeluaran harian Anda untuk kontrol lebih baik.' },
      { ikon: '🎯', pesan: 'Tetapkan target tabungan bulanan untuk mencapai tujuan keuangan.' },
      { ikon: '✅', pesan: 'Kondisi keuangan Anda dalam pemantauan aktif.' },
    ];
  }
}

// Narasi laporan keuangan — ringkasan bahasa manusia dari data periode
async function generateNarasiLaporan(data) {
  const prompt = `Kamu adalah penasihat keuangan pribadi yang ramah dan to-the-point (Bahasa Indonesia).
Buat narasi singkat dari laporan keuangan berikut.

Data laporan:
${JSON.stringify(data, null, 2)}

Tulis dalam format markdown ringan dengan struktur:
**Ringkasan** — 1-2 kalimat tentang kondisi keuangan periode ini.
**Yang menonjol** — 2-3 poin (kategori terbesar, kenaikan/penurunan, pola).
**Saran** — 2-3 langkah konkret dan bisa langsung dilakukan.

Aturan: pakai angka rupiah yang ada di data, jangan mengarang angka. Maksimal 220 kata. Jangan pakai tabel.`;

  try {
    const textRes = await generateWithFallbackModels(prompt);
    return textRes.trim();
  } catch (err) {
    console.error('Gemini narasi error:', err.message || err);
    return null;
  }
}

module.exports = {
  extractJson,
  normalizeKategori,
  normalizeMetode,
  parseTransaksiDariTeks,
  tanyaAIAdvisor,
  scanNota,
  scanMutasi,
  generateInsight,
  generateNarasiLaporan,
  KATEGORI,
};
