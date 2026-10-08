import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/app_prefs.dart';
import '../services/notif_service.dart';
import '../services/permission_service.dart';

/// Bottom sheet wizard onboarding auto-catat notifikasi (2 langkah).
class AutoNotifOnboardingSheet extends StatefulWidget {
  const AutoNotifOnboardingSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AutoNotifOnboardingSheet(),
    );
    return result ?? false;
  }

  @override
  State<AutoNotifOnboardingSheet> createState() => _AutoNotifOnboardingSheetState();
}

class _AutoNotifOnboardingSheetState extends State<AutoNotifOnboardingSheet> {
  int _step = 0;
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_step == 0) _buildStep1() else _buildStep2(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktifkan Auto-Catat',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Langkah 1 dari 2: Privasi & Cara Kerja',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            children: [
              _infoRow(
                icon: Icons.shield_outlined,
                color: AppColors.income,
                title: 'Data Diproses di HP',
                desc: 'MengFin hanya membaca notifikasi pembayaran m-banking/e-wallet langsung di perangkat. Privasimu 100% aman.',
              ),
              const Divider(height: 20),
              _infoRow(
                icon: Icons.filter_alt_outlined,
                color: AppColors.accent,
                title: 'Filter Kata Kunci Aman',
                desc: 'Hanya notifikasi berisi transaksi & nominal valid yang dicatat. Chat pribadi diabaikan sepenuhnya.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Nanti Saja', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Lanjutkan', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.security_rounded, color: AppColors.income, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beri Izin Akses Notifikasi',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Langkah 2 dari 2: Pengaturan Sistem Android',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Tekan tombol di bawah untuk membuka halaman "Akses Notifikasi" Android, lalu aktifkan toggle untuk MengFin.',
          style: TextStyle(color: AppColors.textSecond, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () async {
            await PermissionService.bukaPengaturanAksesNotifikasi();
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Buka Pengaturan Akses Notifikasi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _checking ? null : _verifikasiIzin,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.income,
            side: BorderSide(color: AppColors.income.withValues(alpha: 0.6)),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _checking
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.income),
                )
              : const Text('Saya Sudah Memberikan Izin', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _verifikasiIzin() async {
    setState(() => _checking = true);
    final granted = await PermissionService.cekIzinAksesNotifikasi();
    setState(() => _checking = false);

    if (granted) {
      await AppPrefs.instance.setHasSeenNotifOnboarding(true);
      await AppPrefs.instance.setNotifAktif(true);
      await NotifService.instance.terapkanPreferensi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Auto-catat notifikasi berhasil diaktifkan!'),
          backgroundColor: AppColors.income,
        ),
      );
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izin belum terdeteksi aktif. Pastikan toggle MengFin dinyalakan di pengaturan HP.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
