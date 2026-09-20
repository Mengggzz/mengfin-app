// Kalkulasi status ring HUD untuk daily budget
function calculateRingHudStatus(todaySpent, dailyLimit) {
  // Validasi input
  if (!dailyLimit || dailyLimit <= 0) {
    return {
      ring_percentage: 0,
      status_color: '#00F2FE',
      status_label: 'BUDGET TIDAK AKTIF',
      remaining_daily_budget: 0,
      daily_limit: 0,
      today_spent: 0
    };
  }

  const spent = Math.max(0, todaySpent || 0);
  const remaining = Math.max(0, dailyLimit - spent);
  const percentage = Math.round((spent / dailyLimit) * 100);

  let statusColor = '#00F2FE'; // Safe
  let statusLabel = 'AMAN';

  if (percentage >= 90) {
    statusColor = '#FF0055'; // Danger
    statusLabel = 'BAHAYA OVERBUDGET';
  } else if (percentage >= 70) {
    statusColor = '#FFB703'; // Warning
    statusLabel = 'PERHATIAN BUDGET';
  }

  return {
    ring_percentage: Math.min(percentage, 100),
    status_color: statusColor,
    status_label: statusLabel,
    remaining_daily_budget: remaining,
    daily_limit: dailyLimit,
    today_spent: spent
  };
}

module.exports = { calculateRingHudStatus };
