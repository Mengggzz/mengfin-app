const express = require('express');
const router = express.Router();
const { checkGitHubLatestRelease, isNewerVersion } = require('../services/update_checker');

const GITHUB_OWNER = process.env.GITHUB_OWNER || 'user';
const GITHUB_REPO = process.env.GITHUB_REPO || 'mengfin';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';

// Cek update versi aplikasi
router.get('/check', async (req, res) => {
  try {
    const latest = await checkGitHubLatestRelease(GITHUB_OWNER, GITHUB_REPO);
    const hasUpdate = isNewerVersion(APP_VERSION, latest.version);

    res.json({
      current_version: APP_VERSION,
      latest_version: latest.version,
      has_update: hasUpdate,
      release: hasUpdate ? latest : null
    });
  } catch (err) {
    console.error('Update check error:', err);
    res.json({
      current_version: APP_VERSION,
      latest_version: APP_VERSION,
      has_update: false,
      error: err.message
    });
  }
});

module.exports = router;
