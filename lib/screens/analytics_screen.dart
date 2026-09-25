import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_colors.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Data structures for charts
  List<Transaksi> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // For simplicity fetch all transactions; in production would use aggregation endpoint
      final data = await ApiService.getTransaksi(limit: 1000);
      setState(() {
        _transactions = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Helper: group by week (starting Monday) and compute totals
  Map<DateTime, double> _weeklyBalance() {
    final map = <DateTime, double>{};
    for (final tx in _transactions) {
      final date = DateTime.parse(tx.tanggal);
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      map.update(weekStart, (v) => v + (tx.jenis == 'pemasukan' ? tx.nominal : -tx.nominal), ifAbsent: () => (tx.jenis == 'pemasukan' ? tx.nominal : -tx.nominal));
    }
    return map;
  }

  // Helper: group by month
  Map<String, double> _monthlyBalance() {
    final map = <String, double>{};
    for (final tx in _transactions) {
      final date = DateTime.parse(tx.tanggal);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      map.update(key, (v) => v + (tx.jenis == 'pemasukan' ? tx.nominal : -tx.nominal), ifAbsent: () => (tx.jenis == 'pemasukan' ? tx.nominal : -tx.nominal));
    }
    return map;
  }

  // Helper: category expense totals (only pengeluaran)
  Map<String, double> _categoryExpenses() {
    final map = <String, double>{};
    for (final tx in _transactions) {
      if (tx.jenis != 'pengeluaran') continue;
      map.update(tx.kategori, (v) => v + tx.nominal, ifAbsent: () => tx.nominal);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        title:  Text('Analytics', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme:  IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: _loading
          ?  Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line chart weekly trend
                   Text('Tren Saldo Mingguan', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(height: 200, child: _buildLineChart(_weeklyBalance())),
                  const SizedBox(height: 24),
                  // Line chart monthly trend
                   Text('Tren Saldo Bulanan', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(height: 200, child: _buildLineChart(_monthlyBalance())),
                  const SizedBox(height: 24),
                  // Donut chart kategori terbesar
                   Text('Pengeluaran per Kategori', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(height: 250, child: _buildDonutChart(_categoryExpenses())),
                  const SizedBox(height: 24),
                  // Summary stats
                   Text('Ringkasan', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildSummary(),
                ],
              ),
            ),
    );
  }

  Widget _buildLineChart(Map<dynamic, double> dataMap) {
    if (dataMap.isEmpty) return  Center(child: Text('Tidak ada data', style: TextStyle(color: AppColors.textMuted)));
    final sortedKeys = dataMap.keys.toList()..sort((a, b) => a.compareTo(b));
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      spots.add(FlSpot(i.toDouble(), dataMap[key]!.toDouble()));
    }
    return LineChart(
      LineChartData(
        backgroundColor: AppColors.bg,
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: null, getTitlesWidget: (value, meta) => Text('\${value.toInt()}', style:  TextStyle(color: AppColors.textSecond, fontSize: 10))),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(Map<String, double> dataMap) {
    if (dataMap.isEmpty) return  Center(child: Text('Tidak ada data', style: TextStyle(color: AppColors.textMuted)));
    final total = dataMap.values.fold<double>(0, (p, e) => p + e);
    final sections = dataMap.entries.map((e) {
      final percent = (e.value / total) * 100;
      final color = _categoryColor(e.key);
      return PieChartSectionData(
        value: e.value,
        title: '${percent.toStringAsFixed(1)}%',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
    }).toList();
    return PieChart(
      PieChartData(
        centerSpaceRadius: 40,
        sections: sections,
        borderData: FlBorderData(show: false),
        sectionsSpace: 0,
      ),
    );
  }

  Color _categoryColor(String cat) {
    // Simple hash to color mapping, ensure distinct but dark-friendly
    final colors = [AppColors.primary, AppColors.success, AppColors.expense, AppColors.income, AppColors.warning];
    return colors[cat.codeUnitAt(0) % colors.length];
  }

  Widget _buildSummary() {
    final totalIncome = _transactions.where((t) => t.jenis == 'pemasukan').fold<double>(0, (p, e) => p + e.nominal);
    final totalExpense = _transactions.where((t) => t.jenis == 'pengeluaran').fold<double>(0, (p, e) => p + e.nominal);
    final avgDaily = _transactions.isEmpty ? 0 : _transactions.map((t) => DateTime.parse(t.tanggal)).toSet().length == 0 ? 0 : (totalExpense / _transactions.map((t) => DateTime.parse(t.tanggal)).toSet().length);
    // For growth comparison, use last week vs previous week
    final now = DateTime.now();
    final lastWeekStart = now.subtract(Duration(days: now.weekday + 6));
    final prevWeekStart = lastWeekStart.subtract(const Duration(days: 7));
    final lastWeekExp = _transactions.where((t) => t.jenis == 'pengeluaran' && DateTime.parse(t.tanggal).isAfter(lastWeekStart)).fold<double>(0, (p, e) => p + e.nominal);
    final prevWeekExp = _transactions.where((t) => t.jenis == 'pengeluaran' && DateTime.parse(t.tanggal).isAfter(prevWeekStart) && DateTime.parse(t.tanggal).isBefore(lastWeekStart)).fold<double>(0, (p, e) => p + e.nominal);
    final changePct = prevWeekExp == 0 ? 0 : ((lastWeekExp - prevWeekExp) / prevWeekExp) * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total pemasukan: \${totalIncome.toStringAsFixed(0)}', style:  TextStyle(color: AppColors.income, fontSize: 14)),
        Text('Total pengeluaran: \${totalExpense.toStringAsFixed(0)}', style:  TextStyle(color: AppColors.expense, fontSize: 14)),
        Text('Rata-rata harian: \${avgDaily.toStringAsFixed(0)}', style:  TextStyle(color: AppColors.textSecond, fontSize: 14)),
        Text('Perubahan minggu lalu: ${changePct.toStringAsFixed(1)}%', style: TextStyle(color: changePct >= 0 ? AppColors.danger : AppColors.income, fontSize: 14)),
      ],
    );
  }
}
