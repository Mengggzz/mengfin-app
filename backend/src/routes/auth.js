const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const { User } = require('../models');
const { authMiddleware, JWT_SECRET } = require('../middleware/auth');

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const client = new OAuth2Client(GOOGLE_CLIENT_ID);

/**
 * POST /api/auth/google
 * Mendukung dua mode:
 *   1. { idToken }                          — dari One Tap / mobile
 *   2. { accessToken, googleId, email, ... } — dari OAuth2 web popup
 */
router.post('/google', async (req, res) => {
  try {
    const { idToken, accessToken, googleId, email, nama, foto } = req.body;

    let google_id, userEmail, userName, userFoto;

    if (idToken) {
      // ─── Mode 1: Verifikasi ID Token (One Tap / mobile) ───────────────────
      const ticket = await client.verifyIdToken({
        idToken,
        audience: GOOGLE_CLIENT_ID,
      });
      const payload = ticket.getPayload();
      google_id = payload.sub;
      userEmail = payload.email;
      userName  = payload.name  || '';
      userFoto  = payload.picture || '';

    } else if (accessToken && googleId) {
      // ─── Mode 2: Verifikasi Access Token (web OAuth2 popup) ───────────────
      const tokenInfoRes = await fetch(
        `https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=${accessToken}`
      );
      const tokenInfo = await tokenInfoRes.json();

      if (tokenInfo.error || tokenInfo.user_id !== googleId) {
        return res.status(401).json({ error: 'Access token tidak valid' });
      }
      // Pastikan token untuk client_id kita
      if (GOOGLE_CLIENT_ID && tokenInfo.issued_to !== GOOGLE_CLIENT_ID) {
        return res.status(401).json({ error: 'Token bukan untuk aplikasi ini' });
      }

      google_id = googleId;
      userEmail = email   || '';
      userName  = nama    || '';
      userFoto  = foto    || '';

    } else {
      return res.status(400).json({ error: 'Wajib kirim idToken atau accessToken+googleId' });
    }

    // ─── Cari atau buat user ──────────────────────────────────────────────────
    let user = await User.findOne({ google_id });
    if (!user) {
      user = await User.create({ google_id, email: userEmail, nama: userName, foto: userFoto });
    } else {
      user.nama = userName || user.nama;
      user.foto = userFoto || user.foto;
      await user.save();
    }

    // ─── Buat JWT ─────────────────────────────────────────────────────────────
    const token = jwt.sign(
      { id: user._id.toString(), google_id, email: userEmail, nama: user.nama, foto: user.foto },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: { id: user._id, email: userEmail, nama: user.nama, foto: user.foto },
    });
  } catch (err) {
    console.error('Auth error:', err.message);
    res.status(401).json({ error: 'Login gagal: ' + err.message });
  }
});

// GET /api/auth/me — info user yang sedang login
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ error: 'User tidak ditemukan' });
    res.json({ id: user._id, email: user.email, nama: user.nama, foto: user.foto });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
