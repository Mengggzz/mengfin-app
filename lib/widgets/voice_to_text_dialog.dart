import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../services/api_service.dart';

/// Voice → transaksi otomatis.
/// Alur: rekam suara → transkripsi → kirim ke AI (/ai/chat) →
/// deteksi objek + nominal → simpan otomatis (/ai/konfirmasi-transaksi).
class VoiceToTextDialog extends StatefulWidget {
  const VoiceToTextDialog({super.key});

  @override
  State<VoiceToTextDialog> createState() => _VoiceToTextDialogState();
}

enum _VoiceStage { listening, parsing, saving, done, error }

class _VoiceToTextDialogState extends State<VoiceToTextDialog> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  _VoiceStage _stage = _VoiceStage.listening;
  String _errorMsg = '';
  Map<String, dynamic>? _savedTx;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _startListening();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        debugPrint('onStatus: $val');
        if ((val == 'done' || val == 'notListening') &&
            _isListening && _text.trim().isNotEmpty) {
          _processVoice(_text);
        }
      },
      onError: (val) => debugPrint('onError: $val'),
    );
    if (!mounted) return;
    if (available) {
      setState(() { _isListening = true; _stage = _VoiceStage.listening; });
      _speech.listen(
        localeId: 'id_ID',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onResult: (val) {
          if (!mounted) return;
          setState(() => _text = val.recognizedWords);
          // Auto-proses begitu speech engine menandai hasil final
          if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
            _processVoice(val.recognizedWords);
          }
        },
      );
    } else {
      setState(() {
        _isListening = false;
        _stage = _VoiceStage.error;
        _errorMsg = 'Mikrofon tidak tersedia atau izin ditolak.';
      });
    }
  }

  /// Kirim hasil transkripsi ke AI, lalu simpan transaksi otomatis.
  Future<void> _processVoice(String raw) async {
    final text = raw.trim();
    if (text.isEmpty ||
        _stage == _VoiceStage.parsing ||
        _stage == _VoiceStage.saving) return;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }
    if (!mounted) return;
    setState(() => _stage = _VoiceStage.parsing);

    try {
      final res = await ApiService.chat(text);

      // AI mendeteksi transaksi → simpan otomatis
      if (res['tipe'] == 'transaksi_preview' && res['data'] is Map) {
        if (!mounted) return;
        setState(() => _stage = _VoiceStage.saving);
        final data = Map<String, dynamic>.from(res['data'] as Map);
        await ApiService.konfirmasiTransaksi(data);
        if (!mounted) return;
        setState(() { _savedTx = data; _stage = _VoiceStage.done; });
        return;
      }

      // Bukan transaksi — tampilkan jawaban AI sebagai info
      if (!mounted) return;
      setState(() {
        _stage = _VoiceStage.error;
        _errorMsg = (res['pesan'] ?? 'Tidak terdeteksi sebagai transaksi.').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _VoiceStage.error;
        _errorMsg = 'Gagal memproses: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _retry() {
    setState(() {
      _text = '';
      _savedTx = null;
      _errorMsg = '';
      _stage = _VoiceStage.listening;
    });
    _startListening();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        const Icon(Icons.mic, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        const Text('Input Suara', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _statusIcon(),
        const SizedBox(height: 14),
        Text(
          _text.isEmpty ? 'Contoh: "beli kopi 5 ribu"' : '"$_text"',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text.isEmpty ? AppColors.textHint : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: _text.isEmpty ? FontWeight.w400 : FontWeight.w600),
        ),
        const SizedBox(height: 14),
        _statusBody(),
      ]),
      actions: _actions(),
    );
  }

  Widget _statusIcon() {
    switch (_stage) {
      case _VoiceStage.listening:
        return Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(_isListening ? 0.18 : 0.08),
            shape: BoxShape.circle),
          child: Icon(_isListening ? Icons.mic : Icons.mic_none,
            size: 32, color: _isListening ? AppColors.primary : AppColors.textMuted),
        );
      case _VoiceStage.parsing:
      case _VoiceStage.saving:
        return const SizedBox(
          width: 64, height: 64,
          child: Center(child: CircularProgressIndicator(
            strokeWidth: 3, color: AppColors.primary)));
      case _VoiceStage.done:
        return Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.income.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, size: 34, color: AppColors.income),
        );
      case _VoiceStage.error:
        return Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline, size: 32, color: AppColors.warning),
        );
    }
  }

  Widget _statusBody() {
    switch (_stage) {
      case _VoiceStage.listening:
        return Text(_isListening ? 'Mendengarkan…' : 'Menunggu…',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12));
      case _VoiceStage.parsing:
        return const Text('AI mendeteksi objek & nominal…',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12));
      case _VoiceStage.saving:
        return const Text('Menyimpan transaksi…',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12));
      case _VoiceStage.done:
        return _savedPreview();
      case _VoiceStage.error:
        return Text(_errorMsg, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecond, fontSize: 12));
    }
  }

  Widget _savedPreview() {
    final t = _savedTx ?? {};
    final info = getKategoriInfo((t['kategori'] ?? 'Lainnya').toString());
    final isIncome = (t['jenis'] ?? 'pengeluaran') == 'pemasukan';
    final nominal = (t['nominal'] as num? ?? 0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(info.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text((t['deskripsi'] ?? '-').toString(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(info.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          Text('${isIncome ? '+' : '-'}Rp ${formatAmount(nominal)}',
            style: TextStyle(
              color: isIncome ? AppColors.income : AppColors.expense,
              fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  List<Widget> _actions() {
    if (_stage == _VoiceStage.done) {
      return [
        TextButton(onPressed: _retry,
          child: const Text('Rekam Lagi', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ];
    }
    if (_stage == _VoiceStage.parsing || _stage == _VoiceStage.saving) {
      return [const SizedBox.shrink()];
    }
    if (_stage == _VoiceStage.error) {
      return [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          onPressed: _retry,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: () { _speech.stop(); Navigator.pop(context); },
        child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
      ElevatedButton(
        onPressed: _text.trim().isNotEmpty ? () => _processVoice(_text) : null,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        child: const Text('Proses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ];
  }
}
