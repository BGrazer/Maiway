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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBACnHHYIoOdZcXFJSjJL-4CPR3ExXyw3Y',
    appId: '1:712466241107:web:8a1c016024cdcaa10dd8a6',
    messagingSenderId: '712466241107',
    projectId: 'maiwaykate2',
    authDomain: 'maiwaykate2.firebaseapp.com',
    storageBucket: 'maiwaykate2.firebasestorage.app',
    measurementId: 'G-4MPM8H7H8S',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAv4dzmaHPHErGZJt31YokR8HvxNLNoYxk',
    appId: '1:712466241107:android:38e086b08182b8ea0dd8a6',
    messagingSenderId: '712466241107',
    projectId: 'maiwaykate2',
    storageBucket: 'maiwaykate2.firebasestorage.app',
  );
}
