import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/app_colors.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaksi_screen.dart';
import 'screens/anggaran_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/ai_screen.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Init services
  await LocalDb.db; // Buka DB lokal
  await ConnectivityService.instance.init();

  // Pull data awal jika online
  if (ConnectivityService.instance.isOnline) {
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
          surface: AppColors.bgCard,
          background: AppColors.bg,
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
      ),
      home: const MainNav(),
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
    DashboardScreen(),
    TransaksiScreen(),
    AnggaranScreen(),
    GoalsScreen(),
    AiScreen(),
  ];

  static const _tabs = [
    (icon: Icons.dashboard_outlined,      activeIcon: Icons.dashboard,      label: 'Beranda'),
    (icon: Icons.receipt_long_outlined,   activeIcon: Icons.receipt_long,   label: 'Transaksi'),
    (icon: Icons.wallet_outlined,         activeIcon: Icons.wallet,         label: 'Anggaran'),
    (icon: Icons.flag_outlined,           activeIcon: Icons.flag,           label: 'Goals'),
    (icon: Icons.auto_awesome_outlined,   activeIcon: Icons.auto_awesome,   label: 'AI'),
  ];

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline;
    _updatePendingCount();

    ConnectivityService.instance.onStatusChange.listen((online) async {
      setState(() => _isOnline = online);
      if (online) {
        // Auto sync saat online
        setState(() => _showSyncBanner = true);
        await SyncService.instance.syncToServer();
        await _updatePendingCount();
        // Sembunyikan banner setelah 3 detik
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) setState(() => _showSyncBanner = false);
      }
    });
  }

  Future<void> _updatePendingCount() async {
    final count = await LocalDb.getPendingCount();
    if (mounted) setState(() => _pendingCount = count);
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
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
              }),
            ),
          ),
        ),
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
      bgColor = const Color(0xFFEF4444);
      icon = Icons.wifi_off_rounded;
      text = _pendingCount > 0
          ? '📴 Mode Offline · $_pendingCount data menunggu sync'
          : '📴 Mode Offline · Data tersimpan lokal';
    } else if (_showSyncBanner) {
      bgColor = const Color(0xFF10B981);
      icon = Icons.sync_rounded;
      text = '✅ Kembali Online · Menyinkronkan data...';
    } else {
      bgColor = const Color(0xFFF59E0B);
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
