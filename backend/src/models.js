const mongoose = require('mongoose');

// ── User ────────────────────────────────────────────────────────────────────
const UserSchema = new mongoose.Schema({
  google_id: { type: String, required: true, unique: true },
  email:     { type: String, required: true },
  nama:      { type: String, default: '' },
  foto:      { type: String, default: '' },
}, { timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' } });

// ── Akun ───────────────────────────────────────────────────────────────────
const AkunSchema = new mongoose.Schema({
  user_id: { type: String, required: true, index: true },
  nama: { type: String, required: true },
  jenis: { type: String, default: 'bank' },
  saldo: { type: Number, default: 0 },
  warna: { type: String, default: '#2563EB' },
  ikon: { type: String, default: 'bank' },
  local_id: { type: String, default: null, index: true },
  // Tabungan
  target_nominal: { type: Number, default: null },
  target_tanggal: { type: String, default: null },
  // Kartu Kredit
  limit_kartu: { type: Number, default: null },
  tgl_cetak: { type: Number, default: null },
  tgl_tempo: { type: Number, default: null },
  // Aset Emas
  gram: { type: Number, default: null },
  harga_beli_per_gram: { type: Number, default: null },
}, { timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' } });

// ── Transaksi ──────────────────────────────────────────────────────────────
const TransaksiSchema = new mongoose.Schema({
  user_id: { type: String, required: true, index: true },
  tanggal: { type: String, required: true },
  jenis: { type: String, enum: ['pemasukan', 'pengeluaran', 'transfer'], required: true },
  nominal: { type: Number, required: true, min: 0 },
  kategori: { type: String, required: true },
  deskripsi: { type: String, default: '' },
  metode_pembayaran: { type: String, default: 'tunai' },
  akun_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Akun', default: null },
  local_id: { type: String, default: null, index: true },
}, { timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' } });

// ── Anggaran ───────────────────────────────────────────────────────────────
const AnggaranSchema = new mongoose.Schema({
  user_id: { type: String, required: true, index: true },
  kategori: { type: String, required: true },
  batas: { type: Number, required: true, min: 0 },
  periode: { type: String, required: true }, // format: YYYY-MM
  local_id: { type: String, default: null, index: true },
}, { timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' } });

// ── Goal ────────────────────────────────────────────────────────────────────
const GoalSchema = new mongoose.Schema({
  user_id: { type: String, required: true, index: true },
  nama: { type: String, required: true },
  target: { type: Number, required: true, min: 0 },
  terkumpul: { type: Number, default: 0 },
  deadline: { type: String, default: null },
  prioritas: { type: String, enum: ['tinggi', 'sedang', 'rendah'], default: 'sedang' },
  nabung_per_bulan: { type: Number, default: 0 },
  catatan: { type: String, default: '' },
  local_id: { type: String, default: null, index: true },
}, { timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' } });

// ── Feedback (Bug / Saran) ──────────────────────────────────────────────────
const FeedbackSchema = new mongoose.Schema({
  user_id: { type: String, required: true, index: true },
  user_email: { type: String, default: '' },
  user_nama: { type: String, default: '' },
  jenis: { type: String, enum: ['Bug', 'Saran', 'bug', 'saran'], required: true },
  judul: { type: String, required: true },
  deskripsi: { type: String, required: true },
  device_info: { type: String, default: '' },
  app_version: { type: String, default: '' },
  telegram_sent: { type: Boolean, default: false },
  telegram_error: { type: String, default: null },
}, { timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' } });

const User     = mongoose.model('User', UserSchema);
const Akun     = mongoose.model('Akun', AkunSchema);
const Transaksi = mongoose.model('Transaksi', TransaksiSchema);
const Anggaran = mongoose.model('Anggaran', AnggaranSchema);
const Goal     = mongoose.model('Goal', GoalSchema);
const Feedback = mongoose.model('Feedback', FeedbackSchema);

module.exports = { User, Akun, Transaksi, Anggaran, Goal, Feedback };

