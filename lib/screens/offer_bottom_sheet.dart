import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class OfferBottomSheet extends StatefulWidget {
  final String productId;
  final String productName;
  final String productImage;
  final String storeId;
  final double originalPrice;

  const OfferBottomSheet({
    super.key,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.storeId,
    required this.originalPrice,
  });

  @override
  State<OfferBottomSheet> createState() => _OfferBottomSheetState();
}

class _OfferBottomSheetState extends State<OfferBottomSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _offerController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _offerController.dispose();
    _messageController.dispose();
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

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    final offerPrice = double.tryParse(
      _offerController.text.trim().replaceAll(' ', ''),
    );

    if (offerPrice == null) {
      _showError("Narx noto'g'ri formatda");
      return;
    }

    if (offerPrice >= widget.originalPrice) {
      _showError("Taklif narxi mahsulot narxidan past bo'lishi kerak");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get customer FCM token for future notifications back to them
      String? customerFcmToken;
      try {
        customerFcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      // Create the offer document
      final offerRef =
          await FirebaseFirestore.instance.collection('offers').add({
        'productId': widget.productId,
        'productName': widget.productName,
        'productImage': widget.productImage,
        'storeId': widget.storeId,
        'customerName': _nameController.text.trim(),
        'customerPhone': _phoneController.text.trim(),
        'customerAddress': _addressController.text.trim(),
        'customerFcmToken': customerFcmToken,
        'originalPrice': widget.originalPrice,
        'offerPrice': offerPrice,
        'counterPrice': null,
        'status': 'pending', // pending | countered | accepted | rejected
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add first message if customer wrote something
      final msg = _messageController.text.trim();
      if (msg.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('offers')
            .doc(offerRef.id)
            .collection('messages')
            .add({
          'text': msg,
          'senderRole': 'customer',
          'senderName': _nameController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Notify the store owner via FCM (server-side trigger via Firestore)
      // We write a notification request that your Cloud Function will pick up
      await FirebaseFirestore.instance.collection('notification_queue').add({
        'type': 'new_offer',
        'storeId': widget.storeId,
        'offerId': offerRef.id,
        'productName': widget.productName,
        'offerPrice': offerPrice,
        'customerName': _nameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, offerRef.id); // return offerId to caller
      }
    } catch (e) {
      _showError("Xatolik yuz berdi: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: _primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Narx taklif qilish',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        Text(
                          widget.productName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Original price banner
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sell_outlined, color: _primary, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Joriy narx: ',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '${_formatPrice(widget.originalPrice)} so\'m',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Scrollable form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Sizning ma\'lumotlaringiz'),
                      const SizedBox(height: 12),
                      _field(
                        controller: _nameController,
                        hint: 'To\'liq ismingiz',
                        icon: Icons.person_outline,
                        validator: (v) =>
                            v!.isEmpty ? 'Ism kiriting' : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _phoneController,
                        hint: '+998 9x xxx xx xx',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v!.isEmpty) return 'Telefon kiriting';
                          if (v.length < 9) return 'To\'liq raqam kiriting';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _addressController,
                        hint: 'Manzil (shahar, ko\'cha)',
                        icon: Icons.location_on_outlined,
                        validator: (v) =>
                            v!.isEmpty ? 'Manzil kiriting' : null,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('Narx taklifingiz'),
                      const SizedBox(height: 12),
                      // Offer price field — styled prominently
                      TextFormField(
                        controller: _offerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[300],
                          ),
                          suffixText: 'so\'m',
                          suffixStyle: const TextStyle(
                            fontSize: 16,
                            color: _primary,
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: _primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Taklif narxini kiriting';
                          }
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed <= 0) {
                            return 'To\'g\'ri narx kiriting';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _field(
                        controller: _messageController,
                        hint:
                            'Egasiga xabar yozishingiz mumkin (ixtiyoriy)...',
                        icon: Icons.chat_bubble_outline,
                        maxLines: 3,
                        required: false,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Submit button
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOffer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: _primary.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Taklif yuborish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator ??
          (required ? (v) => v!.isEmpty ? 'To\'ldiring' : null : null),
    );
  }
}