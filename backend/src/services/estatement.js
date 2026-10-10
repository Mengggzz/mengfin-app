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

const FOOTER_STOP_MARKERS = [
  'HUBUNGI KAMI', 'CALL CENTER', 'TELEPON', 'CS@', '@SEABANK',
  'WWW.', '.CO.ID', 'PT BANK', 'SYARAT DAN KETENTUAN',
  'HALAMAN', 'PAGE', 'REKENING KORAN', 'S/N'
];

function isFooterOrHeaderLine(line) {
  const upper = line.toUpperCase();
  for (const marker of FOOTER_STOP_MARKERS) {
    if (upper.includes(marker)) return true;
  }
  if (upper.includes('TABUNGAN - RINCIAN') || upper.includes('RINGKASAN REKENING')) return true;
  if (upper.includes('TANGGAL') && upper.includes('TRANSAKSI') && upper.includes('SALDO')) return true;
  return false;
}

function isValidNumberString(s) {
  if (!s || typeof s !== 'string') return false;
  s = s.trim();
  if (/^\d{1,9}$/.test(s)) return true;
  if (/^\d{1,3}(\.\d{3})+(?:,\d{2})?$/.test(s)) return true;
  if (/^\d{1,3}(,\d{3})+(?:\.\d{2})?$/.test(s)) return true;
  return false;
}

