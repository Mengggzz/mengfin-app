import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'touch_effect.dart';

/// Modal bottom sheet untuk kirim laporan bug atau saran ke developer.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FeedbackSheet(),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _judulCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();

  String _jenis = 'Bug'; // 'Bug' atau 'Saran'
  String _versi = 'Memuat…';
  String _device = 'Memuat…';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _muatInfoPerangkat();
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  Future<void> _muatInfoPerangkat() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      _versi = 'v${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      _versi = 'v2.0.0';
    }

    try {
      final dev = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final a = await dev.androidInfo;
        _device = '${a.manufacturer} ${a.model} (Android ${a.version.release})';
      } else if (!kIsWeb && Platform.isIOS) {
        final i = await dev.iosInfo;
        _device = '${i.name} (iOS ${i.systemVersion})';
      } else {
        _device = 'Web / Desktop';
      }
    } catch (_) {
      _device = 'Perangkat Android';
    }

    if (mounted) setState(() {});
  }

  Future<void> _kirim() async {
    final judul = _judulCtrl.text.trim();
    final deskripsi = _deskripsiCtrl.text.trim();

    if (judul.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul laporan wajib diisi')),
      );
      return;
    }
    if (deskripsi.length < 10) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deskripsi minimal 10 karakter')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.sendFeedback(
        jenis: _jenis,
        judul: judul,
        deskripsi: deskripsi,
        deviceInfo: _device,
        appVersion: _versi,
      );
      if (!mounted) return;
      Navigator.pop(context);
      final msg = res['message'] as String? ?? 'Laporan terkirim ke developer 👍';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.income,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim laporan: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bug_report_rounded, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Laporkan Bug / Saran',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Laporan langsung terkirim ke Telegram developer secara otomatis.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Chips: Bug / Saran
            Row(
              children: [
                _buildTypeChip('Bug', '🐞', const Color(0xFFEF4444)),
                const SizedBox(width: 10),
                _buildTypeChip('Saran', '💡', const Color(0xFF3B82F6)),
              ],
            ),
            const SizedBox(height: 16),

            // Input: Judul
            Text(
              'Judul Singkat *',
              style: TextStyle(color: AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _judulCtrl,
              maxLength: 80,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _jenis == 'Bug' ? 'cth: Tombol simpan tidak merespons' : 'cth: Tambahkan ekspor ke Excel',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.bgElevated,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Input: Deskripsi
            Text(
              'Deskripsi Detail * (min. 10 karakter)',
              style: TextStyle(color: AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _deskripsiCtrl,
              maxLines: 4,
              minLines: 3,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _jenis == 'Bug'
                  ? 'Jelaskan kronologi bug, apa yang ditekan, dan apa yang terjadi…'
                  : 'Jelaskan ide saran atau fitur yang kamu harapkan…',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Info perangkat otomatis
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smartphone_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Lampiran Info Perangkat (Otomatis)',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Perangkat: $_device\nVersi App: $_versi',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tombol Kirim
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _loading ? null : _kirim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Kirim Laporan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String emoji, Color accentColor) {
    final isSelected = _jenis == label;
    return TouchEffect(
      onTap: () => setState(() => _jenis = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.18) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
