require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { connectDB, initDB } = require('./db');

const authRoutes    = require('./routes/auth');
const transaksiRoutes = require('./routes/transaksi');
const akunRoutes    = require('./routes/akun');
const anggaranRoutes = require('./routes/anggaran');
const goalsRoutes   = require('./routes/goals');
const laporanRoutes = require('./routes/laporan');
const aiRoutes      = require('./routes/ai');
const scanRoutes    = require('./routes/scan');
const updateRoutes  = require('./routes/update');

const app = express();
// Railway provides PORT automatically; fallback to 3000 locally
const PORT = parseInt(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Routes — /api/auth tidak perlu middleware (public)
app.use('/api/auth', authRoutes);
app.use('/api/update', updateRoutes);
app.use('/api/transaksi', transaksiRoutes);
app.use('/api/akun', akunRoutes);
app.use('/api/anggaran', anggaranRoutes);
app.use('/api/goals', goalsRoutes);
app.use('/api/laporan', laporanRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/scan', scanRoutes);


// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', app: 'MengFin Backend', version: '2.0.0', db: 'MongoDB Atlas' });
});

// Start setelah DB terhubung
async function start() {
  try {
    await connectDB();
    await initDB();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`✅ MengFin Backend running on port ${PORT}`);
      console.log(`📡 API: http://localhost:${PORT}/api`);
    });
  } catch (err) {
    console.error('❌ Gagal start server:', err.message);
    process.exit(1);
  }
}

start();
