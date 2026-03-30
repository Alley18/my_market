import 'package:flutter/material.dart';
import '../models/product.dart';

class StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const StoreCard({super.key, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // --- STORE IMAGE BOX ---
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 70,
                width: 70,
                color: Colors.grey[100],
                child: _buildStoreImage(),
              ),
            ),
            const SizedBox(width: 14),
            
            // --- STORE INFO (Fixed Overflow) ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2E294E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.location,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Rating & Verified
                  Row(
                    children: [
                      _buildRatingBadge(),
                      const SizedBox(width: 8),
                      if (store.isVerified) _buildVerifiedBadge(),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreImage() {
    // 1. Check if it's a Network Image (from Firestore)
    if (store.imageUrl.startsWith('http')) {
      return Image.network(
        store.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildStorePlaceholder(),
      );
    } 
    
    // 2. Check if it's an Asset Image (from Dummy Data)
    else if (store.imageUrl.isNotEmpty) {
      // Logic to ensure the path is correct even if it's missing "assets/"
      String finalPath = store.imageUrl;
      if (!finalPath.startsWith('assets/')) {
        finalPath = 'assets/$finalPath';
      }

      return Image.asset(
        finalPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If the asset file itself is missing or name is wrong, show placeholder
          return _buildStorePlaceholder();
        },
      );
    }

    // 3. Fallback for empty strings
    return _buildStorePlaceholder();
  }

  Widget _buildStorePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.store_rounded, color: Colors.white, size: 30),
    );
  }

  Widget _buildRatingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, size: 12, color: Color(0xFFFFA726)),
          const SizedBox(width: 3),
          Text(
            store.rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified, size: 12, color: Color(0xFF4CAF50)),
          SizedBox(width: 3),
          Text(
            'Tasdiqlangan',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50)),
          ),
        ],
      ),
    );
  }
}