import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';

class _Msg {
  final String id;
  final bool isUser;
  final String text;
  final Map<String, dynamic>? txData;
  final String? type; // 'transaksi_preview', 'hapus_preview', 'jawaban'
  _Msg({
    required this.id,
    required this.isUser,
    required this.text,
    this.txData,
    this.type,
  });
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _msgs = <_Msg>[
    _Msg(
      id: 'welcome',
      isUser: false,
      text: '👋 Hai! Saya **MengFin AI**, asisten keuangan personalmu.\n\n'
          'Kamu bisa:\n• Tanya analisis keuangan & saldo\n• Catat transaksi langsung (misal: "beli kopi 25rb")\n• Minta tips hemat & kelola budget\n• Hapus transaksi terakhir\n\nAda yang bisa saya bantu? 😊',
    ),
  ];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _cancelled = false;
  Map<String, dynamic>? _pendingTx;
  Map<String, dynamic>? _pendingHapus;
  String? _pendingMsgId;

  List<String> _currentSuggestions = [
    'Berapa saldo saya?',
    'Gimana kondisi keuanganku?',
    'Tips hemat bulan ini',
    'Beli kopi 25rb',
    'Riwayat transaksi',
  ];

  void _addMsg(_Msg m) {
    setState(() => _msgs.add(m));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _batalKirim() {
    setState(() {
      _cancelled = true;
      _sending = false;
    });
    _addMsg(_Msg(
      id: 'c${DateTime.now().millisecondsSinceEpoch}',
      isUser: false,
      text: 'Permintaan dibatalkan.',
    ));
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _ctrl.text).trim();
    if (msg.isEmpty || _sending) return;

    _ctrl.clear();
    _cancelled = false;
    setState(() => _sending = true);

    final uid = 'u${DateTime.now().millisecondsSinceEpoch}';
    _addMsg(_Msg(id: uid, isUser: true, text: msg));

    try {
      final res = await ApiService.chat(msg);
      if (_cancelled || !mounted) return;

      final aid = 'a${DateTime.now().millisecondsSinceEpoch}';

      // Update quick reply suggestions jika ada
      if (res['saran'] is List) {
        final rawSaran = (res['saran'] as List).map((s) => s.toString()).toList();
        if (rawSaran.isNotEmpty) {
          setState(() => _currentSuggestions = rawSaran);
        }
      }

      if (res['tipe'] == 'transaksi_preview') {
        setState(() {
          _pendingTx = res['data'];
          _pendingHapus = null;
          _pendingMsgId = aid;
        });
        _addMsg(_Msg(
          id: aid,
          isUser: false,
          text: res['pesan'] ?? '',
          txData: res['data'],
          type: 'transaksi_preview',
        ));
      } else if (res['tipe'] == 'hapus_preview') {
        setState(() {
          _pendingHapus = res['data'];
          _pendingTx = null;
          _pendingMsgId = aid;
        });
        _addMsg(_Msg(
          id: aid,
          isUser: false,
          text: res['pesan'] ?? '',
          txData: res['data'],
          type: 'hapus_preview',
        ));
      } else {
        // Multi-bubble splitting untuk analisis panjang
        final fullText = (res['pesan'] ?? '...').toString();
        if (fullText.length > 350 && fullText.contains('\n\n')) {
          final sections = fullText.split('\n\n').where((s) => s.trim().isNotEmpty).toList();
          if (sections.length > 1) {
            for (int sIdx = 0; sIdx < sections.length; sIdx++) {
              final sText = sections[sIdx];
              final subId = 'a_${DateTime.now().millisecondsSinceEpoch}_$sIdx';
              _addMsg(_Msg(id: subId, isUser: false, text: sText));
              if (sIdx < sections.length - 1) {
                await Future.delayed(const Duration(milliseconds: 300));
              }
            }
          } else {
            _addMsg(_Msg(id: aid, isUser: false, text: fullText));
          }
        } else {
          _addMsg(_Msg(id: aid, isUser: false, text: fullText));
        }
      }
    } catch (_) {
      if (!_cancelled && mounted) {
        _addMsg(_Msg(
          id: 'e${DateTime.now().millisecondsSinceEpoch}',
          isUser: false,
          text: '⚠️ Maaf, terjadi kendala saat memproses pesan. Silakan coba lagi.',
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _konfirmasi() async {
    if (_pendingTx == null) return;
    setState(() => _sending = true);
    try {
      await ApiService.konfirmasiTransaksi(_pendingTx!);
      setState(() {
        _pendingTx = null;
        _pendingMsgId = null;
      });
      _addMsg(_Msg(
        id: 'k${DateTime.now().millisecondsSinceEpoch}',
        isUser: false,
        text: '✅ Transaksi berhasil dicatat! Cek di tab Transaksi.',
      ));
    } catch (_) {
      _addMsg(_Msg(
        id: 'ke${DateTime.now().millisecondsSinceEpoch}',
        isUser: false,
        text: '❌ Gagal menyimpan transaksi. Coba lagi.',
      ));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _konfirmasiHapus() async {
    if (_pendingHapus == null) return;
    final id = _pendingHapus!['id'];
    setState(() => _sending = true);
    try {
      if (id != null) {
        await ApiService.deleteTransaksi(id);
      }
      setState(() {
        _pendingHapus = null;
        _pendingMsgId = null;
      });
      _addMsg(_Msg(
        id: 'dh${DateTime.now().millisecondsSinceEpoch}',
        isUser: false,
        text: '🗑️ Transaksi berhasil dihapus.',
      ));
    } catch (e) {
      _addMsg(_Msg(
        id: 'dhe${DateTime.now().millisecondsSinceEpoch}',
        isUser: false,
        text: '❌ Gagal menghapus transaksi: $e',
      ));
    } finally {
      setState(() => _sending = false);
    }
  }

  void _tolak() {
    setState(() {
      _pendingTx = null;
      _pendingHapus = null;
      _pendingMsgId = null;
    });
    _addMsg(_Msg(
      id: 't${DateTime.now().millisecondsSinceEpoch}',
      isUser: false,
      text: 'Ok, dibatalkan. Ada yang lain yang bisa saya bantu? 😊',
    ));
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
             Text('MengFin AI', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
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
            icon:  Icon(Icons.refresh_outlined, color: AppColors.textMuted, size: 20),
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

        // Quick reply suggestions chips (always accessible)
        if (_currentSuggestions.isNotEmpty)
          Container(
            height: 42,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: _currentSuggestions.map((p) => GestureDetector(
                onTap: _sending ? null : () => _send(p),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),

        // Input bar
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
          decoration:  BoxDecoration(
            color: AppColors.bgCard,
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              style:  TextStyle(color: AppColors.textPrimary, fontSize: 14),
              maxLines: 3, minLines: 1,
              decoration: InputDecoration(
                hintText: 'Tulis pesan atau catat transaksi...',
                hintStyle:  TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true, fillColor: AppColors.bgElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.glassBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.glassBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.primary)),
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

  Widget _renderMessageText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white : AppColors.textPrimary;
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) return const SizedBox(height: 6);

        final isBullet = line.trimLeft().startsWith('•') ||
            line.trimLeft().startsWith('-') ||
            RegExp(r'^\d+\.').hasMatch(line.trimLeft());

        final spans = <TextSpan>[];
        final regex = RegExp(r'\*\*(.*?)\*\*');
        int lastIndex = 0;

        for (final match in regex.allMatches(line)) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(
              text: line.substring(lastIndex, match.start),
              style: TextStyle(color: baseColor, fontSize: 13.5, height: 1.45),
            ));
          }
          spans.add(TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: isUser ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              height: 1.45,
            ),
          ));
          lastIndex = match.end;
        }

        if (lastIndex < line.length) {
          spans.add(TextSpan(
            text: line.substring(lastIndex),
            style: TextStyle(color: baseColor, fontSize: 13.5, height: 1.45),
          ));
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 2, left: isBullet ? 4 : 0),
          child: RichText(
            text: TextSpan(children: spans),
          ),
        );
      }).toList(),
    );
  }

  Widget _bubble(_Msg m) {
    final showConfirmTx = m.type == 'transaksi_preview' && _pendingMsgId == m.id && _pendingTx != null;
    final showConfirmHapus = m.type == 'hapus_preview' && _pendingMsgId == m.id && _pendingHapus != null;

    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.isUser) ...[
            Container(width: 30, height: 30, margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.auto_awesome, size: 14, color: AppColors.primary)),
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
              _renderMessageText(m.text, m.isUser),
              if (showConfirmTx) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: _konfirmasi,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Simpan', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                      ])),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: _tolak,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Text('Batal', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                      ])),
                  )),
                ]),
              ],
              if (showConfirmHapus) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: _konfirmasiHapus,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Text('Ya, Hapus', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                      ])),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: _tolak,
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.glassBorder)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Batal', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          const SizedBox(width: 10),
          Text('Mengetik...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _batalKirim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text('Batal', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }
}
