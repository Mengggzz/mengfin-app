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

// 3. Test Bukan PDF
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
