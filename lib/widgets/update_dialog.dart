import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/update_service.dart';

/// Alur notifikasi update terpadu — dipakai oleh ikon notifikasi di beranda
/// dan cek otomatis saat app dibuka.
///
/// Tugasnya hanya MEMBERITAHU:
///  - ada versi lebih baru  → dialog dengan tombol Download (tidak memaksa)
///  - sudah paling terbaru   → dialog info singkat
///  - build lokal / tak dikenal → info, tidak menawarkan apa-apa
class UpdateFlow {
  /// Jalankan cek update dan tampilkan dialog yang sesuai.
  /// [silentWhenNoUpdate] = true → tidak menampilkan apa pun kalau sudah terbaru
  /// (dipakai untuk auto-check saat app dibuka, supaya tidak mengganggu).
  /// [force] = true → abaikan cache, benar-benar tanya ulang ke GitHub.
  /// Dipakai tombol "Cek pembaruan" manual; tanpa ini tombolnya hanya
  /// memutar ulang jawaban lama.
  static Future<void> run(
    BuildContext context, {
    bool silentWhenNoUpdate = false,
    bool force = false,
  }) async {
    if (!context.mounted) return;

    final result = await UpdateService.instance.checkForUpdate(force: force);
    if (!context.mounted) return;

    if (result.hasUpdate && result.release != null) {
      await UpdateDialog.show(context, result);
      return;
    }

    if (silentWhenNoUpdate) return;

    await InfoDialog.show(
      context,
      unknownCurrent: result.unknownCurrent,
      latestTag: result.latestTag,
      currentTag: result.currentTag,
      error: result.error,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Dialog: update tersedia
// ═══════════════════════════════════════════════════════════════════════════
class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;
  final String currentTag;

  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentTag,
  });

  static Future<void> show(BuildContext context, UpdateCheckResult result) async {
    if (!result.hasUpdate || result.release == null) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => UpdateDialog(
        release: result.release!,
        currentTag: result.currentTag,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openDownload() async {
    setState(() => _isDownloading = true);
    final url = widget.release.apkUrl.isNotEmpty
        ? widget.release.apkUrl
        : widget.release.htmlUrl;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (widget.release.htmlUrl.isNotEmpty) {
        await launchUrl(Uri.parse(widget.release.htmlUrl),
            mode: LaunchMode.externalApplication);
      }
    }
    if (mounted) setState(() => _isDownloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradientPrimary,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
                ),
                child: Column(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.system_update_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text('🚀 Update Tersedia!',
                    style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 6),
                  Text(widget.release.name,
                    style: TextStyle(color: Colors.white.withOpacity(0.85),
                      fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center),
                ]),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _versionBadge(
                      label: 'Terpasang',
                      version: widget.currentTag.isEmpty ? 'dev' : widget.currentTag,
                      color: AppColors.textMuted,
                    ),
                     Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppColors.textMuted),
                    ),
                    _versionBadge(
                      label: 'Terbaru',
                      version: widget.release.tag,
                      color: AppColors.success,
                    ),
                    const Spacer(),
                    Text(widget.release.readableVersion,
                      style:  TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ]),
                  const SizedBox(height: 20),

                  if (widget.release.body.isNotEmpty) ...[
                    Row(children: [
                      Container(
                        width: 3, height: 16,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.gradientPrimary,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                       Text('Yang Baru',
                        style: TextStyle(color: AppColors.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        _parseChangelog(widget.release.body),
                        style:  TextStyle(color: AppColors.textSecond,
                          fontSize: 12.5, height: 1.6),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child:  Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Setelah download, buka APK dan pilih "Install" untuk update. Ini opsional — kamu bisa update kapan saja.',
                        style: TextStyle(color: AppColors.warning, fontSize: 11.5, height: 1.4),
                      )),
                    ]),
                  ),
                ]),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side:  BorderSide(color: AppColors.glassBorder),
                        ),
                      ),
                      child:  Text('Nanti',
                        style: TextStyle(color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.gradientPrimary),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isDownloading ? null : _openDownload,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: _isDownloading
                                  ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.download_rounded, size: 18, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text('Download Update',
                                        style: TextStyle(color: Colors.white,
                                          fontWeight: FontWeight.w700, fontSize: 13)),
                                    ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _versionBadge({
    required String label,
    required String version,
    required Color color,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style:  TextStyle(color: AppColors.textMuted,
          fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(version, style: TextStyle(color: color, fontSize: 12,
            fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ),
      ]);

  String _parseChangelog(String body) => body
      .replaceAll(RegExp(r'#{1,6}\s'), '')
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
      .replaceAll(RegExp(r'`(.+?)`'), r'$1')
      .replaceAll(RegExp(r'^\s*[-*]\s', multiLine: true), '• ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

// ═══════════════════════════════════════════════════════════════════════════
// Dialog: info (sudah terbaru / versi dev / gagal cek)
// ═══════════════════════════════════════════════════════════════════════════
class InfoDialog extends StatelessWidget {
  final bool unknownCurrent;
  final String? latestTag;
  final String currentTag;
  final String? error;

  const InfoDialog({
    super.key,
    required this.unknownCurrent,
    required this.currentTag,
    this.latestTag,
    this.error,
  });

  static Future<void> show(
    BuildContext context, {
    required bool unknownCurrent,
    required String currentTag,
    String? latestTag,
    String? error,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => InfoDialog(
        unknownCurrent: unknownCurrent,
        currentTag: currentTag,
        latestTag: latestTag,
        error: error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isError = error != null && latestTag == null;
    final IconData icon;
    final Color color;
    final String title;
    final String message;

    if (isError) {
      icon = Icons.cloud_off_rounded;
      color = AppColors.warning;
      title = 'Gagal Cek Update';
      message = 'Tidak bisa menghubungi GitHub untuk cek versi terbaru.\n$error';
    } else if (unknownCurrent) {
      icon = Icons.build_circle_outlined;
      color = AppColors.info;
      title = 'Versi Pengembangan';
      message = 'Ini build lokal (versi tidak diketahui), jadi pengecekan update dilewati.'
          '${latestTag != null ? '\n\nVersi terbaru di GitHub: $latestTag' : ''}';
    } else {
      icon = Icons.verified_rounded;
      color = AppColors.income;
      title = 'Sudah Versi Terbaru';
      message = 'Kamu memakai versi terbaru ($currentTag).'
          '${latestTag != null && latestTag != currentTag ? '\n\nVersi terbaru di GitHub: $latestTag' : ''}';
    }

    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 16),
        Text(title, style:  TextStyle(color: AppColors.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center,
          style:  TextStyle(color: AppColors.textSecond, fontSize: 13, height: 1.5)),
      ]),
      actions: [
        if (latestTag != null)
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(UpdateService.releasesPage),
              mode: LaunchMode.externalApplication,
            ),
            child: Text('Buka GitHub', style: TextStyle(
              color: AppColors.textSecond, fontWeight: FontWeight.w600)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:  Text('OK', style: TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
