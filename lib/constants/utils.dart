// Format currency IDR
String formatRupiah(double amount) {
  final abs = amount.abs();
  if (abs >= 1000000000) return 'Rp ${(abs / 1000000000).toStringAsFixed(1)}M';
  if (abs >= 1000000)    return 'Rp ${(abs / 1000000).toStringAsFixed(1)}jt';
  if (abs >= 1000)       return 'Rp ${(abs / 1000).toStringAsFixed(0)}rb';
  return 'Rp ${abs.toStringAsFixed(0)}';
}

String formatRupiahFull(double amount) {
  final abs = amount.abs();
  final str = abs.toStringAsFixed(0);
  final buffer = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
    count++;
  }
  return 'Rp ${buffer.toString().split('').reversed.join()}';
}

/// Format amount with IDR prefix and thousand separators, no "Rp" prefix
String formatAmount(double amount) {
  final abs = amount.abs();
  final str = abs.toStringAsFixed(0);
  final buffer = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
    count++;
  }
  return buffer.toString().split('').reversed.join();
}

String formatTanggal(String dateStr) {
  try {
    final dt = DateTime.parse(dateStr);
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    const days = ['Min','Sen','Sel','Rab','Kam','Jum','Sab'];
    return '${days[dt.weekday % 7]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) { return dateStr; }
}

String formatTanggalShort(String dateStr) {
  try {
    final dt = DateTime.parse(dateStr);
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) { return dateStr; }
}

String formatBulan(String yyyy_mm) {
  try {
    final parts = yyyy_mm.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    const months = ['Januari','Februari','Maret','April','Mei','Juni',
                    'Juli','Agustus','September','Oktober','November','Desember'];
    return '${months[dt.month - 1]} ${dt.year}';
  } catch (_) { return yyyy_mm; }
}

String formatBulanShort(String yyyy_mm) {
  try {
    final parts = yyyy_mm.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${months[dt.month - 1]} ${dt.year}';
  } catch (_) { return yyyy_mm; }
}

String currentBulan() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

String currentTanggal() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String formatTime(String dateStr) {
  try {
    final dt = DateTime.parse(dateStr);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) { return ''; }
}

// ─────────────────────────────────────────────────────────────
// Category info
// ─────────────────────────────────────────────────────────────
class KategoriInfo {
  final String label;
  final String icon; // emoji
  final int color;   // ARGB
  const KategoriInfo({required this.label, required this.icon, required this.color});
}

const List<KategoriInfo> kategoriList = [
  // Expense categories (matching Kazz grid)
  KategoriInfo(label: 'Makan & Minum',  icon: '🍜', color: 0xFFFF8A65),
  KategoriInfo(label: 'Transportasi',   icon: '🚗', color: 0xFF42A5F5),
  KategoriInfo(label: 'Belanja',        icon: '🛍️', color: 0xFFEC407A),
  KategoriInfo(label: 'Hiburan',        icon: '🎮', color: 0xFFAB47BC),
  KategoriInfo(label: 'Kesehatan',      icon: '💊', color: 0xFF66BB6A),
  KategoriInfo(label: 'Pendidikan',     icon: '📚', color: 0xFF5C6BC0),
  KategoriInfo(label: 'Tagihan',        icon: '📄', color: 0xFFEF5350),
  KategoriInfo(label: 'Makanan',        icon: '🍜', color: 0xFFFF8A65), // legacy compat
  KategoriInfo(label: 'Kerja',          icon: '💼', color: 0xFF78909C),
  KategoriInfo(label: 'Pajak & Asuransi', icon: '🏛️', color: 0xFF8D6E63),
  KategoriInfo(label: 'Sosial',         icon: '🤝', color: 0xFF4FC3F7),
  KategoriInfo(label: 'Keluarga',       icon: '👨‍👩‍👧', color: 0xFFFFB74D),
  KategoriInfo(label: 'Pakaian',        icon: '👕', color: 0xFFBA68C8),
  KategoriInfo(label: 'Perawatan',      icon: '💅', color: 0xFFF48FB1),
  KategoriInfo(label: 'Olahraga',       icon: '🏀', color: 0xFFFF7043),
  KategoriInfo(label: 'Pemeliharaan',   icon: '🏠', color: 0xFF9CCC65),
  KategoriInfo(label: 'Rumah Tangga',   icon: '🏡', color: 0xFF8BC34A),
  KategoriInfo(label: 'Kendaraan',      icon: '🏍️', color: 0xFF7986CB),
  KategoriInfo(label: 'Koreksi (-)',    icon: '↩️', color: 0xFF90A4AE),
  KategoriInfo(label: 'Lainnya',        icon: '📦', color: 0xFF90A4AE),

  // Income categories
  KategoriInfo(label: 'Gaji',           icon: '💰', color: 0xFF4CAF50),
  KategoriInfo(label: 'Bonus',          icon: '🎁', color: 0xFFFFA726),
  KategoriInfo(label: 'Investasi',      icon: '📈', color: 0xFF7E57C2),

  // Common
  KategoriInfo(label: 'Transfer',       icon: '↔️', color: 0xFF78909C),
];

/// Expense-only categories for the grid in transaction input
List<KategoriInfo> get expenseCategories => kategoriList.where((k) =>
  !['Gaji', 'Bonus', 'Investasi', 'Transfer', 'Makanan'].contains(k.label)
).toList();

/// Income-only categories for the grid in transaction input
List<KategoriInfo> get incomeCategories => kategoriList.where((k) =>
  ['Gaji', 'Bonus', 'Investasi', 'Transfer', 'Lainnya'].contains(k.label)
).toList();

KategoriInfo getKategoriInfo(String label) {
  return kategoriList.firstWhere(
    (k) => k.label == label,
    orElse: () => KategoriInfo(label: label, icon: '📦', color: 0xFF90A4AE),
  );
}

// ─────────────────────────────────────────────────────────────
// Transaction Type: Need / Want / Saving
// ─────────────────────────────────────────────────────────────
enum TransactionType { need, want, saving }

class TransactionTypeInfo {
  final TransactionType type;
  final String label;
  final String icon;
  final String description;
  final int color;
  const TransactionTypeInfo({
    required this.type, required this.label,
    required this.icon, required this.description, required this.color,
  });
}

const List<TransactionTypeInfo> transactionTypes = [
  TransactionTypeInfo(
    type: TransactionType.need,
    label: 'Need',
    icon: '🏠',
    description: 'Kebutuhan pokok yang harus dipenuhi',
    color: 0xFF42A5F5,
  ),
  TransactionTypeInfo(
    type: TransactionType.want,
    label: 'Want',
    icon: '👑',
    description: 'Keinginan pribadi yang bisa ditunda atau dihindari',
    color: 0xFFFFA726,
  ),
  TransactionTypeInfo(
    type: TransactionType.saving,
    label: 'Saving',
    icon: '🏦',
    description: 'Tabungan atau investasi untuk masa depan',
    color: 0xFF66BB6A,
  ),
];
