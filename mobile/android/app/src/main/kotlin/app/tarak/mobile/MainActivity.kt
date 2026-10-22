package app.tarak.mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_ICON_CHANNEL).setMethodCallHandler { call, result ->
            val ids = call.argument<List<String>>("ids") ?: emptyList()
            val defaultId = call.argument<String>("default") ?: ""
            when (call.method) {
                "isSupported" -> result.success(true)
                "current" -> result.success(currentIcon(ids, defaultId))
                "change" -> {
                    val id = call.argument<String>("id")
                    if (id == null || !ids.contains(id)) {
                        result.error("invalid_icon", "Bilinmeyen ikon: $id", null)
                    } else {
                        try {
                            changeIcon(id, ids)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("icon_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Every selectable icon is an <activity-alias> (".IconAltin", ".IconLacivert", …, see AndroidManifest.xml);
    // exactly one is enabled and it is the launcher entry of the app.
    private fun alias(id: String) = ComponentName(packageName, "$ALIAS_PACKAGE.Icon${id.replaceFirstChar { it.uppercase() }}")

    private fun isEnabled(id: String, defaultId: String): Boolean =
        when (packageManager.getComponentEnabledSetting(alias(id))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> id == defaultId // the manifest enables only the default one
            else -> false
        }

    private fun currentIcon(ids: List<String>, defaultId: String): String =
        ids.firstOrNull { isEnabled(it, defaultId) } ?: defaultId

    private fun changeIcon(id: String, ids: List<String>) {
        // The new entry is enabled first so the app never has no launcher icon; DONT_KILL_APP keeps this screen running.
        packageManager.setComponentEnabledSetting(alias(id), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (other in ids) {
            if (other != id) {
                packageManager.setComponentEnabledSetting(alias(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
    }

    companion object {
        private const val APP_ICON_CHANNEL = "app.tarak.mobile/app_icon"
        private const val ALIAS_PACKAGE = "app.tarak.mobile"
    }
}
