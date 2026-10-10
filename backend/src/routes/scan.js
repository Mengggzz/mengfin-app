const express = require('express');
const router = express.Router();
const { scanNota, scanMutasi } = require('../services/gemini');
const { parseEStatementPdf } = require('../services/estatement');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// Scan nota/struk dari base64 image → kembalikan data transaksi terstruktur
// (belum disimpan; app menampilkan preview dulu sebelum user konfirmasi).
router.post('/', async (req, res) => {
  try {
    const { imageBase64, mimeType } = req.body;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return res.status(400).json({ error: 'imageBase64 diperlukan' });
    }
    // Buang prefix data URL kalau ada (data:image/jpeg;base64,....)
    const base64 = imageBase64.includes(',')
      ? imageBase64.split(',').pop()
      : imageBase64;

    if (base64.length < 100) {
      return res.status(400).json({ error: 'Gambar terlalu kecil / tidak valid' });
    }

    const result = await scanNota(base64, mimeType || 'image/jpeg');

    if (!result) {
      console.error('Scan nota gagal: hasil null dari model');
      return res.status(502).json({
        error: 'Gagal membaca struk. Pastikan foto jelas, tidak blur, dan pencahayaan cukup.',
      });
    }
    if (!result.nominal || result.nominal <= 0) {
      return res.status(422).json({
        error: 'Total pada struk tidak terbaca. Coba foto ulang dengan struk memenuhi frame.',
        data: result,
      });
    }

    res.json({ data: result, message: 'Struk berhasil dibaca' });
  } catch (err) {
    console.error('Scan route error:', err.message || err);
    res.status(500).json({ error: 'Terjadi kesalahan saat memproses struk' });
  }
});

// Scan bukti transfer / riwayat mutasi bank dari base64 screenshot
router.post('/mutasi', async (req, res) => {
  try {
    const { imageBase64, mimeType } = req.body;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return res.status(400).json({ error: 'imageBase64 diperlukan' });
    }
    const base64 = imageBase64.includes(',')
      ? imageBase64.split(',').pop()
      : imageBase64;

    if (base64.length < 100) {
      return res.status(400).json({ error: 'Gambar terlalu kecil / tidak valid' });
    }

    const results = await scanMutasi(base64, mimeType || 'image/jpeg');

    if (!results || results.length === 0) {
      console.error('Scan mutasi gagal: 0 transaksi terdeteksi');
      return res.status(422).json({
        error: 'Tidak ditemukan transaksi mutasi pada screenshot ini. Pastikan gambar jelas.',
        data: [],
      });
    }

    res.json({ data: results, message: `${results.length} transaksi mutasi terdeteksi` });
  } catch (err) {
    console.error('Scan mutasi route error:', err.message || err);
    res.status(500).json({ error: 'Terjadi kesalahan saat memproses screenshot mutasi' });
  }
});

// Import e-statement PDF (SeaBank, BCA, Mandiri, dll)
router.post('/estatement', async (req, res) => {
  try {
    const { pdfBase64 } = req.body;
    if (!pdfBase64 || typeof pdfBase64 !== 'string') {
      return res.status(400).json({ error: 'pdfBase64 diperlukan' });
    }

    const cleanBase64 = pdfBase64.includes(',') ? pdfBase64.split(',').pop() : pdfBase64;
    const buffer = Buffer.from(cleanBase64, 'base64');

    if (buffer.length > 10 * 1024 * 1024) {
      return res.status(400).json({ error: 'Ukuran file melebihi batas 10 MB' });
    }

    const result = await parseEStatementPdf(buffer);
    const results = Array.isArray(result) ? result : (result.data || []);
    const stages = result.log || [];

    if (!results || results.length === 0) {
      return res.status(422).json({
        error: 'Tidak ditemukan transaksi pada e-statement PDF ini.',
        data: [],
        log: stages,
      });
    }

    res.json({
      data: results,
      log: stages,
      message: `${results.length} transaksi e-statement terdeteksi`,
    });
  } catch (err) {
    console.error('Import estatement error:', err.message || err);
    const msg = err.message || 'Terjadi kesalahan saat memproses e-statement PDF';
    res.status(422).json({
      error: msg,
      failed_stage: err.stage,
      log: err.stages || [],
    });
  }
});

module.exports = router;
