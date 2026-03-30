import 'package:flutter/material.dart';
import '../models/product.dart';

class MakeOfferDialog extends StatefulWidget {
  final Product product;

  const MakeOfferDialog({super.key, required this.product});

  @override
  State<MakeOfferDialog> createState() => _MakeOfferDialogState();
}

class _MakeOfferDialogState extends State<MakeOfferDialog> {
  late TextEditingController _priceController;
  String message = '';

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: (widget.product.currentPrice * 0.85).toStringAsFixed(0)
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _applyDiscount(double percentage) {
    final newPrice = widget.product.currentPrice * (1 - percentage / 100);
    _priceController.text = newPrice.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Taklifingizni kiriting', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Sotuvchi narxi: ${widget.product.currentPrice.toStringAsFixed(0)} so\'m',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 16),
            const Text('Sizning taklifingiz:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffix: const Text('so\'m'),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tez chegirmalar:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildDiscountChip('-10%', 10),
                _buildDiscountChip('-15%', 15),
                _buildDiscountChip('-20%', 20),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => message = value,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Xabar yozish (ixtiyoriy)...',
                filled: true,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Bekor qilish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Taklif yuborildi! Sotuvchi tez orada javob beradi.'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
                    },
                    child: const Text('Yuborish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountChip(String label, double percentage) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyDiscount(percentage),
      backgroundColor: const Color(0xFFF0F0F0),
    );
  }
}