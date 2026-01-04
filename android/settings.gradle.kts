/* settings.gradle (project root: android/) */
pluginManagement {
    // read flutter sdk path from local.properties
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def path = properties.getProperty("flutter.sdk")
        assert path != null, "flutter.sdk not set in local.properties"
        return path
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

/*
 * Plugins block: pick AGP and Kotlin versions here.
 * Use AGP >= 8.6.0 and Kotlin >= 2.1.0 (matching Kotlin Gradle plugin).
 */
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.7.0" apply false
    // START: FlutterFire Configuration
    id "com.google.gms.google-services" version "4.4.2" apply false
    // END: FlutterFire Configuration
    id "com.android.library"     version "8.7.0" apply false
    id "org.jetbrains.kotlin.android" version "2.1.0" apply false
}

rootProject.name = "adchat"
include ":app"
