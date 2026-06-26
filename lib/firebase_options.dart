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
    authDomain: 'chessdiary.app',
    storageBucket: 'chessdiary-7f1e3.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCtVTOKiqwzKasA6C_u7PHSWDYvqUfxIvo',
    appId: '1:641104743114:android:ffd06a3c31cb9cadec4233',
    messagingSenderId: '641104743114',
    projectId: 'chessdiary-7f1e3',
    storageBucket: 'chessdiary-7f1e3.firebasestorage.app',
  );
}
