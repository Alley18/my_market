import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'add_product_screen.dart';

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFFFF6B35);
  static const background = Color(0xFFF8F9FA);
  static const cardBorder = Color(0xFFFF6B35);
}

// ─────────────────────────────────────────────
// AUTH SERVICE — separates business logic from UI
// ─────────────────────────────────────────────
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AuthResult> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // Force account picker

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return AuthResult.cancelled();

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      final storeQuery = await _firestore
          .collection('stores')
          .where('ownerEmail', isEqualTo: user.email)
          .limit(1)
          .get();

      final batch = _firestore.batch();
      bool storeRecovered = false;

      if (storeQuery.docs.isNotEmpty) {
        final storeDoc = storeQuery.docs.first;
        storeRecovered = true;

        batch.update(storeDoc.reference, {
          'ownerUid': user.uid,
          'lastLogin': FieldValue.serverTimestamp(),
        });

        batch.set(
          _firestore.collection('users').doc(user.uid),
          {
            'email': user.email,
            'fullName': user.displayName,
            'storeId': storeDoc.id,
            'isStoreOwner': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        batch.set(
          _firestore.collection('users').doc(user.uid),
          {
            'email': user.email,
            'fullName': user.displayName,
            'isStoreOwner': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      return AuthResult.success(storeRecovered: storeRecovered);
    } catch (e, stack) {
      debugPrint('AuthService.signInWithGoogle error: $e\n$stack');
      return AuthResult.error(e.toString());
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}

// ─────────────────────────────────────────────
// AUTH RESULT — typed return instead of try/catch in UI
// ─────────────────────────────────────────────
class AuthResult {
  final bool success;
  final bool cancelled;
  final bool storeRecovered;
  final String? error;

  const AuthResult._({
    this.success = false,
    this.cancelled = false,
    this.storeRecovered = false,
    this.error,
  });

  factory AuthResult.success({bool storeRecovered = false}) =>
      AuthResult._(success: true, storeRecovered: storeRecovered);
  factory AuthResult.cancelled() => const AuthResult._(cancelled: true);
  factory AuthResult.error(String message) =>
      AuthResult._(error: message);
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.cancelled) return;

    if (result.error != null) {
      _showSnackBar("Xatolik yuz berdi. Qayta urining.", isError: true);
      return;
    }

    if (result.storeRecovered) {
      _showSnackBar("Do'koningiz muvaffaqiyatli tiklandi!", isError: false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await _showConfirmDialog(
      title: "Chiqish",
      message: "Hisobingizdan chiqishni xohlaysizmi?",
    );
    if (!confirmed || !mounted) return;

    await _authService.signOut();
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Bekor qilish"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text("Ha", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return _LoginView(
            isLoading: _isLoading,
            onSignIn: _handleGoogleAuth,
          );
        }

        return _ProfileView(
          user: user,
          onSignOut: _handleSignOut,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// LOGIN VIEW
// ─────────────────────────────────────────────
class _LoginView extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSignIn;

  const _LoginView({required this.isLoading, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, size: 52, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                "Xush kelibsiz!",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Do'koningizni boshqarish yoki xarid qilish\nuchun tizimga kiring",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              "Google orqali kirish",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROFILE VIEW (authenticated)
// ─────────────────────────────────────────────
class _ProfileView extends StatelessWidget {
  final User user;
  final VoidCallback onSignOut;

  const _ProfileView({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final isOwner = data?['isStoreOwner'] as bool? ?? false;
          final storeId = data?['storeId'] as String? ?? '';

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              // Triggers StreamBuilder rebuild automatically
            },
            child: CustomScrollView(
              slivers: [
                _ProfileHeader(user: user, onSignOut: onSignOut),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (isOwner) ...[
                        _StoreBadge(storeId: storeId),
                        const SizedBox(height: 24),
                        _SectionTitle("Do'kon boshqaruvi"),
                        const SizedBox(height: 8),
                        _MenuCard(items: [
                          _MenuItem(
                            icon: Icons.add_business_rounded,
                            label: "Mahsulot qo'shish",
                            color: Colors.green,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddProductScreen()),
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.inventory_2_rounded,
                            label: "Mahsulotlarim",
                            color: Colors.blue,
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.bar_chart_rounded,
                            label: "Statistika",
                            color: Colors.indigo,
                            onTap: () {},
                          ),
                        ]),
                      ] else ...[
                        _MenuCard(items: [
                          _MenuItem(
                            icon: Icons.storefront_rounded,
                            label: "Do'kon ochish",
                            color: AppColors.primary,
                            onTap: () {},
                          ),
                        ]),
                      ],
                      const SizedBox(height: 24),
                      _SectionTitle("Mening hisobim"),
                      const SizedBox(height: 8),
                      _MenuCard(items: [
                        _MenuItem(
                            icon: Icons.favorite_rounded,
                            label: "Sevimlilar",
                            color: Colors.red,
                            onTap: () {}),
                        _MenuItem(
                            icon: Icons.receipt_long_rounded,
                            label: "Buyurtmalar",
                            color: Colors.purple,
                            onTap: () {}),
                        _MenuItem(
                            icon: Icons.settings_rounded,
                            label: "Sozlamalar",
                            color: Colors.grey,
                            onTap: () {}),
                      ]),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final User user;
  final VoidCallback onSignOut;

  const _ProfileHeader({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: AppColors.primary,
      actions: [
        IconButton(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          tooltip: "Chiqish",
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8C5A), AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person, size: 42, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName ?? "Foydalanuvchi",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? "",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreBadge extends StatelessWidget {
  final String storeId;
  const _StoreBadge({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: Colors.blue, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Faol do'kon",
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                "@$storeId",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                title: Text(item.label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.grey, size: 20),
                onTap: item.onTap,
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}