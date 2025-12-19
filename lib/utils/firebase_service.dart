import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;
      debugPrint("Firebase initialized successfully.");
    } catch (e) {
      debugPrint("Warning: Firebase initialization failed. This is expected if google-services.json/GoogleService-Info.plist are missing.");
      debugPrint("Error: $e");
      // App continues to function without Firebase
    }
  }
}
