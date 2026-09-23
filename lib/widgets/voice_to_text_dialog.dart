import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../constants/app_colors.dart';
import '../screens/transaction_input_screen.dart';

class VoiceToTextDialog extends StatefulWidget {
  const VoiceToTextDialog({super.key});

  @override
  State<VoiceToTextDialog> createState() => _VoiceToTextDialogState();
}

class _VoiceToTextDialogState extends State<VoiceToTextDialog> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Bicara sekarang...';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _startListening();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) => debugPrint('onStatus: $val'),
      onError: (val) => debugPrint('onError: $val'),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0 && val.finalResult) {
              _onDone();
            }
          });
        },
      );
    } else {
      setState(() {
        _isListening = false;
        _text = 'Permission denied or speech not available.';
      });
    }
  }

  void _onDone() {
    if (_isListening) {
      _speech.stop();
    }
    Navigator.pop(context); // close dialog
    if (_text.isNotEmpty && _text != 'Bicara sekarang...') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionInputScreen(initialDeskripsi: _text),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('Voice to Text', style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            size: 48,
            color: _isListening ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _text,
            style: const TextStyle(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _speech.stop();
            Navigator.pop(context);
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _onDone,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Selesai'),
        ),
      ],
    );
  }
}
