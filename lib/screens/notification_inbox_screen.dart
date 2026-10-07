import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/app_events.dart';
import '../services/local_db.dart';
import '../services/notif_service.dart';
import '../widgets/category_icon_widget.dart';
import 'settings_screen.dart';
import 'transaction_input_screen.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  String _filterStatus = 'draft'; // 'semua', 'draft', 'approved', 'ignored'
  List<NotifDraft> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.notifDraft.addListener(_onDraftBerubah);
  }

  @override
  void dispose() {
    AppEvents.instance.notifDraft.removeListener(_onDraftBerubah);
    super.dispose();
  }

  void _onDraftBerubah() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await LocalDb.getNotifDrafts(
      status: _filterStatus == 'semua' ? null : _filterStatus,
    );
    if (mounted) {
      setState(() {
        _drafts = list;
        _loading = false;
      });
    }
  }

  Future<void> _approveDraft(NotifDraft d) async {
    final ok = await NotifService.instance.setujuiDraft(d);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi ${formatRupiah(d.nominal)} berhasil dicatat!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _approveAll() async {
    final pendingCount = _drafts.where((d) => d.status == 'draft').length;
    if (pendingCount == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui Semua Draft?'),
        content: Text('Sebanyak $pendingCount transaksi dari notifikasi akan dicatat ke keuanganmu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Setujui Semua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final total = await NotifService.instance.setujuiSemuaDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$total draft berhasil disetujui menjadi transaksi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _ignoreDraft(NotifDraft d) async {
    await NotifService.instance.abaikanDraft(d.id);
  }

  Future<void> _deleteDraft(NotifDraft d) async {
    await LocalDb.deleteNotifDraft(d.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draftCount = _drafts.where((d) => d.status == 'draft').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox Notifikasi Keuangan'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Pengaturan Auto-Catat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen(page: SettingsPage.autoNotif)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips & Info Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inbox, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Menangkap mutasi m-banking & e-wallet otomatis.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (draftCount > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text('Setujui Semua ($draftCount)'),
                        onPressed: _approveAll,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('draft', 'Draft Perlu Ditinjau'),
                      const SizedBox(width: 8),
                      _buildFilterChip('approved', 'Disetujui'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ignored', 'Diabaikan'),
                      const SizedBox(width: 8),
                      _buildFilterChip('semua', 'Semua'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List Data
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _drafts.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _drafts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _buildDraftCard(_drafts[i], isDark),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _filterStatus = status);
          _load();
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : null,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              _filterStatus == 'draft'
                  ? 'Tidak ada draft notifikasi'
                  : 'Belum ada data notifikasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Notifikasi dari m-banking dan e-wallet yang aktif akan muncul di sini untuk kamu tinjau.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCard(NotifDraft d, bool isDark) {
    final isExpense = d.jenis == 'pengeluaran';
    final nominalColor = isExpense ? AppColors.expense : AppColors.income;
    final isDraft = d.status == 'draft';
    final isApproved = d.status == 'approved';

    return Card(
      elevation: 0,
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDraft
              ? AppColors.primary.withValues(alpha: 0.3)
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: App Badge + Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    d.appName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (isDraft)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Draft',
                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isApproved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Tercatat',
                      style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Content: Category Icon + Nominal + Description
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryIconWidget(
                  kategori: d.kategori,
                  size: 24,
                  padding: 8,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isExpense ? '-' : '+'} ${formatRupiah(d.nominal)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: nominalColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.body.isNotEmpty ? d.body : d.title,
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kategori: ${d.kategori}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Action Buttons
            if (isDraft) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Abaikan', style: TextStyle(fontSize: 12)),
                    onPressed: () => _ignoreDraft(d),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionInputScreen(
                            edit: Transaksi(
                              id: 'draft_${d.id}',
                              tanggal: DateTime.now().toIso8601String().substring(0, 10),
                              jenis: d.jenis,
                              nominal: d.nominal,
                              kategori: d.kategori,
                              deskripsi: d.body.isNotEmpty ? d.body : d.title,
                              metodePembayaran: 'auto-notifikasi (${d.appName})',
                              akunId: d.akunId,
                              synced: false,
                            ),
                          ),
                        ),
                      ).then((_) {
                        _approveDraft(d);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Setujui'),
                    onPressed: () => _approveDraft(d),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Hapus riwayat notifikasi',
                  onPressed: () => _deleteDraft(d),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
