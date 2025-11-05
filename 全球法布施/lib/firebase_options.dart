import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError('DefaultFirebaseOptions未配置此平台');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCsvE8XER-hGKOftkTO6B5qGHTfI5vG-ik',
    appId: '1:700291601159:web:2749eebfa8b73ef9622ba2',
    messagingSenderId: '700291601159',
    projectId: 'quanqiubushi',
    authDomain: 'quanqiubushi.firebaseapp.com',
    storageBucket: 'quanqiubushi.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCsvE8XER-hGKOftkTO6B5qGHTfI5vG-ik',
    appId: '1:700291601159:android:6266ae078c4aa918622ba2',
    messagingSenderId: '700291601159',
    projectId: 'quanqiubushi',
    storageBucket: 'quanqiubushi.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCsvE8XER-hGKOftkTO6B5qGHTfI5vG-ik',
    appId: '1:700291601159:ios:ae57131c72d41361622ba2',
    messagingSenderId: '700291601159',
    projectId: 'quanqiubushi',
    storageBucket: 'quanqiubushi.firebasestorage.app',
    iosBundleId: 'com.example.globalDharmaSharing',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCsvE8XER-hGKOftkTO6B5qGHTfI5vG-ik',
    appId: '1:700291601159:ios:ae57131c72d41361622ba2',
    messagingSenderId: '700291601159',
    projectId: 'quanqiubushi',
    storageBucket: 'quanqiubushi.firebasestorage.app',
    iosBundleId: 'com.example.globalDharmaSharing',
  );
}
