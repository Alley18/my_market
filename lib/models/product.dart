// ============================================================================
// PRODUCT MODEL - The Blueprint for Items in Your Digital Bazaar
// ============================================================================
// This file defines what a "Product" is and how we store information about it.
// Think of this as a template that describes every item in every shop.

/// Product Class
/// This represents a single item that a shop owner is selling.
/// For example: a red apple, a t-shirt, or a TV.
class Product {
  // ========== BASIC INFORMATION ==========
  final String id;              // Unique ID for this product (like a barcode)
  final String name;            // What is it? (e.g., "Classic Oq Koylak")
  final String description;     // Short explanation of the product
  final String imageUrl;        // Link to the product's photo
  final String category;        // Which section? (Clothes, Fruits, Electronics)
  
  // ========== PRICING ==========
  final double askingPrice;     // The price the seller WANTS (starting point for negotiation)
  final double minPrice;        // The LOWEST price the seller will accept (hidden from buyer)
  final double discount;        // Optional discount percentage (0-100)
  
  // ========== STORE INFORMATION ==========
  final String storeId;         // Which store sells this? (connects to Store)
  final String storeName;       // Name of the shop (e.g., "Dilemma's Fashion")
  final String storeLocation;   // Physical location in town (e.g., "Main Bazaar, Row 3")
  
  // ========== SOCIAL PROOF ==========
  // These help buyers trust the product
  final double rating;          // Average rating (0.0 to 5.0 stars)
  final int reviewCount;        // How many people reviewed it
  final int soldCount;          // How many have been sold (builds trust)
  
  // ========== INVENTORY ==========
  final int stockQuantity;      // How many are available right now
  final bool isAvailable;       // Is it in stock? (true/false)
  
  // ========== SPECIAL FLAGS ==========
  final bool isFeatured;        // Should this appear in the featured section?
  final bool allowsNegotiation; // Can buyers make offers? (almost always true)

  // ========== CONSTRUCTOR ==========
  // This is how we CREATE a new product
  // "required" means you MUST provide this value
  // If no value is given, it uses the default after the "="
  Product({
    required this.id,
    required this.name,
    required this.askingPrice,
    required this.imageUrl,
    required this.category,
    required this.storeId,
    required this.storeName,
    this.description = '',
    this.storeLocation = '',
    this.minPrice = 0,               // Default: seller sets this separately
    this.rating = 4.5,               // Default: 4.5 stars (good but not perfect)
    this.reviewCount = 0,            // Default: no reviews yet
    this.soldCount = 0,              // Default: nothing sold yet
    this.discount = 0,               // Default: no discount
    this.stockQuantity = 10,         // Default: 10 items in stock
    this.isAvailable = true,         // Default: available for sale
    this.isFeatured = false,         // Default: not featured
    this.allowsNegotiation = true,   // Default: negotiation allowed (bazaar style!)
    
  });

  // ========== CALCULATED PROPERTIES ==========
  // These are computed automatically based on other values
  
  /// Gets the current price after discount (if any)
  /// Example: $100 with 20% discount = $80
  double get currentPrice {
    if (discount > 0) {
      return askingPrice * (1 - discount / 100);
    }
    return askingPrice;
  }

  /// How much money you save with the discount
  /// Example: $100 - $80 = $20 saved
  double get savingsAmount {
    return askingPrice - currentPrice;
  }

  /// Is this product out of stock?
  bool get isOutOfStock {
    return !isAvailable || stockQuantity <= 0;
  }

  /// Get a display-friendly stock message
  /// Example: "Only 3 left!" or "In Stock" or "Out of Stock"
  String get stockMessage {
    if (isOutOfStock) return 'Out of Stock';
    if (stockQuantity <= 5) return 'Only $stockQuantity left!';
    return 'In Stock';
  }
}

// ============================================================================
// STORE MODEL - Represents a Physical Shop in Your Town
// ============================================================================
// Each store is like a "vendor" or "shopkeeper" in the bazaar

class Store {
  final String id;              // Unique store ID
  final String name;            // Store name (e.g., "Dilemma's Fashion")
  final String ownerName;       // Owner's name (e.g., "Akmal")
  final String description;     // What does this store sell?
  final String imageUrl;        // Store logo/photo
  final String location;        // Physical address (e.g., "Main Bazaar, Row 3")
  final String phoneNumber;     // Contact number for the store
  
  // Statistics that build trust
  final double rating;          // Average store rating (0.0 to 5.0)
  final int reviewCount;        // How many reviews
  final int totalSales;         // How many deals completed
  final bool isVerified;        // Is this a verified/trusted seller?
  
