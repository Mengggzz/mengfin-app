const { getDB } = require('../db');

// Hitung financial health score (0-100)
function hitungHealthScore(pemasukan, pengeluaran, saldoTotal, anggaranData) {
  let score = 0;
  const details = {};

  // 1. Savings Rate (40 poin) — tabungan / pemasukan
  const tabungan = pemasukan - pengeluaran;
  const savingsRate = pemasukan > 0 ? tabungan / pemasukan : 0;
  let savingsScore = 0;
  if (savingsRate >= 0.3) savingsScore = 40;
  else if (savingsRate >= 0.2) savingsScore = 32;
  else if (savingsRate >= 0.1) savingsScore = 20;
  else if (savingsRate >= 0) savingsScore = 10;
  else savingsScore = 0;
  score += savingsScore;
  details.savingsRate = Math.round(savingsRate * 100);
  details.savingsScore = savingsScore;

  // 2. Cash Flow (20 poin) — apakah positif
  const cashFlowScore = tabungan > 0 ? 20 : (tabungan === 0 ? 10 : 0);
  score += cashFlowScore;
  details.cashFlowScore = cashFlowScore;

  // 3. Budget Compliance (30 poin)
  let budgetScore = 30;
  if (anggaranData && anggaranData.length > 0) {
    const melebihi = anggaranData.filter(a => a.terpakai > a.batas).length;
    const total = anggaranData.length;
    budgetScore = Math.round(30 * (1 - melebihi / total));
  }
  score += budgetScore;
  details.budgetScore = budgetScore;
  details.budgetUsage = pemasukan > 0 ? Math.round((pengeluaran / pemasukan) * 100) : 0;

  // 4. Emergency Fund (10 poin) — saldo > 3x pengeluaran bulanan rata-rata
  const avgPengeluaranBulanan = pengeluaran;
  const emergencyScore = saldoTotal >= avgPengeluaranBulanan * 3 ? 10 :
    saldoTotal >= avgPengeluaranBulanan ? 6 :
    saldoTotal >= 0 ? 3 : 0;
  score += emergencyScore;
  details.emergencyScore = emergencyScore;

  // Status label
  let status = 'Kritis';
  let warna = '#EF4444';
  if (score >= 80) { status = 'Excellent'; warna = '#10B981'; }
  else if (score >= 60) { status = 'Healthy'; warna = '#10B981'; }
  else if (score >= 40) { status = 'Cukup'; warna = '#F59E0B'; }
  else if (score >= 20) { status = 'Perlu Perhatian'; warna = '#F59E0B'; }

  let pesan = 'Keuangan Anda terkendali';
  if (score >= 80) pesan = 'Keuangan Anda sangat sehat!';
  else if (score >= 60) pesan = 'Keuangan Anda terkendali';
  else if (score >= 40) pesan = 'Keuangan cukup baik, ada ruang perbaikan';
  else pesan = 'Perlu perhatian lebih pada keuangan Anda';

  return { score, status, warna, pesan, details };
}

// Prediksi saldo aman
function prediksiSaldoAman(saldoTotal, pengeluaranBulanIni, hariIni) {
  const today = new Date();
  const lastDayOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
  const sisaHari = lastDayOfMonth - hariIni;

  const rataHarian = hariIni > 0 ? pengeluaranBulanIni / hariIni : 0;
  const prediksiSisaPengeluaran = rataHarian * sisaHari;
  const prediksiSaldoAkhir = saldoTotal - prediksiSisaPengeluaran;

  // Estimasi tanggal gajian (asumsi tgl 25)
  const tglGajian = 25;
  const nextGajian = new Date(today.getFullYear(), today.getMonth(), tglGajian);
  if (nextGajian <= today) {
    nextGajian.setMonth(nextGajian.getMonth() + 1);
  }

  const hariSampaiGajian = Math.ceil((nextGajian - today) / (1000 * 60 * 60 * 24));
  const danaAmanHingga = saldoTotal > 0 ? Math.floor(saldoTotal / (rataHarian || 1)) : 0;

  const tanggalAman = new Date(today);
  tanggalAman.setDate(tanggalAman.getDate() + danaAmanHingga);

  const status = prediksiSaldoAkhir > 0 ? 'aman' : 'perlu_perhatian';

  return {
    saldoTotal,
    rataHarian: Math.round(rataHarian),
    prediksiSisaPengeluaran: Math.round(prediksiSisaPengeluaran),
    prediksiSaldoAkhir: Math.round(prediksiSaldoAkhir),
    sisaHari,
    hariSampaiGajian,
    tanggalGajian: nextGajian.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' }),
    danaAman: Math.max(0, Math.round(saldoTotal - prediksiSisaPengeluaran)),
    status
  };
}

module.exports = { hitungHealthScore, prediksiSaldoAman };
