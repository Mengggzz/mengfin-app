import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants/app_colors.dart';
import '../models/models.dart';

class ExportService {
  static String _fmtRp(double n) {
    final abs = n.abs();
    final str = abs.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    final sign = n < 0 ? '-' : '';
    return '${sign}Rp ${buffer.toString().split('').reversed.join()}';
  }

  static Future<void> exportToCSV(List<Transaksi> transactions, BuildContext context) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Tanggal,Jenis,Kategori,Deskripsi,Metode Pembayaran,Nominal');

      for (final tx in transactions) {
        final safeDesc = tx.deskripsi.replaceAll('"', '""');
        final safeMetode = tx.metodePembayaran.replaceAll('"', '""');
        buffer.writeln('"${tx.tanggal}","${tx.jenis}","${tx.kategori}","$safeDesc","$safeMetode",${tx.nominal}');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/transaksi_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(buffer.toString(), encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Transaksi.csv',
          text: 'Ekspor transaksi MengFin',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal ekspor CSV: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  static Future<void> exportToPDF(List<Transaksi> transactions, BuildContext context) async {
    try {
      await initializeDateFormatting('id_ID', null);
      final pdf = pw.Document();

      // Hitung ringkasan
      double totalMasuk = 0;
      double totalKeluar = 0;
      final katMap = <String, ({int count, double total})>{};

      for (final tx in transactions) {
        if (tx.jenis == 'pemasukan') {
          totalMasuk += tx.nominal;
        } else if (tx.jenis == 'pengeluaran') {
          totalKeluar += tx.nominal;
          final current = katMap[tx.kategori] ?? (count: 0, total: 0.0);
          katMap[tx.kategori] = (count: current.count + 1, total: current.total + tx.nominal);
        }
      }

      final netCashFlow = totalMasuk - totalKeluar;
      final sortedKategori = katMap.entries.toList()
        ..sort((a, b) => b.value.total.compareTo(a.value.total));

      final exportDateStr = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context ctx) => _buildPdfHeader(exportDateStr, transactions.length),
          footer: (pw.Context ctx) => _buildPdfFooter(ctx),
          build: (pw.Context ctx) => [
            pw.SizedBox(height: 12),
            _buildSummaryCards(totalMasuk, totalKeluar, netCashFlow),
            pw.SizedBox(height: 20),
            if (sortedKategori.isNotEmpty) ...[
              _buildSectionTitle('Ringkasan per Kategori Pengeluaran'),
              pw.SizedBox(height: 8),
              _buildCategoryTable(sortedKategori, totalKeluar),
              pw.SizedBox(height: 20),
            ],
            _buildSectionTitle('Detail Riwayat Transaksi'),
            pw.SizedBox(height: 8),
            _buildTransactionTable(transactions),
          ],
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/laporan_mengfin_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Laporan_Keuangan_MengFin.pdf',
          text: 'Ekspor laporan transaksi MengFin',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal ekspor PDF: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  static pw.Widget _buildPdfHeader(String exportDate, int totalCount) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('0F172A'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MengFin',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('00E5FF'),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Laporan Keuangan & Riwayat Transaksi',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('94A3B8')),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Diekspor: $exportDate',
                style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('E2E8F0')),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Total $totalCount Transaksi',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('38BDF8')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Dibuat secara otomatis dengan MengFin',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCards(double masuk, double keluar, double net) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _summaryCard('TOTAL PEMASUKAN', _fmtRp(masuk), PdfColors.green700, PdfColors.green50),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _summaryCard('TOTAL PENGELUARAN', _fmtRp(keluar), PdfColors.red700, PdfColors.red50),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _summaryCard('ARUS KAS BERSIH', _fmtRp(net),
              net >= 0 ? PdfColors.cyan700 : PdfColors.red700,
              net >= 0 ? PdfColors.cyan50 : PdfColors.red50),
        ),
      ],
    );
  }

  static pw.Widget _summaryCard(String title, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: textColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textColor)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E293B')),
    );
  }

  static pw.Widget _buildCategoryTable(List<MapEntry<String, ({int count, double total})>> list, double totalKeluar) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
          children: [
            _th('Kategori'),
            _th('Jumlah'),
            _th('Total Nominal'),
            _th('Porsi'),
          ],
        ),
        ...list.map((e) {
          final porsi = totalKeluar > 0 ? (e.value.total / totalKeluar * 100).toStringAsFixed(1) : '0.0';
          return pw.TableRow(
            children: [
              _td(e.key, bold: true),
              _td('${e.value.count} tx', align: pw.TextAlign.center),
              _td(_fmtRp(e.value.total), color: PdfColors.red700),
              _td('$porsi%', align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(List<Transaksi> list) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.8),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(3.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('0F172A')),
          children: [
            _th('Tanggal', isDark: true),
            _th('Kategori', isDark: true),
            _th('Keterangan', isDark: true),
            _th('Metode', isDark: true),
            _th('Nominal', isDark: true, align: pw.TextAlign.right),
          ],
        ),
        ...List.generate(list.length, (i) {
          final tx = list[i];
          final isIncome = tx.jenis == 'pemasukan';
          final isEven = i % 2 == 0;
          final nominalStr = '${isIncome ? '+' : '-'}${_fmtRp(tx.nominal)}';

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : PdfColor.fromHex('F8FAFC'),
            ),
            children: [
              _td(tx.tanggal),
              _td(tx.kategori),
              _td(tx.deskripsi.isEmpty ? '-' : tx.deskripsi),
              _td(tx.metodePembayaran.toUpperCase(), align: pw.TextAlign.center),
              _td(
                nominalStr,
                align: pw.TextAlign.right,
                bold: true,
                color: isIncome ? PdfColors.green700 : PdfColors.red700,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _th(String text, {bool isDark = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: isDark ? PdfColors.white : PdfColor.fromHex('334155'),
        ),
      ),
    );
  }

  static pw.Widget _td(String text, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromHex('1E293B'),
        ),
      ),
    );
  }
}
