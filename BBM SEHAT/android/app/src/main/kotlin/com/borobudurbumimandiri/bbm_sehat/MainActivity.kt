package com.borobudurbumimandiri.bbm_sehat

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by the `health`
// package on Android 14+: it needs registerForActivityResult, which is only
// available via ComponentActivity's Fragment-based lifecycle.
class MainActivity : FlutterFragmentActivity()
