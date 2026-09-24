const { GoogleGenerativeAI } = require('@google/generative-ai');
const { getMengFinAISystemPrompt } = require('../config/mengfin_ai_system_prompt');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.6-flash';

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

/// Retry helper — Gemini sering balas 503 (high demand) secara transien.
async function withRetry(fn, attempts = 4) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      const status = err?.status || err?.response?.status;
      if (status !== 503 && status !== 429) throw err;
      await new Promise(r => setTimeout(r, 1500 * (i + 1)));
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
    const candidate = objMatch ? objMatch[0] : (arrMatch ? arrMatch[0] : null);
    if (!candidate) throw new Error('Tidak ada JSON pada respons model');
    return JSON.parse(candidate);
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
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

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

PENTING: kategori HARUS persis salah satu nilai di atas. Untuk makanan/minuman (kopi, mie ayam, nasi, jajan) pakai "Makan & Minum".

Contoh:
- "beli kopi 5 ribu" → jenis:pengeluaran, nominal:5000, kategori:"Makan & Minum", deskripsi:"Kopi", metode:tunai
- "beli mie ayam 25rb pakai tunai" → jenis:pengeluaran, nominal:25000, kategori:"Makan & Minum", metode:tunai
- "gajian 5 juta" → jenis:pemasukan, nominal:5000000, kategori:"Gaji"
- "bayar listrik 200k transfer" → jenis:pengeluaran, nominal:200000, kategori:"Tagihan", metode:transfer`;

  try {
    const result = await withRetry(() => model.generateContent(prompt));
    const parsed = extractJson(result.response.text());
    parsed.kategori = normalizeKategori(parsed.kategori);
    parsed.metode_pembayaran = normalizeMetode(parsed.metode_pembayaran);
    parsed.nominal = Number(parsed.nominal) || 0;
    return parsed;
  } catch (err) {
    console.error('Gemini parse error:', err.message || err);
    return null;
  }
}

// AI Financial Advisor - jawab pertanyaan keuangan
async function tanyaAIAdvisor(pertanyaan, konteksKeuangan) {
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

  const systemPrompt = getMengFinAISystemPrompt(konteksKeuangan);
  const userPrompt = `Pertanyaan/perintah pengguna: "${pertanyaan}"`;

  try {
    const result = await withRetry(() => model.generateContent(systemPrompt + '\n\n' + userPrompt));
    return result.response.text();
  } catch (err) {
    console.error('Gemini advisor error:', err.message || err);
    return 'Maaf, saya sedang tidak bisa memproses permintaan ini. Coba lagi beberapa saat.';
  }
}

// Scan nota/struk dari base64 image
async function scanNota(imageBase64, mimeType = 'image/jpeg') {
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });
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

  try {
    const result = await withRetry(() => model.generateContent([
      prompt,
      { inlineData: { data: imageBase64, mimeType } },
    ]));
    const parsed = extractJson(result.response.text());
    parsed.jenis = parsed.jenis === 'pemasukan' ? 'pemasukan' : 'pengeluaran';
    parsed.kategori = normalizeKategori(parsed.kategori);
    parsed.metode_pembayaran = normalizeMetode(parsed.metode_pembayaran);
    parsed.nominal = Number(parsed.nominal) || 0;
    parsed.items = Array.isArray(parsed.items) ? parsed.items : [];
    parsed.confidence = typeof parsed.confidence === 'number' ? parsed.confidence : null;
    return parsed;
  } catch (err) {
    console.error('Gemini scan error:', err.message || err);
    return null;
  }
}

// Generate insight otomatis berdasarkan data keuangan
async function generateInsight(dataKeuangan) {
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

  const prompt = `Berdasarkan data keuangan berikut, buat 3 insight singkat dan actionable dalam Bahasa Indonesia.

Data: ${JSON.stringify(dataKeuangan)}

Format response (JSON array, tanpa markdown):
[
  {"ikon": "💡", "pesan": "insight 1"},
  {"ikon": "⚠️", "pesan": "insight 2"},
  {"ikon": "🎯", "pesan": "insight 3"}
]`;

  try {
    const result = await withRetry(() => model.generateContent(prompt));
    return extractJson(result.response.text());
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
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

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
    const result = await withRetry(() => model.generateContent(prompt));
    return result.response.text().trim();
  } catch (err) {
    console.error('Gemini narasi error:', err.message || err);
    return null;
  }
}

module.exports = {
  parseTransaksiDariTeks, tanyaAIAdvisor, scanNota, generateInsight,
  generateNarasiLaporan, KATEGORI,
};
