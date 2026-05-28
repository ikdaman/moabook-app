// File generated manually from google-services.json / GoogleService-Info.plist.
// Replaces `flutterfire configure` output. Regenerate if Firebase config changes.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBQBTXkjcJ3-xBYss4uoxY4JLtwjLKVSDs',
    appId: '1:637762402296:android:b536ab1cd65d48aa43480d',
    messagingSenderId: '637762402296',
    projectId: 'moabook-b1d0a',
    storageBucket: 'moabook-b1d0a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDPLzfuKvUeb7vtDXb1md58PgAzw1tha98',
    appId: '1:637762402296:ios:beaff3f0a7a6f7aa43480d',
    messagingSenderId: '637762402296',
    projectId: 'moabook-b1d0a',
    storageBucket: 'moabook-b1d0a.firebasestorage.app',
    iosClientId:
        '957982912983-ft1n53ruu3ekbq5hepedt7b9ulga8mgb.apps.googleusercontent.com',
    iosBundleId: 'com.Ikdaman',
  );
}
