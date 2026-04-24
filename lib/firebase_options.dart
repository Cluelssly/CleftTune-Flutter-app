import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default FirebaseOptions for your app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'This platform is not configured for Firebase yet.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBygrUN1Dq1iVh1hcO0RcdC6Lt2CtPxDs',
    appId: '1:756813986418:web:68a043e4f9a286037620eb',
    messagingSenderId: '756813986418',
    projectId: 'appcleft2026-55337',
    authDomain: 'appcleft2026-55337.firebaseapp.com',
    storageBucket: 'appcleft2026-55337.firebasestorage.app',
    measurementId: 'G-08JMBP64EL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD9lgM6F2qU5oMBytqy_H-I0tXn1nIE8SY',
    appId: '1:756813986418:android:edc4e7239da11cd07620eb',
    messagingSenderId: '756813986418',
    projectId: 'appcleft2026-55337',
    storageBucket: 'appcleft2026-55337.firebasestorage.app',
  );
}
