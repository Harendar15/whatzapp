# ==== FIX for WindowManager, Folding, Extensions ====

-keep class androidx.window.** { *; }
-dontwarn androidx.window.**

-keep class androidx.window.extensions.** { *; }
-dontwarn androidx.window.extensions.**

-keep class androidx.window.sidecar.** { *; }
-dontwarn androidx.window.sidecar.**

# Agora native / JNI
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Flutter auto-generated code
-keep class io.flutter.embedding.** { *; }

# Because Flutter often needs reflective access
-keep class * extends android.app.Activity
-keep class * extends android.app.Application
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider

# Keep Play Core classes (deferred components / splitinstall)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep Flutter's deferred components manager and PlayStoreSplitApplication references
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.**
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
