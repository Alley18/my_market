import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// [isOwner] = true  → owner view (can accept/reject/counter)
/// [isOwner] = false → customer view (can accept/reject counter-offer)
class NegotiationChatScreen extends StatefulWidget {
  final String offerId;
  final bool isOwner;

  const NegotiationChatScreen({
    super.key,
    required this.offerId,
    required this.isOwner,
  });

  @override
  State<NegotiationChatScreen> createState() => _NegotiationChatScreenState();
}

class _NegotiationChatScreenState extends State<NegotiationChatScreen> {
  final _msgController = TextEditingController();
  final _counterController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);
  static const _ownerBubble = Color(0xFF2E294E);
  static const _customerBubble = Color(0xFFFF6B35);

  @override
  void dispose() {
    _msgController.dispose();
    _counterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _msgController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .collection('messages')
          .add({
        'text': text,
        'senderRole': widget.isOwner ? 'owner' : 'customer',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update offer updatedAt so owner dashboard sorts correctly
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .update({'updatedAt': FieldValue.serverTimestamp()});

      _scrollToBottom();
    } catch (e) {
      _showError('Xabar yuborilmadi: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _updateOfferStatus(
    String status, {
    double? counterPrice,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (counterPrice != null) updates['counterPrice'] = counterPrice;

      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .update(updates);

      // Write notification queue entry for FCM Cloud Function to pick up
      final offerSnap = await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .get();
      final data = offerSnap.data()!;

      String notifType;
      String bodyText;
      String targetToken;

      if (widget.isOwner) {
        // Owner acted → notify customer
        targetToken = data['customerFcmToken'] ?? '';
        if (status == 'accepted') {
          notifType = 'offer_accepted';
          bodyText =
              '${data['productName']} uchun taklifingiz qabul qilindi! 🎉';
        } else if (status == 'rejected') {
          notifType = 'offer_rejected';
          bodyText =
              '${data['productName']} uchun taklifingiz rad etildi.';
        } else {
          notifType = 'offer_countered';
          bodyText =
              '${data['productName']}: Do\'kon ${_formatPrice(counterPrice!)} so\'m taklif qildi.';
        }
      } else {
        // Customer acted on counter → notify owner via storeId
        targetToken = ''; // Cloud Function resolves owner token from storeId
        notifType = status == 'accepted'
            ? 'counter_accepted'
            : 'counter_rejected';
        bodyText = status == 'accepted'
            ? 'Mijoz narxni qabul qildi!'
            : 'Mijoz narxni rad etdi.';
      }

      await FirebaseFirestore.instance.collection('notification_queue').add({
        'type': notifType,
        'offerId': widget.offerId,
        'storeId': data['storeId'],
        'targetFcmToken': targetToken,
        'body': bodyText,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showError('Amal bajarilmadi: $e');
    }
  }

  void _showCounterDialog(Map<String, dynamic> offerData) {
    _counterController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Narx taklif qilish',
          style: TextStyle(
            color: _dark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mijoz: ${_formatPrice((offerData['offerPrice'] as num).toDouble())} so\'m taklif qildi',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _counterController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _dark,
              ),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'so\'m',
                suffixStyle: const TextStyle(color: _primary),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(_counterController.text.trim());
              if (val == null || val <= 0) return;
              Navigator.pop(ctx);
              await _updateOfferStatus('countered', counterPrice: val);
              // Also send a system message into chat
              await FirebaseFirestore.instance
                  .collection('offers')
                  .doc(widget.offerId)
                  .collection('messages')
                  .add({
                'text':
                    '🏷 Do\'kon yangi narx taklif qildi: ${_formatPrice(val)} so\'m',
                'senderRole': 'system',
                'timestamp': FieldValue.serverTimestamp(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Yuborish'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .snapshots(),
      builder: (context, offerSnap) {
        if (!offerSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _primary)),
          );
        }

        final offer = offerSnap.data!.data() as Map<String, dynamic>;
        final status = offer['status'] as String;
        final originalPrice =
            (offer['originalPrice'] as num).toDouble();
        final offerPrice = (offer['offerPrice'] as num).toDouble();
        final counterPrice = offer['counterPrice'] != null
            ? (offer['counterPrice'] as num).toDouble()
            : null;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),
          appBar: _buildAppBar(offer, status),
          body: Column(
            children: [
              // Offer summary card
              _buildOfferCard(
                offer, status, originalPrice, offerPrice, counterPrice),

              // Owner action buttons (only when pending or countered by customer)
              if (widget.isOwner && status == 'pending')
                _buildOwnerActions(offer),

              // Customer action buttons (only when owner countered)
              if (!widget.isOwner && status == 'countered' && counterPrice != null)
                _buildCustomerCounterActions(counterPrice),

              // Chat messages
              Expanded(child: _buildMessagesList()),

              // Message input (only when not resolved)
              if (status != 'accepted' && status != 'rejected')
                _buildMessageInput(),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(Map<String, dynamic> offer, String status) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: const BackButton(color: _dark),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer['productName'] ?? '',
            style: const TextStyle(
              color: _dark,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            widget.isOwner
                ? offer['customerName'] ?? ''
                : 'Do\'kon bilan muzokaralar',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      actions: [
        _StatusBadge(status: status),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildOfferCard(
    Map<String, dynamic> offer,
    String status,
    double originalPrice,
    double offerPrice,
    double? counterPrice,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: offer['productImage'] != null &&
                          (offer['productImage'] as String).isNotEmpty
                      ? Image.network(
                          offer['productImage'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.shopping_bag_outlined,
                              color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer['productName'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _dark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Asl narx: ${_formatPrice(originalPrice)} so\'m',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Price row
          Row(
            children: [
              _priceChip(
                label: 'Taklif',
                price: offerPrice,
                color: Colors.blue,
              ),
              if (counterPrice != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      size: 16, color: Colors.grey),
                ),
                _priceChip(
                  label: 'Kontr',
                  price: counterPrice,
                  color: _primary,
                ),
              ],
              const Spacer(),
              if (status == 'accepted')
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Kelishildi',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Customer info (owner only)
          if (widget.isOwner) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  offer['customerName'] ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.phone_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  offer['customerPhone'] ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    offer['customerAddress'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceChip({
    required String label,
    required double price,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${_formatPrice(price)} so\'m',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerActions(Map<String, dynamic> offer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          // Reject
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await _confirmDialog('Rad etish',
                    'Taklifni rad etishni tasdiqlaysizmi?');
                if (confirm) {
                  await _updateOfferStatus('rejected');
                  await FirebaseFirestore.instance
                      .collection('offers')
                      .doc(widget.offerId)
                      .collection('messages')
                      .add({
                    'text': '❌ Do\'kon taklifni rad etdi.',
                    'senderRole': 'system',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
              },
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Rad etish'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Counter
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCounterDialog(offer),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Narx taklif'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Accept
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await _confirmDialog('Qabul qilish',
                    'Taklifni qabul qilishni tasdiqlaysizmi?');
                if (confirm) {
                  await _updateOfferStatus('accepted');
                  await FirebaseFirestore.instance
                      .collection('offers')
                      .doc(widget.offerId)
                      .collection('messages')
                      .add({
                    'text': '✅ Kelishildi! Do\'kon siz bilan bog\'lanadi.',
                    'senderRole': 'system',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Qabul'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCounterActions(double counterPrice) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do\'kon ${_formatPrice(counterPrice)} so\'m taklif qildi',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _dark,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _updateOfferStatus('rejected');
                    await FirebaseFirestore.instance
                        .collection('offers')
                        .doc(widget.offerId)
                        .collection('messages')
                        .add({
                      'text': '❌ Mijoz narxni rad etdi.',
                      'senderRole': 'system',
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Rad etish'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _updateOfferStatus('accepted');
                    await FirebaseFirestore.instance
                        .collection('offers')
                        .doc(widget.offerId)
                        .collection('messages')
                        .add({
                      'text':
                          '✅ Kelishildi! Do\'kon siz bilan bog\'lanadi.',
                      'senderRole': 'system',
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Qabul qilish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Hali xabar yo\'q.\nMuloqotni boshlang!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final msg = docs[index].data() as Map<String, dynamic>;
            final role = msg['senderRole'] as String;
            final text = msg['text'] as String;
            final ts = msg['timestamp'] as Timestamp?;

            if (role == 'system') {
              return _SystemMessage(text: text);
            }

            final isMe = (widget.isOwner && role == 'owner') ||
                (!widget.isOwner && role == 'customer');

            return _ChatBubble(
              text: text,
              isMe: isMe,
              timestamp: ts,
              bubbleColor:
                  role == 'owner' ? _ownerBubble : _customerBubble,
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Xabar yozing...',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: const TextStyle(
                    color: _dark, fontWeight: FontWeight.bold)),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Bekor',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tasdiqlash'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'pending': ('Kutilmoqda', Colors.orange),
      'countered': ('Kontr-taklif', Colors.blue),
      'accepted': ('Kelishildi', Colors.green),
      'rejected': ('Rad etildi', Colors.red),
    };
    final (label, color) = map[status] ?? ('Noma\'lum', Colors.grey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Timestamp? timestamp;
  final Color bubbleColor;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.bubbleColor,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? bubbleColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF2E294E),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                color: isMe
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey[400],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}