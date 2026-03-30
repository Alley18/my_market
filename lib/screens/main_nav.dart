import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'stores_screen.dart';
import 'offers_screen.dart';
import 'profile_screen.dart';
import 'add_product_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  // Each nav item gets its own animation controller for the tap bounce
  late final List<AnimationController> _itemControllers;
  late final List<Animation<double>> _itemScales;

  final List<Widget> _screens = const [
    HomeScreen(),
    StoresScreen(),
    OffersScreen(),
    ProfileScreen(),
  ];

  // Nav items: index, activeIcon, inactiveIcon, label
  // Index 2 is reserved for the center FAB (no screen)
  static const _navItems = [
    (0, Icons.home_rounded, Icons.home_outlined, 'Bosh sahifa'),
    (1, Icons.store_rounded, Icons.store_outlined, 'Do\'konlar'),
    (2, Icons.local_offer_rounded, Icons.local_offer_outlined, 'Takliflar'),
    (3, Icons.person_rounded, Icons.person_outline, 'Profil'),
  ];

  @override
  void initState() {
    super.initState();
    _itemControllers = List.generate(
      4,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 200),
      ),
    );
    _itemScales = _itemControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onNavTap(int index) {
    HapticFeedback.lightImpact();
    _itemControllers[index].forward().then((_) => _itemControllers[index].reverse());
    setState(() => _currentIndex = index);
  }

  void _verifyStoreOwner(BuildContext context) {
    HapticFeedback.mediumImpact();
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: _primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Do'kon egasi",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Mahsulot qo'shish uchun maxfiy kalitni kiriting",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: keyController,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _dark,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: "• • • • • • • •",
                  hintStyle: TextStyle(
                    color: Colors.grey[300],
                    letterSpacing: 4,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.key_rounded, color: _primary, size: 20),
                  ),
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
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => _submitKey(context, keyController),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[200]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: Colors.grey[600],
                      ),
                      child: const Text(
                        "Bekor",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _submitKey(context, keyController),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Kirish",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitKey(BuildContext context, TextEditingController controller) {
    if (controller.text == 'bozorim2027') {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddProductScreen()),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Kalit noto'g'ri"),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        itemScales: _itemScales,
        onTap: _onNavTap,
        onAddTap: () => _verifyStoreOwner(context),
        navItems: _navItems,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Nav extracted as its own widget for clean rebuilds
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<Animation<double>> itemScales;
  final void Function(int) onTap;
  final VoidCallback onAddTap;
  final List<(int, IconData, IconData, String)> navItems;

  static const _primary = Color(0xFFFF6B35);
  static const _dark = Color(0xFF2E294E);

  const _BottomNav({
    required this.currentIndex,
    required this.itemScales,
    required this.onTap,
    required this.onAddTap,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Left two nav items
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: navItems
                      .take(2)
                      .map((item) => _buildNavItem(item))
                      .toList(),
                ),
              ),

              // Center FAB — fixed width so it doesn't compress sides
              SizedBox(
                width: 72,
                child: Center(child: _buildFab()),
              ),

              // Right two nav items
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: navItems
                      .skip(2)
                      .map((item) => _buildNavItem(item))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem((int, IconData, IconData, String) item) {
    final (index, activeIcon, inactiveIcon, label) = item;
    final isSelected = currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: ScaleTransition(
        scale: itemScales[index > 1 ? index - 1 : index],
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: isSelected ? 36 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? _primary : const Color(0xFFBDBDBD),
                size: 24,
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? _primary : const Color(0xFFBDBDBD),
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: isSelected ? 0.2 : 0,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return GestureDetector(
      onTap: onAddTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF9A6C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}