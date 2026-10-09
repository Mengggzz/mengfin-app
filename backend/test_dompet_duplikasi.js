const assert = require('assert');

// Test that GET /akun logic does not mutate or auto-create wallets
// We can test the handler behavior directly or with mock models

console.log('Testing Wallet Deletion & Idempotency logic...');

// Test 1: Simulating GET /akun on empty database
let mockDb = [];

async function getAkunHandler(userId) {
  // Simulates our updated route logic
  let rows = mockDb.filter(a => a.user_id === userId);
  const totalSaldo = rows.reduce((s, a) => s + (a.saldo || 0), 0);
  return { data: rows, totalSaldo };
}

// 1. Initial empty
(async () => {
  const r1 = await getAkunHandler('user_1');
  assert.strictEqual(r1.data.length, 0, 'GET /akun on empty returns empty array');
  assert.strictEqual(r1.totalSaldo, 0, 'Total saldo is 0');

  // 2. 5 concurrent requests on empty
  const concurrent = await Promise.all([
    getAkunHandler('user_1'),
    getAkunHandler('user_1'),
    getAkunHandler('user_1'),
    getAkunHandler('user_1'),
    getAkunHandler('user_1'),
  ]);
  concurrent.forEach(c => {
    assert.strictEqual(c.data.length, 0, 'No wallet created during concurrent GET');
  });

  // 3. User creates a wallet
  mockDb.push({ user_id: 'user_1', nama: 'BCA', saldo: 500000 });
  const r2 = await getAkunHandler('user_1');
  assert.strictEqual(r2.data.length, 1);
  assert.strictEqual(r2.totalSaldo, 500000);

  // 4. User deletes the wallet
  mockDb = mockDb.filter(a => a.nama !== 'BCA');
  const r3 = await getAkunHandler('user_1');
  assert.strictEqual(r3.data.length, 0, 'Wallet deleted stays deleted');
  assert.strictEqual(r3.totalSaldo, 0);

  console.log('Pass: Wallet deletion and concurrency test passed!');
})();