  // Business info
  final String openingHours;    // When is the store open?
  final List<String> categories; // What categories does this store sell?

  Store({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.location,
    this.description = '',
    this.imageUrl = '',
    this.phoneNumber = '',
    this.rating = 4.5,
    this.reviewCount = 0,
    this.totalSales = 0,
    this.isVerified = false,
    this.openingHours = '8:00 - 19:00',
    this.categories = const [],
  });
}

// ============================================================================
// OFFER MODEL - Represents a Negotiation Between Buyer and Seller
// ============================================================================
// This is the HEART of your bazaar concept - the negotiation system!

class Offer {
  final String id;              // Unique offer ID
  final String productId;       // Which product is being negotiated?
  final String productName;     // Product name (for display)
  final String productImage;    // Product image (for display)
  final String buyerId;         // Who is making the offer?
  final String buyerName;       // Buyer's name
  final String sellerId;        // Store owner receiving the offer
  final String sellerName;      // Store owner's name
  final double offeredPrice;    // What price did the buyer suggest?
  final double originalPrice;   // What was the asking price?
  final int quantity;           // How many units?
  final String message;         // Optional message from buyer
  
  // Status tracking
  final OfferStatus status;     // Current state of the offer
  final DateTime createdAt;     // When was the offer made?
  final DateTime? respondedAt;  // When did seller respond?
  
  // Seller's response (if any)
  final double? counterPrice;   // Did seller make a counter-offer?
  final String? sellerMessage;  // Message from seller

  Offer({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.offeredPrice,
    required this.originalPrice,
    this.quantity = 1,
    this.message = '',
    this.status = OfferStatus.pending,
    DateTime? createdAt,
    this.respondedAt,
    this.counterPrice,
    this.sellerMessage,
  }) : createdAt = createdAt ?? DateTime.now();

  // How much is the buyer trying to save?
  double get savingsAmount {
    return originalPrice - offeredPrice;
  }

  // What percentage discount is the buyer asking for?
  double get discountPercentage {
    return ((originalPrice - offeredPrice) / originalPrice) * 100;
  }

  // Total cost if offer accepted
  double get totalCost {
    return offeredPrice * quantity;
  }
}

// ============================================================================
// OFFER STATUS - The Different States of a Negotiation
// ============================================================================
// This is like a "traffic light" for negotiations

enum OfferStatus {
  pending,      // ⏳ Waiting for seller to respond
  accepted,     // ✅ Seller said YES! Deal made!
  rejected,     // ❌ Seller said NO, price too low
  countered,    // 🔄 Seller suggested a different price
  expired,      // ⌛ Offer timed out (seller didn't respond)
  cancelled,    // 🚫 Buyer cancelled their offer
}

// Helper to get user-friendly text for each status
extension OfferStatusExtension on OfferStatus {
  String get displayText {
    switch (this) {
      case OfferStatus.pending:
        return 'Javob kutilmoqda';
      case OfferStatus.accepted:
        return 'Taklif olindi🎉';
      case OfferStatus.rejected:
        return 'Taklif rad etildi';
      case OfferStatus.countered:
        return 'Yangi taklif keldi';
      case OfferStatus.expired:
        return 'Muddati o\'tgan';
      case OfferStatus.cancelled:
        return 'Bekor qilingan';
    }
  }
}

// ============================================================================
// DEMO DATA - Sample Products, Stores, and Offers for Testing
// ============================================================================
// This is fake data to test the app before connecting to a real database

