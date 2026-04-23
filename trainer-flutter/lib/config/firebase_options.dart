// ─────────────────────────────────────────────────────────────────────────────
// Firebase-Konfiguration
// Werte aus der Firebase Console eintragen:
//   console.firebase.google.com → Projekt → Projekteinstellungen → Web-App
// ─────────────────────────────────────────────────────────────────────────────
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Nur Web wird unterstützt.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyCKgPYMfLsrJdS3jzHTeBCLbaMe4sFRG0s',
    appId:             '1:331324831259:web:1fcdda2be34329ec9b2abe',
    messagingSenderId: '331324831259',
    projectId:         'sihltraining-3ce40',
    databaseURL:       'https://sihltraining-3ce40-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket:     'sihltraining-3ce40.firebasestorage.app',
    authDomain:        'sihltraining-3ce40.firebaseapp.com',
    measurementId:     'G-TB93TDX8YE',
  );
}
