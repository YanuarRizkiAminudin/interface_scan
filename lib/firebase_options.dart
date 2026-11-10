// Generated from google-services.json
// Project: interfacescan (InterfaceScan)

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
    apiKey: 'AIzaSyBscNj2IrvYS18qRMogalhfFQcQQouXuew',
    appId: '1:892218538962:android:5ba3275eb0d57acad8660b',
    messagingSenderId: '892218538962',
    projectId: 'interfacescan',
    storageBucket: 'interfacescan.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBscNj2IrvYS18qRMogalhfFQcQQouXuew',
    appId: '1:892218538962:android:5ba3275eb0d57acad8660b',
    messagingSenderId: '892218538962',
    projectId: 'interfacescan',
    storageBucket: 'interfacescan.firebasestorage.app',
  );
}