// All the stores in your town
List<Store> demoStores = [
  Store(
    id: 'store_1',
    name: 'Dilemma\'s Fashion',
    ownerName: 'Akmal Rahimov',
    description: 'Sifatli kiyimlar va aksessuarlar',
    location: 'Kombinat Bozori, 3 chi yolak, B2-10',
    phoneNumber: '+998 90 123 4567',
    rating: 4.8,
    reviewCount: 156,
    totalSales: 423,
    isVerified: true,
    categories: ['Clothes', 'Accessories'],
    imageUrl: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
  ),
  Store(
    id: 'store_2',
    name: 'Dehqon Shukurillo',
    ownerName: 'Shukurillo Toshmatov',
    description: 'Yangi va sifatli meva-sabzavotlar',
    location: 'Dehqon Bozori, 13 -bo\'lim',
    phoneNumber: '+998 91 234 5678',
    rating: 4.9,
    reviewCount: 234,
    totalSales: 891,
    isVerified: true,
    categories: ['Mevalar', 'Sabzavotlar'],
    imageUrl: 'https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=400',
  ),
  Store(
    id: 'store_3',
    name: 'Real Savdo',
    ownerName: 'Dilshod Karimov',
    description: 'Maishiy texnika va elektronika',
    location: 'Sarmazor Ko\'chasi, Elektronika Markazi',
    phoneNumber: '+998 93 345 6789',
    rating: 4.6,
    reviewCount: 98,
    totalSales: 267,
    isVerified: true,
    categories: ['Maishiy texnika', 'Electronics'],
    imageUrl: 'https://images.unsplash.com/photo-1574269909862-7e1d70bb8078?w=400',
  ),
  Store(
    id: 'store_4',
    name: 'Telefon Bozori',
    ownerName: 'Sardor Alimov',
    description: 'Zamonaviy elektron qurilmalar',
    location: 'Margilon shahar, 25chi dokon, Raqam 45',
    phoneNumber: '+998 94 456 7890',
    rating: 4.7,
    reviewCount: 189,
    totalSales: 445,
    isVerified: true,
    categories: ['Electronics', 'Gadgets'],
    imageUrl: 'https://images.unsplash.com/photo-1601524909162-ae8725290836?w=400',
  ),
];

// All the products from all stores (Global Feed!)
List<Product> demoProducts = [
  // CLOTHES from Dilemma's Fashion
  Product(
    id: 'prod_1',
    name: 'Classic Oq Koylak',
    storeId: 'store_1',
    storeName: 'Dilemma\'s Fashion',
    storeLocation: 'Kombinat Bozori, 3 chi yolak, B2-10',
    askingPrice: 150000,
    minPrice: 120000,        // Seller will accept minimum 120k
    category: 'Kiyimlar',
    imageUrl: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500',
    description: 'Sifatli matodan tikilgan klassik oq koylak',
    rating: 4.8,
    reviewCount: 124,
    soldCount: 56,
    stockQuantity: 8,
    isFeatured: true,
    discount: 15,
  ),
  Product(
    id: 'prod_2',
    name: 'Teri Tufli',
    storeId: 'store_1',
    storeName: 'Dilemma\'s Fashion',
    storeLocation: 'Kombinat Bozori, 3 chi yolak, B2-10',
    askingPrice: 850000,
    minPrice: 700000,
    category: 'Kiyimlar',
    imageUrl: 'https://avatars.mds.yandex.net/i?id=e2861f5aca4ae75bd811e312c42010fbe49261a0-8276139-images-thumbs&n=13',
    description: 'Yuqori sifatli qo\'l mehnati bilan qilingan tufli',
    rating: 4.6,
    reviewCount: 89,
    soldCount: 34,
    stockQuantity: 5,
    discount: 20,
  ),
  Product(
    id: 'prod_3',
    name: 'Denim shimlari',
    storeId: 'store_1',
    storeName: 'Dilemma\'s Fashion',
    storeLocation: 'Kombinat Bozori, 3 chi yolak, B2-10',
    askingPrice: 280000,
    minPrice: 230000,
    category: 'Kiyimlar',
    imageUrl: 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=500',
    description: 'Qulay va sifatli shimlar',
    rating: 4.7,
    reviewCount: 156,
    soldCount: 78,
    isFeatured: true,
  ),

  // FRUITS from Dehqon Shukurillo
  Product(
    id: 'prod_4',
    name: 'Qizil Olma',
    storeId: 'store_2',
    storeName: 'Dehqon Shukurillo',
    storeLocation: 'Dehqon Bozori, 13 -bo\'lim',
    askingPrice: 25000,
    minPrice: 20000,
    category: 'Mevalar',
    imageUrl: 'https://img.freepik.com/free-photo/delicious-red-apples-studio_23-2150811099.jpg?semt=ais_hybrid&w=740&q=80',
    description: 'Yangi va sifatli qizil olma (per kg)',
    rating: 4.9,
    reviewCount: 445,
    soldCount: 234,
    stockQuantity: 50,
    isFeatured: true,
  ),
  Product(
    id: 'prod_5',
    name: 'Organik Banan',
    storeId: 'store_2',
    storeName: 'Dehqon Shukurillo',
    storeLocation: 'Dehqon Bozori, 13 -bo\'lim',
    askingPrice: 18000,
    minPrice: 15000,
    category: 'Mevalar',
    imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500',
    description: 'Shirin va organic bananlar, sogliq uchun foydali (per kg)',
    rating: 4.6,
    reviewCount: 312,
    soldCount: 189,
  ),

  // APPLIANCES from Real Savdo
  Product(
    id: 'prod_6',
    name: 'Artel Televizor 42',
    storeId: 'store_3',
    storeName: 'Real Savdo',
    storeLocation: 'Sarmazor Ko\'chasi, Elektronika Markazi',
    askingPrice: 4500000,
    minPrice: 4000000,
    category: 'Maishiy texnika',
    imageUrl: 'https://tezz.uz/uploads/images/product/521/215931.jpg',
    description: '55 Diumli Artel smart televizor',
    rating: 4.5,
    reviewCount: 167,
    soldCount: 45,
    stockQuantity: 3,
    isFeatured: true,
    discount: 12,
  ),
  Product(
    id: 'prod_7',
    name: 'Samsung Muzlatgich',
    storeId: 'store_3',
    storeName: 'Real Savdo',
    storeLocation: 'Sarmazor Ko\'chasi, Elektronika Markazi',
    askingPrice: 3800000,
    minPrice: 3400000,
    category: 'Maishiy texnika',
    imageUrl: 'https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?w=500',
    description: 'Energiya tejamkor ikki eshikli Muzlatgich',
    rating: 4.7,
    reviewCount: 134,
    soldCount: 67,
  ),

  // ELECTRONICS from Tech Plaza
  Product(
    id: 'prod_8',
    name: 'Galaxy S21',
    storeId: 'store_4',
    storeName: 'Telefon Bozori',
    storeLocation: 'Margilon shahar, 25chi dokon, Raqam 45',
    askingPrice: 5200000,
    minPrice: 4800000,
    category: 'Electronics',
    imageUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500',
    description: '128GB hotirali, triple (3 camera) camera systemali',
    rating: 4.8,
    reviewCount: 567,
    soldCount: 123,
    stockQuantity: 7,
    isFeatured: true,
    discount: 10,
  ),
  Product(
    id: 'prod_9',
    name: 'Quloqchin',
    storeId: 'store_4',
    storeName: 'Telefon Bozori',
    storeLocation: 'Margilon shahar, 25chi dokon, Raqam 45',
    askingPrice: 450000,
    minPrice: 350000,
    category: 'Electronics',
    imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500',
    description: 'Shovqun otkazmas Bluetooth Quloqchin',
    rating: 4.7,
    reviewCount: 892,
    soldCount: 234,
    discount: 20,
  ),
];

