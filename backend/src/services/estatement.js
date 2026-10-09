const pdfParse = require('pdf-parse');
const {
  extractJson,
  normalizeKategori,
  normalizeMetode,
  KATEGORI_LIST,
} = require('./gemini');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');
const CANDIDATE_MODELS = [
  process.env.GEMINI_MODEL,
  'gemini-1.5-flash',
  'gemini-2.0-flash',
  'gemini-1.5-pro',
].filter(Boolean);

const MONTH_MAP = {
  jan: '01', feb: '02', mar: '03', apr: '04', mei: '05', may: '05',
  jun: '06', jul: '07', agu: '08', aug: '08', sep: '09', okt: '10', oct: '10',
  nov: '11', des: '12', dec: '12',
};

function parsePeriodeYear(text) {
  const currentYear = new Date().getFullYear();
  const match = text.match(/(?:periode|period)?[^\d]*(20\d\d)/i);
  if (match) return match[1];
  const generalYear = text.match(/\b(20\d\d)\b/);
  return generalYear ? generalYear[1] : String(currentYear);
}

function parseSeabankText(text, defaultYear) {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
  const results = [];
  const dateRegex = /^(\d{1,2})\s+(JAN|FEB|MAR|APR|MAY|MEI|JUN|JUL|AUG|AGU|SEP|OCT|OKT|NOV|DEC|DES)\b/i;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const dateMatch = line.match(dateRegex);
    if (!dateMatch) continue;

    const day = dateMatch[1].padStart(2, '0');
    const monthKey = dateMatch[2].toLowerCase();
    const month = MONTH_MAP[monthKey] || '01';
    const tanggal = `${defaultYear}-${month}-${day}`;

    let fullBlock = line.substring(dateMatch[0].length).trim();
    let j = i + 1;
    while (
      j < lines.length &&
      !lines[j].match(dateRegex) &&
      !lines[j].toUpperCase().includes('TABUNGAN - RINCIAN') &&
      !lines[j].toUpperCase().includes('RINGKASAN REKENING') &&
      !lines[j].toUpperCase().includes('HALAMAN')
    ) {
      fullBlock += ' ' + lines[j];
      j++;
    }

    const numMatches = [...fullBlock.matchAll(/(?<![A-Za-z0-9])(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{4,9})(?![A-Za-z0-9])/g)];
    if (numMatches.length >= 2) {
      // Nominal transaksi adalah angka sebelum saldo akhir
      const nominalRaw = numMatches[numMatches.length - 2][1];
      const cleanNominal = parseInt(
        nominalRaw.replace(/[.,]\d{2}$/, '').replace(/[.,]/g, ''),
        10
      );

      if (cleanNominal > 0) {
        const isMasuk = /masuk|kredit|top up|transfer dari|tf dari|bunga/i.test(fullBlock);
        let desc = fullBlock;
        for (const nm of numMatches) {
          desc = desc.replace(nm[0], '');
        }
        desc = desc.replace(/\s+/g, ' ').trim() || 'Transaksi SeaBank';

        results.push({
          tanggal,
          deskripsi: desc,
          nominal: cleanNominal,
          jenis: isMasuk ? 'pemasukan' : 'pengeluaran',
          kategori: normalizeKategori(desc),
          metode_pembayaran: 'transfer',
        });
      }
    }
  }

  return results;
}

async function parseEStatementWithGemini(extractedText, defaultYear) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY tidak dikonfigurasi');
  }

  const prompt = `Teks berikut diekstrak dari e-statement rekening koran bank di Indonesia (periode tahun ${defaultYear}).
Ekstrak SEMUA transaksi mutasi yang tercatat ke dalam format JSON.

Aturan penting:
1. Abaikan ringkasan rekening (Saldo Awal, Total Keluar, Total Masuk, Saldo Akhir).
2. Abaikan kolom SALDO / SALDO AKHIR tiap baris transaksi (JANGAN masukkan sebagai transaksi).
3. "tanggal": YYYY-MM-DD.
4. "nominal": angka bulat positif tanpa titik/koma (misal 50.000 → 50000).
5. "jenis": "pengeluaran" (debet, uang keluar, transfer keluar, bayar) atau "pemasukan" (kredit, transfer masuk).
6. "deskripsi": nama transaksi, pengirim/penerima, atau merchant.
7. "kategori": salah satu dari [${KATEGORI_LIST}].
8. "metode_pembayaran": "transfer", "qris", "debit", "kredit", atau "tunai".

Teks E-Statement:
"""
${extractedText.slice(0, 15000)}
"""

Kembalikan HANYA JSON berformat:
{
  "transaksi": [
    {
      "tanggal": "${defaultYear}-01-01",
      "deskripsi": "Keterangan",
      "nominal": 50000,
      "jenis": "pengeluaran",
      "kategori": "Lainnya",
      "metode_pembayaran": "transfer"
    }
  ]
}`;

  let textRes;
  for (const modelName of CANDIDATE_MODELS) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const res = await model.generateContent(prompt);
      textRes = res.response.text();
      break;
    } catch (_) {}
  }

  if (!textRes) throw new Error('Model AI tidak mengembalikan respon');

  const parsed = extractJson(textRes);
  const list = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.transaksi) ? parsed.transaksi : []);
  return list.map(t => ({
    tanggal: t.tanggal || `${defaultYear}-01-01`,
    deskripsi: (t.deskripsi || 'Transaksi E-Statement').trim(),
    nominal: Math.max(0, Number(t.nominal) || 0),
    jenis: t.jenis === 'pemasukan' ? 'pemasukan' : 'pengeluaran',
    kategori: normalizeKategori(t.kategori || t.deskripsi),
    metode_pembayaran: normalizeMetode(t.metode_pembayaran || 'transfer'),
  })).filter(t => t.nominal > 0);
}

async function parseEStatementPdf(pdfBuffer) {
  if (!pdfBuffer || !Buffer.isBuffer(pdfBuffer)) {
    throw new Error('Data berkas PDF tidak valid');
  }

  if (pdfBuffer.length > 10 * 1024 * 1024) {
    throw new Error('Ukuran file melebihi batas 10 MB');
  }

  // Cek magic header PDF
  const header = pdfBuffer.slice(0, 5).toString('ascii');
  if (!header.startsWith('%PDF')) {
    throw new Error('File harus berformat PDF asli');
  }

  const parsedPdf = await pdfParse(pdfBuffer);
  const rawText = (parsedPdf.text || '').trim();

  // Validasi jika PDF scan/foto tanpa layer teks
  if (rawText.length < 50) {
    throw new Error('PDF ini hasil scan gambar, tidak bisa dibaca. Gunakan e-statement asli dari aplikasi bank.');
  }

  const year = parsePeriodeYear(rawText);

  // 1. Jalur deterministik SeaBank
  if (rawText.toUpperCase().includes('SEABANK') || rawText.toUpperCase().includes('TABUNGAN - RINCIAN TRANSAKSI')) {
    const seabankResults = parseSeabankText(rawText, year);
    if (seabankResults.length > 0) {
      return seabankResults;
    }
  }

  // 2. Jalur Gemini AI (fallback SeaBank atau bank lain seperti BCA/Mandiri/BRI/BNI)
  const aiResults = await parseEStatementWithGemini(rawText, year);
  return aiResults;
}

module.exports = {
  parseEStatementPdf,
  parseSeabankText,
  parsePeriodeYear,
};
