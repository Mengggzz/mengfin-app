const assert = require('assert');
const { StemmerId, tebakKamus, tebakTipe, matches } = require('./src/services/kategori');
const aiRouter = require('./src/routes/ai');
const parse = aiRouter.fastParseTransaksi;

console.log('Running Comprehensive Category & Stemmer tests...');

// 1. StemmerId tests
assert.deepStrictEqual(StemmerId.varian('makanan').includes('makan'), true, 'Stemmer makanan -> makan');
assert.deepStrictEqual(StemmerId.varian('membeli').includes('beli'), true, 'Stemmer membeli -> beli');
assert.deepStrictEqual(StemmerId.varian('pembayaran').includes('bayar'), true, 'Stemmer pembayaran -> bayar');

// 2. Kamus Kategori Bug F
assert.strictEqual(tebakKamus('beli cilok 5000'), 'Makan & Minum');
assert.strictEqual(tebakKamus('kue cubit'), 'Makan & Minum');
assert.strictEqual(tebakKamus('membeli cireng'), 'Makan & Minum');
assert.strictEqual(tebakKamus('es teler 15000'), 'Makan & Minum');
assert.strictEqual(tebakKamus('bensin pertalite'), 'Transportasi');
assert.strictEqual(tebakKamus('bayar wifi indihome'), 'Tagihan');
assert.strictEqual(tebakKamus('sabun mandi'), 'Belanja');
assert.strictEqual(tebakKamus('nonton bioskop xxi'), 'Hiburan');
assert.strictEqual(tebakKamus('beli panadol'), 'Kesehatan');
assert.strictEqual(tebakKamus('uang spp kuliah'), 'Pendidikan');
assert.strictEqual(tebakKamus('sewa server hosting'), 'Kerja');
assert.strictEqual(tebakKamus('sedekah jumat'), 'Sosial');
assert.strictEqual(tebakKamus('gaji bulanan', false), 'Gaji');
assert.strictEqual(tebakKamus('bonus tahunan', false), 'Bonus');
assert.strictEqual(tebakKamus('dividen saham', false), 'Investasi');

// 3. Tipe Otomatis (Need / Want / Saving)
assert.strictEqual(tebakTipe('beli cilok 5000', 'Makan & Minum'), 'need');
assert.strictEqual(tebakTipe('starbucks 60000', 'Makan & Minum'), 'want');
assert.strictEqual(tebakTipe('beli sabun', 'Belanja'), 'need');
assert.strictEqual(tebakTipe('beli kemeja', 'Belanja'), 'want');
assert.strictEqual(tebakTipe('tiket pesawat liburan', 'Transportasi'), 'want');
assert.strictEqual(tebakTipe('bensin motor', 'Transportasi'), 'need');
assert.strictEqual(tebakTipe('investasi reksadana', 'Investasi', false), 'saving');

// 4. fastParseTransaksi integration
const p1 = parse('saya beli cilok 5000');
assert.strictEqual(p1.kategori, 'Makan & Minum');
assert.strictEqual(p1.tipe, 'need');
assert.strictEqual(p1.nominal, 5000);

const p2 = parse('starbucks 60000');
assert.strictEqual(p2.kategori, 'Makan & Minum');
assert.strictEqual(p2.tipe, 'want');
assert.strictEqual(p2.nominal, 60000);

const p3 = parse('beli sabun mandi 15rb');
assert.strictEqual(p3.kategori, 'Belanja');
assert.strictEqual(p3.tipe, 'need');
assert.strictEqual(p3.nominal, 15000);

console.log('All Comprehensive Category & Stemmer tests PASSED successfully!');
