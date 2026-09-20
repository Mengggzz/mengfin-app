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
      bulan: bulanIni, pemasukan, pengeluaran,
      saldoBersih: pemasukan - pengeluaran, saldoTotal,
      rataHarian: hariIni > 0 ? Math.round(pengeluaran / hariIni) : 0,
      pengeluaranHariIni,
      budgetHarian: 100000, // Default, bisa diambil dari user settings nanti
      topKategoriPengeluaran: topKategori,
      sisaHariBulan: lastDay - hariIni,
      hariIni
    };

    if (cekApakahTransaksi(pesan)) {
      const parsed = await parseTransaksiDariTeks(pesan);
      if (parsed) {
        return res.json({
          tipe: 'transaksi_preview',
          data: parsed,
          pesan: `Saya mendeteksi transaksi:\n*${parsed.deskripsi}*\n💰 Rp ${Number(parsed.nominal).toLocaleString('id-ID')}\n📁 ${parsed.kategori}\n💳 ${parsed.metode_pembayaran}\n\nKonfirmasi untuk menyimpan?`
        });
      }
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
    const { tanggal, jenis, nominal, kategori, deskripsi, metode_pembayaran } = req.body;
    const tx = await Transaksi.create({
      user_id: req.user.id,
      tanggal, jenis,
      nominal: Number(nominal),
      kategori, deskripsi,
      metode_pembayaran: metode_pembayaran || 'tunai',
    });
    res.status(201).json({
      message: `✅ Transaksi berhasil dicatat!\n*${deskripsi}* — Rp ${Number(nominal).toLocaleString('id-ID')}`,
      id: tx._id
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function cekApakahTransaksi(teks) {
  const kata = ['beli', 'bayar', 'makan', 'jajan', 'transfer', 'kirim', 'isi', 'top up', 'belanja', 'gajian', 'gaji', 'dapat', 'terima', 'bonus', 'masuk'];
  return kata.some(k => teks.toLowerCase().includes(k));
}

module.exports = router;
