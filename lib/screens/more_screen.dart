import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'ai_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          const Text('Lainnya', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Pengaturan & fitur tambahan', style: TextStyle(
            color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),

          // ── Features ─────────────────────────────────────────
          _sectionLabel('FITUR'),
          _menuTile(
            icon: Icons.auto_awesome,
            color: AppColors.primary,
            title: 'Kazz AI',
            subtitle: 'Chat asisten keuangan pribadi',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
          ),
          _menuTile(
            icon: Icons.flag,
            color: AppColors.warning,
            title: 'Goals & Tabungan',
            subtitle: 'Tetapkan dan lacak tujuan keuanganmu',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
          ),
          const SizedBox(height: 16),

          // ── Settings ─────────────────────────────────────────
          _sectionLabel('PENGATURAN'),
          _menuTile(
            icon: Icons.wallet,
            color: AppColors.info,
            title: 'Pengaturan Kazz Utama',
            subtitle: 'Pilih dompet yang tampil di beranda',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SettingsScreen(page: SettingsPage.kazzUtama))),
          ),
          _menuTile(
            icon: Icons.notifications_active,
            color: AppColors.accent,
            title: 'Auto-catat dari notifikasi',
            subtitle: 'Baca notifikasi untuk otomatis mencatat',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SettingsScreen(page: SettingsPage.autoNotif))),
          ),
          _menuTile(
            icon: Icons.dashboard_customize,
            color: AppColors.primaryLight,
            title: 'Pengaturan beranda',
            subtitle: 'Tampilan & perilaku layar utama',
            onTap: () => _showHomeSettings(context),
          ),
          const SizedBox(height: 16),

          // ── Account ──────────────────────────────────────────
          _sectionLabel('AKUN'),
          _menuTile(
            icon: Icons.info_outline,
            color: AppColors.textMuted,
            title: 'Tentang MengFin',
            subtitle: 'Versi 3.0.0 · Personal Finance Manager',
            onTap: () {},
          ),
          _menuTile(
            icon: Icons.logout,
            color: AppColors.danger,
            title: 'Keluar',
            subtitle: 'Logout dari akun',
            onTap: () => _handleLogout(context),
          ),
          const SizedBox(height: 40),
        ],
      )),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: const TextStyle(
      color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  );

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(
            color: AppColors.textMuted, fontSize: 11)),
        ])),
        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      ]),
    ),
  );

  void _showHomeSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HomeSettingsSheet(),
    );
  }

  void _handleLogout(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Keluar', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('Yakin ingin keluar dari akun?',
        style: TextStyle(color: AppColors.textSecond)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Keluar', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (ok == true) {
      await AuthService.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}

class _HomeSettingsSheet extends StatefulWidget {
  @override State<_HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

class _HomeSettingsSheetState extends State<_HomeSettingsSheet> {
  int _dataMode = 0; // 0 = 7 hari terakhir, 1 = Siklus aktif
  bool _showChart = true;
  bool _showBudget = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: Text('Pengaturan beranda',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        const Align(alignment: Alignment.centerLeft, child: Text(
          'Sesuaikan tampilan dan perilaku layar beranda kamu.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        const SizedBox(height: 16),

        // Data mode options
        _dataModeOption(0, Icons.bolt, '7 hari terakhir',
          'Ringan. Muat seketika — cocok untuk cek harian.'),
        const SizedBox(height: 8),
        _dataModeOption(1, Icons.calendar_month, 'Siklus aktif (Sep 2026)',
          'Tampilan satu siklus penuh. Mengambil lebih banyak data.'),
        const SizedBox(height: 20),

        // Display toggles
        const Align(alignment: Alignment.centerLeft, child: Text('Tampilan',
          style: TextStyle(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        _toggleRow('Tampilkan grafik segmen', _showChart, (v) => setState(() => _showChart = v)),
        _toggleRow('Tampilkan budget harian', _showBudget, (v) => setState(() => _showBudget = v)),
        const SizedBox(height: 20),

        // Quick action ordering
        const Align(alignment: Alignment.centerLeft, child: Text('Aksi cepat',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        _menuRow(Icons.sort, 'Urutkan aksi cepat', 'Sesuaikan urutan tombol aksi cepat Anda'),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('Tutup', style: TextStyle(
            color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }

  Widget _dataModeOption(int idx, IconData icon, String title, String desc) => GestureDetector(
    onTap: () => setState(() => _dataMode = idx),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dataMode == idx ? AppColors.primary.withOpacity(0.1) : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _dataMode == idx ? AppColors.primary : AppColors.glassBorder),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: _dataMode == idx ? AppColors.primary : AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
            color: _dataMode == idx ? AppColors.primary : AppColors.textPrimary,
            fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        if (_dataMode == idx)
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
      ]),
    ),
  );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 13)),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        inactiveTrackColor: AppColors.bgElevated,
      ),
    ]),
  );

  Widget _menuRow(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ])),
      const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
    ]),
  );
}
