const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { Transaksi, Akun, Anggaran } = require('../models');
const { parseTransaksiDariTeks, tanyaAIAdvisor } = require('../services/gemini');
const { authMiddleware } = require('../middleware/auth');
const { tebakKamus, tebakTipe } = require('../services/kategori');

router.use(authMiddleware);

function isValidObjectId(id) {
  if (!id) return false;
  const s = String(id).trim();
  return mongoose.Types.ObjectId.isValid(s) && String(new mongoose.Types.ObjectId(s)) === s;
}

// ── Fast Local Regex Parser (<1ms latency) ───────────────────────────────────
function fastParseTransaksi(teks) {
  if (!teks || typeof teks !== 'string') return null;
  const t = teks.trim();
  const lower = t.toLowerCase();

  // 1. Ekstrak metode pembayaran
  let metode = 'tunai';
  if (/\b(transfer|trf|tf|bca|mandiri|bri|bni|jago)\b/i.test(lower)) metode = 'transfer';
  else if (/\b(qris|qr)\b/i.test(lower)) metode = 'qris';
  else if (/\b(debit|kartu debit)\b/i.test(lower)) metode = 'debit';
  else if (/\b(kredit|cc|kartu kredit)\b/i.test(lower)) metode = 'kredit';
  else if (/\b(gopay|ovo|dana|shopeepay|spay|linkaja)\b/i.test(lower)) metode = 'transfer';

  // 2. Ekstrak nominal
  let nominal = 0;
  // Pola angka dengan multiplier (misal: 25rb, 50k, 1.5jt, 5 juta, 100 ribu, 25.000)
  const numMultiplierMatch = lower.match(/(\d+(?:[.,]\d+)?)\s*(ribu|juta|jt|rb|k)\b/i);
  const plainNumberMatch = lower.match(/(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d{4,9})\b/i);

  if (numMultiplierMatch) {
    let rawNum = parseFloat(numMultiplierMatch[1].replace(',', '.'));
    const unit = numMultiplierMatch[2].toLowerCase();
    if (unit === 'juta' || unit === 'jt') rawNum *= 1000000;
    else rawNum *= 1000;
    nominal = Math.round(rawNum);
  } else if (plainNumberMatch) {
    const rawDigits = plainNumberMatch[1].replace(/\./g, '');
    nominal = parseInt(rawDigits, 10) || 0;
  }

  if (nominal <= 0) return null;

  // 3. Tentukan jenis transaksi
  const isPemasukan = /\b(gajian|gaji|dapat transfer|terima|bonus|pemasukan|inflow|penjualan|omset)\b/i.test(lower);
  const jenis = isPemasukan ? 'pemasukan' : 'pengeluaran';

  // 4. Tebak kategori dan tipe menggunakan Kamus Komprehensif & Stemmer
  const kategori = tebakKamus(lower, !isPemasukan) || (isPemasukan ? 'Transfer' : 'Lainnya');
  const tipe = tebakTipe(lower, kategori, !isPemasukan);

  // 5. Ekstrak deskripsi ringkas
  let deskripsi = t
    .replace(/^(tolong|bantu|catat|masukkan|input|tambahkan)\s+/i, '')
    .replace(/\b(pakai|pake|via|lewat)\s+(tunai|cash|transfer|tf|qris|debit|kredit|gopay|ovo|dana)\b/gi, '')
    .replace(/(\d+(?:[.,]\d+)?)\s*(ribu|juta|jt|rb|k)\b/gi, '')
    .replace(/(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d{4,9})\b/gi, '')
    .trim();

  // Bersihkan kata kerja awal dari deskripsi (mis. "beli kopi" -> "Kopi")
  deskripsi = deskripsi.replace(/^(beli|bayar|makan|minum|jajan|order|pesan|topup|top up)\s+/i, '').trim();
  if (!deskripsi || deskripsi.length < 2) {
    deskripsi = kategori === 'Lainnya' ? (jenis === 'pemasukan' ? 'Pemasukan' : 'Pengeluaran') : kategori;
  } else {
    // Capitalize huruf pertama
    deskripsi = deskripsi.charAt(0).toUpperCase() + deskripsi.slice(1);
  }

  return {
    jenis,
    nominal,
    kategori,
    tipe,
    deskripsi,
    metode_pembayaran: metode,
    tanggal: new Date().toISOString().split('T')[0]
  };
}

