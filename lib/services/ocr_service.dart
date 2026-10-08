import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'struk_parser.dart';

/// Layanan OCR On-Device menggunakan Google ML Kit Text Recognition.
/// Cepat, offline, dan tanpa memerlukan kuota API.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  /// Pindai berkas gambar struk di perangkat dan parse menjadi data transaksi.
  Future<Map<String, dynamic>> scanFile(String filePath) async {
    if (kIsWeb) {
      return {
        'confidence': 0.0,
        'error': 'OCR lokal tidak didukung di web',
        'nominal': 0,
        'sumber': 'lokal',
      };
    }

    TextRecognizer? textRecognizer;
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      final parsed = StrukParser.parse(recognizedText.text);
      return parsed;
    } catch (e) {
      debugPrint('OcrService error: $e');
      return {
        'confidence': 0.0,
        'error': e.toString(),
        'nominal': 0,
        'sumber': 'lokal',
      };
    } finally {
      try {
        await textRecognizer?.close();
      } catch (_) {}
    }
  }
}
