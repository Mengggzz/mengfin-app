const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const { Feedback } = require('../models');

router.use(authMiddleware);

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

router.post('/', async (req, res) => {
  try {
    const { jenis, judul, deskripsi, device_info, app_version } = req.body;

    // Validasi
    const cleanJenis = (jenis || '').trim();
    const cleanJudul = (judul || '').trim();
    const cleanDeskripsi = (deskripsi || '').trim();

    if (!cleanJenis || !cleanJudul || !cleanDeskripsi) {
      return res.status(400).json({ error: 'Jenis, judul, dan deskripsi wajib diisi.' });
    }

    if (cleanDeskripsi.length < 10) {
      return res.status(400).json({ error: 'Deskripsi minimal 10 karakter.' });
    }

    const normJenis = cleanJenis.toLowerCase() === 'saran' ? 'Saran' : 'Bug';
    const cleanDevice = (device_info || 'Perangkat tidak dikenal').trim();
    const cleanVersion = (app_version || 'v2.0.0').trim();

    // Waktu format lokal Indonesia YYYY-MM-DD HH:mm WIB
    const now = new Date();
    const waktuWIB = new Date(now.getTime() + 7 * 60 * 60 * 1000)
      .toISOString()
      .replace('T', ' ')
      .substring(0, 16);

    const botToken = process.env.TELEGRAM_BOT_TOKEN;
    const chatId = process.env.TELEGRAM_CHAT_ID;

    let telegramSent = false;
    let telegramError = null;

    if (botToken && chatId) {
      const headerIcon = normJenis === 'Bug' ? '🐞' : '💡';
      const headerTitle = normJenis === 'Bug' ? 'Laporan Bug' : 'Saran Fitur';
      const pelaporInfo = req.user?.email ? ` (${escapeHtml(req.user.email)})` : '';

      const text = `${headerIcon} <b>${headerTitle}</b> — MengFin ${escapeHtml(cleanVersion)}\n` +
        `<b>${escapeHtml(cleanJudul)}</b>\n\n` +
        `${escapeHtml(cleanDeskripsi)}\n\n` +
        `<i>Perangkat: ${escapeHtml(cleanDevice)} | ${waktuWIB} WIB</i>\n` +
        `<i>Pelapor: ${escapeHtml(req.user?.nama || 'Pengguna')}${pelaporInfo}</i>`;

      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);

        const tgRes = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id: chatId,
            text,
            parse_mode: 'HTML',
          }),
          signal: controller.signal,
        });
        clearTimeout(timeoutId);

        const tgData = await tgRes.json().catch(() => ({}));
        if (tgRes.ok && tgData.ok) {
          telegramSent = true;
        } else {
          telegramError = tgData.description || `HTTP ${tgRes.status}`;
          console.warn('[Feedback] Telegram Bot API error:', telegramError);
        }
      } catch (err) {
        telegramError = err.message || 'Network error';
        console.warn('[Feedback] Telegram fetch exception:', telegramError);
      }
    } else {
      telegramError = 'TELEGRAM_BOT_TOKEN atau TELEGRAM_CHAT_ID belum diset di environment';
    }

    // Selalu simpan ke database feedbacks (termasuk sebagai fallback jika Telegram gagal)
    const feedbackDoc = await Feedback.create({
      user_id: req.user.id,
      user_email: req.user.email || '',
      user_nama: req.user.nama || '',
      jenis: normJenis,
      judul: cleanJudul,
      deskripsi: cleanDeskripsi,
      device_info: cleanDevice,
      app_version: cleanVersion,
      telegram_sent: telegramSent,
      telegram_error: telegramError,
    });

    return res.json({
      status: 'ok',
      message: telegramSent
        ? 'Laporan terkirim ke developer 👍'
        : 'Laporan tersimpan di sistem 👍',
      id: feedbackDoc._id,
      telegram_sent: telegramSent,
    });
  } catch (err) {
    console.error('[Feedback] Internal error:', err);
    return res.status(500).json({ error: 'Gagal memproses laporan: ' + err.message });
  }
});

module.exports = router;
