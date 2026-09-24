const express = require('express');
const router = express.Router();
const { Transaksi, Akun, Anggaran } = require('../models');
const { hitungHealthScore, prediksiSaldoAman } = require('../services/finance');
const { generateInsight, generateNarasiLaporan } = require('../services/gemini');
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

// Narasi AI dari laporan periode tertentu (?bulan=YYYY-MM)
router.get('/narasi', async (req, res) => {
  try {
    const uid = req.user.id;
    const bulan = /^\d{4}-\d{2}$/.test(req.query.bulan || '')
      ? req.query.bulan
      : new Date().toISOString().slice(0, 7);

    const prev = new Date(Number(bulan.slice(0, 4)), Number(bulan.slice(5, 7)) - 2, 1);
    const bulanLalu = `${prev.getFullYear()}-${String(prev.getMonth() + 1).padStart(2, '0')}`;

    const [txIni, txLalu] = await Promise.all([
      Transaksi.find({ user_id: uid, tanggal: { $regex: `^${bulan}` } }),
      Transaksi.find({ user_id: uid, tanggal: { $regex: `^${bulanLalu}` } }),
    ]);

    if (txIni.length === 0) {
      return res.json({
        data: {
          narasi: `Belum ada transaksi tercatat di periode ${bulan}. Catat transaksi dulu supaya saya bisa membuat analisis yang berguna.`,
          kosong: true,
        },
      });
    }

    const sum = (txs, jenis) =>
      txs.filter(t => t.jenis === jenis).reduce((s, t) => s + t.nominal, 0);

    const pemasukan = sum(txIni, 'pemasukan');
    const pengeluaran = sum(txIni, 'pengeluaran');

    const katMap = {};
    txIni.filter(t => t.jenis === 'pengeluaran').forEach(t => {
      katMap[t.kategori] = (katMap[t.kategori] || 0) + t.nominal;
    });
    const kategori = Object.entries(katMap)
      .sort((a, b) => b[1] - a[1])
      .map(([nama, total]) => ({
        nama,
        total,
        persen: pengeluaran > 0 ? Math.round((total / pengeluaran) * 100) : 0,
      }));

    // Rata-rata harian & hari paling boros
    const hariMap = {};
    txIni.filter(t => t.jenis === 'pengeluaran').forEach(t => {
      hariMap[t.tanggal] = (hariMap[t.tanggal] || 0) + t.nominal;
    });
    const hariArr = Object.entries(hariMap).sort((a, b) => b[1] - a[1]);
    const hariBoros = hariArr[0] ? { tanggal: hariArr[0][0], total: hariArr[0][1] } : null;
    const jumlahHariAktif = hariArr.length;

    const data = {
      periode: bulan,
      pemasukan,
      pengeluaran,
      saldoBersih: pemasukan - pengeluaran,
      jumlahTransaksi: txIni.length,
      rataPengeluaranHarian: jumlahHariAktif > 0
        ? Math.round(pengeluaran / jumlahHariAktif) : 0,
      hariPalingBoros: hariBoros,
      kategoriPengeluaran: kategori.slice(0, 6),
      pembandingBulanLalu: {
        bulan: bulanLalu,
        pemasukan: sum(txLalu, 'pemasukan'),
        pengeluaran: sum(txLalu, 'pengeluaran'),
      },
    };

    const narasi = await generateNarasiLaporan(data);
    if (!narasi) {
      return res.status(502).json({ error: 'Gagal membuat narasi, coba lagi sebentar lagi.' });
    }
    res.json({ data: { narasi, kosong: false } });
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