// Chat dengan AI Advisor
router.post('/chat', async (req, res) => {
  try {
    const { pesan } = req.body;
    if (!pesan) return res.status(400).json({ error: 'Pesan tidak boleh kosong' });

    const uid = req.user.id;
    const bulanIni = new Date().toISOString().slice(0, 7);

    // 1. Fast Pattern Matching untuk transaksi (respons instan 0ms)
    if (cekApakahTransaksi(pesan)) {
      const fastParsed = fastParseTransaksi(pesan);
      if (fastParsed && fastParsed.nominal > 0) {
        return res.json({
          tipe: 'transaksi_preview',
          data: fastParsed,
          pesan: `Saya mendeteksi transaksi:\n*${fastParsed.deskripsi}*\n💰 Rp ${Number(fastParsed.nominal).toLocaleString('id-ID')}\n📁 ${fastParsed.kategori}\n💳 ${fastParsed.metode_pembayaran}\n\nKonfirmasi untuk menyimpan?`
        });
      }

      // Jika fast parser tidak pasti, coba Gemini parser
      try {
        const parsed = await parseTransaksiDariTeks(pesan);
        if (parsed && parsed.nominal && Number(parsed.nominal) > 0 && parsed.deskripsi && parsed.deskripsi.trim().length > 0) {
          return res.json({
            tipe: 'transaksi_preview',
            data: parsed,
            pesan: `Saya mendeteksi transaksi:\n*${parsed.deskripsi}*\n💰 Rp ${Number(parsed.nominal).toLocaleString('id-ID')}\n📁 ${parsed.kategori}\n💳 ${parsed.metode_pembayaran}\n\nKonfirmasi untuk menyimpan?`
          });
        }
      } catch (_) {}
    }

    // 2. Ambil data keuangan lengkap secara paralel
    const [txs, akuns, anggarans, recentTxs] = await Promise.all([
      Transaksi.find({ user_id: uid, tanggal: { $regex: `^${bulanIni}` } }),
      Akun.find({ user_id: uid }),
      Anggaran.find({ user_id: uid, periode: bulanIni }),
      Transaksi.find({ user_id: uid }).sort({ tanggal: -1, created_at: -1 }).limit(10),
    ]);

    const pemasukan   = txs.filter(t => t.jenis === 'pemasukan').reduce((s, t) => s + t.nominal, 0);
    const pengeluaran = txs.filter(t => t.jenis === 'pengeluaran').reduce((s, t) => s + t.nominal, 0);
    const saldoTotal  = akuns.reduce((s, a) => s + (a.saldo || 0), 0);

    const katMap = {};
    txs.filter(t => t.jenis === 'pengeluaran').forEach(t => {
      katMap[t.kategori] = (katMap[t.kategori] || 0) + t.nominal;
    });
    const topKategori = Object.entries(katMap)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([kategori, total]) => ({ kategori, total }));

    const today = new Date();
    const hariIni = today.getDate();
    const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    const todayStr = today.toISOString().split('T')[0];
    
    const pengeluaranHariIni = txs
      .filter(t => t.jenis === 'pengeluaran' && t.tanggal === todayStr)
      .reduce((s, t) => s + t.nominal, 0);

    const totalAnggaran = anggarans.reduce((s, a) => s + (a.batas || 0), 0);
    const budgetHarian = totalAnggaran > 0 ? Math.round(totalAnggaran / lastDay) : 100000;

    const anggaranList = anggarans.map(a => {
      const terpakai = katMap[a.kategori] || 0;
      return {
        kategori: a.kategori,
        batas: a.batas,
        terpakai,
        persentase: Math.round((terpakai / (a.batas || 1)) * 100)
      };
    });

    const konteks = {
      bulanIni: bulanIni,
      pemasukan,
      pengeluaran,
      saldoBersih: pemasukan - pengeluaran,
      saldoTotal,
      rataHarian: hariIni > 0 ? Math.round(pengeluaran / hariIni) : 0,
      pengeluaranHariIni,
      budgetHarian,
      topKategoriPengeluaran: topKategori,
      anggaranList,
      riwayatTransaksi: recentTxs.map(t => ({
        tanggal: t.tanggal,
        jenis: t.jenis,
        nominal: t.nominal,
        kategori: t.kategori,
        deskripsi: t.deskripsi
      })),
      sisaHariBulan: lastDay - hariIni,
      hariIni
    };

    const jawaban = await tanyaAIAdvisor(pesan, konteks);
    res.json({ tipe: 'jawaban', pesan: jawaban });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Konfirmasi simpan transaksi dari AI chat
router.post('/konfirmasi-transaksi', async (req, res) => {
  try {
    const { tanggal, jenis, nominal, kategori, deskripsi, metode_pembayaran, akun_id } = req.body;
    if (!tanggal || !jenis || nominal === undefined || nominal === null || !kategori) {
      return res.status(400).json({ error: 'Field transaksi tidak lengkap' });
    }

    let validAkunId = null;
    if (akun_id) {
      const aidStr = String(akun_id).trim();
      if (isValidObjectId(aidStr)) {
        const akunExists = await Akun.findOne({ _id: aidStr, user_id: req.user.id });
        if (akunExists) validAkunId = aidStr;
      } else {
        const akunByLocal = await Akun.findOne({ user_id: req.user.id, local_id: aidStr });
        if (akunByLocal) validAkunId = akunByLocal._id;
      }
    }

    if (!validAkunId) {
      let defaultAkun = await Akun.findOne({ user_id: req.user.id }).sort({ jenis: 1, _id: 1 });
      if (!defaultAkun) {
        defaultAkun = await Akun.create({
          user_id: req.user.id,
          nama: 'Dompet Utama',
          jenis: 'cashflow',
          saldo: 0,
          warna: '#2563EB',
          ikon: 'cashflow',
        });
      }
      validAkunId = defaultAkun._id;
    }

    const tx = await Transaksi.create({
      user_id: req.user.id,
      tanggal, jenis,
      nominal: Number(nominal),
      kategori, deskripsi: deskripsi || '',
      metode_pembayaran: metode_pembayaran || 'tunai',
      akun_id: validAkunId,
    });

    if (validAkunId) {
      const delta = jenis === 'pemasukan' ? Number(nominal) : -Number(nominal);
      await Akun.findByIdAndUpdate(validAkunId, { $inc: { saldo: delta } });
    }

    res.status(201).json({
      message: `✅ Transaksi berhasil dicatat!\n*${deskripsi || kategori}* — Rp ${Number(nominal).toLocaleString('id-ID')}`,
      id: tx._id,
      data: { id: tx._id, ...tx.toObject() }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function cekApakahTransaksi(teks) {
  const t = (teks || '').toLowerCase().trim();
  if (!t || t.length > 85) return false;

  // Kalimat tanya / konsultasi / evaluasi (jangan dicatat sebagai transaksi baru)
  const isQuestionOrAnalysis = /(\?|\b(bagaimana|gimana|berapa|apa|apakah|kenapa|mengapa|analisis|analisa|laporan|ringkasan|tips|saran|proyeksi|prediksi|cek saldo|kondisi|menurutmu|menurut anda|menurut kamu|apakah wajar|apakah bijak|apakah boros|apakah aman|apakah cukup|apakah bisa|tolong jelaskan|jelaskan|hitung|hitungkan|hitungin|konsultasi|tanya|kemarin|tadi|minggu lalu|bulan lalu|kalau|jika|apabila|sebaiknya|harus|perlukah|layak|apa itu|maksudnya|definisi)\b)/i.test(t);
  if (isQuestionOrAnalysis) return false;

  // Kata kunci transaksi
  const kata = [
    'beli', 'bayar', 'makan', 'minum', 'jajan', 'kopi', 'transfer', 'kirim',
    'top up', 'topup', 'belanja', 'gajian', 'gaji', 'bonus',
    'pesan', 'order', 'parkir', 'bensin', 'tarik', 'setor',
    'bayarin', 'sewa', 'tagihan', 'listrik', 'pulsa'
  ];
  const hasKeyword = kata.some(k => new RegExp(`\\b${k}\\b`).test(t));
  if (!hasKeyword) return false;

  // Nominal: harus ada angka atau nominal terbilang yang valid
  const hasNumber = /\d+/.test(t) ||
    /\b(ribu|juta|jt|rb|k)\b/.test(t) ||
    /\b(satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh)\s*(ribu|juta|rb|jt|k)\b/.test(t);

  return hasNumber;
}

router.fastParseTransaksi = fastParseTransaksi;
router.cekApakahTransaksi = cekApakahTransaksi;

module.exports = router;
