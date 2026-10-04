// Kaitkan data yatim (tanpa user_id) ke akun tertentu.
//
// Pemakaian:
//   node _claim_orphans.js --email user@gmail.com --apply   -> kaitkan ke user itu
//   node _claim_orphans.js --email user@gmail.com           -> dry run (lihat dulu)
//   node _claim_orphans.js --delete --apply                 -> HAPUS data yatim
//
// Data yatim = dokumen yang dibuat 12-13 Sep 2026 sebelum user pertama
// terdaftar (16 Sep), sisa era migrasi SQLite -> MongoDB. Karena tidak punya
// user_id, data ini tidak pernah terlihat oleh akun mana pun.
require('dotenv').config();
const mongoose = require('mongoose');
const { Transaksi, Akun, User } = require('./src/models');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const doDelete = args.includes('--delete');
const emailIdx = args.indexOf('--email');
const email = emailIdx >= 0 ? args[emailIdx + 1] : null;

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);

  const orphanTx = (await Transaksi.find({}).lean()).filter(t => !t.user_id);
  const orphanAkun = (await Akun.find({}).lean()).filter(a => !a.user_id);

  console.log(`data yatim: ${orphanTx.length} transaksi, ${orphanAkun.length} akun\n`);
  if (orphanTx.length === 0 && orphanAkun.length === 0) {
    console.log('tidak ada data yatim.');
    await mongoose.disconnect();
    return;
  }

  console.log('--- transaksi yatim ---');
  orphanTx.forEach(t => console.log(`  ${t.tanggal} | ${t.jenis} | Rp${t.nominal} | ${t.kategori} | "${t.deskripsi}"`));
  console.log('--- akun yatim ---');
  orphanAkun.forEach(a => console.log(`  ${a.nama} | saldo Rp${a.saldo}`));

  if (doDelete) {
    if (!apply) { console.log('\n(dry run) tambahkan --apply untuk menghapus.'); await mongoose.disconnect(); return; }
    await Transaksi.deleteMany({ _id: { $in: orphanTx.map(t => t._id) } });
    await Akun.deleteMany({ _id: { $in: orphanAkun.map(a => a._id) } });
    console.log(`\nDIHAPUS: ${orphanTx.length} transaksi, ${orphanAkun.length} akun.`);
    await mongoose.disconnect();
    return;
  }

  if (!email) {
    console.log('\nTentukan tujuan dengan --email <email> (atau --delete).');
    await mongoose.disconnect();
    return;
  }

  const user = await User.findOne({ email }).lean();
  if (!user) { console.log(`\nUser ${email} tidak ditemukan.`); await mongoose.disconnect(); return; }
  const uid = user._id.toString();
  console.log(`\ntujuan: ${email} (user_id=${uid})`);

  if (!apply) {
    console.log('(dry run) tambahkan --apply untuk benar-benar mengaitkan.');
    await mongoose.disconnect();
    return;
  }

  const r1 = await Transaksi.updateMany(
    { _id: { $in: orphanTx.map(t => t._id) } }, { $set: { user_id: uid } });
  const r2 = await Akun.updateMany(
    { _id: { $in: orphanAkun.map(a => a._id) } }, { $set: { user_id: uid } });

  console.log(`\nSELESAI: ${r1.modifiedCount} transaksi + ${r2.modifiedCount} akun dikaitkan ke ${email}`);
  const total = await Transaksi.countDocuments({ user_id: uid });
  console.log(`total transaksi ${email} sekarang: ${total}`);

  await mongoose.disconnect();
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
