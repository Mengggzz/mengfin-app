const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

const VALID_CATEGORIES = [
  'Makan & Minum', 'Belanja', 'Transportasi', 'Tagihan', 
  'Hiburan', 'Kesehatan', 'Gaji', 'Investasi', 'Lainnya'
];

// Parse transkripsi suara menjadi data transaksi terstruktur
async function parseVoiceTranscription(transcription) {
  if (!transcription || transcription.trim().length === 0) {
    return null;
  }

  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

  const prompt = `Kamu adalah parser transaksi keuangan yang akurat. Parse transkripsi suara berikut dan kembalikan JSON terstruktur.

Transkripsi: "${transcription}"

Daftar kategori valid: ${VALID_CATEGORIES.join(', ')}

Petunjuk:
1. Ekstrak tipe: "expense" (pengeluaran) atau "income" (pemasukan)
2. Ekstrak nominal dalam Rupiah (asumsikan IDR jika tidak ada mata uang)
3. Buat deskripsi ringkas (maks 30 kata)
4. Inferensikan kategori terbaik dari konteks
5. Confidence: 0.0 - 1.0 (seberapa jelas perintah user)

Contoh output:
{"type": "expense", "amount": 25000, "description": "Beli kopi", "category": "Makan & Minum", "confidence": 0.95}

Kembalikan HANYA JSON valid tanpa markdown atau penjelasan tambahan.`;

  try {
    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    // Bersihkan markdown jika ada
    const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const parsed = JSON.parse(clean);

    // Validasi & sanitasi hasil
    return {
      type: ['expense', 'income'].includes(parsed.type) ? parsed.type : 'expense',
      amount: Math.max(0, parseInt(parsed.amount) || 0),
      description: (parsed.description || '').substring(0, 100),
      category: VALID_CATEGORIES.includes(parsed.category) ? parsed.category : 'Lainnya',
      confidence: Math.max(0, Math.min(1, parseFloat(parsed.confidence) || 0.5))
    };
  } catch (err) {
    console.error('Voice parser error:', err);
    return null;
  }
}

module.exports = { parseVoiceTranscription };
