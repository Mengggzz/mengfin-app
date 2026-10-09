import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'constants/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaksi_screen.dart';
import 'screens/saldo_screen.dart';
import 'screens/more_screen.dart';
import 'screens/transaction_input_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/local_db.dart';
import 'services/theme_service.dart';
import 'services/update_service.dart';
import 'services/app_prefs.dart';
import 'services/notif_service.dart';
import 'widgets/update_dialog.dart';
import 'widgets/voice_to_text_dialog.dart';
import 'widgets/season_background.dart';

/// Warna status bar & navigation bar Android harus ikut mode tampilan —
/// di mode terang ikonnya harus gelap, kalau tidak jadi tidak terbaca.
void applySystemUi(bool isDark) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: AppColors.bgCard,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Init services — sqflite tidak support web, skip di web
  if (!kIsWeb) {
    await LocalDb.db; // Buka DB lokal (mobile/desktop only)
  }
  await ConnectivityService.instance.init();

  // Load token dari storage (cek apakah sudah login)
  await AuthService.instance.init();

  // Baca preferensi mode tampilan (Sistem / Terang / Gelap)
  await ThemeService.instance.init();

  // Baca preferensi pengguna: dompet utama/tampil, toggle auto-notif,
  // kata kunci, aplikasi yang dipantau. Harus selesai sebelum runApp —
  // layar pertama membacanya.
  await AppPrefs.instance.init();

  // Nama paket sendiri (Android): supaya pembaca notifikasi tidak ikut
  // membaca notifikasi milik aplikasi ini sendiri. Tidak perlu blocking.
  NotifService.instance.muatPaketSendiri();
  // Nyalakan listener kalau pengguna pernah mengaktifkan togglenya.
  NotifService.instance.terapkanPreferensi();

  // Init update service (baca versi app dari PackageInfo)
  if (!kIsWeb) {
    await UpdateService.instance.init();
  }

  // Di web langsung online, tidak perlu sync queue
  if (!kIsWeb && ConnectivityService.instance.isOnline) {
    SyncService.instance.pullFromServer();
  }

  runApp(
    ChangeNotifierProvider<ThemeService>.value(
      value: ThemeService.instance,
      child: const MengFinApp(),
    ),
  );
}

class MengFinApp extends StatelessWidget {
  const MengFinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Bangun ulang MaterialApp setiap mode tampilan berubah supaya
    // dialog, date picker, dan komponen bawaan ikut menyesuaikan.
    final themeService = context.watch<ThemeService>();
    applySystemUi(themeService.isDark);

    return MaterialApp(
      title: 'MengFin',
      debugShowCheckedModeBanner: false,
      themeMode: themeService.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: AuthService.instance.isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        // Bukan `const`: builder ini dievaluasi ulang tiap MaterialApp
        // rebuild, jadi state MainNav diperbarui (bukan dibuat ulang) dan
        // seluruh layar tab membangun ulang dengan warna mode terbaru.
        '/home':  (_) => MainNav(),
      },
    );
  }
}


class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> with WidgetsBindingObserver {
  int _idx = 0;
  bool _isOnline = true;
  bool _showSyncBanner = false;
  int _pendingCount = 0;
  bool _isLocked = false;
  DateTime? _pausedTime;

  // Sengaja BUKAN `static const`: kalau instance-nya sama persis, Flutter
  // melewati rebuild dan layar tidak ikut berubah warna saat mode tampilan
  // diganti. Dengan instance baru tiap build, tiap layar membangun ulang
  // (state-nya tetap) dan membaca AppColors yang sudah diperbarui.
  List<Widget> get _screens => [
    DashboardScreen(),   // 0 — Home
    SaldoScreen(),        // 1 — Saldo (Wallets/Budget)
    TransaksiScreen(),   // 2 — Transaksi (History/View)
    MoreScreen(),        // 3 — More (Settings, AI, Goals)
  ];

