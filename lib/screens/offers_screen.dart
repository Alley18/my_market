import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'negotiation_chat_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  // null = still loading, true = owner, false = customer
  bool? _isOwner;
  String? _storeId;
  String? _customerPhone;

  @override
  void initState() {
    super.initState();
    _resolveUserRole();
  }

  Future<void> _resolveUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Signed-in user — check if they own a store
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isOwner = userDoc.data()?['isStoreOwner'] == true;
      final storeId = userDoc.data()?['storeId'] as String?;

      // Save FCM token for owner notifications while we're here
      if (isOwner) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'fcmToken': token});
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isOwner = isOwner;
          _storeId = storeId;
        });
      }
    } else {
      // Guest — they submitted offers with their phone number
      // We'll ask them to enter their phone to look up their offers
      if (mounted) setState(() => _isOwner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOwner == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_isOwner == true && _storeId != null) {
      return _OwnerOffersView(storeId: _storeId!);
    }

    return _CustomerOffersView();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNER VIEW
// ─────────────────────────────────────────────────────────────────────────────

class   _OwnerOffersView extends StatefulWidget {
  final String storeId;
  const _OwnerOffersView({required this.storeId});

  @override
  State<_OwnerOffersView> createState() => _OwnerOffersViewState();
}

class _OwnerOffersViewState extends State<_OwnerOffersView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  final _statuses = ['pending', 'countered', 'accepted', 'rejected'];
  final _tabLabels = ['Yangi', 'Muzokaralar', 'Kelishildi', 'Rad etildi'];
  final _tabIcons = [
    Icons.inbox_outlined,
    Icons.swap_horiz,
    Icons.check_circle_outline,
    Icons.cancel_outlined,
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kelgan takliflar',
              style: TextStyle(
                color: _dark,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('offers')
                  .where('storeId', isEqualTo: widget.storeId)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Text(
                  count > 0
                      ? '$count ta yangi taklif kutmoqda'
                      : 'Barcha takliflar ko\'rib chiqilgan',
                  style: TextStyle(
                    fontSize: 12,
                    color: count > 0 ? _primary : Colors.grey,
                    fontWeight: count > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                );
              },
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: TabBar(
            controller: _tabController,
            tabs: List.generate(
              4,
              (i) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_tabIcons[i], size: 15),
                    const SizedBox(width: 4),
                    Text(_tabLabels[i]),
                  ],
                ),
              ),
            ),
            labelColor: _primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 12),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses
            .map((status) => _OfferListView(
                  storeId: widget.storeId,
                  status: status,
                  isOwner: true,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerOffersView extends StatefulWidget {
  @override
  State<_CustomerOffersView> createState() => _CustomerOffersViewState();
}

class _CustomerOffersViewState extends State<_CustomerOffersView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  String? _lookupPhone;

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  final _statuses = ['pending', 'countered', 'accepted', 'rejected'];
  final _tabLabels = ['Kutilmoqda', 'Javob keldi', 'Kelishildi', 'Rad etildi'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mening takliflarim',
          style: TextStyle(
            color: _dark,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Column(
        children: [
          // Phone lookup bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Telefon raqamingiz bilan takliflarni toping',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: Colors.grey, size: 20),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (v) =>
                        setState(() => _lookupPhone = v.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => setState(
                      () => _lookupPhone = _phoneController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Topish',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
              labelColor: _primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 12),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
            ),
          ),

          Expanded(
            child: _lookupPhone == null || _lookupPhone!.isEmpty
                ? _buildPhonePrompt()
                : TabBarView(
                    controller: _tabController,
                    children: _statuses
                        .map((status) => _OfferListView(
                              customerPhone: _lookupPhone,
                              status: status,
                              isOwner: false,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhonePrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Takliflaringizni ko\'rish uchun\ntelefon raqamingizni kiriting',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED OFFER LIST (used by both owner and customer views)
// ─────────────────────────────────────────────────────────────────────────────

class _OfferListView extends StatelessWidget {
  final String? storeId;
  final String? customerPhone;
  final String status;
  final bool isOwner;

  const _OfferListView({
    this.storeId,
    this.customerPhone,
    required this.status,
    required this.isOwner,
  });

  static const _primary = Color(0xFFFF6B35);

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

  Query<Map<String, dynamic>> _buildQuery() {
  Query<Map<String, dynamic>> q =
      FirebaseFirestore.instance.collection('offers');

  if (isOwner && storeId != null) {
    q = q.where('storeId', isEqualTo: storeId);
  } else if (!isOwner && customerPhone != null) {
    q = q.where('customerPhone', isEqualTo: customerPhone);
  }

  return q
      .where('status', isEqualTo: status)
      .orderBy('updatedAt', descending: true);
}
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildEmpty();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snap.data!.docs[i];
            final offer = doc.data() as Map<String, dynamic>;
            return _OfferCard(
              offerId: doc.id,
              offer: offer,
              isOwner: isOwner,
              formatPrice: _formatPrice,
              timeAgo: _timeAgo,
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    final emptyConfig = {
      'pending': (Icons.inbox_outlined, 'Yangi taklif yo\'q'),
      'countered': (Icons.swap_horiz, 'Muzokaralar yo\'q'),
      'accepted': (Icons.check_circle_outline, 'Kelishilgan taklif yo\'q'),
      'rejected': (Icons.cancel_outlined, 'Rad etilgan taklif yo\'q'),
    };

    final (icon, label) =
        emptyConfig[status] ?? (Icons.inbox_outlined, 'Taklif yo\'q');

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> offer;
  final bool isOwner;
  final String Function(double) formatPrice;
  final String Function(Timestamp?) timeAgo;

  const _OfferCard({
    required this.offerId,
    required this.offer,
    required this.isOwner,
    required this.formatPrice,
    required this.timeAgo,
  });

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  Color _statusColor(String s) => switch (s) {
        'pending' => Colors.orange,
        'countered' => Colors.blue,
        'accepted' => Colors.green,
        'rejected' => Colors.red,
        _ => Colors.grey,
      };

  String _statusLabel(String s) => switch (s) {
        'pending' => isOwner ? 'Yangi' : 'Kutilmoqda',
        'countered' => isOwner ? 'Kontr-taklif' : 'Javob keldi',
        'accepted' => 'Kelishildi ✅',
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

    // Highlight cards that need attention
    final needsAttention = (isOwner && status == 'pending') ||
        (!isOwner && status == 'countered');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NegotiationChatScreen(
            offerId: offerId,
            isOwner: isOwner,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: needsAttention
              ? Border.all(color: statusColor.withOpacity(0.4), width: 1.5)
              : null,
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
                      child: (offer['productImage'] as String? ?? '').isNotEmpty
                          ? Image.network(
                              offer['productImage'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imageFallback(),
                            )
                          : _imageFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name + status badge
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
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
                        // Show different secondary info based on role
                        if (isOwner) ...[
                          _infoRow(Icons.person_outline,
                              offer['customerName'] ?? ''),
                          const SizedBox(height: 2),
                          _infoRow(Icons.phone_outlined,
                              offer['customerPhone'] ?? ''),
                        ] else ...[
                          _infoRow(Icons.store_outlined,
                              'Do\'kon: ${offer['storeId'] ?? ''}'),
                          const SizedBox(height: 2),
                          _infoRow(Icons.location_on_outlined,
                              offer['customerAddress'] ?? ''),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Price strip + time + arrow
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: needsAttention
                    ? statusColor.withOpacity(0.05)
                    : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  _miniPrice('Asl', originalPrice, Colors.grey),
                  _arrow(),
                  _miniPrice('Taklif', offerPrice, Colors.blue),
                  if (counterPrice != null) ...[
                    _arrow(),
                    _miniPrice('Kontr', counterPrice, _primary),
                  ],
                  const Spacer(),
                  Text(
                    timeAgo(updatedAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  // Attention dot for cards needing action
                  if (needsAttention)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
        color: Colors.grey[100],
        child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
      );

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _miniPrice(String label, double price, Color color) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color.withOpacity(0.7))),
            Text(
              '${formatPrice(price)} so\'m',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
          ],
        ),
      );

  Widget _arrow() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
      );
}