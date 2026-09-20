const { GoogleGenerativeAI } = require('@google/generative-ai');
const { getMengFinAISystemPrompt } = require('../config/mengfin_ai_system_prompt');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

// Parse transaksi dari teks natural language
async function parseTransaksiDariTeks(teks) {
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

  const prompt = `Kamu adalah sistem pencatat keuangan. Parse teks berikut menjadi JSON transaksi.

Teks: "${teks}"

Kembalikan JSON dengan format persis ini (tanpa markdown, tanpa penjelasan):
{
  "jenis": "pengeluaran" atau "pemasukan",
  "nominal": angka dalam rupiah (hilangkan "rb" = x1000, "jt" = x1000000),
  "kategori": salah satu dari ["Makanan", "Transportasi", "Belanja", "Hiburan", "Kesehatan", "Pendidikan", "Tagihan", "Gaji", "Bonus", "Investasi", "Transfer", "Lainnya"],
  "deskripsi": deskripsi singkat,
  "metode_pembayaran": salah satu dari ["tunai", "transfer", "qris", "debit", "kredit"],
  "tanggal": "${new Date().toISOString().split('T')[0]}"
}

Contoh:
- "beli mie ayam 25rb pakai tunai" → jenis:pengeluaran, nominal:25000, kategori:Makanan, metode:tunai
- "gajian 5 juta" → jenis:pemasukan, nominal:5000000, kategori:Gaji
- "bayar listrik 200k transfer" → jenis:pengeluaran, nominal:200000, kategori:Tagihan, metode:transfer`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    // Bersihkan markdown jika ada
    const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    return JSON.parse(clean);
  } catch (err) {
    console.error('Gemini parse error:', err);
    return null;
  }
}

// AI Financial Advisor - jawab pertanyaan keuangan
async function tanyaAIAdvisor(pertanyaan, konteksKeuangan) {
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

  const systemPrompt = getMengFinAISystemPrompt(konteksKeuangan);
  const userPrompt = `Pertanyaan/perintah pengguna: "${pertanyaan}"`;

  try {
    const result = await model.generateContent(systemPrompt + '\n\n' + userPrompt);
    return result.response.text();
  } catch (err) {
    console.error('Gemini advisor error:', err);
    return 'Maaf, saya sedang tidak bisa memproses permintaan ini. Coba lagi beberapa saat.';
  }
}

// Scan nota dari base64 image
async function scanNota(imageBase64, mimeType = 'image/jpeg') {
  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

  const prompt = `Analisis gambar nota/struk belanja ini dan ekstrak informasi transaksi.
  
Kembalikan JSON dengan format persis ini (tanpa markdown):
{
  "jenis": "pengeluaran",
  "nominal": total bayar dalam rupiah (angka saja),
  "kategori": kategori belanja,
  "deskripsi": nama toko atau keterangan singkat,
  "metode_pembayaran": "tunai" atau "debit" atau "qris" atau "kredit",
  "tanggal": tanggal pada struk format YYYY-MM-DD (jika tidak ada pakai "${new Date().toISOString().split('T')[0]}"),
  "items": [{"nama": "...", "harga": angka}] array item yang dibeli
}`;

  try {
    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          data: imageBase64,
          mimeType: mimeType
        }
      }
    ]);
    const text = result.response.text().trim();
    const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    return JSON.parse(clean);
  } catch (err) {
    console.error('Gemini scan error:', err);
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
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    return JSON.parse(clean);
  } catch (err) {
    return [
      { ikon: '💡', pesan: 'Pantau pengeluaran harian Anda untuk kontrol lebih baik.' },
      { ikon: '🎯', pesan: 'Tetapkan target tabungan bulanan untuk mencapai tujuan keuangan.' },
      { ikon: '✅', pesan: 'Kondisi keuangan Anda dalam pemantauan aktif.' }
    ];
  }
}

module.exports = { parseTransaksiDariTeks, tanyaAIAdvisor, scanNota, generateInsight };
