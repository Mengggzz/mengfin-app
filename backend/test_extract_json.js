const assert = require('assert');
const { extractJson } = require('./src/services/gemini');

console.log('Testing extractJson...');

// Case (a): JSON polos
const plainJson = '{"transaksi": [{"nominal": 50000, "deskripsi": "Makan"}]}';
const resA = extractJson(plainJson);
assert.strictEqual(resA.transaksi[0].nominal, 50000);
console.log('Case (a) passed: JSON polos');

// Case (b): JSON dalam ```json fences
const fencedJson = '```json\n{\n  "transaksi": [{"nominal": 75000, "deskripsi": "Kopi"}]\n}\n```';
const resB = extractJson(fencedJson);
assert.strictEqual(resB.transaksi[0].nominal, 75000);
console.log('Case (b) passed: JSON fences');

// Case (c): Teks campuran + JSON
const mixedText = 'Berikut adalah hasil analisis mutasi Anda:\n```json\n{"transaksi": [{"nominal": 100000, "deskripsi": "Bensin"}]}\n```\nSemoga membantu!';
const resC = extractJson(mixedText);
assert.strictEqual(resC.transaksi[0].nominal, 100000);
console.log('Case (c) passed: Teks campuran + JSON');

// Extra: Array JSON dengan multiple objects
const arrayText = 'Ekstraksi berhasil: [{"nominal": 10000}, {"nominal": 20000}] Selesai.';
const resD = extractJson(arrayText);
assert.strictEqual(resD.length, 2);
assert.strictEqual(resD[1].nominal, 20000);
console.log('Case (d) passed: Array of objects');

console.log('All extractJson tests passed successfully!');
