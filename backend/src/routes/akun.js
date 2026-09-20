const express = require('express');
const router = express.Router();
const { Akun } = require('../models');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const rows = await Akun.find({ user_id: req.user.id }).sort({ jenis: 1, nama: 1 });
    const totalSaldo = rows.reduce((s, a) => s + (a.saldo || 0), 0);
    res.json({ data: rows.map(a => ({ id: a._id, ...a.toObject() })), totalSaldo });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { nama, jenis, saldo, warna, ikon } = req.body;
    const akun = await Akun.create({
      user_id: req.user.id,
      nama, jenis: jenis || 'bank',
      saldo: Number(saldo) || 0,
      warna: warna || '#2563EB',
      ikon: ikon || 'bank',
    });
    res.status(201).json({ data: { id: akun._id, ...akun.toObject() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { nama, saldo, warna, ikon } = req.body;
    const update = {};
    if (nama  !== undefined) update.nama  = nama;
    if (saldo !== undefined) update.saldo = Number(saldo);
    if (warna !== undefined) update.warna = warna;
    if (ikon  !== undefined) update.ikon  = ikon;
    const result = await Akun.findOneAndUpdate({ _id: req.params.id, user_id: req.user.id }, update);
    if (!result) return res.status(404).json({ error: 'Akun tidak ditemukan' });
    res.json({ message: 'Akun berhasil diupdate' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const result = await Akun.findOneAndDelete({ _id: req.params.id, user_id: req.user.id });
    if (!result) return res.status(404).json({ error: 'Akun tidak ditemukan' });
    res.json({ message: 'Akun berhasil dihapus' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
