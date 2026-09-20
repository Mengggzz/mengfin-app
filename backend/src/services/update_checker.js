const https = require('https');

// Cek version terbaru dari GitHub
async function checkGitHubLatestRelease(owner, repo) {
  return new Promise((resolve, reject) => {
    const url = `https://api.github.com/repos/${owner}/${repo}/releases/latest`;
    const options = {
      hostname: 'api.github.com',
      path: `/repos/${owner}/${repo}/releases/latest`,
      method: 'GET',
      headers: {
        'User-Agent': 'MengFin-App',
        'Accept': 'application/vnd.github.v3+json'
      }
    };

    https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({
            version: parsed.tag_name || 'unknown',
            name: parsed.name || '',
            url: parsed.html_url || '',
            published_at: parsed.published_at || ''
          });
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', reject).end();
  });
}

// Compare versions (simple semantic versioning)
function isNewerVersion(currentVersion, latestVersion) {
  const current = (currentVersion || '1.0.0').replace(/^v/, '').split('.').map(Number);
  const latest = (latestVersion || '1.0.0').replace(/^v/, '').split('.').map(Number);
  
  for (let i = 0; i < 3; i++) {
    const c = current[i] || 0;
    const l = latest[i] || 0;
    if (l > c) return true;
    if (l < c) return false;
  }
  return false;
}

module.exports = { checkGitHubLatestRelease, isNewerVersion };
