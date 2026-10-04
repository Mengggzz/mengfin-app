const express = require('express');
const router = express.Router();
const { Anggaran, Transaksi } = require('../models');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const uid = req.user.id;
    const periode = req.query.periode || new Date().toISOString().slice(0, 7);
    const anggaran = await Anggaran.find({ user_id: uid, periode });

    const result = await Promise.all(anggaran.map(async (ang) => {
      const txs = await Transaksi.find({
        user_id: uid,
        kategori: ang.kategori,
        tanggal: { $regex: `^${periode}` },
        jenis: 'pengeluaran',
      });
      const terpakai = txs.reduce((sum, t) => sum + (t.nominal || 0), 0);
      return {
        id: ang._id,
        kategori: ang.kategori,
        batas: ang.batas,
        periode: ang.periode,
        terpakai,
        persentase: ang.batas > 0 ? Math.round((terpakai / ang.batas) * 100) : 0,
      };
    }));

    res.json({ data: result, periode });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { kategori, batas, periode } = req.body;
    const p = periode || new Date().toISOString().slice(0, 7);
    const ang = await Anggaran.create({ user_id: req.user.id, kategori, batas: Number(batas), periode: p });
    res.status(201).json({ data: { id: ang._id, ...ang.toObject() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { batas } = req.body;
    const result = await Anggaran.findOneAndUpdate(
      { _id: req.params.id, user_id: req.user.id },
      { batas: Number(batas) }
    );
    if (!result) return res.status(404).json({ error: 'Anggaran tidak ditemukan' });
    res.json({ message: 'Anggaran berhasil diupdate' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const result = await Anggaran.findOneAndDelete({ _id: req.params.id, user_id: req.user.id });
    if (!result) return res.status(404).json({ error: 'Anggaran tidak ditemukan' });
    res.json({ message: 'Anggaran berhasil dihapus' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
