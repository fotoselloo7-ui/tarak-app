package app.tarak.mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensurePushChannel()
    }

    // FCM background notifications use this exact channel ID. Android 8+
    // requires the channel to exist on-device before it can play alert sounds.
    private fun ensurePushChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(PUSH_CHANNEL_ID) != null) return

        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()
        val channel = NotificationChannel(
            PUSH_CHANNEL_ID, "Tarak bildirimleri", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Mesajlar, randevular, başvurular ve Tarak duyuruları"
            enableVibration(true)
            enableLights(true)
            setSound(sound, attributes)
        }
        manager.createNotificationChannel(channel)
    }

    private fun showForegroundPush(title: String, body: String, id: Int): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return false
        }
        ensurePushChannel()

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, PUSH_CHANNEL_ID)
        } else {
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getSystemService(NotificationManager::class.java).notify(id, notification)
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_PUSH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val title = call.argument<String>("title") ?: "Tarak"
                    val body = call.argument<String>("body") ?: ""
                    val id = call.argument<Int>("id") ?: System.currentTimeMillis().toInt()
                    if (body.isBlank()) {
                        result.success(false)
                    } else {
                        try {
                            result.success(showForegroundPush(title, body, id))
                        } catch (e: Exception) {
                            result.error("foreground_push_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
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
        private const val FOREGROUND_PUSH_CHANNEL = "app.tarak.mobile/notifications"
        private const val PUSH_CHANNEL_ID = "berberimgelsin_notifications"
        private const val APP_ICON_CHANNEL = "app.tarak.mobile/app_icon"
        private const val ALIAS_PACKAGE = "app.tarak.mobile"
    }
}
