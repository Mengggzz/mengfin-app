import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'constants/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaksi_screen.dart';
import 'screens/kazz_screen.dart';
import 'screens/laporan_screen.dart';
import 'screens/more_screen.dart';
import 'screens/transaction_input_screen.dart';
import 'screens/anggaran_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/ai_screen.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/local_db.dart';
import 'services/theme_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

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

  // Init services — sqflite tidak support web, skip di web
  if (!kIsWeb) {
    await LocalDb.db; // Buka DB lokal (mobile/desktop only)
  }
  await ConnectivityService.instance.init();

  // Load token dari storage (cek apakah sudah login)
  await AuthService.instance.init();

  // Baca preferensi mode tampilan (Sistem / Terang / Gelap)
  await ThemeService.instance.init();

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

class _MainNavState extends State<MainNav> {
  int _idx = 0;
  bool _isOnline = true;
  bool _showSyncBanner = false;
  int _pendingCount = 0;

  // Sengaja BUKAN `static const`: kalau instance-nya sama persis, Flutter
  // melewati rebuild dan layar tidak ikut berubah warna saat mode tampilan
  // diganti. Dengan instance baru tiap build, tiap layar membangun ulang
  // (state-nya tetap) dan membaca AppColors yang sudah diperbarui.
  List<Widget> get _screens => [
    DashboardScreen(),   // 0 — Home
    KazzScreen(),        // 1 — Kazz (Wallets/Budget)
    TransaksiScreen(),   // 2 — Transaksi (History/View)
    MoreScreen(),        // 3 — More (Settings, AI, Goals)
  ];

  static const _tabs = [
    (icon: Icons.home_outlined,           activeIcon: Icons.home,           label: 'Home'),
    (icon: Icons.folder_outlined,         activeIcon: Icons.folder,         label: 'Kazz'),
    (icon: Icons.search,                  activeIcon: Icons.search,         label: 'View'),
    (icon: Icons.more_horiz,              activeIcon: Icons.more_horiz,     label: 'Lainnya'),
  ];

  @override
  void initState() {
    super.initState();
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
    ThemeService.instance.removeListener(_onThemeBerubah);
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // Offline / Sync Banner
        _buildBanner(),
        Expanded(
          child: IndexedStack(index: _idx, children: _screens),
        ),
      ]),
      // ── FAB for Quick Add Transaction ──────────────────────────
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: FloatingActionButton(
          onPressed: _openTransactionInput,
          backgroundColor: AppColors.primaryDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side:  BorderSide(color: AppColors.primary, width: 2),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // ── Bottom Navigation Bar ──────────────────────────────────
      bottomNavigationBar: Container(
        decoration:  BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left tabs
                _navItem(0),
                _navItem(1),
                // Center space for FAB
                const SizedBox(width: 56),
                // Right tabs
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
