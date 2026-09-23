import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants/app_colors.dart';
import '../models/models.dart';

class ExportService {
  static Future<void> exportToCSV(List<Transaksi> transactions, BuildContext context) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Tanggal,Jenis,Kategori,Nominal,Deskripsi');

      for (final tx in transactions) {
        final safeDesc = tx.deskripsi.replaceAll('"', '""');
        buffer.writeln('"${tx.tanggal}","${tx.jenis}","${tx.kategori}",${tx.nominal},"$safeDesc"');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/transaksi_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(buffer.toString(), encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Transaksi.csv',
          text: 'Ekspor transaksi',
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
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Laporan Transaksi', 
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueAccent)),
                pw.SizedBox(height: 10),
                pw.Text('Tanggal ekspor: ${DateTime.now().toLocal()}', 
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                      children: [
                        _pdfCell('Tanggal', isHeader: true),
                        _pdfCell('Jenis', isHeader: true),
                        _pdfCell('Kategori', isHeader: true),
                        _pdfCell('Nominal', isHeader: true),
                        _pdfCell('Deskripsi', isHeader: true),
                      ],
                    ),
                    ...transactions.map((tx) => pw.TableRow(
                          children: [
                            _pdfCell(tx.tanggal),
                            _pdfCell(tx.jenis),
                            _pdfCell(tx.kategori),
                            _pdfCell(tx.nominal.toString(), 
                              color: tx.jenis == 'pemasukan' ? PdfColors.green : PdfColors.red),
                            _pdfCell(tx.deskripsi),
                          ],
                        )),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/transaksi_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Transaksi.pdf',
          text: 'Ekspor transaksi',
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

  static pw.Widget _pdfCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, 
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
        )),
    );
  }
}
