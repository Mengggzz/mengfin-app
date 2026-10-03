import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/settings_screen.dart';
import '../services/app_prefs.dart';

/// Modal pengaturan beranda yang persisten dan sinkron ke SharedPreferences
class HomeSettingsSheet extends StatefulWidget {
  const HomeSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const HomeSettingsSheet(),
    );
  }

  @override
  State<HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

class _HomeSettingsSheetState extends State<HomeSettingsSheet> {
  late int _dataMode;
  late bool _showChart;
  late bool _showBudget;
  late List<String> _quickActionOrder;
  late String _homeTitle;

  static const _bulanNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() {
    final prefs = AppPrefs.instance;
    _dataMode = prefs.homeDataMode;
    _showChart = prefs.homeShowChart;
    _showBudget = prefs.homeShowBudget;
    _quickActionOrder = List.of(prefs.quickActionOrder);
    _homeTitle = prefs.homeTitle;
  }

  String _getCycleLabel() {
    final now = DateTime.now();
    final m = _bulanNames[now.month];
    return 'Siklus aktif ($m ${now.year})';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pengaturan beranda',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sesuaikan tampilan dan perilaku layar beranda kamu.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Data mode options
              _dataModeOption(
                0,
                Icons.bolt,
                '7 hari terakhir',
                'Ringan. Muat seketika — cocok untuk cek harian.',
              ),
              const SizedBox(height: 8),
              _dataModeOption(
                1,
                Icons.calendar_month,
                _getCycleLabel(),
                'Tampilan satu siklus penuh. Mengambil lebih banyak data.',
              ),
              const SizedBox(height: 20),

              // Display toggles
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tampilan',
                  style: TextStyle(
                    color: AppColors.expense,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _toggleRow(
                'Tampilkan grafik segmen',
                _showChart,
                (v) async {
                  setState(() => _showChart = v);
                  await AppPrefs.instance.setHomeShowChart(v);
                },
              ),
              _toggleRow(
                'Tampilkan budget harian',
                _showBudget,
                (v) async {
                  setState(() => _showBudget = v);
                  await AppPrefs.instance.setHomeShowBudget(v);
                },
              ),
              const SizedBox(height: 20),

              // Quick action ordering
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aksi cepat',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _menuRow(
                Icons.sort,
                'Urutkan aksi cepat',
                'Sesuaikan susunan tombol aksi di layar utama',
                onTap: _showReorderQuickActionsDialog,
              ),
              const SizedBox(height: 8),
              _menuRow(
                Icons.edit_note,
                'Nama & Emoji Judul Beranda',
                'Judul aktif: $_homeTitle',
                onTap: _showEditHomeTitleDialog,
              ),
              const SizedBox(height: 16),

              // Menu terkait lainnya
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Lainnya',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _menuRow(
                Icons.wallet,
                'Pengaturan Kazz Utama',
                'Pilih dompet yang tampil di beranda',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(page: SettingsPage.kazzUtama),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _menuRow(
                Icons.notifications_active,
                'Auto-catat dari Notifikasi',
                'Otomatis catat transaksi saat notif masuk',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(page: SettingsPage.autoNotif),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  Widget _dataModeOption(int idx, IconData icon, String title, String desc) => GestureDetector(
    onTap: () async {
      setState(() => _dataMode = idx);
      await AppPrefs.instance.setHomeDataMode(idx);
    },
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dataMode == idx ? AppColors.primary.withOpacity(0.1) : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _dataMode == idx ? AppColors.primary : AppColors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _dataMode == idx ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _dataMode == idx ? AppColors.primary : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          if (_dataMode == idx)
            Icon(Icons.check_circle, color: AppColors.primary, size: 20),
        ],
      ),
    ),
  );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecond, fontSize: 13)),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          inactiveTrackColor: AppColors.bgElevated,
        ),
      ],
    ),
  );

  Widget _menuRow(IconData icon, String title, String subtitle, {VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMuted),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      );

  void _showReorderQuickActionsDialog() {
    final meta = {
      'voice': {'title': 'Voice Text', 'icon': Icons.mic, 'color': AppColors.primary},
      'ai': {'title': 'Kazz AI', 'icon': Icons.auto_awesome, 'color': AppColors.primary},
      'scan': {'title': 'Scan Struk', 'icon': Icons.camera_alt, 'color': AppColors.expense},
      'budget': {'title': 'Budget', 'icon': Icons.pie_chart, 'color': AppColors.expense},
    };

    final order = List<String>.from(_quickActionOrder);
    for (final k in meta.keys) {
      if (!order.contains(k)) order.add(k);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Urutan Aksi Cepat',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gunakan tombol panah untuk menukar posisi aksi cepat.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                ...List.generate(order.length, (i) {
                  final key = order[i];
                  final item = meta[key] ?? {'title': key, 'icon': Icons.circle, 'color': AppColors.primary};
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(item['icon'] as IconData, size: 18, color: item['color'] as Color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (i > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            color: AppColors.textMuted,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setDlgState(() {
                                final tmp = order[i - 1];
                                order[i - 1] = order[i];
                                order[i] = tmp;
                              });
                            },
                          ),
                        const SizedBox(width: 8),
                        if (i < order.length - 1)
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            color: AppColors.textMuted,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setDlgState(() {
                                final tmp = order[i + 1];
                                order[i + 1] = order[i];
                                order[i] = tmp;
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDlgState(() {
                  order.clear();
                  order.addAll(AppPrefs.kDefaultQuickActions);
                });
              },
              child: Text('Reset', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() => _quickActionOrder = List.of(order));
                await AppPrefs.instance.setQuickActionOrder(order);
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHomeTitleDialog() {
    final ctrl = TextEditingController(text: _homeTitle);
    final emojis = ['🏠', '💰', '💳', '🚀', '💎', '🌟', '📊', '⚡', '🎯', '🔥', '☕', '🐱'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Ubah Nama & Emoji Beranda',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kustomisasi judul tampilan di beranda utama kamu.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Home 🏠',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.bgElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                Text(
                  'Pilihan emoji cepat:',
                  style: TextStyle(
                    color: AppColors.textSecond,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: emojis.map((e) => InkWell(
                    onTap: () {
                      final current = ctrl.text.trim();
                      if (current.isEmpty) {
                        ctrl.text = e;
                      } else {
                        ctrl.text = '$current $e';
                      }
                      setDlgState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 16)),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ctrl.text = 'Home';
                setDlgState(() {});
              },
              child: Text('Reset', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                final finalTitle = text.isEmpty ? 'Home' : text;
                setState(() => _homeTitle = finalTitle);
                await AppPrefs.instance.setHomeTitle(finalTitle);
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