// Demo offers (active negotiations)
List<Offer> demoOffers = [
  Offer(
    id: 'offer_1',
    productId: 'prod_1',
    productName: 'Classic Oq Koylak',
    productImage: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500',
    buyerId: 'user_1',
    buyerName: 'You',
    sellerId: 'store_1',
    sellerName: 'Dilemma\'s Fashion',
    originalPrice: 150000,
    offeredPrice: 120000,
    quantity: 1,
    message: 'Can you do 120k? I\'m a regular customer',
    status: OfferStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Offer(
    id: 'offer_2',
    productId: 'prod_6',
    productName: 'Artel Televizor',
    productImage: 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?w=500',
    buyerId: 'user_1',
    buyerName: 'You',
    sellerId: 'store_3',
    sellerName: 'Real Savdo',
    originalPrice: 4500000,
    offeredPrice: 4000000,
    quantity: 1,
    status: OfferStatus.countered,
    counterPrice: 4200000,
    sellerMessage: 'I can do 4.2M - best price!',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    respondedAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
];

// ========== HELPER FUNCTIONS ==========
// These make it easy to filter and find data

/// Get all products from a specific store
List<Product> getProductsByStore(String storeId) {
  return demoProducts.where((p) => p.storeId == storeId).toList();
}

/// Get all products in a category
List<Product> getProductsByCategory(String category) {
  return demoProducts.where((p) => p.category == category).toList();
}

/// Get only featured products (for home screen showcase)
List<Product> getFeaturedProducts() {
  return demoProducts.where((p) => p.isFeatured).toList();
}

/// Get all unique categories
List<String> getAllCategories() {
  return demoProducts.map((p) => p.category).toSet().toList();
}

/// Find a store by ID
Store? getStoreById(String storeId) {
  try {
    return demoStores.firstWhere((s) => s.id == storeId);
  } catch (e) {
    return null;
  }
}

/// Find a product by ID
Product? getProductById(String productId) {
  try {
    return demoProducts.firstWhere((p) => p.id == productId);
  } catch (e) {
    return null;
  }
}