import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterStoreScreen extends StatefulWidget {
  const RegisterStoreScreen({super.key});

  @override
  State<RegisterStoreScreen> createState() => _RegisterStoreScreenState();
}

class _RegisterStoreScreenState extends State<RegisterStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  // Controllers
  final _storeNameController = TextEditingController();
  final _storeIdController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<TextEditingController> _phoneControllers = [TextEditingController()];

  // Use ValueNotifier to avoid rebuilding the entire widget tree on loading state change
  final _isLoading = ValueNotifier<bool>(false);
  File? _storeImage;
  final ImagePicker _picker = ImagePicker();

  final cloudinary = CloudinaryPublic('djqjonzkq', 'product_images', cache: false);

  static const primaryColor = Color(0xFFFF6B35);

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeIdController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _isLoading.dispose();
    for (var c in _phoneControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<User?> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (mounted) _showErrorSnackBar("Google bilan ulanishda xatolik: $e");
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null) {
        setState(() => _storeImage = File(pickedFile.path));
      }
    } catch (e) {
      _showErrorSnackBar("Rasm tanlashda xatolik: ${e.toString()}");
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar("Barcha maydonlarni to'ldiring");
      return;
    }
    if (_storeImage == null) {
      _showErrorSnackBar("Do'kon rasmini tanlang");
      return;
    }
    if (_phoneControllers.isEmpty || _phoneControllers.first.text.trim().isEmpty) {
      _showErrorSnackBar("Kamida bitta telefon raqam kiriting");
      return;
    }

    _isLoading.value = true;

    try {
      User? user = await _signInWithGoogle();
      if (user == null) {
        _isLoading.value = false;
        return;
      }

      String storeId = _storeIdController.text.trim().toLowerCase();

      // Check if email already owns a store
      final existingStores = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerEmail', isEqualTo: user.email)
          .limit(1)
          .get();

      if (existingStores.docs.isNotEmpty) {
        final existingStoreId = existingStores.docs.first.id;
        debugPrint("🔄 Store found for this email, reconnecting to new UID...");

        final reconnectBatch = FirebaseFirestore.instance.batch();
        reconnectBatch.update(
          FirebaseFirestore.instance.collection('stores').doc(existingStoreId),
          {'ownerUid': user.uid, 'updatedAt': FieldValue.serverTimestamp()},
        );
        reconnectBatch.set(
          FirebaseFirestore.instance.collection('users').doc(user.uid),
          {
            'fullName': user.displayName ?? 'User',
            'email': user.email,
            'storeId': existingStoreId,
            'isStoreOwner': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        reconnectBatch.update(
          FirebaseFirestore.instance.collection('store_names').doc(existingStoreId),
          {'ownerUid': user.uid},
        );
        await reconnectBatch.commit();

        if (mounted) {
          _showSuccessSnackBar("Do'kon qayta ulandi!");
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pop(context, true);
        }
        return;
      }

      // Check Store ID uniqueness
      final idDoc = await FirebaseFirestore.instance
          .collection('store_names')
          .doc(storeId)
          .get();
      if (idDoc.exists) throw Exception("Bu ID band. Iltimos boshqasini tanlang.");

      // Upload image to Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _storeImage!.path,
          folder: 'store_images',
          publicId: storeId,
        ),
      );

      // Batch save to Firestore
      final batch = FirebaseFirestore.instance.batch();
      final phones = _phoneControllers
          .map((c) => c.text.trim())
          .where((phone) => phone.isNotEmpty)
          .toList();

      batch.set(
        FirebaseFirestore.instance.collection('stores').doc(storeId),
        {
          'name': _storeNameController.text.trim(),
          'storeId': storeId,
          'location': _locationController.text.trim(),
          'description': _descriptionController.text.trim(),
          'phones': phones,
          'ownerUid': user.uid,
          'ownerEmail': user.email,
          'ownerName': user.displayName,
          'imageUrl': response.secureUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
        {
          'fullName': user.displayName ?? 'User',
          'email': user.email,
          'storeId': storeId,
          'isStoreOwner': true,
          'lastLogin': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance.collection('store_names').doc(storeId),
        {'ownerUid': user.uid, 'createdAt': FieldValue.serverTimestamp()},
      );
      await batch.commit();

      if (mounted) {
        _showSuccessSnackBar("Do'kon muvaffaqiyatli ochildi!");
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, storeId);
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar("Autentifikatsiya xatosi: ${e.message}");
    } on FirebaseException catch (e) {
      _showErrorSnackBar("Firebase xatosi: ${e.message}");
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  void _addPhoneField() {
    if (_phoneControllers.length < 5) {
      setState(() => _phoneControllers.add(TextEditingController()));
    } else {
      _showErrorSnackBar("Maksimal 5 ta telefon raqam qo'shish mumkin");
    }
  }

  void _removePhoneField(int index) {
    if (_phoneControllers.length > 1) {
      setState(() {
        _phoneControllers[index].dispose();
        _phoneControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Yangi Do'kon Ochish",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      // Stack lets the form stay mounted while the overlay appears on top —
      // no full rebuild, no layout jank when loading starts/stops.
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Do'koningiz haqida ma'lumotlarni kiriting",
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Image picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 130,
                            width: 130,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 2,
                              ),
                              // Fade-in effect when image is selected
                              image: _storeImage != null
                                  ? DecorationImage(
                                      image: FileImage(_storeImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _storeImage == null
                                ? const Icon(
                                    Icons.storefront_outlined,
                                    size: 50,
                                    color: primaryColor,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  _inputLabel("Do'kon nomi"),
                  _customField(
                    _storeNameController,
                    "Masalan: Erkaklar kiyimi",
                    Icons.store_outlined,
                  ),

                  _inputLabel("Store Username (@)"),
                  _customField(
                    _storeIdController,
                    "fashion_id",
                    Icons.alternate_email,
                    validator: (v) {
                      if (v == null || v.isEmpty) return "To'ldirish majburiy";
                      if (v.contains(' ')) return "Bo'sh joy bo'lmasligi kerak";
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) {
                        return "Faqat kichik harflar, raqamlar va _ belgisi";
                      }
                      if (v.length < 3) return "Kamida 3 ta belgi kiriting";
                      return null;
                    },
                  ),

                  _inputLabel("Bozordagi manzil"),
                  _customField(
                    _locationController,
                    "Masalan: 4-blok, 12-do'kon",
                    Icons.map_outlined,
                  ),

                  _inputLabel("Tavsif (ixtiyoriy)"),
                  _customField(
                    _descriptionController,
                    "Do'koningiz haqida qisqacha ma'lumot",
                    Icons.description_outlined,
                    maxLines: 3,
                    required: false,
                  ),

                  _inputLabel("Telefon raqam"),
                  ...List.generate(_phoneControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _customField(
                              _phoneControllers[index],
                              "+998 9x xxx xx xx",
                              Icons.phone_android,
                              validator: (v) {
                                if (index == 0 && (v == null || v.isEmpty)) {
                                  return "Kamida bitta raqam kiriting";
                                }
                                if (v != null && v.isNotEmpty && v.length < 9) {
                                  return "To'liq raqam kiriting";
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_phoneControllers.length > 1)
                            IconButton(
                              onPressed: () => _removePhoneField(index),
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.red,
                            ),
                        ],
                      ),
                    );
                  }),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _addPhoneField,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Raqam qo'shish"),
                      style: TextButton.styleFrom(foregroundColor: primaryColor),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Button reacts to loading state without rebuilding the whole tree
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoading,
                    builder: (context, loading, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: loading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: primaryColor.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: loading
                                ? const SizedBox(
                                    key: ValueKey('loader'),
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Row(
                                    key: ValueKey('label'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login),
                                      SizedBox(width: 12),
                                      Text(
                                        "GOOGLE BILAN DO'KON OCHISH",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Semi-transparent overlay blocks interaction during async work
          // without destroying and rebuilding the form widget tree.
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, loading, _) {
              return loading
                  ? Container(color: Colors.black12)
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      );

  Widget _customField(
    TextEditingController c,
    String hint,
    IconData icon, {
    String? Function(String?)? validator,
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      // Keeps the keyboard from dismissing and re-appearing on load state changes
      keyboardAppearance: Brightness.light,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      validator: validator ??
          (required ? (v) => v!.isEmpty ? "To'ldirish majburiy" : null : null),
    );
  }

  void _showErrorSnackBar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}