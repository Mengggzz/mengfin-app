const https = require('https');

// Ambil release terbaru dari GitHub Releases (termasuk asset APK + changelog)
async function checkGitHubLatestRelease(owner, repo) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.github.com',
      path: `/repos/${owner}/${repo}/releases/latest`,
      method: 'GET',
      headers: {
        'User-Agent': 'MengFin-App',
        'Accept': 'application/vnd.github.v3+json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.message) {
            // e.g. "Not Found" — repo private atau belum ada release
            return reject(new Error(parsed.message));
          }

          // Cari asset APK
          let apkUrl = '';
          const assets = Array.isArray(parsed.assets) ? parsed.assets : [];
          for (const a of assets) {
            const name = a.name || '';
            if (name.endsWith('.apk')) {
              apkUrl = a.browser_download_url || '';
              break;
            }
          }

          resolve({
            version: parsed.tag_name || 'unknown',
            name: parsed.name || '',
            body: parsed.body || '',
            html_url: parsed.html_url || '',
            apk_url: apkUrl,
            published_at: parsed.published_at || ''
          });
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on('error', reject);
    req.setTimeout(10000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

// Bandingkan versi. Mendukung dua format:
//  1) tag timestamp CI: v20260923-1210  → bandingkan langsung (lebih besar = lebih baru)
//  2) semver: 3.0.1                     → bandingkan per-numerik
function isNewerVersion(currentVersion, latestVersion) {
  if (!currentVersion || !latestVersion) return false;

  const cur = String(currentVersion).trim();
  const lat = String(latestVersion).trim();
  if (cur === lat) return false;

  // Format timestamp: vYYYYMMDD-HHMM
  const tsRe = /^v?(\d{8})-(\d{4})$/;
  const cTs = cur.match(tsRe);
  const lTs = lat.match(tsRe);
  if (cTs && lTs) {
    return Number(`${lTs[1]}${lTs[2]}`) > Number(`${cTs[1]}${cTs[2]}`);
  }

  // Fallback semver
  const parse = (v) => v.replace(/^v/, '').split('.').map((n) => parseInt(n, 10) || 0);
  const c = parse(cur);
  const l = parse(lat);
  for (let i = 0; i < Math.max(c.length, l.length, 3); i++) {
    const cv = c[i] || 0;
    const lv = l[i] || 0;
    if (lv > cv) return true;
    if (lv < cv) return false;
  }
  return false;
}

module.exports = { checkGitHubLatestRelease, isNewerVersion };