function parseIndoNumber(s) {
  if (!s) return 0;
  let c = s.trim().replace(/[.,]\d{2}$/, '').replace(/[.,]/g, '');
  return parseInt(c, 10) || 0;
}

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

  let inRincianSection = false;
  let saldoAwal = null;
  let saldoAkhirRingkasan = null;

  // 1. Ekstraksi ringkasan dijangkar ke baris TABUNGAN
  const tabunganMatch = text.match(/^.*TABUNGAN(\d[\d.,]*).*$/m);
  if (tabunganMatch) {
    const tn = [...tabunganMatch[1].matchAll(/\d{1,3}(?:\.\d{3})+/g)]
      .map(x => parseIndoNumber(x[0]));
    // tn = [saldoAwal, keluar, masuk, saldoAkhir]
    if (tn.length >= 1) saldoAwal = tn[0];
    if (tn.length >= 4) saldoAkhirRingkasan = tn[3];
    else if (tn.length >= 2) saldoAkhirRingkasan = tn[tn.length - 1];
  }

  // Fallback saldoAkhirRingkasan dari TOTAL: bila baris TABUNGAN tak ketemu
  if (saldoAkhirRingkasan === null) {
    const totalMatch = text.match(/TOTAL:\s*(\d{1,3}(?:\.\d{3})+)/i);
    if (totalMatch) {
      saldoAkhirRingkasan = parseIndoNumber(totalMatch[1]);
    }
  }

  // Fallback saldoAwal jika TABUNGAN tidak cocok (misal sample mock)
  if (saldoAwal === null) {
    const ringkasanMatch = text.match(/RINGKASAN\s+REKENING[\s\S]*?RINCIAN\s+TRANSAKSI/i);
    if (ringkasanMatch) {
      const rText = ringkasanMatch[0];
      const nums = [...rText.matchAll(/(?<!\d)(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{4,9})(?!\d)/g)];
      const validNums = nums.map(x => x[1]).filter(isValidNumberString).map(parseIndoNumber);
      if (validNums.length >= 1) saldoAwal = validNums[0];
      if (saldoAkhirRingkasan === null && validNums.length >= 2) {
        saldoAkhirRingkasan = validNums[validNums.length - 1];
      }
    }
  }

  let runningSaldo = saldoAwal;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Section gating: hanya proses setelah RINCIAN TRANSAKSI
    if (/RINCIAN\s+TRANSAKSI/i.test(line)) {
      inRincianSection = true;
      continue;
    }
    if (!inRincianSection) continue;

    const dateMatch = line.match(dateRegex);
    if (!dateMatch) continue;

    const day = dateMatch[1].padStart(2, '0');
    const monthKey = dateMatch[2].toLowerCase();
    const month = MONTH_MAP[monthKey] || '01';
    const tanggal = `${defaultYear}-${month}-${day}`;

    let fullBlock = line.substring(dateMatch[0].length).trim();
    let j = i + 1;
    while (j < lines.length) {
      if (lines[j].match(dateRegex)) break;
      if (isFooterOrHeaderLine(lines[j])) {
        j++;
        continue;
      }
      fullBlock += ' ' + lines[j];
      j++;
    }

    // Bersihkan fragmen footer
    const cutIdx = fullBlock.search(/(@|www\.|\bhttps?:)/i);
    if (cutIdx !== -1) fullBlock = fullBlock.slice(0, cutIdx).trim();

    for (const marker of FOOTER_STOP_MARKERS) {
      const re = new RegExp(marker.replace(/([.*+?^${}()|[\]\/\\])/g, '\\$1'), 'gi');
      fullBlock = fullBlock.replace(re, ' ');
    }
    fullBlock = fullBlock.replace(/\s+/g, ' ').trim();

    // Pisahkan deskripsi dan kandidat nominal/saldo
    const tokens = fullBlock.split(/\s+/).filter(Boolean);
    if (tokens.length === 0) continue;

    let matched = null;
    const candidates = [];

    // 2. Kandidat dari SEMUA posisi token (iterasi dari belakang):
    // (a) Tiap pasangan token bersebelahan sebagai nominal+saldo
    // (b) Tiap split tiap token sebagai nominal+saldo menempel
    // deskripsi = token SEBELUM blob (otomatis bersih dari footer)
    for (let p = tokens.length - 1; p >= 0; p--) {
      // (a) Spaced pair
      if (p >= 1) {
        const tNom = tokens[p - 1];
        const tSal = tokens[p];
        if (isValidNumberString(tNom) && isValidNumberString(tSal)) {
          const nom = parseIndoNumber(tNom);
          const sal = parseIndoNumber(tSal);
          const desc = tokens.slice(0, p - 1).join(' ').trim();
          if (nom > 0) {
            candidates.push({
              desc,
              nom,
              sal,
              type: 'spaced',
            });
          }
        }
      }

      // (b) Glued split
      const lastToken = tokens[p];
      const descForGlued = tokens.slice(0, p).join(' ').trim();
      for (let k = 1; k < lastToken.length; k++) {
        const left = lastToken.slice(0, k);
        const right = lastToken.slice(k);
        if (isValidNumberString(left) && isValidNumberString(right)) {
          const nom = parseIndoNumber(left);
          const sal = parseIndoNumber(right);
          if (nom > 0) {
            candidates.push({
              desc: descForGlued,
              nom,
              sal,
              type: 'glued',
            });
          }
        }
      }
    }

    // Pilih kandidat yang memenuhi |runningSaldo - saldo| == nominal
    if (runningSaldo !== null) {
      const validMatch = candidates.find(c => Math.abs(runningSaldo - c.sal) === c.nom);
      if (validMatch) {
        matched = {
          deskripsi: validMatch.desc,
          nominal: validMatch.nom,
          saldo: validMatch.sal,
          jenis: validMatch.sal > runningSaldo ? 'pemasukan' : 'pengeluaran'
        };
      }
    } else {
      // Baris pertama tanpa saldo awal dari ringkasan
      if (candidates.length > 0) {
        const best = candidates.find(c => c.type === 'spaced') || candidates[0];
        const isMasuk = /masuk|kredit|top up|transfer dari|tf dari|bunga|cashback|refund/i.test(best.desc);
        matched = {
          deskripsi: best.desc,
          nominal: best.nom,
          saldo: best.sal,
          jenis: isMasuk ? 'pemasukan' : 'pengeluaran'
        };
      }
    }

    // Validasi penolakan: deskripsi < 3 karakter atau mengandung kata header ringkasan
    if (!matched || !matched.deskripsi || matched.deskripsi.length < 3) continue;
    const upperDesc = matched.deskripsi.toUpperCase();
    if (
      upperDesc.includes('SALDO AWAL') ||
      upperDesc.includes('TRANSAKSI KELUAR') ||
      upperDesc.includes('TRANSAKSI MASUK') ||
      upperDesc.includes('SALDO AKHIR')
    ) {
      continue;
    }

    runningSaldo = matched.saldo;

    results.push({
      tanggal,
      deskripsi: matched.deskripsi,
      nominal: matched.nominal,
      jenis: matched.jenis,
      kategori: normalizeKategori(matched.deskripsi),
      metode_pembayaran: 'transfer',
      saldo: matched.saldo,
    });
  }

  // Validasi rantai: saldo akhir baris terakhir harus ≈ TOTAL di ringkasan
  if (saldoAkhirRingkasan !== null && results.length > 0) {
    const lastSaldo = results[results.length - 1].saldo;
    if (Math.abs(lastSaldo - saldoAkhirRingkasan) > 100) {
      return [];
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
  let lastError = null;
  for (const modelName of CANDIDATE_MODELS) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const res = await model.generateContent(prompt);
      textRes = res.response.text();
      if (textRes) break;
    } catch (err) {
      lastError = err;
      console.error(`[Gemini E-Statement] Model ${modelName} gagal:`, err.message || err);
    }
  }

  if (!textRes) {
    const reason = lastError ? (lastError.message || String(lastError)) : 'tidak ada respon';
    throw new Error(`AI gagal: ${reason}`);
  }

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
  const stages = [];
  const t0 = Date.now();

  function addStage(stage, ok, detail, startMs) {
    const ms = Date.now() - (startMs || t0);
    const item = { stage, ok, detail, ms };
    stages.push(item);
    console.log(`[E-Statement Stage] [${stage}] ${ok ? 'OK' : 'FAIL'}: ${detail} (${ms}ms)`);
    return item;
  }

  if (!pdfBuffer || !Buffer.isBuffer(pdfBuffer)) {
    addStage('extract', false, 'Data berkas PDF tidak valid');
    const err = new Error('Data berkas PDF tidak valid');
    err.stages = stages;
    err.stage = 'extract';
    throw err;
  }

  if (pdfBuffer.length > 10 * 1024 * 1024) {
    addStage('extract', false, 'Ukuran file melebihi batas 10 MB');
    const err = new Error('Ukuran file melebihi batas 10 MB');
    err.stages = stages;
    err.stage = 'extract';
    throw err;
  }

  // Cek magic header PDF
  const header = pdfBuffer.slice(0, 5).toString('ascii');
  if (!header.startsWith('%PDF')) {
    addStage('extract', false, 'Bukan file PDF asli (header magic mismatch)');
    const err = new Error('File harus berformat PDF asli');
    err.stages = stages;
    err.stage = 'extract';
    throw err;
  }

  // 1. Tahap Extract
  const extractStart = Date.now();
  let parsedPdf;
  try {
    parsedPdf = await pdfParse(pdfBuffer);
  } catch (err) {
    addStage('extract', false, `Ekstraksi teks gagal: ${err.message || err}`, extractStart);
    const e = new Error(`Ekstraksi PDF gagal: ${err.message || err}`);
    e.stages = stages;
    e.stage = 'extract';
    throw e;
  }

  const rawText = (parsedPdf.text || '').trim();
  const numPages = parsedPdf.numpages || 1;
  if (rawText.length < 50) {
    addStage('extract', false, `Teks terlalu pendek (${rawText.length} karakter, ${numPages} hal) — terdeteksi scan gambar`, extractStart);
    const err = new Error('PDF ini hasil scan gambar, tidak bisa dibaca. Gunakan e-statement asli dari aplikasi bank.');
    err.stages = stages;
    err.stage = 'extract';
    throw err;
  }
  addStage('extract', true, `${rawText.length} karakter, ${numPages} halaman`, extractStart);

  // 2. Tahap Detect
  const detectStart = Date.now();
  const isSeaBank = rawText.toUpperCase().includes('SEABANK') || rawText.toUpperCase().includes('TABUNGAN - RINCIAN TRANSAKSI');
  const bankName = isSeaBank ? 'SeaBank' : 'Bank Umum / Lainnya';
  const year = parsePeriodeYear(rawText);
  addStage('detect', true, `Bank: ${bankName}, Tahun Periode: ${year}`, detectStart);

  // 3. Tahap Parse (deterministik SeaBank)
  const parseStart = Date.now();
  if (isSeaBank) {
    const seabankResults = parseSeabankText(rawText, year);
    if (seabankResults.length > 0) {
      addStage('parse', true, `${seabankResults.length} transaksi diekstrak via parser SeaBank (validasi rantai sukses)`, parseStart);
      return Object.assign(seabankResults, { data: seabankResults, log: stages });
    } else {
      addStage('parse', false, 'Parser SeaBank menghasilkan 0 baris valid atau validasi rantai gagal', parseStart);
    }
  }

  // 4. Tahap AI Fallback (Gemini)
  const aiStart = Date.now();
  try {
    const aiResults = await parseEStatementWithGemini(rawText, year);
    if (!aiResults || aiResults.length === 0) {
      addStage('ai_fallback', false, 'Parser AI tidak menemukan transaksi dalam teks e-statement', aiStart);
      const err = new Error('Parser tidak menemukan transaksi pada dokumen ini');
      err.stages = stages;
      err.stage = 'ai_fallback';
      throw err;
    }
    addStage('ai_fallback', true, `${aiResults.length} transaksi diekstrak via AI Gemini`, aiStart);
    return Object.assign(aiResults, { data: aiResults, log: stages });
  } catch (err) {
    addStage('ai_fallback', false, err.message || 'AI fallback gagal', aiStart);
    err.stages = stages;
    err.stage = err.stage || 'ai_fallback';
    throw err;
  }
}

module.exports = {
  parseEStatementPdf,
  parseSeabankText,
  parsePeriodeYear,
};
