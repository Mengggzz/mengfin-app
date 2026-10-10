import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../services/app_events.dart';
import '../services/app_prefs.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/connectivity_service.dart';
import '../services/theme_service.dart';
import '../services/sync_service.dart';
import '../services/local_db.dart';
import '../widgets/home_settings_sheet.dart';
import '../widgets/update_dialog.dart';
import 'ai_screen.dart';
import 'goals_screen.dart';
import 'import_csv_screen.dart';
import 'notification_inbox_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
            icon: Icons.inbox,
            color: AppColors.primary,
            title: 'Inbox Notifikasi Keuangan',
            subtitle: 'Review & setujui draft transaksi dari m-banking',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationInboxScreen())),
          ),
          _menuTile(
            icon: Icons.auto_awesome,
            color: AppColors.primary,
            title: 'MengFin AI',
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
          _menuTile(
            icon: Icons.table_chart_outlined,
            color: AppColors.accent,
            title: 'Import Mutasi',
            subtitle: 'Impor riwayat transaksi dari e-statement bank (CSV / PDF)',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportCsvScreen())),
          ),
          const SizedBox(height: 16),

          // ── Settings ─────────────────────────────────────────
          _sectionLabel('PENGATURAN'),
          _menuTile(
            icon: Icons.fingerprint,
            color: AppColors.success,
            title: 'Kunci Biometrik (Sidik Jari / Wajah)',
            subtitle: 'Amankan aplikasi dengan biometrik perangkat',
            onTap: () => _showBiometricDialog(context),
          ),
          _menuTile(
            icon: Icons.wallet,
            color: AppColors.info,
            title: 'Pengaturan Saldo Utama',
            subtitle: 'Pilih dompet yang tampil di beranda',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SettingsScreen(page: SettingsPage.saldoUtama))),
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
            onTap: () => HomeSettingsSheet.show(context),
          ),
          // Mode tampilan: Dark Mode / Light Mode toggle switch
          Consumer<ThemeService>(
            builder: (context, theme, _) {
              final isDark = theme.isDark;
              final currentSeason = theme.season;
              final animasiBg = theme.animasiBackground;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Gelap Switch
                    Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            'Mode Gelap',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDark ? 'Tema gelap aktif' : 'Tema terang aktif',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ]),
                      ),
                      Switch.adaptive(
                        value: isDark,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          theme.setMode(val ? ThemeMode.dark : ThemeMode.light);
                        },
                      ),
                    ]),

                    const Divider(height: 20),

                    // Tema Musim
                    Text(
                      'Tema Musim (Warna Aksen)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _seasonChip(
                            label: 'Default',
                            icon: '⚡',
                            color: const Color(0xFF00E5FF),
                            isSelected: currentSeason == Season.defaut,
                            onTap: () => theme.setSeason(Season.defaut),
                          ),
                          const SizedBox(width: 8),
                          _seasonChip(
                            label: 'Semi',
                            icon: '🌸',
                            color: const Color(0xFFF472B6),
                            isSelected: currentSeason == Season.semi,
                            onTap: () => theme.setSeason(Season.semi),
                          ),
                          const SizedBox(width: 8),
                          _seasonChip(
                            label: 'Panas',
                            icon: '☀️',
                            color: const Color(0xFFFB923C),
                            isSelected: currentSeason == Season.panas,
                            onTap: () => theme.setSeason(Season.panas),
                          ),
                          const SizedBox(width: 8),
                          _seasonChip(
                            label: 'Gugur',
                            icon: '🍂',
                            color: const Color(0xFFF59E0B),
                            isSelected: currentSeason == Season.gugur,
                            onTap: () => theme.setSeason(Season.gugur),
                          ),
                          const SizedBox(width: 8),
                          _seasonChip(
                            label: 'Dingin',
                            icon: '❄️',
                            color: const Color(0xFF7DD3FC),
                            isSelected: currentSeason == Season.dingin,
                            onTap: () => theme.setSeason(Season.dingin),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 20),

                    // Animasi Partikel Latar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Animasi Background',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Efek partikel musim di layar beranda',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: animasiBg,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) {
                            theme.setAnimasiBackground(val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
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
            icon: Icons.cleaning_services_outlined,
            color: AppColors.warning,
            title: 'Reset & Bersihkan Data Lokal',
            subtitle: 'Lihat ringkasan dan reset database lokal',
            onTap: () => _showResetDataPreview(context),
          ),
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

  Widget _seasonChip({
    required String label,
    required String icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.glassBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecond,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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

  void _showBiometricDialog(BuildContext context) async {
    final canAuth = await BiometricService.instance.canAuthenticate();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isEnabled = AppPrefs.instance.biometricAktif;
          return AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.fingerprint, color: AppColors.success),
                const SizedBox(width: 8),
                Text('Kunci Biometrik', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gunakan sidik jari atau wajah perangkat untuk mengamankan data transaksi dan saldo MengFin.',
                  style: TextStyle(color: AppColors.textSecond, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (!canAuth)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Perangkat ini tidak memiliki sensor biometrik atau belum didaftarkan sidik jari di pengaturan HP.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  )
                else
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Aktifkan Kunci Biometrik',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isEnabled ? 'Aplikasi terkunci saat dibuka' : 'Kunci aplikasi nonaktif',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    value: isEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (val) async {
                      if (val) {
                        final result = await BiometricService.instance.authenticateWithDetails(
                          localizedReason: 'Konfirmasi biometrik untuk mengaktifkan kunci MengFin',
                        );
                        if (result.isSuccess) {
                          await AppPrefs.instance.setBiometricAktif(true);
                          setDialogState(() {});
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                          }
                        }
                      } else {
                        await AppPrefs.instance.setBiometricAktif(false);
                        setDialogState(() {});
                      }
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tutup', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetDataPreview(BuildContext context) async {
    final summary = await LocalDb.getAccountDataSummary();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Text('Ringkasan Data Lokal', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Berikut ringkasan data yang tersimpan di perangkat ini:',
              style: TextStyle(color: AppColors.textSecond, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                children: [
                  _summaryRow('Transaksi', summary['transaksi'] ?? 0),
                  const Divider(height: 10),
                  _summaryRow('Dompet / Akun', summary['akun'] ?? 0),
                  const Divider(height: 10),
                  _summaryRow('Anggaran (Budget)', summary['anggaran'] ?? 0),
                  const Divider(height: 10),
                  _summaryRow('Goals Tabungan', summary['goals'] ?? 0),
                  const Divider(height: 10),
                  _summaryRow('Draft Notifikasi', summary['notif_draft'] ?? 0),
                  const Divider(height: 10),
                  _summaryRow('Antrean Sync Offline', summary['sync_queue'] ?? 0),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mereset data lokal akan membersihkan seluruh tabel di HP dan menarik ulang data dari server cloud.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              BuildContext? progressCtx;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (dCtx) {
                  progressCtx = dCtx;
                  return AlertDialog(
                    backgroundColor: AppColors.bgCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Membersihkan data & memulihkan dari server...',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

              try {
                await LocalDb.clearAll();
                if (ConnectivityService.instance.isOnline) {
                  await SyncService.instance.pullFromServer();
                }
                AppEvents.instance.transaksiBerubah();
                AppEvents.instance.akunBerubah();
                AppEvents.instance.anggaranBerubah();
                AppEvents.instance.goalsBerubah();
                AppEvents.instance.notifDraftBerubah();

                if (progressCtx != null && progressCtx!.mounted) {
                  Navigator.pop(progressCtx!);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Data berhasil direset dan diselaraskan dari cloud!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (progressCtx != null && progressCtx!.mounted) {
                  Navigator.pop(progressCtx!);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pembersihan lokal selesai, namun sync gagal: $e'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              }
            },
            child: const Text('Bersihkan & Reset'),
          ),
        ],
      ),
    );
  }

  static Widget _summaryRow(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: AppColors.textSecond, fontSize: 12)),
        Text(
          '$count item',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SvgPicture.asset('assets/logo.svg', width: 64, height: 64),
          ),
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
  int _queueFailed = 0;
  int _queuePermFailed = 0;
  String? _queueError;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final d = await LocalDb.db;
    final count = await LocalDb.getQueueCount();
    final permFailed = await LocalDb.getPermanentFailedCount();
    int failed = 0;
    String? lastErr;
    try {
      final rows = await d.rawQuery(
          "SELECT COUNT(*) as c FROM sync_queue WHERE retry_count > 0 AND (status != 'permanent_failed' OR status IS NULL)");
      failed = (rows.first['c'] as int?) ?? 0;
      final errRows = await d.rawQuery(
          "SELECT last_error FROM sync_queue WHERE last_error IS NOT NULL AND last_error != '' ORDER BY id DESC LIMIT 1");
      if (errRows.isNotEmpty) lastErr = errRows.first['last_error'] as String?;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _queueCount = count;
        _queueFailed = failed;
        _queuePermFailed = permFailed;
        _queueError = lastErr;
      });
    }
  }

  Future<void> _handleSync() async {
    setState(() => _syncing = true);
    final res = await SyncService.instance.triggerManualSync();
    await _loadQueue();
    if (!mounted) return;
    setState(() => _syncing = false);

    if (res.adaGagal) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sinkronisasi Parsial — Berhasil: ${res.terkirim}, '
            'Gagal: ${res.gagal}, Pending: ${res.pending}'),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sinkronisasi selesai — ${res.terkirim} perubahan terkirim'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ));
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
              if (_queuePermFailed > 0) ...[
                const Divider(height: 16, thickness: 0.5),
                Row(children: [
                  Icon(Icons.report_problem_rounded, size: 14, color: AppColors.expense),
                  const SizedBox(width: 6),
                  Text('$_queuePermFailed item gagal permanen (tidak akan dicoba lagi)',
                      style: TextStyle(color: AppColors.expense, fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              ],
              if (_queueFailed > 0) ...[
                const Divider(height: 16, thickness: 0.5),
                Row(children: [
                  Icon(Icons.error_outline, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Text('$_queueFailed item gagal — akan dicoba ulang otomatis',
                      style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
                if (_queueError != null && _queueError!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Error terakhir: $_queueError',
                      style: TextStyle(color: AppColors.textSecond, fontSize: 10, height: 1.35)),
                ],
              ],
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
