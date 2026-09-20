const express = require('express');
const router = express.Router();
const { Transaksi, Akun, Anggaran } = require('../models');
const { hitungHealthScore, prediksiSaldoAman } = require('../services/finance');
const { generateInsight } = require('../services/gemini');
const { calculateRingHudStatus } = require('../services/ring_hud');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// Dashboard summary lengkap
router.get('/dashboard', async (req, res) => {
  try {
    const uid = req.user.id;
    const now = new Date();
    const bulanIni  = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const bulanLalu = `${prevMonth.getFullYear()}-${String(prevMonth.getMonth() + 1).padStart(2, '0')}`;

    const [txIni, txLalu, akuns, anggaran] = await Promise.all([
      Transaksi.find({ user_id: uid, tanggal: { $regex: `^${bulanIni}` } }),
      Transaksi.find({ user_id: uid, tanggal: { $regex: `^${bulanLalu}` } }),
      Akun.find({ user_id: uid }),
      Anggaran.find({ user_id: uid, periode: bulanIni }),
    ]);

    const sumTx = (txs, jenis) => txs.filter(t => t.jenis === jenis).reduce((s, t) => s + t.nominal, 0);

    const ini  = { pemasukan: sumTx(txIni, 'pemasukan'),  pengeluaran: sumTx(txIni, 'pengeluaran') };
    const lalu = { pemasukan: sumTx(txLalu, 'pemasukan'), pengeluaran: sumTx(txLalu, 'pengeluaran') };

    const saldoTotal = akuns.reduce((s, a) => s + (a.saldo || 0), 0);

    const anggaranDenganUsage = anggaran.map(ang => {
      const terpakai = txIni
        .filter(t => t.kategori === ang.kategori && t.jenis === 'pengeluaran')
        .reduce((s, t) => s + t.nominal, 0);
      return { ...ang.toObject(), terpakai };
    });

    const health  = hitungHealthScore(ini.pemasukan, ini.pengeluaran, saldoTotal, anggaranDenganUsage);
    const prediksi = prediksiSaldoAman(saldoTotal, ini.pengeluaran, now.getDate());

    // Mingguan
    const startOfWeek = new Date(now);
    const dayOfWeek = now.getDay() === 0 ? 6 : now.getDay() - 1;
    startOfWeek.setDate(now.getDate() - dayOfWeek);
    startOfWeek.setHours(0, 0, 0, 0);
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);

    const sowStr = startOfWeek.toISOString().split('T')[0];
    const eowStr = endOfWeek.toISOString().split('T')[0];

    const startPrevWeek = new Date(startOfWeek);
    startPrevWeek.setDate(startPrevWeek.getDate() - 7);
    const endPrevWeek = new Date(startPrevWeek);
    endPrevWeek.setDate(endPrevWeek.getDate() + 6);

    const [weekTx, prevWeekTx] = await Promise.all([
      Transaksi.find({ user_id: uid, tanggal: { $gte: sowStr, $lte: eowStr } }),
      Transaksi.find({ user_id: uid, tanggal: { $gte: startPrevWeek.toISOString().split('T')[0], $lte: endPrevWeek.toISOString().split('T')[0] } }),
    ]);

    const mingguIniPengeluaran = sumTx(weekTx, 'pengeluaran');
    const mingguIniPemasukan   = sumTx(weekTx, 'pemasukan');
    const mingguLaluPengeluaran = sumTx(prevWeekTx, 'pengeluaran');

    const kenaikan = mingguLaluPengeluaran > 0
      ? Math.round(((mingguIniPengeluaran - mingguLaluPengeluaran) / mingguLaluPengeluaran) * 100)
      : 0;

    const katMap = {};
    weekTx.filter(t => t.jenis === 'pengeluaran').forEach(t => {
      katMap[t.kategori] = (katMap[t.kategori] || 0) + t.nominal;
    });
    const kategoriTerbesar = Object.entries(katMap).sort((a, b) => b[1] - a[1])[0];

    res.json({
      bulanIni:  { ...ini, bulan: bulanIni },
      bulanLalu: { ...lalu, bulan: bulanLalu },
      saldoTotal,
      health,
      prediksi,
      mingguIni: {
        pengeluaran: mingguIniPengeluaran,
        pemasukan:   mingguIniPemasukan,
        rataHarian:  Math.round(mingguIniPengeluaran / 7),
        kenaikanDariBulanLalu: kenaikan,
        kategoriTerbesar: kategoriTerbesar ? kategoriTerbesar[0] : '-',
        periode: `${startOfWeek.toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })} – ${endOfWeek.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })}`
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Laporan bulanan (6 bulan terakhir)
router.get('/bulanan', async (req, res) => {
  try {
    const cutoff = new Date();
    cutoff.setMonth(cutoff.getMonth() - 6);
    const cutoffStr = cutoff.toISOString().split('T')[0];

    const txs = await Transaksi.find({ user_id: req.user.id, tanggal: { $gte: cutoffStr } });
    const byMonth = {};
    txs.forEach(t => {
      const bulan = t.tanggal.slice(0, 7);
      if (!byMonth[bulan]) byMonth[bulan] = { bulan, pemasukan: 0, pengeluaran: 0 };
      if (t.jenis === 'pemasukan')   byMonth[bulan].pemasukan   += t.nominal;
      if (t.jenis === 'pengeluaran') byMonth[bulan].pengeluaran += t.nominal;
    });

    const result = Object.values(byMonth)
      .sort((a, b) => a.bulan.localeCompare(b.bulan))
      .map(r => ({ ...r, saldoBersih: r.pemasukan - r.pengeluaran }));

    res.json({ data: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Insight AI
router.get('/insight', async (req, res) => {
  try {
    const bulanIni = new Date().toISOString().slice(0, 7);
    const txs = await Transaksi.find({ user_id: req.user.id, tanggal: { $regex: `^${bulanIni}` } });

    const sumTx = (txs, jenis) => txs.filter(t => t.jenis === jenis).reduce((s, t) => s + t.nominal, 0);
    const pemasukan   = sumTx(txs, 'pemasukan');
    const pengeluaran = sumTx(txs, 'pengeluaran');

    const katMap = {};
    txs.filter(t => t.jenis === 'pengeluaran').forEach(t => {
      katMap[t.kategori] = (katMap[t.kategori] || 0) + t.nominal;
    });
    const topKategori = Object.entries(katMap)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([kategori, total]) => ({ kategori, total }));

    const insight = await generateInsight({ pemasukan, pengeluaran, topKategori, bulan: bulanIni });
    res.json({ data: insight });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Interactive Ring HUD untuk daily budget status
router.get('/ring-hud', async (req, res) => {
  try {
    const uid = req.user.id;
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    // Ambil transaksi hari ini
    const todayTxs = await Transaksi.find({
      user_id: uid,
      tanggal: todayStr,
      jenis: 'pengeluaran'
    });

    const todaySpent = todayTxs.reduce((s, t) => s + t.nominal, 0);

    // Default daily limit 100k (bisa di-override dari settings user nanti)
    const dailyLimit = 100000;

    const ringData = calculateRingHudStatus(todaySpent, dailyLimit);
    res.json(ringData);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
