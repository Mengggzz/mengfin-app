import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';

class _Msg {
  final String id;
  final bool isUser;
  final String text;
  final Map<String, dynamic>? txData;
  _Msg({required this.id, required this.isUser, required this.text, this.txData});
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _msgs = <_Msg>[
    _Msg(id: 'welcome', isUser: false, text:
      '👋 Hai! Saya MengFin AI, asisten keuangan personalmu.\n\n'
      'Kamu bisa:\n• Tanya analisis keuanganmu\n• Catat transaksi langsung (contoh: "beli mie ayam 25rb")\n• Minta saran penghematan\n\nAda yang bisa saya bantu? 😊'),
  ];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  Map<String, dynamic>? _pendingTx;
  String? _pendingMsgId;

  static const _quickPrompts = [
    'Gimana kondisi keuanganku?',
    'Tips hemat bulan ini',
    'Beli kopi 25rb cash',
    'Gajian 5 juta',
  ];

  void _addMsg(_Msg m) {
    setState(() => _msgs.add(m));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _ctrl.text).trim();
    if (msg.isEmpty || _sending) return;

    // Cek offline
    if (!ConnectivityService.instance.isOnline) {
      _addMsg(_Msg(id: 'off${DateTime.now().millisecondsSinceEpoch}', isUser: false,
        text: '📴 Fitur AI memerlukan koneksi internet.\n\nUntuk input transaksi saat offline, gunakan tombol + di tab Transaksi.'));
      return;
    }

    _ctrl.clear();
    setState(() => _sending = true);

    final uid = 'u${DateTime.now().millisecondsSinceEpoch}';
    _addMsg(_Msg(id: uid, isUser: true, text: msg));

    try {
      final res = await ApiService.chat(msg);
      final aid = 'a${DateTime.now().millisecondsSinceEpoch}';
      if (res['tipe'] == 'transaksi_preview') {
        setState(() { _pendingTx = res['data']; _pendingMsgId = aid; });
        _addMsg(_Msg(id: aid, isUser: false, text: res['pesan'] ?? '', txData: res['data']));
      } else {
        _addMsg(_Msg(id: aid, isUser: false, text: res['pesan'] ?? '...'));
      }
    } catch (_) {
      _addMsg(_Msg(id: 'e${DateTime.now().millisecondsSinceEpoch}', isUser: false,
        text: '⚠️ Gagal terhubung ke AI. Pastikan server backend berjalan.'));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _konfirmasi() async {
    if (_pendingTx == null) return;
    setState(() => _sending = true);
    try {
      await ApiService.konfirmasiTransaksi(_pendingTx!);
      setState(() { _pendingTx = null; _pendingMsgId = null; });
      _addMsg(_Msg(id: 'k${DateTime.now().millisecondsSinceEpoch}', isUser: false,
        text: '✅ Transaksi berhasil dicatat! Cek di tab Transaksi.'));
    } catch (_) {
      _addMsg(_Msg(id: 'ke${DateTime.now().millisecondsSinceEpoch}', isUser: false,
        text: '❌ Gagal menyimpan transaksi. Coba lagi.'));
    } finally {
      setState(() => _sending = false);
    }
  }

  void _tolak() {
    setState(() { _pendingTx = null; _pendingMsgId = null; });
    _addMsg(_Msg(id: 't${DateTime.now().millisecondsSinceEpoch}', isUser: false,
      text: 'Ok, transaksi dibatalkan. Ada yang lain? 😊'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MengFin AI', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: ConnectivityService.instance.isOnline ? AppColors.success : AppColors.danger,
                shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(ConnectivityService.instance.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: ConnectivityService.instance.isOnline ? AppColors.success : AppColors.danger,
                  fontSize: 11)),
            ]),
          ]),
        ]),
        actions: [
          IconButton(
            onPressed: () => setState(() { _msgs.clear(); _msgs.add(_Msg(id: 'welcome', isUser: false, text: '👋 Sesi baru! Ada yang bisa saya bantu?')); }),
            icon: const Icon(Icons.refresh_outlined, color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
      body: Column(children: [
        // Messages
        Expanded(child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: _msgs.length + (_sending ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _msgs.length) return _typingBubble();
            final m = _msgs[i];
            return _bubble(m);
          },
        )),

        // Quick prompts (only at start)
        if (_msgs.length <= 1)
          SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _quickPrompts.map((p) => GestureDetector(
              onTap: () => _send(p),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
                child: Text(p, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          )),

        // Input bar
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              maxLines: 3, minLines: 1,
              decoration: InputDecoration(
                hintText: 'Tulis pesan atau catat transaksi...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true, fillColor: AppColors.bgElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.glassBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.glassBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : () => _send(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _sending ? AppColors.primary.withOpacity(0.4) : AppColors.primary,
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(_Msg m) {
    final showConfirm = m.txData != null && _pendingMsgId == m.id && _pendingTx != null;
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.isUser) ...[
            Container(width: 30, height: 30, margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary)),
          ],
          Flexible(child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            decoration: BoxDecoration(
              color: m.isUser ? AppColors.primary : AppColors.bgCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(m.isUser ? 18 : 4),
                bottomRight: Radius.circular(m.isUser ? 4 : 18),
              ),
              border: m.isUser ? null : Border.all(color: AppColors.glassBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.text, style: TextStyle(color: m.isUser ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.4)),
              if (showConfirm) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: _konfirmasi,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withOpacity(0.4))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Simpan', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                      ])),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: _tolak,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withOpacity(0.4))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                        SizedBox(width: 4),
                        Text('Batal', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                      ])),
                  )),
                ]),
              ],
            ]),
          )),
        ],
      ),
    );
  }

  Widget _typingBubble() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12, left: 38),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.glassBorder)),
      child: const SizedBox(width: 40, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
    ),
  );

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }
}
