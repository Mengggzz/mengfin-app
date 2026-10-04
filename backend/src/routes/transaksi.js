const express = require('express');
const router = express.Router();
const { Transaksi, Akun } = require('../models');
const { parseVoiceTranscription } = require('../services/voice_parser');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// GET semua transaksi (dengan filter)
router.get('/', async (req, res) => {
  try {
    const { bulan, tanggal, jenis, kategori, limit = 50 } = req.query;
    const filter = { user_id: req.user.id };

    if (bulan)    filter.tanggal = { $regex: `^${bulan}` };
    if (tanggal)  filter.tanggal = tanggal;
    if (jenis)    filter.jenis = jenis;
    if (kategori) filter.kategori = kategori;

    const rows = await Transaksi.find(filter)
      .sort({ tanggal: -1, created_at: -1 })
      .limit(parseInt(limit))
      .populate('akun_id', 'nama');

    const result = rows.map(t => ({
      id: t._id,
      tanggal: t.tanggal,
      jenis: t.jenis,
      nominal: t.nominal,
      kategori: t.kategori,
      deskripsi: t.deskripsi,
      metode_pembayaran: t.metode_pembayaran,
      akun_id: t.akun_id?._id || null,
      akun_nama: t.akun_id?.nama || null,
    }));

    res.json({ data: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET kalender
router.get('/kalender/:bulan', async (req, res) => {
  try {
    const { bulan } = req.params;
    const rows = await Transaksi.find({ user_id: req.user.id, tanggal: { $regex: `^${bulan}` } });

    const byDate = {};
    rows.forEach(t => {
      if (!byDate[t.tanggal]) {
        byDate[t.tanggal] = { tanggal: t.tanggal, total_pemasukan: 0, total_pengeluaran: 0, jumlah_transaksi: 0 };
      }
      if (t.jenis === 'pemasukan')   byDate[t.tanggal].total_pemasukan  += t.nominal;
      if (t.jenis === 'pengeluaran') byDate[t.tanggal].total_pengeluaran += t.nominal;
      byDate[t.tanggal].jumlah_transaksi++;
    });

    res.json({ data: Object.values(byDate).sort((a, b) => a.tanggal.localeCompare(b.tanggal)) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST tambah transaksi
router.post('/', async (req, res) => {
  try {
    const { tanggal, jenis, nominal, kategori, deskripsi, metode_pembayaran, akun_id } = req.body;

    if (!tanggal || !jenis || !nominal || !kategori) {
      return res.status(400).json({ error: 'Field wajib: tanggal, jenis, nominal, kategori' });
    }

    const tx = await Transaksi.create({
      user_id: req.user.id,
      tanggal, jenis,
      nominal: Number(nominal),
      kategori,
      deskripsi: deskripsi || '',
      metode_pembayaran: metode_pembayaran || 'tunai',
      akun_id: akun_id || null,
    });

    // Update saldo akun milik user
    if (akun_id) {
      const akun = await Akun.findOne({ _id: akun_id, user_id: req.user.id });
      if (akun) {
        const delta = jenis === 'pemasukan' ? Number(nominal) : -Number(nominal);
        await Akun.findByIdAndUpdate(akun_id, { $inc: { saldo: delta } });
      }
    }

    res.status(201).json({
      data: { id: tx._id, ...tx.toObject() },
      message: 'Transaksi berhasil ditambahkan'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT update transaksi
router.put('/:id', async (req, res) => {
  try {
    const { tanggal, jenis, nominal, kategori, deskripsi, metode_pembayaran } = req.body;
    const old = await Transaksi.findOne({ _id: req.params.id, user_id: req.user.id });
    if (!old) return res.status(404).json({ error: 'Transaksi tidak ditemukan' });

    if (old.akun_id) {
      const delta = old.jenis === 'pemasukan' ? -old.nominal : old.nominal;
      await Akun.findByIdAndUpdate(old.akun_id, { $inc: { saldo: delta } });
    }

    await Transaksi.findByIdAndUpdate(req.params.id, { tanggal, jenis, nominal: Number(nominal), kategori, deskripsi, metode_pembayaran });

    if (old.akun_id) {
      const delta = jenis === 'pemasukan' ? Number(nominal) : -Number(nominal);
      await Akun.findByIdAndUpdate(old.akun_id, { $inc: { saldo: delta } });
    }

    res.json({ message: 'Transaksi berhasil diupdate' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE transaksi
router.delete('/:id', async (req, res) => {
  try {
    const tx = await Transaksi.findOne({ _id: req.params.id, user_id: req.user.id });
    if (!tx) return res.status(404).json({ error: 'Transaksi tidak ditemukan' });

    if (tx.akun_id) {
      const delta = tx.jenis === 'pemasukan' ? -tx.nominal : tx.nominal;
      await Akun.findByIdAndUpdate(tx.akun_id, { $inc: { saldo: delta } });
    }

    await tx.deleteOne();
    res.json({ message: 'Transaksi berhasil dihapus' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Parse transkripsi suara
router.post('/voice-parse', async (req, res) => {
  try {
    const { transcription } = req.body;
    if (!transcription) return res.status(400).json({ error: 'Transkripsi diperlukan' });

    const parsed = await parseVoiceTranscription(transcription);
    if (!parsed) return res.status(400).json({ error: 'Gagal parse transkripsi' });

    res.json(parsed);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Konfirmasi & simpan transaksi dari voice parse
router.post('/voice-save', async (req, res) => {
  try {
    const uid = req.user.id;
    const { type, amount, description, category } = req.body;

    if (!type || !amount || !description || !category) {
      return res.status(400).json({ error: 'Data transaksi tidak lengkap' });
    }

    const today = new Date().toISOString().split('T')[0];
    const tx = await Transaksi.create({
      user_id: uid,
      tanggal: today,
      jenis: type === 'income' ? 'pemasukan' : 'pengeluaran',
      nominal: Number(amount),
      kategori: category,
      deskripsi: description,
      metode_pembayaran: 'voice'
    });

    res.status(201).json({
      message: `✅ Transaksi dicatat: ${description}`,
      data: tx
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
