# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Deferred Components / Play Core optional dependencies
-dontwarn com.google.android.play.core.**

# WebView Flutter & PayTR JavaScript Interfaces
-keepattributes *JavascriptInterface*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class android.webkit.** { *; }

# Firebase Messaging & Core
-keepattributes *Annotation*,EnclosingMethod,Signature
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }

# Models & JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Network / OkHttp / Dio
-dontwarn okio.**
-dontwarn okhttp3.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
