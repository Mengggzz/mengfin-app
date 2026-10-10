const assert = require('assert');
const { parseSeabankText, parsePeriodeYear, parseEStatementPdf } = require('./src/services/estatement');

console.log('Testing E-Statement Parser...');

// 1. Test Periode Year Extraction
const sampleHeader = `
PT BANK SEABANK INDONESIA
REKENING KORAN / STATEMENT OF ACCOUNT
PERIODE / PERIOD : 01/10/2026 - 31/10/2026
NO. REKENING : 9012345678
`;
const year = parsePeriodeYear(sampleHeader);
assert.strictEqual(year, '2026');
console.log('Pass: parsePeriodeYear = 2026');

// 2. Test SeaBank Deterministic Parsing
const sampleSeabank = `
PT BANK SEABANK INDONESIA
REKENING KORAN / STATEMENT OF ACCOUNT
PERIODE / PERIOD : 01/10/2026 - 31/10/2026
RINGKASAN REKENING
SALDO AWAL (IDR) | TRANSAKSI KELUAR (IDR) | TRANSAKSI MASUK (IDR) | SALDO AKHIR (IDR)
1,000,000 | 75,000 | 500,000 | 1,425,000

TABUNGAN - RINCIAN TRANSAKSI
TANGGAL | TRANSAKSI | KELUAR (IDR) | MASUK (IDR) | SALDO AKHIR (IDR)
07 OCT Transfer Masuk Dari Budi Utomo 500,000 1,500,000
08 OCT Pembayaran QRIS Kopi Kenangan 25,000 1,475,000
09 OCT Transfer Keluar ke Rekening Mandiri 50,000 1,425,000
HALAMAN 1 DARI 1
`;

const seabankTxs = parseSeabankText(sampleSeabank, '2026');
assert.strictEqual(seabankTxs.length, 3);

// Baris 1: Pemasukan 500.000
assert.strictEqual(seabankTxs[0].tanggal, '2026-10-07');
assert.strictEqual(seabankTxs[0].nominal, 500000);
assert.strictEqual(seabankTxs[0].jenis, 'pemasukan');
assert.strictEqual(seabankTxs[0].deskripsi.includes('Budi Utomo'), true);

// Baris 2: Pengeluaran QRIS 25.000
assert.strictEqual(seabankTxs[1].tanggal, '2026-10-08');
assert.strictEqual(seabankTxs[1].nominal, 25000);
assert.strictEqual(seabankTxs[1].jenis, 'pengeluaran');

// Baris 3: Pengeluaran Transfer 50.000
assert.strictEqual(seabankTxs[2].tanggal, '2026-10-09');
assert.strictEqual(seabankTxs[2].nominal, 50000);
assert.strictEqual(seabankTxs[2].jenis, 'pengeluaran');

// Pastikan Saldo Akhir (1.500.000, 1.475.000, 1.425.000) TIDAK menjadi nominal transaksi
const hasSaldo = seabankTxs.some(t => t.nominal === 1500000 || t.nominal === 1475000 || t.nominal === 1425000);
assert.strictEqual(hasSaldo, false);
console.log('Pass: parseSeabankText 3 transaksi valid, saldo akhir diabaikan');

// 3. Test SeaBank September Sequence (10 transaksi pertama persis)
const sampleSeptember = `
PT BANK SEABANK INDONESIA
REKENING KORAN / STATEMENT OF ACCOUNT
PERIODE / PERIOD : 01/09/2026 - 30/09/2026
RINGKASAN REKENING
SALDO AWAL (IDR) | TRANSAKSI KELUAR (IDR) | TRANSAKSI MASUK (IDR) | SALDO AKHIR (IDR)
100.000 | 4.418.460 | 5.617.957 | 1.299.497

TABUNGAN - RINCIAN TRANSAKSI
TANGGAL | TRANSAKSI | KELUAR (IDR) | MASUK (IDR) | SALDO AKHIR (IDR)
01 SEP Bunga Tabungan 9 100.009
02 SEP ShopeePay Transfer 45.255 145.264
03 SEP ShopeePay Transfer 2.100.000 2.245.264
04 SEP ELLYA NOER AFIFA Transfer 3.475.000 5.720.264
05 SEP ELLYA NOER AFIFA Transfer 3.475.000 2.245.264
06 SEP Pembayaran Pinjaman 775.000 1.470.264
07 SEP Bunga Tabungan 102 1.470.366
08 SEP Shopee Pembayaran 42.500 1.427.866
09 SEP Shopee Pembayaran 128.460 1.299.406
10 SEP Bunga Tabungan 91 1.299.497
HALAMAN 1 DARI 1
Hubungi kami di cs@seabank.co.id atau Telepon 1500 130 / +6221 5086 7070
`;

