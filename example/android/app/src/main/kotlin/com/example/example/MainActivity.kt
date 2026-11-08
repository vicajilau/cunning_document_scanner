package biz.cunning.cunning_document_scanner_example

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openLanguageSettings") {
                    openLanguageSettings()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Opens the system page choosing this app's language, available from Android 13, or
     * the app's details page on older versions and devices without the former.
     */
    private fun openLanguageSettings() {
        val app = Uri.fromParts("package", packageName, null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                startActivity(Intent(Settings.ACTION_APP_LOCALE_SETTINGS, app))
                return
            } catch (_: ActivityNotFoundException) {
                // Some builds of Android drop the page; the details page is always there.
            }
        }
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, app))
    }

    private companion object {
        const val SETTINGS_CHANNEL = "cunning_document_scanner_example/settings"
    }
}
