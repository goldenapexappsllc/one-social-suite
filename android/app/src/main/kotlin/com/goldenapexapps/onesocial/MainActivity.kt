package com.goldenapexapps.onesocial

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Handles opening other installed apps directly by their Android package
/// name, rather than relying on each app's custom URL scheme (which many
/// apps -- Facebook and Instagram included -- only register narrowly for
/// specific deep-link paths, not for a generic "open the app" request).
/// This is the reliable Android-native way to do what canLaunchUrl's
/// custom-scheme check can't guarantee.
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.goldenapexapps.onesocial/app_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openApp") {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val launchIntent =
                        packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent != null) {
                        startActivity(launchIntent)
                        result.success(true)
                    } else {
                        // App isn't installed -- Dart side falls back to
                        // copy-only behavior when this returns false.
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
