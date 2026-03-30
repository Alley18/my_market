import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'negotiation_chat_screen.dart';

class OwnerOffersScreen extends StatefulWidget {
  final String storeId;

  const OwnerOffersScreen({super.key, required this.storeId});

  @override
  State<OwnerOffersScreen> createState() => _OwnerOffersScreenState();
}

class _OwnerOffersScreenState extends State<OwnerOffersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  final _tabs = const [
    Tab(text: 'Yangi'),
    Tab(text: 'Kontr-taklif'),
    Tab(text: 'Kelishildi'),
    Tab(text: 'Rad etildi'),
  ];

  final _statuses = ['pending', 'countered', 'accepted', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Hozir';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    return '${diff.inDays} kun oldin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _dark),
        title: const Text(
          'Kelgan takliflar',
          style: TextStyle(
            color: _dark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          labelColor: _primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses
            .map((status) => _OffersList(
                  storeId: widget.storeId,
                  status: status,
                  formatPrice: _formatPrice,
                  timeAgo: _timeAgo,
                ))
            .toList(),
      ),
    );
  }
}

class _OffersList extends StatelessWidget {
  final String storeId;
  final String status;
  final String Function(double) formatPrice;
  final String Function(Timestamp?) timeAgo;

  const _OffersList({
    required this.storeId,
    required this.status,
    required this.formatPrice,
    required this.timeAgo,
  });

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('storeId', isEqualTo: storeId)
          .where('status', isEqualTo: status)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == 'pending'
                      ? Icons.inbox_outlined
                      : status == 'accepted'
                          ? Icons.check_circle_outline
                          : Icons.do_not_disturb_outlined,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  _emptyLabel(status),
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snap.data!.docs[index];
            final offer = doc.data() as Map<String, dynamic>;
            return _OfferCard(
              offerId: doc.id,
              offer: offer,
              formatPrice: formatPrice,
              timeAgo: timeAgo,
            );
          },
        );
      },
    );
  }

  String _emptyLabel(String status) {
    return switch (status) {
      'pending' => 'Yangi taklif yo\'q',
      'countered' => 'Kontr-taklif yo\'q',
      'accepted' => 'Kelishilgan taklif yo\'q',
      'rejected' => 'Rad etilgan taklif yo\'q',
      _ => 'Taklif yo\'q',
    };
  }
}

class _OfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> offer;
  final String Function(double) formatPrice;
  final String Function(Timestamp?) timeAgo;

  const _OfferCard({
    required this.offerId,
    required this.offer,
    required this.formatPrice,
    required this.timeAgo,
  });

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  Color _statusColor(String status) => switch (status) {
        'pending' => Colors.orange,
        'countered' => Colors.blue,
        'accepted' => Colors.green,
        'rejected' => Colors.red,
        _ => Colors.grey,
      };

  String _statusLabel(String status) => switch (status) {
        'pending' => 'Yangi',
        'countered' => 'Kontr-taklif',
        'accepted' => 'Kelishildi',
        'rejected' => 'Rad etildi',
        _ => 'Noma\'lum',
      };

  @override
  Widget build(BuildContext context) {
    final status = offer['status'] as String;
    final originalPrice = (offer['originalPrice'] as num).toDouble();
    final offerPrice = (offer['offerPrice'] as num).toDouble();
    final counterPrice = offer['counterPrice'] != null
        ? (offer['counterPrice'] as num).toDouble()
        : null;
    final updatedAt = offer['updatedAt'] as Timestamp?;
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NegotiationChatScreen(
              offerId: offerId,
              isOwner: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
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
                              color: Colors.grey[100],
                              child: const Icon(Icons.shopping_bag_outlined,
                                  color: Colors.grey),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                offer['productName'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _dark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              offer['customerName'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              offer['customerPhone'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Price row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  _miniPrice(
                    'Asl narx',
                    originalPrice,
                    Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  _miniPrice(
                    'Taklif',
                    offerPrice,
                    Colors.blue,
                  ),
                  if (counterPrice != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    _miniPrice('Kontr', counterPrice, _primary),
                  ],
                  const Spacer(),
                  Text(
                    timeAgo(updatedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPrice(String label, double price, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.7),
          ),
        ),
        Text(
          '${formatPrice(price)} so\'m',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}