const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { Transaksi, Akun } = require('../models');
const { parseVoiceTranscription } = require('../services/voice_parser');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

function isValidObjectId(id) {
  if (!id) return false;
  const s = String(id).trim();
  return mongoose.Types.ObjectId.isValid(s) && String(new mongoose.Types.ObjectId(s)) === s;
}

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
    const { tanggal, jenis, nominal, kategori, deskripsi, metode_pembayaran, akun_id, local_id } = req.body;

    if (!tanggal || !jenis || nominal === undefined || nominal === null || !kategori) {
      return res.status(400).json({ error: 'Field wajib: tanggal, jenis, nominal, kategori' });
    }

    // Idempotency: cegah duplikasi jika local_id sudah tercatat di cloud
    if (local_id) {
      const existing = await Transaksi.findOne({ user_id: req.user.id, local_id });
      if (existing) {
        return res.status(200).json({
          data: { id: existing._id, ...existing.toObject() },
          message: 'Transaksi sudah ada (idempotent)'
        });
      }
    }

    // Resolusi akun_id yang aman (bisa ObjectId asli atau local_id dompet)
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

    // Fallback: jika akun_id belum terhubung atau tidak ditemukan, hubungkan ke dompet default/pertama jika ada
    if (!validAkunId) {
      const defaultAkun = await Akun.findOne({ user_id: req.user.id }).sort({ jenis: 1, _id: 1 });
      if (defaultAkun) validAkunId = defaultAkun._id;
    }

    const tx = await Transaksi.create({
      user_id: req.user.id,
      tanggal, jenis,
      nominal: Number(nominal),
      kategori,
      deskripsi: deskripsi || '',
      metode_pembayaran: metode_pembayaran || 'tunai',
      akun_id: validAkunId,
      local_id: local_id || null,
    });

    // Update saldo akun milik user (pemasukan +, pengeluaran -)
    if (validAkunId) {
      const delta = jenis === 'pemasukan' ? Number(nominal) : -Number(nominal);
      await Akun.findByIdAndUpdate(validAkunId, { $inc: { saldo: delta } });
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
    const { tanggal, jenis, nominal, kategori, deskripsi, metode_pembayaran, akun_id } = req.body;
    let query = { user_id: req.user.id };
    if (isValidObjectId(req.params.id)) {
      query._id = req.params.id;
    } else {
      query.local_id = req.params.id;
    }

    const old = await Transaksi.findOne(query);
    if (!old) return res.status(404).json({ error: 'Transaksi tidak ditemukan' });

    let oldAkunId = old.akun_id;
    if (!oldAkunId) {
      const def = await Akun.findOne({ user_id: req.user.id }).sort({ jenis: 1, _id: 1 });
      if (def) oldAkunId = def._id;
    }

    if (oldAkunId) {
      const delta = old.jenis === 'pemasukan' ? -old.nominal : old.nominal;
      await Akun.findByIdAndUpdate(oldAkunId, { $inc: { saldo: delta } });
    }

    const updateData = {};
    if (tanggal !== undefined) updateData.tanggal = tanggal;
    if (jenis !== undefined) updateData.jenis = jenis;
    if (nominal !== undefined) updateData.nominal = Number(nominal);
    if (kategori !== undefined) updateData.kategori = kategori;
    if (deskripsi !== undefined) updateData.deskripsi = deskripsi;
    if (metode_pembayaran !== undefined) updateData.metode_pembayaran = metode_pembayaran;

    if (akun_id !== undefined) {
      if (isValidObjectId(akun_id)) {
        updateData.akun_id = akun_id;
      } else if (akun_id) {
        const akunByLocal = await Akun.findOne({ user_id: req.user.id, local_id: String(akun_id) });
        updateData.akun_id = akunByLocal ? akunByLocal._id : null;
      } else {
        updateData.akun_id = null;
      }
    }

    const updated = await Transaksi.findByIdAndUpdate(old._id, updateData, { new: true });

    const newAkunId = updated.akun_id || oldAkunId;
    if (newAkunId) {
      const delta = updated.jenis === 'pemasukan' ? Number(updated.nominal) : -Number(updated.nominal);
      await Akun.findByIdAndUpdate(newAkunId, { $inc: { saldo: delta } });
    }

    res.json({ message: 'Transaksi berhasil diupdate', data: { id: updated._id, ...updated.toObject() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE transaksi
router.delete('/:id', async (req, res) => {
  try {
    let query = { user_id: req.user.id };
    if (isValidObjectId(req.params.id)) {
      query._id = req.params.id;
    } else {
      query.local_id = req.params.id;
    }

    const tx = await Transaksi.findOne(query);
    if (!tx) return res.status(404).json({ error: 'Transaksi tidak ditemukan' });

    let targetAkunId = tx.akun_id;
    if (!targetAkunId) {
      const def = await Akun.findOne({ user_id: req.user.id }).sort({ jenis: 1, _id: 1 });
      if (def) targetAkunId = def._id;
    }

    if (targetAkunId) {
      const delta = tx.jenis === 'pemasukan' ? -tx.nominal : tx.nominal;
      await Akun.findByIdAndUpdate(targetAkunId, { $inc: { saldo: delta } });
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

    let validAkunId = req.body.akun_id || null;
    if (validAkunId && isValidObjectId(validAkunId)) {
      // ok
    } else if (validAkunId) {
      const akunByLocal = await Akun.findOne({ user_id: uid, local_id: String(validAkunId) });
      validAkunId = akunByLocal ? akunByLocal._id : null;
    }
    if (!validAkunId) {
      const defaultAkun = await Akun.findOne({ user_id: uid }).sort({ jenis: 1, _id: 1 });
      if (defaultAkun) validAkunId = defaultAkun._id;
    }

    const today = new Date().toISOString().split('T')[0];
    const jenis = type === 'income' ? 'pemasukan' : 'pengeluaran';
    const nominal = Number(amount);
    const tx = await Transaksi.create({
      user_id: uid,
      tanggal: today,
      jenis,
      nominal,
      kategori: category,
      deskripsi: description,
      metode_pembayaran: 'voice',
      akun_id: validAkunId,
    });

    if (validAkunId) {
      const delta = jenis === 'pemasukan' ? nominal : -nominal;
      await Akun.findByIdAndUpdate(validAkunId, { $inc: { saldo: delta } });
    }

    res.status(201).json({
      message: `✅ Transaksi dicatat: ${description}`,
      data: tx
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
