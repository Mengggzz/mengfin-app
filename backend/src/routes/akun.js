const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { Akun, Transaksi } = require('../models');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

function isValidObjectId(id) {
  if (!id) return false;
  const s = String(id).trim();
  return mongoose.Types.ObjectId.isValid(s) && String(new mongoose.Types.ObjectId(s)) === s;
}

router.get('/', async (req, res) => {
  try {
    let rows = await Akun.find({ user_id: req.user.id }).sort({ jenis: 1, nama: 1 });
    if (rows.length === 0) {
      const defaultAkun = await Akun.create({
        user_id: req.user.id,
        nama: 'Dompet Utama',
        jenis: 'cashflow',
        saldo: 0,
        warna: '#2563EB',
        ikon: 'cashflow',
      });
      rows = [defaultAkun];
    }

    // Reconcile saldo jika akun bersaldo 0 tetapi transaksi riil ada
    const totalSaldoAkun = rows.reduce((s, a) => s + (a.saldo || 0), 0);
    if (totalSaldoAkun === 0) {
      const txRows = await Transaksi.find({ user_id: req.user.id });
      if (txRows.length > 0) {
        for (let a of rows) {
          const saldoTx = txRows
            .filter(t => !t.akun_id || String(t.akun_id) === String(a._id))
            .reduce((s, t) => s + (t.jenis === 'pemasukan' ? t.nominal : -t.nominal), 0);
          if (saldoTx !== 0) {
            a.saldo = saldoTx;
            await Akun.findByIdAndUpdate(a._id, { saldo: saldoTx });
          }
        }
      }
    }

    const totalSaldo = rows.reduce((s, a) => s + (a.saldo || 0), 0);
    res.json({ data: rows.map(a => ({ id: a._id, local_id: a.local_id, ...a.toObject() })), totalSaldo });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { nama, jenis, saldo, warna, ikon, local_id } = req.body;
    if (!nama) return res.status(400).json({ error: 'Nama dompet wajib diisi' });

    // Idempotency: cek jika dompet dengan local_id sudah ada
    if (local_id) {
      const existing = await Akun.findOne({ user_id: req.user.id, local_id });
      if (existing) {
        return res.status(200).json({
          data: { id: existing._id, ...existing.toObject() },
          message: 'Akun sudah ada (idempotent)'
        });
      }
    }

    const akun = await Akun.create({
      user_id: req.user.id,
      nama, jenis: jenis || 'bank',
      saldo: Number(saldo) || 0,
      warna: warna || '#2563EB',
      ikon: ikon || 'bank',
      local_id: local_id || null,
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

    let query = { user_id: req.user.id };
    if (isValidObjectId(req.params.id)) {
      query._id = req.params.id;
    } else {
      query.local_id = req.params.id;
    }

    const result = await Akun.findOneAndUpdate(query, update, { new: true });
    if (!result) return res.status(404).json({ error: 'Akun tidak ditemukan' });
    res.json({ message: 'Akun berhasil diupdate', data: { id: result._id, ...result.toObject() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    let query = { user_id: req.user.id };
    if (isValidObjectId(req.params.id)) {
      query._id = req.params.id;
    } else {
      query.local_id = req.params.id;
    }

    const result = await Akun.findOneAndDelete(query);
    if (!result) return res.status(404).json({ error: 'Akun tidak ditemukan' });

    // Lepaskan referensi akun_id pada transaksi yang pernah terkait
    await Transaksi.updateMany(
      { user_id: req.user.id, akun_id: result._id },
      { $set: { akun_id: null } }
    );

    res.json({ message: 'Akun berhasil dihapus' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
