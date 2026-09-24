const express = require('express');
const router = express.Router();
const { scanNota } = require('../services/gemini');
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

module.exports = router;
