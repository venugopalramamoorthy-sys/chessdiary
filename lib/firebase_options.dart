import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Fill in values before running on web or Android.
// Web: Firebase Console → Project Settings → Your apps → Web app → SDK config
// Android: values are inside google-services.json once you download it.

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions: unsupported platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB_mxJS3rdPPKu9ujQf8kc1eEfw_4F2Nvo',
    appId: '1:641104743114:web:d8ade93353bf2aceec4233',
    messagingSenderId: '641104743114',
    projectId: 'chessdiary-7f1e3',
    authDomain: 'chessdiary-7f1e3.firebaseapp.com',
    storageBucket: 'chessdiary-7f1e3.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}
