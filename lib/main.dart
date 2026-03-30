import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- ADD THIS IMPORT
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 
import 'screens/main_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Sign in the user BEFORE the app starts
  // This ensures your "One User, One Store" security check works immediately
  try {
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("✅ Firebase Auth: Signed in anonymously");
  } catch (e) {
    debugPrint("❌ Firebase Auth Error: $e");
  }

  // 3. Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const BazaarApp());
}

class BazaarApp extends StatelessWidget {
  const BazaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bozorim',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          primary: const Color(0xFFFF6B35),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}