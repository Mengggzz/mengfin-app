import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});
  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _namaCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  String _ikon = 'cash';
  bool _loading = false;

  Future<void> _simpan() async {
    if (_namaCtrl.text.isEmpty || _saldoCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      // Backend butuh endpoint POST /akun (asumsi dari struktur yang ada)
      // Sementara kita panggil via ApiService jika sudah ada, atau create dummy logic
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyimpan dompet...')));
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Tambah Dompet Baru'),
        backgroundColor: AppColors.bg,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _namaCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nama Dompet',
                labelStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _saldoCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Saldo Awal',
                labelStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _iconBtn('cash', '💵'),
                _iconBtn('bank', '💰'),
                _iconBtn('wallet', '👛'),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _simpan,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('SIMPAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(String val, String emoji) => GestureDetector(
    onTap: () => setState(() => _ikon = val),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _ikon == val ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
        border: Border.all(color: _ikon == val ? AppColors.primary : AppColors.textMuted),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 30)),
    ),
  );
}