import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offer_bottom_sheet.dart';
import 'negotiation_chat_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.productData,
  });

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  String _formatPrice(double price) {
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  @override
  Widget build(BuildContext context) {
    final name = productData['name'] ?? 'Nomi yo\'q';
    final price = (productData['price'] ?? 0).toDouble();
    final description = productData['description'] ?? '';
    final imageUrl = productData['imageUrl'] ?? '';
    final category = productData['category'] ?? 'Boshqa';
    final storeId = productData['storeId'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: _dark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductImage(context, imageUrl),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategoryChip(category),
                        const SizedBox(height: 12),
                        _buildProductName(name),
                        const SizedBox(height: 8),
                        _buildStoreName(storeId),
                        const SizedBox(height: 24),
                        _buildPriceSection(price),
                        const SizedBox(height: 8),
                        // Negotiation hint
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handshake_outlined,
                                  size: 16, color: Colors.green),
                              SizedBox(width: 6),
                              Text(
                                'Bu mahsulot narxi moslashuvchan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDescriptionSection(description),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(context, name, imageUrl, storeId, price),
        ],
      ),
    );
  }

  Widget _buildProductImage(BuildContext context, String imageUrl) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.45,
      color: Colors.grey[100],
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: _primary,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                );
              },
            )
          : const Center(
              child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _dark,
        ),
      ),
    );
  }

  Widget _buildProductName(String name) {
    return Text(
      name,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _dark,
        height: 1.2,
      ),
    );
  }

  Widget _buildStoreName(String storeId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('stores').doc(storeId).get(),
      builder: (context, snapshot) {
        String storeName = 'Do\'kon';
        if (snapshot.hasData && snapshot.data!.exists) {
          storeName = snapshot.data!.get('name') ?? 'Do\'kon';
        }
        return Row(
          children: [
            const Icon(Icons.store, size: 18, color: Color(0xFF9E9E9E)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                storeName,
                style: const TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriceSection(double price) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _formatPrice(price),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          const TextSpan(
            text: ' so\'m',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mahsulot haqida',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _dark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description.isNotEmpty ? description : 'Tavsif kiritilmagan',
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Color(0xFF616161),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    String productName,
    String productImage,
    String storeId,
    double price,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Contact button (secondary)
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                onPressed: () => _contactStore(context, storeId),
                icon: const Icon(Icons.phone_outlined, size: 20),
                label: const Text(
                  'Bog\'lanish',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _dark,
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Make offer button (primary)
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                onPressed: () => _openOfferSheet(
                  context,
                  productName,
                  productImage,
                  storeId,
                  price,
                ),
                icon: const Icon(Icons.handshake_outlined, size: 20),
                label: const Text(
                  'Taklif berish',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOfferSheet(
    BuildContext context,
    String productName,
    String productImage,
    String storeId,
    double price,
  ) async {
    // Show the offer bottom sheet and get back the offerId if submitted
    final offerId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferBottomSheet(
        productId: productId,
        productName: productName,
        productImage: productImage,
        storeId: storeId,
        originalPrice: price,
      ),
    );

    // If offer was submitted, navigate to the negotiation/chat screen
    if (offerId != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NegotiationChatScreen(
            offerId: offerId,
            isOwner: false, // customer view
          ),
        ),
      );
    }
  }

  Future<void> _contactStore(BuildContext context, String storeId) async {
    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();

      if (!storeDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Do\'kon topilmadi')),
          );
        }
        return;
      }

      final phones = storeDoc.data()?['phones'] as List<dynamic>? ?? [];

      if (phones.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Telefon raqam topilmadi')),
          );
        }
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Telefon raqamlar',
              style: TextStyle(color: _dark, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: phones
                  .map(
                    (phone) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, color: _primary),
                          const SizedBox(width: 12),
                          Text(
                            phone.toString(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Yopish'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e')),
        );
      }
    }
  }
}