const express = require('express');
const router = express.Router();
const { Transaksi, Akun } = require('../models');
const { parseTransaksiDariTeks, tanyaAIAdvisor } = require('../services/gemini');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// Chat dengan AI Advisor
router.post('/chat', async (req, res) => {
  try {
    const { pesan } = req.body;
    if (!pesan) return res.status(400).json({ error: 'Pesan tidak boleh kosong' });

    const uid = req.user.id;
    const bulanIni = new Date().toISOString().slice(0, 7);
    const [txs, akuns] = await Promise.all([
      Transaksi.find({ user_id: uid, tanggal: { $regex: `^${bulanIni}` } }),
      Akun.find({ user_id: uid }),
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

    const konteks = {
      bulanIni: bulanIni, pemasukan, pengeluaran,
      saldoBersih: pemasukan - pengeluaran, saldoTotal,
      rataHarian: hariIni > 0 ? Math.round(pengeluaran / hariIni) : 0,
      pengeluaranHariIni,
      budgetHarian: 100000, // Default, bisa diambil dari user settings nanti
      topKategoriPengeluaran: topKategori,
      sisaHariBulan: lastDay - hariIni,
      hariIni
    };

    if (cekApakahTransaksi(pesan)) {
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

    let validAkunId = akun_id || null;
    if (!validAkunId) {
      const firstAkun = await Akun.findOne({ user_id: req.user.id }).sort({ created_at: 1 });
      if (firstAkun) validAkunId = firstAkun._id;
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
  if (!t) return false;

  // Kalimat tanya / analisis / status / sapaan → jangan parse sebagai transaksi
  const kataAnalisis = [
    'bagaimana', 'gimana', 'berapa', 'analisis', 'analisa', 'ringkasan', 'laporan',
    'tips', 'hemat', 'saran', 'proyeksi', 'prediksi', 'akhir bulan', 'kondisi',
    'persentase', 'apakah', 'kenapa', 'mengapa', 'bolehkah', 'bisakah', 'keuangan',
    'keuanganku', 'keuangan saya', 'saldo', 'dompet', 'evaluasi', 'rekomendasi',
    'halo', 'hai', 'pagi', 'siang', 'malam', 'bantu', 'help'
  ];
  if (kataAnalisis.some(k => t.includes(k))) return false;

  // Kata kunci transaksi — harus ada kata kerja pencatatan transaksi
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

module.exports = router;
