import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/csv_import_service.dart';

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  String? _fileName;
  List<Map<String, dynamic>> _parsedRows = [];
  final Set<int> _selectedIndices = {};
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _failedStage;
  List<Map<String, dynamic>> _processStages = [];
  bool _logExpanded = false;
  bool _cancelled = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  List<Akun> _akuns = [];
  String? _targetAkunId;

  @override
  void initState() {
    super.initState();
    _loadAkuns();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAkuns() async {
    final list = await ApiService.getAkunList();
    if (!mounted) return;
    setState(() {
      _akuns = list;
      if (list.isNotEmpty) _targetAkunId = list.first.id.toString();
    });
  }

  void _cancelImport() {
    _cancelled = true;
    _timer?.cancel();
    setState(() {
      _loading = false;
      _error = 'Proses import dibatalkan.';
    });
  }

  Future<void> _pickFile() async {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _cancelled = false;
    setState(() {
      _error = null;
      _failedStage = null;
      _processStages = [];
      _loading = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_loading) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'pdf'],
        withData: true,
      );

      if (_cancelled) return;

      if (result == null || result.files.isEmpty) {
        _timer?.cancel();
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _timer?.cancel();
        setState(() {
          _loading = false;
          _error = 'Gagal membaca berkas.';
        });
        return;
      }

      final isPdf = file.name.toLowerCase().endsWith('.pdf');
      List<Map<String, dynamic>> rows = [];
      List<Map<String, dynamic>> stages = [];

      if (isPdf) {
        final base64 = base64Encode(bytes);
        final detailRes = await ApiService.importEStatementDetail(base64);
        if (_cancelled) return;
        _timer?.cancel();

        if (detailRes.containsKey('error') && detailRes['error'] != null) {
          setState(() {
            _loading = false;
            _error = detailRes['error'].toString();
            _failedStage = detailRes['failed_stage']?.toString();
            _processStages = (detailRes['log'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                [];
          });
          return;
        }

        rows = (detailRes['data'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        stages = (detailRes['log'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
      } else {
        String rawCsv;
        try {
          rawCsv = utf8.decode(bytes);
        } catch (_) {
          rawCsv = latin1.decode(bytes);
        }
        rows = CsvImportService.parseCsvContent(rawCsv);
        _timer?.cancel();
      }

      if (_cancelled) return;

      setState(() {
        _fileName = file.name;
        _parsedRows = rows;
        _processStages = stages;
        _selectedIndices.clear();
        for (int i = 0; i < rows.length; i++) {
          _selectedIndices.add(i);
        }
        _loading = false;
        if (rows.isEmpty) {
          _error = 'Tidak ditemukan data transaksi yang valid dalam berkas ini.';
        }
      });
    } catch (e) {
      _timer?.cancel();
      if (!mounted || _cancelled) return;
      String errMsg = e.toString();
      final m = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(errMsg);
      if (m != null) errMsg = m.group(1)!;
      setState(() {
        _loading = false;
        _error = errMsg;
      });
    }
  }

  Future<void> _simpan() async {
    final selected = _selectedIndices.map((i) => _parsedRows[i]).toList();
    if (selected.isEmpty) {
      setState(() => _error = 'Pilih minimal satu transaksi untuk diimpor.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      for (final row in selected) {
        await ApiService.createTransaksi({
          'jenis': row['jenis'] ?? 'pengeluaran',
          'nominal': (row['nominal'] as num).toDouble(),
          'kategori': row['kategori'] ?? 'Lainnya',
          'deskripsi': row['deskripsi'] ?? 'Import CSV',
          'metode_pembayaran': row['metode_pembayaran'] ?? 'transfer',
          'tanggal': row['tanggal'] ?? currentTanggal(),
          if (_targetAkunId != null && _targetAkunId!.isNotEmpty)
            'akun_id': _targetAkunId,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length} transaksi berhasil diimpor!'),
          backgroundColor: AppColors.income,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Gagal menyimpan transaksi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _parsedRows.isNotEmpty && _selectedIndices.length == _parsedRows.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          'Import Mutasi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) ...[
            _buildLoadingCard(),
            const SizedBox(height: 14),
          ] else ...[
            _buildUploadCard(),
            const SizedBox(height: 14),
          ],
          if (_processStages.isNotEmpty) ...[
            _buildProcessLogSection(),
            const SizedBox(height: 14),
          ],
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.expense, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_failedStage != null) ...[
                          Text(
                            'Gagal pada tahap: [${_failedStage!.toUpperCase()}]',
                            style: TextStyle(
                              color: AppColors.expense,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          _error!,
                          style: TextStyle(color: AppColors.expense, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_parsedRows.isNotEmpty) ...[
            _buildTargetAkunSelector(),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Data Transaksi (${_parsedRows.length})',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        _selectedIndices.clear();
                      } else {
                        for (int i = 0; i < _parsedRows.length; i++) {
                          _selectedIndices.add(i);
                        }
                      }
                    });
                  },
                  child: Text(
                    allSelected ? 'Batal Semua' : 'Pilih Semua',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_parsedRows.length, (index) {
              final r = _parsedRows[index];
              final isSel = _selectedIndices.contains(index);
              final isExp = r['jenis'] != 'pemasukan';
              final nom = (r['nominal'] as num).toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.glassBorder,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSel,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIndices.add(index);
                      } else {
                        _selectedIndices.remove(index);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                  title: Text(
                    (r['deskripsi'] ?? 'Transaksi').toString(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${r['tanggal']} · ${r['kategori']}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  secondary: Text(
                    '${isExp ? '-' : '+'}Rp ${formatAmount(nom)}',
                    style: TextStyle(
                      color: isExp ? AppColors.expense : AppColors.income,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _simpan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.income,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Impor (${_selectedIndices.length}) Transaksi',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Sedang Memproses Berkas...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Elapsed: $_elapsedSeconds detik',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _cancelImport,
            icon: Icon(Icons.close, size: 16, color: AppColors.expense),
            label: Text(
              'Batal',
              style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.expense.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessLogSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _logExpanded = !_logExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Log Proses (${_processStages.length} Tahap)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _logExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_logExpanded) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _processStages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final s = _processStages[idx];
                final ok = s['ok'] == true;
                final stage = (s['stage'] ?? '').toString().toUpperCase();
                final detail = s['detail']?.toString() ?? '';
                final ms = s['ms']?.toString() ?? '0';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                      size: 16,
                      color: ok ? AppColors.income : AppColors.expense,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                stage,
                                style: TextStyle(
                                  color: ok ? AppColors.textPrimary : AppColors.expense,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${ms}ms',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            style: TextStyle(color: AppColors.textSecond, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.table_chart_rounded, size: 44, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            _fileName ?? 'Pilih Berkas Mutasi (.CSV / .PDF)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mendukung format e-statement SeaBank, BCA, Mandiri, BRI, BNI (.csv & .pdf asli).',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _pickFile,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(_fileName == null ? 'Pilih Berkas (.csv / .pdf)' : 'Ganti Berkas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetAkunSelector() {
    if (_akuns.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.textSecond),
          const SizedBox(width: 8),
          Text(
            'Tujuan Dompet:',
            style: TextStyle(color: AppColors.textSecond, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _targetAkunId,
                dropdownColor: AppColors.bgCard,
                items: _akuns.map((a) {
                  return DropdownMenuItem<String>(
                    value: a.id.toString(),
                    child: Text(
                      a.nama,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _targetAkunId = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
