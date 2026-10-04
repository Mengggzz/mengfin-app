const mongoose = require('mongoose');

async function connectDB() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI tidak ditemukan di .env');

  await mongoose.connect(uri);
  console.log('✅ MongoDB Atlas terhubung');
}

async function initDB() {
  // Tidak ada global seed — data dibuat per-user saat login pertama
  console.log('✅ Database MongoDB siap (data per-user, login untuk mulai)');
}

module.exports = { connectDB, initDB };

