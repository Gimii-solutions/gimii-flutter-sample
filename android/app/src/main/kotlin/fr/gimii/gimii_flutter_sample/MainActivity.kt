package fr.gimii.gimii_flutter_sample

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * The Gimii SDK requires a FragmentActivity: FlutterActivity extends
 * android.app.Activity and does not qualify. This is the only change the host
 * app needs on Android.
 */
class MainActivity : FlutterFragmentActivity()
