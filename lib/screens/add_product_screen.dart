import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isCheckingStore = true;
  String? _storeId;
  String _userStoreName = "";
  File? _image;
  bool _isUploading = false;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Elektronika';

  // Cloudinary setup
  final cloudinary = CloudinaryPublic(
    'djqjonzkq',
    'product_images',
    cache: false,
  );

  @override
  void initState() {
    super.initState();
    _checkUserStore();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _checkUserStore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()?['isStoreOwner'] == true) {
        setState(() {
          _storeId = userDoc.data()?['storeId'];
          _userStoreName = userDoc.data()?['storeId'] ?? "Mening Do'konim";
          _isCheckingStore = false;
        });
        return;
      }
    }
    setState(() => _isCheckingStore = false);
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery, 
      imageQuality: 70,
    );
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  // 🔧 FIXED: Better price parsing
  double _parsePrice(String text) {
    try {
      // Remove all spaces, commas, and common currency symbols
      String cleaned = text
          .trim()
          .replaceAll(' ', '')
          .replaceAll(',', '')
          .replaceAll('so\'m', '')
          .replaceAll('sum', '')
          .replaceAll('сум', '')
          .replaceAll('\'', '');
      
      // Parse the cleaned string
      double? price = double.tryParse(cleaned);
      
      if (price == null || price <= 0) {
        throw Exception('Invalid price');
      }
      
      debugPrint("✅ Price parsed: $text → $price");
      return price;
    } catch (e) {
      debugPrint("❌ Price parse error: $text → $e");
      throw Exception('Narxni to\'g\'ri kiriting (faqat raqamlar)');
    }
  }

  void _uploadProduct() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Barcha maydonlarni to'ldiring!")),
      );
      return;
    }

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rasm tanlang!")),
      );
      return;
    }

    // Validate price before uploading
    double price;
    try {
      price = _parsePrice(_priceController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String productId = const Uuid().v4();
      
      // Upload to Cloudinary
      debugPrint("📤 Uploading image to Cloudinary...");
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _image!.path,
          folder: 'product_images',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      
      String imageUrl = response.secureUrl;
      debugPrint("✅ Image uploaded: $imageUrl");

      // Save to Firestore
      await FirebaseFirestore.instance.collection('products').doc(productId).set({
        'id': productId,
        'name': _nameController.text.trim(),
        'price': price, // ← Using validated price
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'imageUrl': imageUrl,
        'storeId': _storeId,
        'ownerUid': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Product saved with price: $price");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Muvaffaqiyatli joylandi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint("❌ UPLOAD ERROR: $e");
      debugPrint("Stack trace: $stackTrace");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStore) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_storeId == null) return _buildRegistrationPrompt();

    return Scaffold(
      appBar: AppBar(title: const Text('Yangi e\'lon'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildIdentityHeader(),
              const SizedBox(height: 20),
              _buildImagePickerUI(),
              const SizedBox(height: 20),
              _buildTextFields(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Siz @$_userStoreName nomi bilan joylayapsiz",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerUI() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: _image != null 
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(_image!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey[400]),
                  Text('Rasm yuklash', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
      ),
    );
  }

  Widget _buildTextFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Mahsulot nomi',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.shopping_bag_outlined),
          ),
          validator: (v) => v!.isEmpty ? "Nomini kiriting" : null,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Narxi (so\'m)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            hintText: 'Masalan: 50000',
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return "Narxini kiriting";
            try {
              _parsePrice(v);
              return null;
            } catch (e) {
              return "Faqat raqamlar kiriting";
            }
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _descController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Tavsif',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description_outlined),
            hintText: 'Mahsulot haqida ma\'lumot...',
          ),
          validator: (v) => v!.isEmpty ? "Tavsif kiriting" : null,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _uploadProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'E\'lonni joylashtirish',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildRegistrationPrompt() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 80, color: Color(0xFFFF6B35)),
            const Text(
              "Do'koningiz yo'qmi?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Mahsulot sotish uchun avval do'koningizni ro'yxatdan o'tkazishingiz kerak.",
                textAlign: TextAlign.center,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Orqaga"),
            ),
          ],
        ),
      ),
    );
  }
}