  static const _tabs = [
    (icon: Icons.home_outlined,           activeIcon: Icons.home,           label: 'Home'),
    (icon: Icons.folder_outlined,         activeIcon: Icons.folder,         label: 'Saldo'),
    (icon: Icons.search,                  activeIcon: Icons.search,         label: 'View'),
    (icon: Icons.more_horiz,              activeIcon: Icons.more_horiz,     label: 'Lainnya'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && AuthService.instance.isLoggedIn && AppPrefs.instance.biometricAktif) {
      _isLocked = true;
    }
    _isOnline = ConnectivityService.instance.isOnline;
    _updatePendingCount();
    // Ganti mode tampilan → bangun ulang seluruh layar tab supaya warna
    // (AppColors) langsung ikut berubah tanpa perlu restart app.
    ThemeService.instance.addListener(_onThemeBerubah);

    ConnectivityService.instance.onStatusChange.listen((online) async {
      setState(() => _isOnline = online);
      if (online && !kIsWeb) {
        // Auto sync saat online (mobile/desktop only)
        setState(() => _showSyncBanner = true);
        await SyncService.instance.syncToServer();
        await _updatePendingCount();
        // Sembunyikan banner setelah 3 detik
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) setState(() => _showSyncBanner = false);
      }
    });

    // Cek update setelah 2 detik (beri waktu UI render dulu)
    if (!kIsWeb) {
      Future.delayed(const Duration(seconds: 2), _checkForUpdate);
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    final result = await UpdateService.instance.checkForUpdate();
    if (mounted && result.hasUpdate) {
      await UpdateDialog.show(context, result);
    }
  }

  void _onThemeBerubah() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeService.instance.removeListener(_onThemeBerubah);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (AppPrefs.instance.biometricAktif && AuthService.instance.isLoggedIn) {
        final now = DateTime.now();
        if (_pausedTime != null && now.difference(_pausedTime!).inSeconds >= 2) {
          if (mounted) {
            setState(() {
              _isLocked = true;
            });
          }
        }
      }
    }
  }

  Future<void> _updatePendingCount() async {
    if (kIsWeb) return;
    final count = await LocalDb.getPendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  void _openTransactionInput() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionInputScreen()),
    );
    // Refresh dashboard if transaction was saved
    if (result == true) {
      setState(() {}); // triggers rebuild
    }
  }

  void _openVoiceInput() async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => const VoiceToTextDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return BiometricLockScreen(
        onUnlocked: () {
          if (mounted) setState(() => _isLocked = false);
        },
      );
    }
    final bool bannerVisible = !_isOnline || _showSyncBanner || _pendingCount > 0;
    return Scaffold(
      body: Column(children: [
        // Offline / Sync Banner
        _buildBanner(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: bannerVisible,
            child: SeasonBackground(
              child: IndexedStack(index: _idx, children: _screens),
            ),
          ),
        ),
      ]),
      // ── Dual Floating Action Buttons (Mic & Tambah Transaksi) ──
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Tombol Mic (Atas) - Pink/Magenta
            Tooltip(
              message: 'Input suara',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openVoiceInput,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF007A), Color(0xFFE11D48)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF007A).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tombol Tambah Transaksi (Bawah) - Biru
            Tooltip(
              message: 'Tambah transaksi',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openTransactionInput,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradientPrimary,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // ── Bottom Navigation Bar ──────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0),
                _navItem(1),
                _navItem(2),
                _navItem(3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final tab = _tabs[i];
    final isActive = _idx == i;
    return GestureDetector(
      onTap: () => setState(() => _idx = i),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 40,
            decoration: isActive ? BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ) : null,
            child: Icon(
              isActive ? tab.activeIcon : tab.icon,
              color: isActive ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(tab.label, style: TextStyle(
            fontSize: 10,
            color: isActive ? AppColors.primary : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          )),
        ]),
      ),
    );
  }

  Widget _buildBanner() {
    if (_isOnline && !_showSyncBanner && _pendingCount == 0) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    String text;
    IconData icon;

    if (!_isOnline) {
      bgColor = AppColors.danger;
      icon = Icons.wifi_off_rounded;
      text = _pendingCount > 0
          ? '📴 Mode Offline · $_pendingCount data menunggu sync'
          : '📴 Mode Offline · Data tersimpan lokal';
    } else if (_showSyncBanner) {
      bgColor = AppColors.success;
      icon = Icons.sync_rounded;
      text = '✅ Kembali Online · Menyinkronkan data...';
    } else {
      bgColor = AppColors.warning;
      icon = Icons.cloud_upload_outlined;
      text = '⏳ $_pendingCount data belum tersinkron';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: bgColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
