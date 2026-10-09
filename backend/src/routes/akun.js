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

    // Reconcile saldo jika akun bersaldo 0 atau rusak tetapi transaksi riil ada
    const txRows = await Transaksi.find({ user_id: req.user.id });
    if (txRows.length > 0) {
      for (let a of rows) {
        const saldoTx = txRows
          .filter(t => !t.akun_id || String(t.akun_id) === String(a._id))
          .reduce((s, t) => s + (t.jenis === 'pemasukan' ? t.nominal : -t.nominal), 0);
        const perluReconcile = (a.saldo === 0 && saldoTx !== 0) ||
          (a.saldo < 0 && saldoTx > 0) ||
          (rows.length === 1 && a.saldo !== saldoTx);
        if (perluReconcile) {
          a.saldo = saldoTx;
          await Akun.findByIdAndUpdate(a._id, { saldo: saldoTx });
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
    const {
      nama, jenis, saldo, warna, ikon, local_id,
      target_nominal, target_tanggal,
      limit_kartu, tgl_cetak, tgl_tempo,
      gram, harga_beli_per_gram,
    } = req.body;
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
      target_nominal: target_nominal !== undefined && target_nominal !== null ? Number(target_nominal) : null,
      target_tanggal: target_tanggal || null,
      limit_kartu: limit_kartu !== undefined && limit_kartu !== null ? Number(limit_kartu) : null,
      tgl_cetak: tgl_cetak !== undefined && tgl_cetak !== null ? Number(tgl_cetak) : null,
      tgl_tempo: tgl_tempo !== undefined && tgl_tempo !== null ? Number(tgl_tempo) : null,
      gram: gram !== undefined && gram !== null ? Number(gram) : null,
      harga_beli_per_gram: harga_beli_per_gram !== undefined && harga_beli_per_gram !== null ? Number(harga_beli_per_gram) : null,
    });
    res.status(201).json({ data: { id: akun._id, ...akun.toObject() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const {
      nama, saldo, warna, ikon,
      target_nominal, target_tanggal,
      limit_kartu, tgl_cetak, tgl_tempo,
      gram, harga_beli_per_gram,
    } = req.body;
    const update = {};
    if (nama  !== undefined) update.nama  = nama;
    if (saldo !== undefined) update.saldo = Number(saldo);
    if (warna !== undefined) update.warna = warna;
    if (ikon  !== undefined) update.ikon  = ikon;
    if (target_nominal !== undefined) update.target_nominal = target_nominal !== null ? Number(target_nominal) : null;
    if (target_tanggal !== undefined) update.target_tanggal = target_tanggal;
    if (limit_kartu !== undefined) update.limit_kartu = limit_kartu !== null ? Number(limit_kartu) : null;
    if (tgl_cetak !== undefined) update.tgl_cetak = tgl_cetak !== null ? Number(tgl_cetak) : null;
    if (tgl_tempo !== undefined) update.tgl_tempo = tgl_tempo !== null ? Number(tgl_tempo) : null;
    if (gram !== undefined) update.gram = gram !== null ? Number(gram) : null;
    if (harga_beli_per_gram !== undefined) update.harga_beli_per_gram = harga_beli_per_gram !== null ? Number(harga_beli_per_gram) : null;

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
