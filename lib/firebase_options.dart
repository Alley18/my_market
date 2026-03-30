// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      case TargetPlatform.macOS: return macos; // Fixed: points to macos below
      case TargetPlatform.windows: return windows; // Fixed: points to windows below
      default: throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAsdQCOMlEIOty6W673h7jjOltZBjRFb1g',
    appId: '1:779369773558:web:0ee40c11c6d4fc53af2fd7',
    messagingSenderId: '779369773558',
    projectId: 'bozorim-2027',
    authDomain: 'bozorim-2027.firebaseapp.com',
    storageBucket: 'bozorim-2027.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAfILyak01rnXBZo_9tSvgi9ysag0yR5xo',
    appId: '1:779369773558:android:d223e326fcd842abaf2fd7',
    messagingSenderId: '779369773558',
    projectId: 'bozorim-2027',
    storageBucket: 'bozorim-2027.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAb0cyzyqXoaSw1M3FiafAcvcOvkuChI0Y',
    appId: '1:779369773558:ios:2d4453fe0e1022a8af2fd7',
    messagingSenderId: '779369773558',
    projectId: 'bozorim-2027',
    storageBucket: 'bozorim-2027.firebasestorage.app',
    iosBundleId: 'com.example.margilonBozor',
  );

  static const FirebaseOptions macos = ios; // Simplified for now
  static const FirebaseOptions windows = web; // Simplified for now
}