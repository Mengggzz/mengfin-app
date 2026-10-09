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
  List<Akun> _akuns = [];
  String? _targetAkunId;

  @override
  void initState() {
    super.initState();
    _loadAkuns();
  }

  Future<void> _loadAkuns() async {
    final list = await ApiService.getAkunList();
    if (!mounted) return;
    setState(() {
      _akuns = list;
      if (list.isNotEmpty) _targetAkunId = list.first.id.toString();
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _loading = false;
          _error = 'Gagal membaca berkas.';
        });
        return;
      }

      final isPdf = file.name.toLowerCase().endsWith('.pdf');
      List<Map<String, dynamic>> rows = [];

      if (isPdf) {
        final base64 = base64Encode(bytes);
        rows = await ApiService.importEStatement(base64);
      } else {
        String rawCsv;
        try {
          rawCsv = utf8.decode(bytes);
        } catch (_) {
          rawCsv = latin1.decode(bytes);
        }
        rows = CsvImportService.parseCsvContent(rawCsv);
      }

      setState(() {
        _fileName = file.name;
        _parsedRows = rows;
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
      if (!mounted) return;
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
          _buildUploadCard(),
          const SizedBox(height: 14),
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
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppColors.expense, fontSize: 12),
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
