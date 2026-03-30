import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../widgets/category_chip.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'Barchasi';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final PageController _featuredPageController = PageController(viewportFraction: 0.87);
  int _currentFeaturedPage = 0;

  // Combined products list
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;

  String getOptimizedUrl(String url) {
    if (url.contains('cloudinary.com')) {
      return url.replaceFirst('/upload/', '/upload/f_auto,q_auto,w_500/');
    }
    return url;
  }

  String _formatPrice(double price) {
    String priceStr = price.toStringAsFixed(0);
    return priceStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  @override
  void initState() {
    super.initState();
    _featuredPageController.addListener(() {
      int next = _featuredPageController.page!.round();
      if (_currentFeaturedPage != next) {
        setState(() => _currentFeaturedPage = next);
      }
    });
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> combined = [];

      // 1. Add demo products (converted to Map format)
      for (var product in demoProducts) {
        combined.add({
          'id': product.id,
          'name': product.name,
          'price': product.currentPrice,
          'imageUrl': product.imageUrl,
          'category': product.category,
          'storeId': product.storeId,
          'storeName': product.storeName,
          'description': product.description,
          'rating': product.rating,
          'discount': product.discount,
          'isDemo': true, // Flag to identify demo products
        });
      }

      // 2. Fetch real products from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        combined.add({
          'id': data['id'] ?? doc.id,
          'name': data['name'] ?? 'No Name',
          'price': (data['price'] ?? 0).toDouble(),
          'imageUrl': getOptimizedUrl(data['imageUrl'] ?? ''),
          'category': data['category'] ?? 'Boshqa',
          'storeId': data['storeId'] ?? '',
          'storeName': data['storeId'] ?? 'Unknown Store',
          'description': data['description'] ?? '',
          'rating': 4.5,
          'discount': 0,
          'isDemo': false, // Real product from Firestore
        });
      }

      setState(() {
        _allProducts = combined;
        _isLoading = false;
      });

      debugPrint("✅ Loaded ${combined.length} products (${demoProducts.length} demo + ${snapshot.docs.length} real)");
    } catch (e) {
      debugPrint("❌ Error loading products: $e");
      
      // Fallback to demo products only
      setState(() {
        _allProducts = demoProducts.map((p) => {
          'id': p.id,
          'name': p.name,
          'price': p.currentPrice,
          'imageUrl': p.imageUrl,
          'category': p.category,
          'storeId': p.storeId,
          'storeName': p.storeName,
          'description': p.description,
          'rating': p.rating,
          'discount': p.discount,
          'isDemo': true,
        }).toList();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _featuredPageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredProducts {
    var products = _allProducts;

    if (selectedCategory != 'Barchasi') {
      products = products.where((p) => p['category'] == selectedCategory).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      products = products.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final storeName = (p['storeName'] ?? '').toString().toLowerCase();
        return name.contains(query) || storeName.contains(query);
      }).toList();
    }

    return products;
  }

  List<Map<String, dynamic>> get featuredProducts {
    // Get products with discount or take first 5
    var featured = _allProducts.where((p) => (p['discount'] ?? 0) > 0).toList();
    
    if (featured.length < 5) {
      final remaining = _allProducts.where((p) => (p['discount'] ?? 0) == 0).take(5 - featured.length);
      featured.addAll(remaining);
    }
    
    return featured.take(5).toList();
  }

  Set<String> get allCategories {
    return _allProducts.map((p) => p['category'].toString()).toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B35),
          ),
        ),
      );
    }

    final featuredItems = featuredProducts;
    final categories = ['Barchasi', ...allCategories];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        color: const Color(0xFFFF6B35),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 70,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFFFF6B35),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bozorim',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Mahsulot yoki do\'kon...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF2E294E)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            // Featured Products
            if (searchQuery.isEmpty && selectedCategory == 'Barchasi' && featuredItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        '⭐ Tavsiya etilganlar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        controller: _featuredPageController,
                        itemCount: featuredItems.length,
                        itemBuilder: (context, index) {
                          final product = featuredItems[index];
                          return _buildFeaturedCard(product, index);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        featuredItems.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentFeaturedPage == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentFeaturedPage == index
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

            // Categories
            if (categories.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CategoryChip(
                            label: category,
                            isSelected: selectedCategory == category,
                            onTap: () => setState(() => selectedCategory = category),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Products Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: filteredProducts.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Hech qanday mahsulot topilmadi',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.73,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = filteredProducts[index];
                          return _buildProductCard(context, product);
                        },
                        childCount: filteredProducts.length,
                      ),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadProducts,
        backgroundColor: const Color(0xFFFF6B35),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final name = product['name'] ?? 'Nomi yo\'q';
    final price = (product['price'] ?? 0).toDouble();
    final imageUrl = product['imageUrl'] ?? '';
    final category = product['category'] ?? 'Boshqa';
    final isDemo = product['isDemo'] ?? false;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: product['id'] ?? '',
              productData: product,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  
                  // Demo badge (optional)
                  if (isDemo)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Demo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E294E),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Product name
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF2E294E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Price
                    Text(
                      '${_formatPrice(price)} so\'m',
                      style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> product, int index) {
    final colors = [
      [const Color(0xFFFF6B35), const Color(0xFFFF8C5A)],
      [const Color(0xFF2196F3), const Color(0xFF42A5F5)],
      [const Color(0xFF9C27B0), const Color(0xFFBA68C8)],
    ];
    final gradientColors = colors[index % colors.length];

    final name = product['name'] ?? '';
    final price = (product['price'] ?? 0).toDouble();
    final imageUrl = product['imageUrl'] ?? '';
    final storeName = product['storeName'] ?? '';
    final rating = (product['rating'] ?? 4.5).toDouble();
    final discount = (product['discount'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: product['id'] ?? '',
              productData: product,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: Container(
                  color: Colors.white,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (discount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${discount.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.store, size: 14, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            storeName,
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _formatPrice(price),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}