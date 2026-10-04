const express = require('express');
const router = express.Router();
const { checkGitHubLatestRelease, isNewerVersion } = require('../services/update_checker');

// Terintegrasi dengan repo GitHub ini (release dibuat otomatis oleh CI)
const GITHUB_OWNER = process.env.GITHUB_OWNER || 'Mengggzz';
const GITHUB_REPO = process.env.GITHUB_REPO || 'mengfin-app';
const APP_VERSION = process.env.APP_VERSION || '3.0.0';

// Cek update versi aplikasi.
// Client mengirim build tag yang terinstall: /api/update/check?current=v20260923-1210
router.get('/check', async (req, res) => {
  const current = (req.query.current || '').trim();

  try {
    const latest = await checkGitHubLatestRelease(GITHUB_OWNER, GITHUB_REPO);

    // Tanpa build tag dari client kita tidak bisa memastikan ada update.
    // Tetap kirim info release terbaru, tapi jangan klaim ada update.
    const unknownCurrent = current.length === 0;
    const hasUpdate = !unknownCurrent && isNewerVersion(current, latest.version);

    res.json({
      current_version: current || APP_VERSION,
      latest_version: latest.version,
      has_update: hasUpdate,
      unknown_current: unknownCurrent,
      release: {
        tag: latest.version,
        name: latest.name || `MengFin ${latest.version}`,
        body: latest.body,
        apk_url: latest.apk_url,
        html_url: latest.html_url,
        published_at: latest.published_at
      }
    });
  } catch (err) {
    console.error('Update check error:', err.message);
    res.json({
      current_version: current || APP_VERSION,
      latest_version: null,
      has_update: false,
      unknown_current: current.length === 0,
      error: err.message,
      release: null
    });
  }
});

module.exports = router;
