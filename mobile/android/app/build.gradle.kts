import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase/FCM: the google-services plugin turns android/app/google-services.json into the
// resources Firebase.initializeApp() reads. Without the file the plugin would fail the build,
// so it is applied only when the real config is present; otherwise the app builds and
// PushNotificationService skips Firebase at runtime.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("google-services.json not found in android/app; Firebase/FCM is disabled for this build.")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "app.tarak.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "app.tarak.mobile"
        // The Maps SDK key is injected by a Gradle property or CI secret.
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            providers.gradleProperty("GOOGLE_MAPS_ANDROID_API_KEY").orElse("").get()
        minSdk = flutter.minSdkVersion
        // Google Play: new apps / updates must target Android 16 (API 36) since 2026-08-31.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// A release BUNDLE (the Play Store upload) must never be debug-signed. The debug fallback in buildTypes.release below
// is only a convenience for local `flutter run --release` / APK smoke tests, so `bundleRelease` stops here unless
// android/key.properties is complete and points at a real keystore (see mobile/android/key.properties.example).
gradle.taskGraph.whenReady {
    val buildsReleaseBundle = allTasks.any { it.project == project && it.name.startsWith("bundle") && it.name.endsWith("Release") }
    if (buildsReleaseBundle) {
        val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        val blank = required.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
        val storePath = keystoreProperties.getProperty("storeFile")
        if (!hasReleaseSigning) {
            throw GradleException(
                "Release AAB needs a real upload keystore: android/key.properties is missing. " +
                    "Create the keystore and key.properties first (mobile/android/key.properties.example); " +
                    "a debug-signed bundle is refused on purpose."
            )
        }
        if (blank.isNotEmpty()) {
            throw GradleException("android/key.properties is incomplete, empty values: ${blank.joinToString(", ")}.")
        }
        if (!file(storePath).exists()) {
            throw GradleException("Keystore not found: ${file(storePath).absolutePath} (storeFile in android/key.properties is relative to android/app).")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