const sepTxs = parseSeabankText(sampleSeptember, '2026');
assert.strictEqual(sepTxs.length, 10);
assert.strictEqual(sepTxs[0].nominal, 9);
assert.strictEqual(sepTxs[0].jenis, 'pemasukan');
assert.strictEqual(sepTxs[1].nominal, 45255);
assert.strictEqual(sepTxs[1].jenis, 'pemasukan');
assert.strictEqual(sepTxs[2].nominal, 2100000);
assert.strictEqual(sepTxs[2].jenis, 'pemasukan');
assert.strictEqual(sepTxs[3].nominal, 3475000);
assert.strictEqual(sepTxs[3].jenis, 'pemasukan');
assert.strictEqual(sepTxs[4].nominal, 3475000);
assert.strictEqual(sepTxs[4].jenis, 'pengeluaran');
assert.strictEqual(sepTxs[5].nominal, 775000);
assert.strictEqual(sepTxs[5].jenis, 'pengeluaran');
assert.strictEqual(sepTxs[6].nominal, 102);
assert.strictEqual(sepTxs[6].jenis, 'pemasukan');
assert.strictEqual(sepTxs[7].nominal, 42500);
assert.strictEqual(sepTxs[7].jenis, 'pengeluaran');
assert.strictEqual(sepTxs[8].nominal, 128460);
assert.strictEqual(sepTxs[8].jenis, 'pengeluaran');
assert.strictEqual(sepTxs[9].nominal, 91);
assert.strictEqual(sepTxs[9].jenis, 'pemasukan');
// Pastikan tidak ada fragmen footer di deskripsi
assert.strictEqual(sepTxs.some(t => t.deskripsi.includes('5086') || t.deskripsi.includes('cs@')), false);
console.log('Pass: parseSeabankText September 10 transaksi valid & bersih footer');

// 4. Test SeaBank Glued Tokens (Oktober)
const sampleOctoberGlued = `
RINGKASAN REKENING
SALDO AWAL (IDR) | TRANSAKSI KELUAR (IDR) | TRANSAKSI MASUK (IDR) | SALDO AKHIR (IDR)
410.507 | 49.900 | 155.047 | 515.654

TABUNGAN - RINCIAN TRANSAKSI
01 OKT Bunga Tabungan 28410.535
02 OKT Shopee Pembayaran 39.900370.635
03 OKT SIOMAY BATAGOR 10.000 360.635
04 OKT Bunga Tabungan 19 360.654
05 OKT SELALU SIAP SOLUSI OCBC 155.000 515.654
`;

const octTxs = parseSeabankText(sampleOctoberGlued, '2026');
assert.strictEqual(octTxs.length, 5);
assert.strictEqual(octTxs[0].nominal, 28);
assert.strictEqual(octTxs[0].jenis, 'pemasukan');
assert.strictEqual(octTxs[1].nominal, 39900);
assert.strictEqual(octTxs[1].jenis, 'pengeluaran');
assert.strictEqual(octTxs[2].nominal, 10000);
assert.strictEqual(octTxs[2].jenis, 'pengeluaran');
assert.strictEqual(octTxs[3].nominal, 19);
assert.strictEqual(octTxs[3].jenis, 'pemasukan');
assert.strictEqual(octTxs[4].nominal, 155000);
assert.strictEqual(octTxs[4].jenis, 'pemasukan');
console.log('Pass: parseSeabankText token menempel (glued) & arah transaksi benar');

// 4b. Test SeaBank Layout Asli dengan TABUNGAN glued & Footer nomor telepon di belakang blob
const sampleSeabankRealGluedFooter = `
PT BANK SEABANK INDONESIA
REKENING KORAN / STATEMENT OF ACCOUNT
PERIODE / PERIOD : 01/09/2026 - 30/09/2026
RINGKASAN REKENING
TABUNGAN127.1724.418.4605.617.9573.341.346
TOTAL: 3.341.346

TABUNGAN - RINCIAN TRANSAKSI
01 SEP Bunga Tabungan 9 127.181 +6221 5086 7070 NO. REKENING SEABANK: 9012345678
02 SEP ShopeePay Transfer 45.255 172.436 +6221 5086 7070
03 SEP ELLYA NOER AFIFA Transfer 3.475.000 3.647.436 +6221 5086 7070
04 SEP Bnet Fiber Internet 306.090 3.341.346 +6221 5086 7070
`;

const realTxs = parseSeabankText(sampleSeabankRealGluedFooter, '2026');
assert.strictEqual(realTxs.length, 4);
assert.strictEqual(realTxs[0].nominal, 9);
assert.strictEqual(realTxs[0].jenis, 'pemasukan');
assert.strictEqual(realTxs[0].deskripsi, 'Bunga Tabungan');
assert.strictEqual(realTxs[1].nominal, 45255);
assert.strictEqual(realTxs[1].jenis, 'pemasukan');
assert.strictEqual(realTxs[1].deskripsi, 'ShopeePay Transfer');
assert.strictEqual(realTxs[2].nominal, 3475000);
assert.strictEqual(realTxs[2].jenis, 'pemasukan');
assert.strictEqual(realTxs[2].deskripsi, 'ELLYA NOER AFIFA Transfer');
assert.strictEqual(realTxs[3].nominal, 306090);
assert.strictEqual(realTxs[3].jenis, 'pengeluaran');
assert.strictEqual(realTxs[3].deskripsi, 'Bnet Fiber Internet');
console.log('Pass: parseSeabankText layout SeaBank asli TABUNGAN & footer nomor telepon teratasi sempurna');

// 5. Test Bukan PDF
(async () => {
  try {
    await parseEStatementPdf(Buffer.from('Bukan berkas pdf'));
    assert.fail('Seharusnya melempar error');
  } catch (err) {
    assert.strictEqual(err.message, 'File harus berformat PDF asli');
    console.log('Pass: Non-PDF ditolak');
  }

  console.log('All E-Statement tests passed successfully!');
})();
