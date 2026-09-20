import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  AnimationController? _animCtrl;
  Animation<double>? _fadeAnim;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();

    // Jika sudah login (token diproses di main() dari Google redirect),
    // langsung navigate ke home tanpa tampilkan login screen
    if (AuthService.instance.isLoggedIn) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      });
      return;
    }

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl!, curve: Curves.easeOut);
    _animCtrl!.forward();
  }

  @override
  void dispose() {
    _animCtrl?.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    setState(() { _loading = true; _error = null; });

    if (kIsWeb) {
      await AuthService.instance.signInWithGoogle();
      // Page akan redirect ke Google — tidak ada kode setelah ini
    } else {
      try {
        final ok = await AuthService.instance.signInWithGoogle();
        if (!mounted) return;
        if (ok) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          setState(() { _loading = false; _error = 'Login dibatalkan'; });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = _parseSignInError(e);
        });
      }
    }
  }

  String _parseSignInError(dynamic e) {
    final msg = e.toString();
    // ApiException: 10 = DEVELOPER_ERROR (SHA-1 not registered)
    if (msg.contains('ApiException: 10') || msg.contains('sign_in_failed')) {
      return 'Konfigurasi Google Sign-In belum selesai.\nHubungi developer untuk menambahkan SHA-1.';
    }
    // ApiException: 7 = NETWORK_ERROR
    if (msg.contains('ApiException: 7') || msg.contains('network_error')) {
      return 'Tidak ada koneksi internet. Periksa jaringan kamu.';
    }
    // ApiException: 12501 = Sign-in cancelled
    if (msg.contains('12501') || msg.contains('canceled')) {
      return 'Login dibatalkan.';
    }
    // ApiException: 12500 = Sign-in failed
    if (msg.contains('12500')) {
      return 'Login gagal. Coba lagi beberapa saat.';
    }
    return 'Login gagal. Coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading spinner saat redirect ke home
    if (_redirecting) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Memuat...', style: TextStyle(color: AppColors.textMuted)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fadeAnim ?? const AlwaysStoppedAnimation(1.0),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ──────────────────────────────────────────────────
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 24, offset: const Offset(0, 8),
                    )],
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 28),

                const Text('MengFin', style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1,
                )),
                const SizedBox(height: 8),
                const Text('Kelola keuangan pribadimu\ndengan cerdas & simpel 💡',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.5)),
                const SizedBox(height: 48),

                // ── Features ──────────────────────────────────────────────
                ...[
                  ('📊', 'Dashboard lengkap real-time'),
                  ('🤖', 'AI Advisor keuangan pribadi'),
                  ('🎯', 'Tracking goals & anggaran'),
                ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(f.$1, style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 14),
                    Text(f.$2, style: const TextStyle(color: AppColors.textSecond, fontSize: 14)),
                  ]),
                )),
                const SizedBox(height: 40),

                // ── Error ─────────────────────────────────────────────────
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                    ]),
                  ),

                // ── Login Button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _onLoginPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    child: _loading
                      ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary)),
                          SizedBox(width: 12),
                          Text('Menghubungkan ke Google…',
                            style: TextStyle(fontSize: 14, color: Colors.black54)),
                        ])
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Image.network(
                            'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                            width: 22, height: 22,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.login, size: 22, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          const Text('Masuk dengan Google',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),

                const SizedBox(height: 16),
                if (kIsWeb && !_loading)
                  const Text('Kamu akan diarahkan ke halaman Google',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 8),
                const Text('Data kamu aman & terenkripsi 🔒',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
