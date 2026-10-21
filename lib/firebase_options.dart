// File generated from google-services.json
// Project: framework-next-c9691

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured.');
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDzNtpAm3kMDUJbKtGKkJdlaFl8HARwBdM',
    appId: '1:794393072413:android:742542651dc1bf43bc07f4',
    messagingSenderId: '794393072413',
    projectId: 'framework-next-c9691',
    storageBucket: 'framework-next-c9691.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDzNtpAm3kMDUJbKtGKkJdlaFl8HARwBdM',
    appId: '1:794393072413:android:742542651dc1bf43bc07f4',
    messagingSenderId: '794393072413',
    projectId: 'framework-next-c9691',
    storageBucket: 'framework-next-c9691.firebasestorage.app',
  );
}
