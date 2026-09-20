const express = require('express');
const router = express.Router();
const { scanNota } = require('../services/gemini');

// Scan nota dari base64 image
router.post('/', async (req, res) => {
  const { imageBase64, mimeType } = req.body;
  if (!imageBase64) return res.status(400).json({ error: 'imageBase64 diperlukan' });

  const result = await scanNota(imageBase64, mimeType || 'image/jpeg');
  if (!result) return res.status(500).json({ error: 'Gagal memproses gambar nota' });

  res.json({ data: result, message: 'Nota berhasil discan' });
});

module.exports = router;
