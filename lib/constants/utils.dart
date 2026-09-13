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

String formatTanggal(String dateStr) {
  try {
    final dt = DateTime.parse(dateStr);
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    const days = ['Min','Sen','Sel','Rab','Kam','Jum','Sab'];
    return '${days[dt.weekday % 7]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
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

String currentBulan() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

String currentTanggal() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

// Category info
class KategoriInfo {
  final String label;
  final String icon; // emoji
  final int color;   // ARGB
  const KategoriInfo({required this.label, required this.icon, required this.color});
}

const List<KategoriInfo> kategoriList = [
  KategoriInfo(label: 'Makanan',      icon: '🍜', color: 0xFFF59E0B),
  KategoriInfo(label: 'Transportasi', icon: '🚗', color: 0xFF3B82F6),
  KategoriInfo(label: 'Belanja',      icon: '🛍️', color: 0xFFEC4899),
  KategoriInfo(label: 'Hiburan',      icon: '🎮', color: 0xFF8B5CF6),
  KategoriInfo(label: 'Kesehatan',    icon: '💊', color: 0xFF10B981),
  KategoriInfo(label: 'Pendidikan',   icon: '📚', color: 0xFF6366F1),
  KategoriInfo(label: 'Tagihan',      icon: '📄', color: 0xFFEF4444),
  KategoriInfo(label: 'Gaji',         icon: '💰', color: 0xFF10B981),
  KategoriInfo(label: 'Bonus',        icon: '🎁', color: 0xFFF59E0B),
  KategoriInfo(label: 'Investasi',    icon: '📈', color: 0xFF6C63FF),
  KategoriInfo(label: 'Transfer',     icon: '↔️', color: 0xFF64748B),
  KategoriInfo(label: 'Lainnya',      icon: '📦', color: 0xFF94A3B8),
];

KategoriInfo getKategoriInfo(String label) {
  return kategoriList.firstWhere(
    (k) => k.label == label,
    orElse: () => KategoriInfo(label: label, icon: '📦', color: 0xFF94A3B8),
  );
}
