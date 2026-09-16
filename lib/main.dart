import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/app_colors.dart';
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
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bgCard,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Init services — sqflite tidak support web, skip di web
  if (!kIsWeb) {
    await LocalDb.db; // Buka DB lokal (mobile/desktop only)
  }
  await ConnectivityService.instance.init();

  // Load token dari storage (cek apakah sudah login)
  await AuthService.instance.init();

  // Init update service (baca versi app dari PackageInfo)
  if (!kIsWeb) {
    await UpdateService.instance.init();
  }

  // Di web langsung online, tidak perlu sync queue
  if (!kIsWeb && ConnectivityService.instance.isOnline) {
    SyncService.instance.pullFromServer();
  }

  runApp(const MengFinApp());
}

class MengFinApp extends StatelessWidget {
  const MengFinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MengFin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.bgCard,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        useMaterial3: true,
        splashColor: AppColors.primary.withOpacity(0.1),
        highlightColor: AppColors.primary.withOpacity(0.05),
      ),
      initialRoute: AuthService.instance.isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home':  (_) => const MainNav(),
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

  static const _screens = [
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
        child: FloatingActionButton(
          onPressed: _openTransactionInput,
          backgroundColor: AppColors.primary,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // ── Bottom Navigation Bar ──────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
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
