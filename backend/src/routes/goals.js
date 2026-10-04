const express = require('express');
const router = express.Router();
const { Goal } = require('../models');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

const pMap = { tinggi: 3, sedang: 2, rendah: 1 };

router.get('/', async (req, res) => {
  try {
    const goals = await Goal.find({ user_id: req.user.id }).sort({ created_at: -1 });
    const sorted = goals
      .map(g => ({ id: g._id, ...g.toObject() }))
      .sort((a, b) => (pMap[b.prioritas] || 2) - (pMap[a.prioritas] || 2));
    res.json({ data: sorted });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const { nama, target, terkumpul, deadline, prioritas, nabung_per_bulan, catatan } = req.body;
    const goal = await Goal.create({
      user_id: req.user.id,
      nama, target: Number(target),
      terkumpul: Number(terkumpul) || 0,
      deadline: deadline || null,
      prioritas: prioritas || 'sedang',
      nabung_per_bulan: Number(nabung_per_bulan) || 0,
      catatan: catatan || '',
    });
    res.status(201).json({ data: { id: goal._id, ...goal.toObject() } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id/progres', async (req, res) => {
  try {
    const { tambah } = req.body;
    const goal = await Goal.findOne({ _id: req.params.id, user_id: req.user.id });
    if (!goal) return res.status(404).json({ error: 'Goal tidak ditemukan' });

    goal.terkumpul = Math.min(goal.target, (goal.terkumpul || 0) + Number(tambah));
    await goal.save();
    res.json({ message: 'Progres berhasil diupdate', terkumpul: goal.terkumpul });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { nama, target, deadline, prioritas, nabung_per_bulan, catatan } = req.body;
    const update = {};
    if (nama             !== undefined) update.nama             = nama;
    if (target           !== undefined) update.target           = Number(target);
    if (deadline         !== undefined) update.deadline         = deadline;
    if (prioritas        !== undefined) update.prioritas        = prioritas;
    if (nabung_per_bulan !== undefined) update.nabung_per_bulan = Number(nabung_per_bulan);
    if (catatan          !== undefined) update.catatan          = catatan;
    const result = await Goal.findOneAndUpdate({ _id: req.params.id, user_id: req.user.id }, update);
    if (!result) return res.status(404).json({ error: 'Goal tidak ditemukan' });
    res.json({ message: 'Goal berhasil diupdate' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const result = await Goal.findOneAndDelete({ _id: req.params.id, user_id: req.user.id });
    if (!result) return res.status(404).json({ error: 'Goal tidak ditemukan' });
    res.json({ message: 'Goal berhasil dihapus' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
