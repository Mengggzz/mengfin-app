import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_db.dart';
import '../widgets/update_dialog.dart';
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
           Text('Lainnya', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
           Text('Pengaturan & fitur tambahan', style: TextStyle(
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
          // Mode tampilan: ketuk untuk berganti Sistem → Terang → Gelap.
          Consumer<ThemeService>(
            builder: (context, theme, _) => _menuTile(
              icon: theme.icon,
              color: AppColors.accent,
              title: 'Mode Tampilan',
              subtitle: '${theme.label} · ketuk untuk ganti',
              onTap: () {
                theme.cycle();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Mode tampilan: ${theme.label}'),
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Sync & Database ──────────────────────────────────
          _sectionLabel('SINKRONISASI & DATABASE'),
          _menuTile(
            icon: Icons.sync,
            color: AppColors.primary,
            title: 'Sinkronisasi Akun & Database',
            subtitle: 'Otomatis aktif · Log & riwayat database',
            onTap: () => _showSyncLog(context),
          ),
          const SizedBox(height: 16),

          // ── Account ──────────────────────────────────────────
          _sectionLabel('AKUN'),
          _menuTile(
            icon: Icons.info_outline,
            color: AppColors.textMuted,
            title: 'Tentang MengFin',
            subtitle: 'Personal Finance Manager',
            onTap: () => _showTentang(context),
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
    child: Text(label, style:  TextStyle(
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
          Text(title, style:  TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style:  TextStyle(
            color: AppColors.textMuted, fontSize: 11)),
        ])),
         Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
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

  void _showSyncLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _SyncLogSheet(),
    );
  }

  // ── Tentang MengFin ──────────────────────────────────────────
  void _showTentang(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _TentangSheet(),
    );
  }

  void _handleLogout(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title:  Text('Keluar', style: TextStyle(color: AppColors.textPrimary)),
      content:  Text('Yakin ingin keluar dari akun?',
        style: TextStyle(color: AppColors.textSecond)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child:  Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child:  Text('Keluar', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (ok == true) {
      try {
        await AuthService.instance.signOut();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal keluar: $e')),
          );
        }
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
         Align(alignment: Alignment.centerLeft, child: Text('Pengaturan beranda',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
         Align(alignment: Alignment.centerLeft, child: Text(
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
         Align(alignment: Alignment.centerLeft, child: Text('Tampilan',
          style: TextStyle(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        _toggleRow('Tampilkan grafik segmen', _showChart, (v) => setState(() => _showChart = v)),
        _toggleRow('Tampilkan budget harian', _showBudget, (v) => setState(() => _showBudget = v)),
        const SizedBox(height: 20),

        // Quick action ordering
         Align(alignment: Alignment.centerLeft, child: Text('Aksi cepat',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        _menuRow(Icons.sort, 'Urutkan aksi cepat', 'Sesuaikan urutan tombol aksi cepat Anda'),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child:  Text('Tutup', style: TextStyle(
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
          Text(desc, style:  TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        if (_dataMode == idx)
           Icon(Icons.check_circle, color: AppColors.primary, size: 20),
      ]),
    ),
  );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style:  TextStyle(color: AppColors.textSecond, fontSize: 13)),
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
        Text(title, style:  TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle, style:  TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ])),
       Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// Tentang MengFin — versi & jalan pintas cek pembaruan
// ─────────────────────────────────────────────────────────────
class _TentangSheet extends StatefulWidget {
  const _TentangSheet();

  @override
  State<_TentangSheet> createState() => _TentangSheetState();
}

class _TentangSheetState extends State<_TentangSheet> {
  String _versi = '…';
  bool _cek = false;

  @override
  void initState() {
    super.initState();
    _muatVersi();
  }

  /// Versi dibaca dari PackageInfo, bukan ditulis mati di dalam widget.
  Future<void> _muatVersi() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versi = '${info.version}+${info.buildNumber}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _versi = 'Tidak diketahui');
    }
  }

  Future<void> _cekPembaruan() async {
    if (_cek) return;
    setState(() => _cek = true);
    try {
      // force: true — tanpa ini pengecekan mengembalikan jawaban lama.
      await UpdateFlow.run(context, force: true);
    } finally {
      if (mounted) setState(() => _cek = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(child: Text('💸', style: TextStyle(fontSize: 30))),
        ),
        const SizedBox(height: 12),
        Text('MengFin', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Versi $_versi', style: TextStyle(
          color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('Personal Finance Manager', style: TextStyle(
          color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 20),

        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _cek ? null : _cekPembaruan,
          icon: _cek
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.system_update_alt, size: 18),
          label: Text(_cek ? 'Memeriksa…' : 'Cek pembaruan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Tutup', style: TextStyle(
            color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }
}

// ── Log Sinkronisasi & Database ─────────────────────────────────
class _SyncLogSheet extends StatefulWidget {
  const _SyncLogSheet();

  @override
  State<_SyncLogSheet> createState() => _SyncLogSheetState();
}

class _SyncLogSheetState extends State<_SyncLogSheet> {
  bool _syncing = false;
  int _queueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final count = await LocalDb.getQueueCount();
    if (mounted) setState(() => _queueCount = count);
  }

  Future<void> _handleSync() async {
    setState(() => _syncing = true);
    await SyncService.instance.triggerManualSync();
    await _loadQueue();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi database selesai'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = SyncService.instance.logs;
    final lastSync = SyncService.instance.lastSyncTime;
    final lastSyncStr = lastSync == null
        ? 'Belum ada riwayat'
        : DateFormat('dd MMM yyyy, HH:mm:ss').format(lastSync);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sync, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sinkronisasi Database', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              Text('Log aktivitas & sinkronisasi data', style: TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
            ])),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: AppColors.textMuted, size: 20),
            ),
          ]),
          const SizedBox(height: 16),

          // Banner Status Sinkronisasi Otomatis
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Sinkronisasi Otomatis: AKTIF', style: TextStyle(
                  color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Data akun/dompet, transaksi, dan anggaran otomatis diselaraskan ke database cloud setiap kali perangkat terhubung ke internet.',
                style: TextStyle(color: AppColors.textSecond, fontSize: 11, height: 1.4),
              ),
              const Divider(height: 16, thickness: 0.5),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Terakhir Sinkron:', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  Text(lastSyncStr, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Antrean Offline:', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  Text('$_queueCount pending', style: TextStyle(
                    color: _queueCount > 0 ? AppColors.warning : AppColors.success,
                    fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _syncing ? null : _handleSync,
                icon: _syncing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_sync, size: 18),
                label: Text(_syncing ? 'Menyinkronkan…' : 'Sinkronkan Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                SyncService.instance.clearLogs();
                setState(() {});
              },
              icon: const Icon(Icons.cleaning_services, size: 16),
              label: const Text('Bersihkan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: BorderSide(color: AppColors.glassBorder),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Log List Header
          Row(children: [
            Text('LOG AKTIVITAS DATABASE', style: TextStyle(
              color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            Text('${logs.length} catatan', style: TextStyle(
              color: AppColors.textMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 8),

          // Logs List
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text('Belum ada riwayat aktivitas sinkronisasi',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 12, thickness: 0.5),
                    itemBuilder: (_, i) {
                      final log = logs[i];
                      final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
                      final icon = log.isError
                          ? Icons.error_outline
                          : log.type == 'pull'
                              ? Icons.cloud_download_outlined
                              : log.type == 'push'
                                  ? Icons.cloud_upload_outlined
                                  : Icons.sync;
                      final iconColor = log.isError
                          ? AppColors.danger
                          : log.type == 'pull'
                              ? AppColors.info
                              : log.type == 'push'
                                  ? AppColors.warning
                                  : AppColors.primary;

                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(icon, size: 16, color: iconColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(log.title, style: TextStyle(
                                  color: log.isError ? AppColors.danger : AppColors.textPrimary,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              Text(timeStr, style: TextStyle(
                                color: AppColors.textMuted, fontSize: 10)),
                            ]),
                            const SizedBox(height: 2),
                            Text(log.message, style: TextStyle(
                              color: AppColors.textSecond, fontSize: 11, height: 1.3)),
                          ]),
                        ),
                      ]);
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    );
  }
}
