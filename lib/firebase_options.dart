import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Placeholder Firebase configuration.
///
/// Replace the dummy values by running `flutterfire configure` or by
/// providing the actual Firebase project configuration manually.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAV523nw3cb-yheZpIibfMmRccQEDdnP28',
    appId: '1:408329565311:web:708a01ca2a7ef0892b3b4a',
    messagingSenderId: '408329565311',
    projectId: 'workit-1daa1',
    authDomain: 'workit-1daa1.firebaseapp.com',
    storageBucket: 'workit-1daa1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsRvMUQRAGfHjNU3bQjgaPQkX3pvgm6s8',
    appId: '1:408329565311:android:31252aa4e2c1a53b2b3b4a',
    messagingSenderId: '408329565311',
    projectId: 'workit-1daa1',
    storageBucket: 'workit-1daa1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBF05P2nxeZwnadCgem3gzpIRAGO8VYO1w',
    appId: '1:408329565311:ios:e102873ef2b07da72b3b4a',
    messagingSenderId: '408329565311',
    projectId: 'workit-1daa1',
    storageBucket: 'workit-1daa1.firebasestorage.app',
    iosBundleId: 'com.workit.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBF05P2nxeZwnadCgem3gzpIRAGO8VYO1w',
    appId: '1:408329565311:ios:c45711c080ae59412b3b4a',
    messagingSenderId: '408329565311',
    projectId: 'workit-1daa1',
    storageBucket: 'workit-1daa1.firebasestorage.app',
    iosBundleId: 'com.example.workit',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAV523nw3cb-yheZpIibfMmRccQEDdnP28',
    appId: '1:408329565311:web:02dc2e4b50fa48482b3b4a',
    messagingSenderId: '408329565311',
    projectId: 'workit-1daa1',
    authDomain: 'workit-1daa1.firebaseapp.com',
    storageBucket: 'workit-1daa1.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'TODO-linux-apiKey',
    appId: 'TODO-linux-appId',
    messagingSenderId: 'TODO-linux-senderId',
    projectId: 'TODO-projectId',
    storageBucket: 'TODO-storageBucket',
  );
}