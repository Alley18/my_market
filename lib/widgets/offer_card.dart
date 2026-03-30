import 'package:flutter/material.dart';
import '../models/product.dart';

class OfferCard extends StatelessWidget {
  final Offer offer;

  const OfferCard({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(offer.productImage, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.productName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Kimga: ${offer.sellerName}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sizning taklifingiz', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text('${offer.offeredPrice.toStringAsFixed(0)} so\'m',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Asl narxi', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text('${offer.originalPrice.toStringAsFixed(0)} so\'m',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], decoration: TextDecoration.lineThrough)),
                  ],
                ),
              ],
            ),
            if (offer.status == OfferStatus.countered && offer.counterPrice != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sync_alt, size: 20, color: Color(0xFFFF6B35)),
                        SizedBox(width: 8),
                        Text('Qarama-qarshi taklif', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(offer.sellerMessage ?? 'Sotuvchi boshqa narx taklif qildi'),
                    const SizedBox(height: 8),
                    Text('${offer.counterPrice!.toStringAsFixed(0)} so\'m',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Rad etish'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Qabul qilish'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Yuborilgan: ${_formatTime(offer.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String emoji;
    String text;

    switch (offer.status) {
      case OfferStatus.pending:
        color = const Color(0xFFFFA726);
        emoji = '⏳';
        text = 'Kutilmoqda';
      case OfferStatus.accepted:
        color = const Color(0xFF4CAF50);
        emoji = '✅';
        text = 'Qabul qilindi';
      case OfferStatus.rejected:
        color = const Color(0xFFF44336);
        emoji = '❌';
        text = 'Rad etildi';
      case OfferStatus.countered:
        color = const Color(0xFF2196F3);
        emoji = '🔄';
        text = 'Yangi taklif';
      case OfferStatus.expired:
        color = const Color(0xFF9E9E9E);
        emoji = '⌛';
        text = 'Muddati o\'tgan';
      case OfferStatus.cancelled:
        color = const Color(0xFF9E9E9E);
        emoji = '🚫';
        text = 'Bekor qilingan';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text('$emoji $text',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} daqiqa oldin';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} soat oldin';
    } else {
      return '${difference.inDays} kun oldin';
    }
  }
}